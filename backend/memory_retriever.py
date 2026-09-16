import re
import unicodedata
from difflib import SequenceMatcher

from backend.atlas_memory import ATLAS_MEMORY


STOP_WORDS = {
    "a", "o", "os", "as",
    "de", "da", "do", "das", "dos",
    "e", "em", "no", "na", "nos", "nas",
    "um", "uma", "uns", "umas",
    "para", "por", "com", "sem",
    "que", "se", "isso", "isto", "aquilo",
    "eu", "me", "mim",
    "meu", "minha", "meus", "minhas",
    "tu", "te", "ti",
    "teu", "tua", "teus", "tuas",
    "seu", "sua", "seus", "suas",
    "ele", "ela", "eles", "elas",
    "ja", "algum", "alguma",
    "alguns", "algumas",
    "ao", "aos",
    "atlas",
    "player",
    "jogador"
}


# =========================================================
# TEXTO
# =========================================================

def normalize_text(text):
    if not text:
        return ""

    text = str(text).lower()

    text = unicodedata.normalize(
        "NFD",
        text
    )

    text = "".join(
        char
        for char in text
        if unicodedata.category(char) != "Mn"
    )

    return text.strip()


def tokenize(text):
    text = normalize_text(text)

    words = re.findall(
        r"[a-z0-9_]+",
        text
    )

    return {
        word
        for word in words
        if word not in STOP_WORDS
        and len(word) >= 3
    }


def text_similarity(text_a, text_b):
    text_a = normalize_text(text_a)
    text_b = normalize_text(text_b)

    if not text_a or not text_b:
        return 0.0

    return SequenceMatcher(
        None,
        text_a,
        text_b
    ).ratio()


def build_memory_text(memory):
    return (
        f"{memory.get('key', '')} "
        f"{memory.get('value', '')}"
    ).strip()


# =========================================================
# STEM SIMPLES
# =========================================================

def simple_stem(word):
    """
    Stem MUITO leve para pequenas variações.

    Não tenta compreender sinónimos.
    Apenas aproxima flexões comuns.

    Ex.:
    desculpas -> desculpa
    ameaças   -> ameac
    ameaçou   -> ameac
    insultos  -> insult
    """

    word = normalize_text(word)

    suffixes = [
        "mente",
        "coes",
        "cao",
        "ando",
        "endo",
        "indo",
        "aram",
        "eram",
        "iram",
        "ou",
        "ei",
        "ar",
        "er",
        "ir",
        "es",
        "os",
        "as",
        "s"
    ]

    for suffix in suffixes:
        if (
            word.endswith(suffix)
            and len(word) - len(suffix) >= 4
        ):
            return word[:-len(suffix)]

    return word


def stem_tokens(text):
    return {
        simple_stem(token)
        for token in tokenize(text)
    }


# =========================================================
# RELEVÂNCIA
# =========================================================

def calculate_text_relevance(
    memory,
    original_message,
    semantic_query
):
    memory_text = build_memory_text(
        memory
    )

    query_tokens = tokenize(
        semantic_query
    )

    message_tokens = tokenize(
        original_message
    )

    memory_tokens = tokenize(
        memory_text
    )

    query_stems = stem_tokens(
        semantic_query
    )

    message_stems = stem_tokens(
        original_message
    )

    memory_stems = stem_tokens(
        memory_text
    )

    query_overlap = len(
        query_tokens & memory_tokens
    )

    message_overlap = len(
        message_tokens & memory_tokens
    )

    query_stem_overlap = len(
        query_stems & memory_stems
    )

    message_stem_overlap = len(
        message_stems & memory_stems
    )

    query_similarity = text_similarity(
        semantic_query,
        memory_text
    )

    message_similarity = text_similarity(
        original_message,
        memory_text
    )

    return {
        "query_overlap": query_overlap,
        "message_overlap": message_overlap,
        "query_stem_overlap": query_stem_overlap,
        "message_stem_overlap": message_stem_overlap,
        "query_similarity": query_similarity,
        "message_similarity": message_similarity
    }


def has_real_relevance(relevance):
    """
    Gate conservador.

    Para recuperar uma memória deve existir
    evidência lexical/conceitual real.

    Similaridade fuzzy SOZINHA não basta.
    """

    if relevance["query_overlap"] >= 1:
        return True

    if relevance["message_overlap"] >= 1:
        return True

    if relevance["query_stem_overlap"] >= 1:
        return True

    if relevance["message_stem_overlap"] >= 1:
        return True

    return False


# =========================================================
# SCORE
# =========================================================

