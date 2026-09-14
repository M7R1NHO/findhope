import re
from difflib import SequenceMatcher

from backend.atlas_memory import ATLAS_MEMORY


STOP_WORDS = {
    "a", "o", "os", "as",
    "de", "da", "do", "das", "dos",
    "e", "é", "em", "no", "na",
    "um", "uma", "para", "por",
    "que", "se"
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

    # -------------------------
    # ENTIDADE
    # -------------------------

    if requested_entity != "any":

        if memory.get("entity") == requested_entity:
            score += 5.0
        else:
            score -= 3.0

    # -------------------------
    # CATEGORIA
    # -------------------------

    if requested_category != "any":

        if memory.get("category") == requested_category:
            score += 4.0
        else:
            score -= 2.0

    # -------------------------
    # TEXTO DA MEMÓRIA
    # -------------------------

    memory_text = (
        f"{memory.get('key', '')} "
        f"{memory.get('value', '')}"
    )

    query_tokens = tokenize(semantic_query)
    memory_tokens = tokenize(memory_text)

    overlap = len(
        query_tokens.intersection(
            memory_tokens
        )
    )

    score += overlap * 2.0

    # -------------------------
    # FUZZY MATCH
    # -------------------------

    similarity = text_similarity(
        semantic_query,
        memory_text
    )

    score += similarity * 3.0

    # Também comparamos diretamente
    # a mensagem original.
    original_similarity = text_similarity(
        original_message,
        memory_text
    )

    score += original_similarity * 1.5

    # -------------------------
    # IMPORTÂNCIA
    # -------------------------

    importance = float(
        memory.get(
            "importance",
            0.5
        )
    )

    score += importance

    # -------------------------
    # CONFIANÇA
    # -------------------------

    confidence = float(
        memory.get(
            "confidence",
            1.0
        )
    )

    score += confidence * 0.5

    return score


def retrieve_relevant_memories(
    message,
    query_data,
    limit=6
):
    if not query_data:
        return []

    if not query_data.get(
        "need_memory",
        False
    ):
        return []

    memories = ATLAS_MEMORY["memories"]

    if not memories:
        return []

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

    return [
        memory
        for score, memory
        in scored[:limit]
        if score > 0
    ]