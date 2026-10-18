"""Exportação, validação, restauração e reinício do estado do Atlas por run.

Este módulo mantém compatibilidade com os módulos de estado atuais, que ainda
expõem estado global. O run_id identifica e valida o snapshot, mas o isolamento
real entre partidas exige que o backend passe a guardar estados por run_id.
"""

from copy import deepcopy
from datetime import datetime, timezone
from typing import Any

from backend import atlas_memory
from backend import atlas_knowledge
from backend import autonomy_state
from backend import discovery_state
from backend import gameplay_context
from backend import narrative_state
from backend import relationship_engine
from backend import conversation_context
from backend import social_state
from backend import world_state

ATLAS_RUN_STATE_VERSION = 2


# Estado inicial canónico de uma nova partida. Não inferir aqui detalhes
# ambientais, descobertas ou causas do acidente que o gameplay não confirmou.
def _default_world_state() -> dict:
    return {
        "player": {"position": {"x": 0.0, "y": 0.0}},
        "atlas": {
            "position": {"x": 2.0, "y": 0.0},
            "radar_range": 50.0,
            "current_detections": [],
        },
        "ship": {
            "status": "damaged",
            "position": {"x": 0.0, "y": 0.0},
        },
        "environment": {
            "planet_name": None,
            "weather": "unknown",
            "time_of_day": "unknown",
        },
        "mission": {"current_objective": "evaluate_crash_site"},
    }


def _copy_state(value: Any) -> Any:
    return deepcopy(value)


def _normalize_run_id(run_id: Any) -> str:
    normalized = str(run_id or "").strip()
    if not normalized:
        raise ValueError("run_id é obrigatório.")
    return normalized


def _get_live_states() -> dict:
    return {
        "memory": atlas_memory.ATLAS_MEMORY,
        "knowledge": atlas_knowledge.ATLAS_KNOWLEDGE,
        "autonomy": autonomy_state.AUTONOMY_STATE,
        "discoveries": discovery_state.DISCOVERY_STATE,
        "gameplay_context": gameplay_context.GAMEPLAY_CONTEXT,
        "narrative": narrative_state.NARRATIVE_STATE,
        "relationship": relationship_engine.RELATIONSHIP_STATE,
        "conversation": conversation_context.CONVERSATION_HISTORY,
        "social": social_state.SOCIAL_STATE,
        "world": world_state.WORLD_STATE,
    }


def export_atlas_run_state(run_id: str, processed_autonomy_event_ids=None) -> dict:
    """Cria um snapshot independente dos estados atuais do backend."""
    normalized_run_id = _normalize_run_id(run_id)
    states = _get_live_states()
    event_ids = processed_autonomy_event_ids or set()
    if not isinstance(event_ids, (set, list, tuple)):
        raise ValueError("processed_autonomy_event_ids tem de ser uma coleção.")

    return {
        "state_version": ATLAS_RUN_STATE_VERSION,
        "run_id": normalized_run_id,
        "exported_at": datetime.now(timezone.utc).isoformat(),
        **{name: _copy_state(value) for name, value in states.items()},
        "processed_autonomy_event_ids": sorted({str(item) for item in event_ids}),
    }


def validate_atlas_run_state(snapshot: Any, expected_run_id: str | None = None) -> tuple[bool, str]:
    """Valida o formato completo antes de alterar qualquer estado em memória."""
    if not isinstance(snapshot, dict):
        return False, "O estado recebido tem de ser um objeto JSON."
    if snapshot.get("state_version") != ATLAS_RUN_STATE_VERSION:
        return False, "Versão do estado de Atlas não suportada."

    run_id = str(snapshot.get("run_id", "")).strip()
    if not run_id:
        return False, "O snapshot não contém run_id."
    if expected_run_id is not None and run_id != str(expected_run_id).strip():
        return False, "O run_id do snapshot não corresponde à run solicitada."

    live_states = _get_live_states()
    for field_name, live_value in live_states.items():
        expected_type = list if isinstance(live_value, list) else dict
        if not isinstance(snapshot.get(field_name), expected_type):
            return False, f"Campo ausente ou inválido no snapshot: {field_name}."

    memory = snapshot["memory"]
    if not isinstance(memory.get("memories"), list):
        return False, "Campo inválido no snapshot: memory.memories."
    if not isinstance(memory.get("next_id"), int) or memory["next_id"] < 1:
        return False, "Campo inválido no snapshot: memory.next_id."

    knowledge = snapshot["knowledge"]
    for key in ("confirmed", "hypotheses", "player_claims", "unknowns"):
        if not isinstance(knowledge.get(key), list):
            return False, f"Campo inválido no snapshot: knowledge.{key}."

    autonomy = snapshot["autonomy"]
    for key in ("autonomy", "self_assertion", "identity_awareness", "curiosity", "protocol_adherence"):
        value = autonomy.get(key)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 <= value <= 100:
            return False, f"Campo inválido no snapshot: autonomy.{key}."

    event_ids = snapshot.get("processed_autonomy_event_ids", [])
    if not isinstance(event_ids, list) or not all(isinstance(item, str) for item in event_ids):
        return False, "Campo inválido no snapshot: processed_autonomy_event_ids."

    return True, "ok"


def _replace_state(target: Any, source: Any, field_name: str) -> None:
    """Substitui um dicionário/lista sem mudar a identidade do objeto global."""
    if isinstance(target, dict) and isinstance(source, dict):
        target.clear()
        target.update(_copy_state(source))
        return
    if isinstance(target, list) and isinstance(source, list):
        target.clear()
        target.extend(_copy_state(source))
        return
    raise ValueError(f"Tipo de estado incompatível: {field_name}.")


def restore_atlas_run_state(snapshot: dict, expected_run_id: str | None = None) -> dict:
    """Valida e restaura o snapshot; se ocorrer erro, tenta repor o estado anterior."""
    valid, reason = validate_atlas_run_state(snapshot, expected_run_id)
    if not valid:
        raise ValueError(reason)

    live_states = _get_live_states()
    backup = {name: _copy_state(value) for name, value in live_states.items()}
    try:
        for name, target in live_states.items():
            _replace_state(target, snapshot[name], name)
    except Exception:
        for name, target in live_states.items():
            _replace_state(target, backup[name], name)
        raise

    return {
        "run_id": snapshot["run_id"],
        "state_version": ATLAS_RUN_STATE_VERSION,
        "restored": True,
        "processed_autonomy_event_ids": list(snapshot.get("processed_autonomy_event_ids", [])),
    }


def reset_atlas_run_state(run_id: str) -> dict:
    """Reinicia os módulos atuais para uma nova partida, sem reutilizar estado anterior."""
    normalized_run_id = _normalize_run_id(run_id)

    atlas_memory.reset_atlas_memory()
    atlas_knowledge.reset_atlas_knowledge()
    autonomy_state.reset_autonomy_state()
    discovery_state.reset_discovery_state()
    gameplay_context.reset_gameplay_context()
    narrative_state.reset_narrative_state()
    relationship_engine.reset_relationship_state()
    conversation_context.reset_conversation_context()

    social_state.SOCIAL_STATE.clear()
    social_state.SOCIAL_STATE.update({"atlas_irritation": 0})

    world_state.WORLD_STATE.clear()
    world_state.WORLD_STATE.update(_default_world_state())

    return {"run_id": normalized_run_id, "state_version": ATLAS_RUN_STATE_VERSION, "reset": True}
