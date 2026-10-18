"""Memoria do Atlas 2.0.

Mantem a compatibilidade com a API antiga e permite separar memoria por run_id.
A memoria regista perspetivas e fontes; nao transforma automaticamente uma
lembranca, afirmacao do jogador ou hipotese em verdade objetiva.
"""

from datetime import datetime, timezone
from copy import deepcopy

ALLOWED_ENTITIES = {"player", "atlas", "shared", "world"}
ALLOWED_CATEGORIES = {
    "identity", "preference", "belief", "relationship", "event",
    "knowledge", "definition", "goal", "emotion", "experience"
}
ALLOWED_MEMORY_TYPES = {"semantic", "episodic"}
ALLOWED_EPISTEMIC_STATUS = {
    "accepted", "supported", "unverified", "doubtful", "contradicted"
}

# Estado legado, usado quando run_id nao e fornecido.
ATLAS_MEMORY = {"memories": [], "next_id": 1}
# Estado separado por partida. Cada partida tem os seus proprios IDs.
_RUN_MEMORIES = {}


def _new_store():
    return {"memories": [], "next_id": 1}


def _get_store(run_id=None, create=True):
    if run_id is None:
        return ATLAS_MEMORY
    if not isinstance(run_id, str) or not run_id.strip():
        return None
    run_id = run_id.strip()
    if create:
        return _RUN_MEMORIES.setdefault(run_id, _new_store())
    return _RUN_MEMORIES.get(run_id)


def normalize_text(value):
    return value.strip() if isinstance(value, str) else value


def normalize_optional_float(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        value = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if value != value:  # NaN
        return None
    return max(0.0, min(value, 1.0))


def _valid_score(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and 0.0 <= value <= 1.0


def validate_memory(entity, category, key, value, memory_type, confidence, importance):
    if entity not in ALLOWED_ENTITIES or category not in ALLOWED_CATEGORIES:
        return False
    if memory_type not in ALLOWED_MEMORY_TYPES:
        return False
    if not isinstance(key, str) or not key.strip():
        return False
    if not isinstance(value, (str, int, float, bool)) or isinstance(value, str) and not value.strip():
        return False
    if not _valid_score(confidence) or not _valid_score(importance):
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
    reaction_hint=None,
    run_id=None,
):
    """Adiciona memoria; semantica atualiza a mesma chave, episodica acumula.

    run_id opcional preserva a API anterior e permite isolamento por partida.
    confidence mede confianca no registo, nao prova que o seu conteudo e verdade.
    """
    entity = normalize_text(entity)
    category = normalize_text(category)
    key = normalize_text(key)
    memory_type = normalize_text(memory_type)
    source = normalize_text(source)
    epistemic_status = normalize_text(epistemic_status)
    reaction_hint = normalize_text(reaction_hint)

    if not isinstance(key, str):
        return False
    if not isinstance(value, (str, int, float, bool)) or value is None:
        return False
    if isinstance(value, str):
        value = value.strip()
    if not isinstance(source, str) or not source.strip():
        source = "unknown"
    if not isinstance(memory_type, str):
        return False
    if epistemic_status is not None and epistemic_status not in ALLOWED_EPISTEMIC_STATUS:
        epistemic_status = "unverified"

    confidence = normalize_optional_float(confidence)
    importance = normalize_optional_float(importance)
    if confidence is None or importance is None:
        return False
    plausibility = normalize_optional_float(plausibility)
    narrative_weight = normalize_optional_float(narrative_weight)

    if not validate_memory(entity, category, key, value, memory_type, confidence, importance):
        return False
    if epistemic_status is None:
        # A origem jogador nao e automaticamente validada como facto.
        epistemic_status = "unverified" if source == "player" else "supported"

    store = _get_store(run_id)
    if store is None:
        return False
    now = datetime.now(timezone.utc).isoformat()

    if memory_type == "semantic":
        for memory in store["memories"]:
            if (memory.get("memory_type") == "semantic"
                    and memory.get("entity") == entity
                    and memory.get("category") == category
                    and memory.get("key") == key):
                memory.update({
                    "value": value,
                    "source": source,
                    "confidence": confidence,
                    "importance": importance,
                    "epistemic_status": epistemic_status,
                    "plausibility": plausibility,
                    "narrative_weight": narrative_weight,
                    "reaction_hint": reaction_hint,
                    "updated_at": now,
                })
                return True

    memory = {
        "id": store["next_id"],
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
        "updated_at": now,
    }
    store["memories"].append(memory)
    store["next_id"] += 1
    return True


def get_atlas_memory(run_id=None):
    """Devolve uma vista do estado da memoria da partida indicada."""
    store = _get_store(run_id, create=False) if run_id is not None else ATLAS_MEMORY
    if store is None:
        return {"memories": [], "next_id": 1}
    return store


def reset_atlas_memory(run_id=None):
    """Limpa uma partida; sem run_id, limpa o estado legado."""
    if run_id is None:
        ATLAS_MEMORY["memories"].clear()
        ATLAS_MEMORY["next_id"] = 1
    elif isinstance(run_id, str) and run_id.strip():
        _RUN_MEMORIES[run_id.strip()] = _new_store()


def remove_run_memory(run_id):
    """Remove completamente o armazenamento em memoria de uma partida."""
    if not isinstance(run_id, str) or not run_id.strip():
        return False
    return _RUN_MEMORIES.pop(run_id.strip(), None) is not None


def build_memory_context(memories=None, run_id=None):
    """Cria contexto que conserva a origem e o estado epistemico das memorias."""
    if memories is None:
        store = _get_store(run_id, create=False) if run_id is not None else ATLAS_MEMORY
        memories = store["memories"] if store else []
    if not isinstance(memories, (list, tuple)) or not memories:
        return "Nenhuma memoria relevante registada."

    lines = [
        "Memorias registadas (nao assumir que todas sao factos objetivos):"
    ]
    for memory in memories:
        if not isinstance(memory, dict):
            continue
        memory_type = memory.get("memory_type", "desconhecido")
        entity = memory.get("entity", "desconhecida")
        category = memory.get("category", "desconhecida")
        key = memory.get("key", "sem_chave")
        value = memory.get("value", "sem_valor")
        source = memory.get("source", "unknown")
        status = memory.get("epistemic_status", "unverified")
        confidence = memory.get("confidence")
        line = f"- [{memory_type}] {entity} / {category} / {key} = {value}"
        line += f" | origem: {source} | estado: {status}"
        if confidence is not None:
            line += f" | confianca do registo: {confidence}"
        if memory.get("plausibility") is not None:
            line += f" | plausibilidade: {memory['plausibility']}"
        if memory.get("narrative_weight") is not None:
            line += f" | peso narrativo: {memory['narrative_weight']}"
        if memory.get("reaction_hint"):
            line += f" | indicacao de reacao: {memory['reaction_hint']}"
        lines.append(line)

    lines.append(
        "Regra: memorias nao substituem a lore canonica nem os resultados confirmados "
        "pelo gameplay. Uma afirmacao do jogador continua por verificar enquanto "
        "nao existir validacao explicita."
    )
    return "\n".join(lines)
