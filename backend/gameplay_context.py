"""Contexto de gameplay confirmado, isolado por partida, para o Atlas 2.0."""

from copy import deepcopy
from typing import Any

MAX_GAMEPLAY_EVENTS = 40


def _new_state() -> dict:
    return {"events": {}}


# Estado legado/predefinido para manter compatibilidade com chamadas antigas.
GAMEPLAY_CONTEXT = _new_state()
_RUN_GAMEPLAY_CONTEXTS: dict[str, dict] = {}


def _normalize_run_id(run_id: Any = None) -> str | None:
    if run_id is None:
        return None
    normalized = str(run_id).strip()
    return normalized or None


def _get_state(run_id: Any = None, create: bool = True) -> dict:
    normalized = _normalize_run_id(run_id)
    if normalized is None:
        return GAMEPLAY_CONTEXT
    if normalized not in _RUN_GAMEPLAY_CONTEXTS and create:
        _RUN_GAMEPLAY_CONTEXTS[normalized] = _new_state()
    return _RUN_GAMEPLAY_CONTEXTS.get(normalized, _new_state())


def register_gameplay_event(
    event_id: str,
    event_type: str,
    description: str,
    active: bool = True,
    run_id: str | None = None,
):
    """Regista um evento fornecido pelo gameplay; não executa ações no jogo."""
    event_id = str(event_id or "").strip()
    event_type = str(event_type or "").strip()
    description = str(description or "").strip()

    if not event_id or not event_type or not description:
        return False

    state = _get_state(run_id)
    events = state.setdefault("events", {})
    events[event_id] = {
        "event_id": event_id,
        "event_type": event_type,
        "description": description,
        "active": bool(active),
    }

    while len(events) > MAX_GAMEPLAY_EVENTS:
        oldest_key = next(iter(events))
        events.pop(oldest_key, None)

    return True


def set_gameplay_event_active(
    event_id: str,
    active: bool,
    run_id: str | None = None,
):
    event_id = str(event_id or "").strip()
    if not event_id:
        return False

    event = _get_state(run_id, create=False).get("events", {}).get(event_id)
    if event is None:
        return False

    event["active"] = bool(active)
    return True


def get_gameplay_context(run_id: str | None = None):
    """Devolve uma cópia para impedir mutações acidentais do estado interno."""
    return deepcopy(_get_state(run_id, create=False))


def build_gameplay_context(run_id: str | None = None):
    """Constrói contexto apenas a partir de eventos de gameplay registados."""
    events = _get_state(run_id, create=False).get("events", {})
    active_events = [
        event for event in events.values()
        if isinstance(event, dict) and event.get("active", False)
    ]

    if not active_events:
        return "Nenhum acontecimento de gameplay ativo."

    lines = [
        "Os eventos seguintes foram registados pelo gameplay. "
        "Não infiras ações, resultados ou progressão que não estejam descritos:"
    ]
    for event in active_events:
        description = str(event.get("description", "")).strip()
        event_type = str(event.get("event_type", "unknown")).strip()
        event_id = str(event.get("event_id", "unknown")).strip()
        if description:
            lines.append(
                f"- {description} (tipo={event_type}, id={event_id})"
            )
    return "\n".join(lines)


def reset_gameplay_context(run_id: str | None = None):
    """Limpa uma partida específica; sem run_id, limpa o estado legado global."""
    normalized = _normalize_run_id(run_id)
    if normalized is None:
        GAMEPLAY_CONTEXT.clear()
        GAMEPLAY_CONTEXT.update(_new_state())
        return
    _RUN_GAMEPLAY_CONTEXTS.pop(normalized, None)


def reset_all_gameplay_contexts():
    """Limpa o estado legado e todos os estados isolados por run."""
    reset_gameplay_context()
    _RUN_GAMEPLAY_CONTEXTS.clear()
