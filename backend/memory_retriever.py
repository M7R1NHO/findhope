import re
from difflib import SequenceMatcher

from backend.atlas_memory import ATLAS_MEMORY


STOP_WORDS = {
    "a", "o", "os", "as",
    "de", "da", "do", "das", "dos",
    "e", "é", "em", "no", "na",
    "um", "uma", "para", "por",
    "que", "se",
    "eu", "meu", "minha", "meus", "minhas",
    "tu", "teu", "tua", "seu", "sua"
}


def tokenize(text):
    if not text:
        return set()

    words = re.findall(
        r"[A-Za-zÀ-ÿ0-9_]+",
        str(text).lower()
    )

    return {
        word
        for word in words
        if word not in STOP_WORDS
        and len(word) > 1
    }


def text_similarity(text_a, text_b):
    if not text_a or not text_b:
        return 0.0

    return SequenceMatcher(
        None,
        str(text_a).lower(),
        str(text_b).lower()
    ).ratio()


def build_memory_text(memory):
    return (
        f"{memory.get('key', '')} "
        f"{memory.get('value', '')}"
    ).strip()


def calculate_memory_score(
    memory,
    original_message,
    query_data
):
    score = 0.0

    requested_entity = query_data.get(
        "entity",
        "any"
    )

    requested_category = query_data.get(
        "category",
        "any"
    )

    semantic_query = query_data.get(
        "query",
        ""
    )

    # --------------------------------------------------
    # ENTIDADE
    # --------------------------------------------------

    if requested_entity != "any":
        if memory.get("entity") == requested_entity:
            score += 5.0
        else:
            score -= 3.0

    # --------------------------------------------------
    # CATEGORIA
    # --------------------------------------------------

    if requested_category != "any":
        if memory.get("category") == requested_category:
            score += 4.0
        else:
            score -= 2.0

    # --------------------------------------------------
    # TEXTO DA MEMÓRIA
    # --------------------------------------------------

    memory_text = build_memory_text(memory)

    query_tokens = tokenize(semantic_query)
    message_tokens = tokenize(original_message)
    memory_tokens = tokenize(memory_text)

    # Query produzida pelo Interpreter
    query_overlap = len(
        query_tokens.intersection(memory_tokens)
    )

    score += query_overlap * 2.0

    # Mensagem original do jogador
    message_overlap = len(
        message_tokens.intersection(memory_tokens)
    )

    score += message_overlap * 2.0

    # --------------------------------------------------
    # FUZZY MATCH
    # --------------------------------------------------

    query_similarity = text_similarity(
        semantic_query,
        memory_text
    )

    score += query_similarity * 3.0

    original_similarity = text_similarity(
        original_message,
        memory_text
    )

    score += original_similarity * 2.0

    # --------------------------------------------------
    # IMPORTÂNCIA
    # --------------------------------------------------

    try:
        importance = float(
            memory.get(
                "importance",
                0.5
            )
        )
    except (TypeError, ValueError):
        importance = 0.5

    importance = max(
        0.0,
        min(importance, 1.0)
    )

    score += importance

    # --------------------------------------------------
    # CONFIANÇA
    # --------------------------------------------------

    try:
        confidence = float(
            memory.get(
                "confidence",
                1.0
            )
        )
    except (TypeError, ValueError):
        confidence = 1.0

    confidence = max(
        0.0,
        min(confidence, 1.0)
    )

    score += confidence * 0.5

    return score


def find_direct_key_matches(message):
    """
    Fast-path para quando o jogador escreve
    explicitamente uma key conhecida.
    """

    message_tokens = tokenize(message)

    matches = []

    for memory in ATLAS_MEMORY["memories"]:
        key = str(
            memory.get("key", "")
        ).lower().strip()

        if not key:
            continue

        key_tokens = tokenize(key)

        if (
            key_tokens
            and key_tokens.issubset(
                message_tokens
            )
        ):
            matches.append(memory)

    return matches


def find_lexical_matches(
    message,
    limit=6
):
    """
    Fallback genérico.

    Mesmo quando o Memory Interpreter diz
    need_memory=false, verificamos se a mensagem
    atual tem relação lexical suficiente com
    alguma memória existente.

    Isto evita depender exclusivamente da key
    interna criada pelo modelo.
    """

    message_tokens = tokenize(message)

    if not message_tokens:
        return []

    scored = []

    for memory in ATLAS_MEMORY["memories"]:
        memory_text = build_memory_text(memory)
        memory_tokens = tokenize(memory_text)

        overlap = len(
            message_tokens.intersection(
                memory_tokens
            )
        )

        similarity = text_similarity(
            message,
            memory_text
        )

        score = 0.0

        # Correspondência lexical direta
        score += overlap * 3.0

        # Correspondência fuzzy
        score += similarity * 2.0

        # Só aceitamos como fallback quando existe
        # alguma evidência textual razoável.
        if overlap > 0 or similarity >= 0.45:
            scored.append(
                (score, memory)
            )

    scored.sort(
        key=lambda item: item[0],
        reverse=True
    )

    return [
        memory
        for score, memory
        in scored[:limit]
    ]


def retrieve_relevant_memories(
    message,
    query_data,
    limit=6
):
    memories = ATLAS_MEMORY["memories"]

    if not memories:
        return []

    # --------------------------------------------------
    # 1. KEY EXPLÍCITA
    # --------------------------------------------------

    direct_matches = find_direct_key_matches(
        message
    )

    if direct_matches:
        return direct_matches[:limit]

    # --------------------------------------------------
    # 2. QUERY SEMÂNTICA DO INTERPRETER
    # --------------------------------------------------

    if (
        isinstance(query_data, dict)
        and query_data.get(
            "need_memory",
            False
        )
    ):
        scored = []

        for memory in memories:
            score = calculate_memory_score(
                memory=memory,
                original_message=message,
                query_data=query_data
            )

            scored.append(
                (score, memory)
            )

        scored.sort(
            key=lambda item: item[0],
            reverse=True
        )

        results = [
            memory
            for score, memory
            in scored[:limit]
            if score > 0
        ]

        if results:
            return results

    # --------------------------------------------------
    # 3. FALLBACK LEXICAL
    # --------------------------------------------------
    #
    # O Interpreter pode ocasionalmente decidir
    # need_memory=false numa pergunta que claramente
    # se relaciona com algo já guardado.
    #
    # Nesse caso fazemos uma busca barata local.
    # --------------------------------------------------

    return find_lexical_matches(
        message=message,
        limit=limit
    )