from datetime import datetime


ALLOWED_ENTITIES = {
    "player",
    "atlas",
    "shared",
    "world"
}


ALLOWED_CATEGORIES = {
    "identity",
    "preference",
    "belief",
    "relationship",
    "event",
    "knowledge",
    "definition",
    "goal",
    "emotion",
    "experience"
}


ALLOWED_MEMORY_TYPES = {
    "semantic",
    "episodic"
}


ATLAS_MEMORY = {
    "memories": [],
    "next_id": 1
}


def normalize_text(value):
    if isinstance(value, str):
        return value.strip()

    return value


def validate_memory(
    entity,
    category,
    key,
    value,
    memory_type,
    confidence,
    importance
):
    if entity not in ALLOWED_ENTITIES:
        return False

    if category not in ALLOWED_CATEGORIES:
        return False

    if memory_type not in ALLOWED_MEMORY_TYPES:
        return False

    if not key:
        return False

    if value is None:
        return False

    if not 0.0 <= confidence <= 1.0:
        return False

    if not 0.0 <= importance <= 1.0:
        return False

    return True


def add_memory(
    entity,
    category,
    key,
    value,
    memory_type="semantic",
    source="player",
    confidence=1.0,
    importance=0.5
):
    entity = normalize_text(entity)
    category = normalize_text(category)
    key = normalize_text(key)
    value = normalize_text(value)
    memory_type = normalize_text(memory_type)
    source = normalize_text(source)

    try:
        confidence = float(confidence)
        importance = float(importance)
    except (TypeError, ValueError):
        return False

    confidence = max(0.0, min(confidence, 1.0))
    importance = max(0.0, min(importance, 1.0))

    if not validate_memory(
        entity=entity,
        category=category,
        key=key,
        value=value,
        memory_type=memory_type,
        confidence=confidence,
        importance=importance
    ):
        return False

    # Memórias semânticas representam conhecimento atual.
    # Portanto podem ser atualizadas.
    if memory_type == "semantic":

        for memory in ATLAS_MEMORY["memories"]:

            if (
                memory["memory_type"] == "semantic"
                and memory["entity"] == entity
                and memory["category"] == category
                and memory["key"] == key
            ):
                memory["value"] = value
                memory["source"] = source
                memory["confidence"] = confidence
                memory["importance"] = importance
                memory["updated_at"] = datetime.now().isoformat()

                return True

    # Memórias episódicas representam acontecimentos.
    # Não substituímos acontecimentos anteriores.
    memory = {
        "id": ATLAS_MEMORY["next_id"],
        "memory_type": memory_type,
        "entity": entity,
        "category": category,
        "key": key,
        "value": value,
        "source": source,
        "confidence": confidence,
        "importance": importance,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat()
    }

    ATLAS_MEMORY["memories"].append(memory)

    ATLAS_MEMORY["next_id"] += 1

    return True


def get_atlas_memory():
    return ATLAS_MEMORY


def reset_atlas_memory():
    ATLAS_MEMORY["memories"].clear()
    ATLAS_MEMORY["next_id"] = 1


def build_memory_context(memories=None):
    if memories is None:
        memories = ATLAS_MEMORY["memories"]

    if not memories:
        return "Nenhuma memória relevante."

    lines = []

    for memory in memories:
        lines.append(
            f"- [{memory['memory_type']}] "
            f"{memory['entity']} / "
            f"{memory['category']} / "
            f"{memory['key']} = "
            f"{memory['value']}"
        )

    return "\n".join(lines)