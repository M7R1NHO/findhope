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


ALLOWED_EPISTEMIC_STATUS = {
    "accepted",
    "supported",
    "unverified",
    "doubtful",
    "contradicted"
}


ATLAS_MEMORY = {
    "memories": [],
    "next_id": 1
}


def normalize_text(value):
    if isinstance(value, str):
        return value.strip()

    return value


def normalize_optional_float(value):
    if value is None:
        return None

    try:
        value = float(value)
    except (TypeError, ValueError):
        return None

    return max(0.0, min(value, 1.0))


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
    memory_type,
    entity,
    category,
    key,
    value,
    source="player",
    confidence=1.0,
    importance=0.5,
    epistemic_status=None,
    plausibility=None,
    narrative_weight=None,
    reaction_hint=None
):
    entity = normalize_text(entity)
    category = normalize_text(category)
    key = normalize_text(key)
    value = normalize_text(value)
    memory_type = normalize_text(memory_type)
    source = normalize_text(source)

    epistemic_status = normalize_text(epistemic_status)
    reaction_hint = normalize_text(reaction_hint)

    try:
        confidence = float(confidence)
        importance = float(importance)
    except (TypeError, ValueError):
        return False

    confidence = max(0.0, min(confidence, 1.0))
    importance = max(0.0, min(importance, 1.0))

    plausibility = normalize_optional_float(plausibility)
    narrative_weight = normalize_optional_float(narrative_weight)

    if (
        epistemic_status is not None
        and epistemic_status not in ALLOWED_EPISTEMIC_STATUS
    ):
        epistemic_status = "unverified"

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

    now = datetime.now().isoformat()

    # ---------------------------------------------------------
    # MEMÓRIA SEMÂNTICA
    # ---------------------------------------------------------
    # Representa conhecimento/estado atual.
    # Se já existir a mesma chave lógica, atualizamos.
    # ---------------------------------------------------------

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

                memory["epistemic_status"] = epistemic_status
                memory["plausibility"] = plausibility
                memory["narrative_weight"] = narrative_weight
                memory["reaction_hint"] = reaction_hint

                memory["updated_at"] = now

                return True

    # ---------------------------------------------------------
    # MEMÓRIA NOVA
    # ---------------------------------------------------------
    # Episódicas não substituem acontecimentos anteriores.
    # Semânticas chegam aqui apenas quando ainda não existem.
    # ---------------------------------------------------------

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

        "epistemic_status": epistemic_status,
        "plausibility": plausibility,
        "narrative_weight": narrative_weight,
        "reaction_hint": reaction_hint,

        "created_at": now,
        "updated_at": now
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

        line = (
            f"- [{memory['memory_type']}] "
            f"{memory['entity']} / "
            f"{memory['category']} / "
            f"{memory['key']} = "
            f"{memory['value']}"
        )

        epistemic_status = memory.get("epistemic_status")
        plausibility = memory.get("plausibility")
        narrative_weight = memory.get("narrative_weight")
        reaction_hint = memory.get("reaction_hint")

        if epistemic_status is not None:
            line += (
                f"\n  epistemic_status: "
                f"{epistemic_status}"
            )

        if plausibility is not None:
            line += (
                f"\n  plausibility: "
                f"{plausibility}"
            )

        if narrative_weight is not None:
            line += (
                f"\n  narrative_weight: "
                f"{narrative_weight}"
            )

        if reaction_hint is not None:
            line += (
                f"\n  reaction_hint: "
                f"{reaction_hint}"
            )

        lines.append(line)

    return "\n".join(lines)