def calculate_memory_score(
    memory,
    original_message,
    query_data,
    relevance
):
    """
    Metadados só ordenam memórias que JÁ
    passaram pelo gate de relevância.
    """

    score = 0.0

    score += (
        relevance["query_overlap"]
        * 5.0
    )

    score += (
        relevance["query_stem_overlap"]
        * 4.0
    )

    score += (
        relevance["message_overlap"]
        * 3.0
    )

    score += (
        relevance["message_stem_overlap"]
        * 2.0
    )

    # Similaridade agora é apenas desempate.
    score += (
        relevance["query_similarity"]
        * 0.5
    )

    score += (
        relevance["message_similarity"]
        * 0.25
    )

    requested_entity = normalize_text(
        query_data.get(
            "entity",
            "any"
        )
    )

    requested_category = normalize_text(
        query_data.get(
            "category",
            "any"
        )
    )

    memory_entity = normalize_text(
        memory.get(
            "entity",
            ""
        )
    )

    memory_category = normalize_text(
        memory.get(
            "category",
            ""
        )
    )

    # Entity/category só ajudam a ORDENAR.
    if (
        requested_entity != "any"
        and memory_entity == requested_entity
    ):
        score += 1.0

    if (
        requested_category != "any"
        and memory_category == requested_category
    ):
        score += 1.0

    try:
        importance = float(
            memory.get(
                "importance",
                0.5
            )
        )
    except (TypeError, ValueError):
        importance = 0.5

    try:
        confidence = float(
            memory.get(
                "confidence",
                1.0
            )
        )
    except (TypeError, ValueError):
        confidence = 1.0

    importance = max(
        0.0,
        min(importance, 1.0)
    )

    confidence = max(
        0.0,
        min(confidence, 1.0)
    )

    score += importance * 0.25
    score += confidence * 0.10

    return score


# =========================================================
# DIRECT KEY
# =========================================================

def find_direct_key_matches(message):
    """
    Fast-path para keys explicitamente
    mencionadas na mensagem.
    """

    message_tokens = tokenize(
        message
    )

    message_stems = stem_tokens(
        message
    )

    matches = []

    for memory in ATLAS_MEMORY["memories"]:
        key = memory.get(
            "key",
            ""
        )

        key_tokens = tokenize(
            key
        )

        key_stems = stem_tokens(
            key
        )

        if not key_tokens:
            continue

        if key_tokens.issubset(
            message_tokens
        ):
            matches.append(
                memory
            )
            continue

        if (
            key_stems
            and key_stems.issubset(
                message_stems
            )
        ):
            matches.append(
                memory
            )

    return matches


# =========================================================
# QUERY DO INTERPRETER
# =========================================================

def retrieve_from_query(
    message,
    query_data,
    limit
):
    semantic_query = str(
        query_data.get(
            "query",
            ""
        )
    ).strip()

    if not semantic_query:
        return []

    scored = []

    for memory in ATLAS_MEMORY["memories"]:
        relevance = calculate_text_relevance(
            memory=memory,
            original_message=message,
            semantic_query=semantic_query
        )

        if not has_real_relevance(
            relevance
        ):
            continue

        score = calculate_memory_score(
            memory=memory,
            original_message=message,
            query_data=query_data,
            relevance=relevance
        )

        scored.append(
            (score, memory)
        )

    scored.sort(
        key=lambda item: item[0],
        reverse=True
    )

    return [
        memory
        for _, memory
        in scored[:limit]
    ]


# =========================================================
# FALLBACK LOCAL
# =========================================================

def find_lexical_matches(
    message,
    limit=6
):
    """
    Usado apenas quando o Interpreter NÃO
    pediu recuperação explicitamente.
    """

    message_tokens = tokenize(
        message
    )

    message_stems = stem_tokens(
        message
    )

    if (
        not message_tokens
        and not message_stems
    ):
        return []

    scored = []

    for memory in ATLAS_MEMORY["memories"]:
        memory_text = build_memory_text(
            memory
        )

        memory_tokens = tokenize(
            memory_text
        )

        memory_stems = stem_tokens(
            memory_text
        )

        exact_overlap = len(
            message_tokens
            & memory_tokens
        )

        stem_overlap = len(
            message_stems
            & memory_stems
        )

        if (
            exact_overlap == 0
            and stem_overlap == 0
        ):
            continue

        score = (
            exact_overlap * 4.0
            + stem_overlap * 3.0
        )

        scored.append(
            (score, memory)
        )

    scored.sort(
        key=lambda item: item[0],
        reverse=True
    )

    return [
        memory
        for _, memory
        in scored[:limit]
    ]


# =========================================================
# FUNÇÃO PRINCIPAL
# =========================================================

def retrieve_relevant_memories(
    message,
    query_data=None,
    limit=6
):
    """
    Recupera somente memórias com evidência
    textual real de relevância.

    Ordem:
    1. key explícita;
    2. query semântica produzida pelo Interpreter;
    3. fallback lexical local.

    Regra fundamental:
    METADATA NUNCA CRIA RELEVÂNCIA.
    """

    memories = ATLAS_MEMORY.get(
        "memories",
        []
    )

    if not memories:
        return []

    if not isinstance(
        query_data,
        dict
    ):
        query_data = {
            "need_memory": False,
            "entity": "any",
            "category": "any",
            "query": ""
        }

    # -----------------------------------------------------
    # 1. DIRECT KEY
    # -----------------------------------------------------

    direct_matches = (
        find_direct_key_matches(
            message
        )
    )

    if direct_matches:
        return direct_matches[:limit]

    # -----------------------------------------------------
    # 2. INTERPRETER QUERY
    # -----------------------------------------------------

    if query_data.get(
        "need_memory"
    ) is True:
        return retrieve_from_query(
            message=message,
            query_data=query_data,
            limit=limit
        )

    # -----------------------------------------------------
    # 3. FALLBACK
    # -----------------------------------------------------

    return find_lexical_matches(
        message=message,
        limit=limit
    )