
"""Exportação e restauração do estado de Atlas por run.

Este módulo serializa os estados mantidos pelos módulos atuais
e permite restaurá-los a partir de um snapshot validado.
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


ATLAS_RUN_STATE_VERSION = 1


def _copy_state(value: Any) -> Any:
    return deepcopy(value)


def export_atlas_run_state(
    run_id: str,
    processed_autonomy_event_ids=None
) -> dict:
    """Cria um snapshot do estado atual do backend para uma run."""
    normalized_run_id = str(run_id or "").strip()

    if not normalized_run_id:
        raise ValueError("run_id é obrigatório")

    return {
        "state_version": ATLAS_RUN_STATE_VERSION,
        "run_id": normalized_run_id,
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "memory": _copy_state(atlas_memory.ATLAS_MEMORY),
        "knowledge": _copy_state(atlas_knowledge.ATLAS_KNOWLEDGE),
        "autonomy": _copy_state(autonomy_state.AUTONOMY_STATE),
        "discoveries": _copy_state(discovery_state.DISCOVERY_STATE),
        "gameplay_context": _copy_state(
            gameplay_context.GAMEPLAY_CONTEXT
        ),
        "narrative": _copy_state(narrative_state.NARRATIVE_STATE),
        "relationship": _copy_state(
            relationship_engine.RELATIONSHIP_STATE
        ),
        "conversation": _copy_state(
            conversation_context.CONVERSATION_HISTORY
        ),
        "social": _copy_state(social_state.SOCIAL_STATE),
        "world": _copy_state(world_state.WORLD_STATE),
        "processed_autonomy_event_ids": sorted(
            str(event_id)
            for event_id in (processed_autonomy_event_ids or set())
        ),
    }


def _replace_dict(
    target: dict,
    source: Any,
    field_name: str
) -> None:
    if not isinstance(source, dict):
        raise ValueError(
            f"Campo inválido no snapshot: {field_name}"
        )

    target.clear()
    target.update(_copy_state(source))


def _replace_list(
    target: list,
    source: Any,
    field_name: str
) -> None:
    if not isinstance(source, list):
        raise ValueError(
            f"Campo inválido no snapshot: {field_name}"
        )

    target.clear()
    target.extend(_copy_state(source))


def validate_atlas_run_state(
    snapshot: Any,
    expected_run_id: str | None = None
) -> tuple[bool, str]:
    if not isinstance(snapshot, dict):
        return False, "O estado recebido tem de ser um objeto JSON."

    if snapshot.get("state_version") != ATLAS_RUN_STATE_VERSION:
        return False, "Versão do estado de Atlas não suportada."

    run_id = str(snapshot.get("run_id", "")).strip()

    if not run_id:
        return False, "O snapshot não contém run_id."

    if (
        expected_run_id is not None
        and run_id != str(expected_run_id).strip()
    ):
        return False, (
            "O run_id do snapshot não corresponde à run solicitada."
        )

    required_fields = (
        "memory",
        "knowledge",
        "autonomy",
        "discoveries",
        "gameplay_context",
        "narrative",
        "relationship",
        "conversation",
        "social",
        "world",
    )

    for field_name in required_fields:
        expected_type = (
            list if field_name == "conversation" else dict
        )

        if not isinstance(snapshot.get(field_name), expected_type):
            return False, (
                f"Campo ausente ou inválido no snapshot: {field_name}."
            )

    event_ids = snapshot.get("processed_autonomy_event_ids", [])

    if (
        not isinstance(event_ids, list)
        or not all(isinstance(item, str) for item in event_ids)
    ):
        return False, (
            "Campo inválido no snapshot: "
            "processed_autonomy_event_ids."
        )

    return True, "ok"


def restore_atlas_run_state(
    snapshot: dict,
    expected_run_id: str | None = None
) -> dict:
    """Valida e restaura os estados globais incluídos no snapshot."""
    valid, reason = validate_atlas_run_state(
        snapshot,
        expected_run_id
    )

    if not valid:
        raise ValueError(reason)

    _replace_dict(
        atlas_memory.ATLAS_MEMORY,
        snapshot["memory"],
        "memory"
    )
    _replace_dict(
        atlas_knowledge.ATLAS_KNOWLEDGE,
        snapshot["knowledge"],
        "knowledge"
    )
    _replace_dict(
        autonomy_state.AUTONOMY_STATE,
        snapshot["autonomy"],
        "autonomy"
    )
    _replace_dict(
        discovery_state.DISCOVERY_STATE,
        snapshot["discoveries"],
        "discoveries"
    )
    _replace_dict(
        gameplay_context.GAMEPLAY_CONTEXT,
        snapshot["gameplay_context"],
        "gameplay_context"
    )
    _replace_dict(
        narrative_state.NARRATIVE_STATE,
        snapshot["narrative"],
        "narrative"
    )
    _replace_dict(
        relationship_engine.RELATIONSHIP_STATE,
        snapshot["relationship"],
        "relationship"
    )
    _replace_list(
        conversation_context.CONVERSATION_HISTORY,
        snapshot["conversation"],
        "conversation"
    )
    _replace_dict(
        social_state.SOCIAL_STATE,
        snapshot["social"],
        "social"
    )
    _replace_dict(
        world_state.WORLD_STATE,
        snapshot["world"],
        "world"
    )

    return {
        "run_id": snapshot["run_id"],
        "state_version": ATLAS_RUN_STATE_VERSION,
        "restored": True,
        "processed_autonomy_event_ids": list(
            snapshot.get("processed_autonomy_event_ids", [])
        ),
    }


def reset_atlas_run_state(run_id: str) -> dict:
    """Reinicia os módulos atuais para iniciar uma run sem memórias antigas."""
    normalized_run_id = str(run_id or "").strip()

    if not normalized_run_id:
        raise ValueError("run_id é obrigatório")

    atlas_memory.reset_atlas_memory()
    atlas_knowledge.reset_atlas_knowledge()
    autonomy_state.reset_autonomy_state()
    discovery_state.reset_discovery_state()
    gameplay_context.reset_gameplay_context()
    narrative_state.reset_narrative_state()
    relationship_engine.reset_relationship_state()
    conversation_context.reset_conversation_context()

    social_state.SOCIAL_STATE.clear()
    social_state.SOCIAL_STATE.update({
        "atlas_irritation": 0
    })

    world_state.WORLD_STATE.clear()
    world_state.WORLD_STATE.update({
        "player": {
            "position": {
                "x": 0.0,
                "y": 0.0
            }
        },
        "atlas": {
            "position": {
                "x": 2.0,
                "y": 0.0
            },
            "radar_range": 50.0,
            "current_detections": []
        },
        "ship": {
            "status": "damaged",
            "position": {
                "x": 0.0,
                "y": 0.0
            }
        },
        "environment": {
            "planet_name": None,
            "weather": "unknown",
            "time_of_day": "unknown"
        },
        "mission": {
            "current_objective": "evaluate_crash_site"
        }
    })

    return {
        "run_id": normalized_run_id,
        "reset": True
    }
