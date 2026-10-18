"""Estado físico atual do mundo para Find Hope / Atlas 2.0.

O estado aqui representa dados técnicos do gameplay, não conhecimento narrativo.
As posições e deteções devem ser atualizadas a partir do Godot.
"""
from copy import deepcopy
from threading import RLock
from typing import Any

DEFAULT_WORLD_STATE: dict[str, Any] = {
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

# Compatibilidade com módulos antigos que importam WORLD_STATE diretamente.
# Para isolamento real entre partidas, usar get_world_state(run_id=...).
WORLD_STATE: dict[str, Any] = deepcopy(DEFAULT_WORLD_STATE)
_RUN_STATES: dict[str, dict[str, Any]] = {}
_LOCK = RLock()


def _normalise_run_id(run_id: str | None) -> str | None:
    if run_id is None:
        return None
    if not isinstance(run_id, str) or not run_id.strip():
        raise ValueError("run_id tem de ser uma string não vazia ou None.")
    return run_id.strip()[:255]


def get_world_state(run_id: str | None = None) -> dict[str, Any]:
    """Devolve uma cópia do estado global legado ou da partida indicada."""
    key = _normalise_run_id(run_id)
    with _LOCK:
        if key is None:
            return deepcopy(WORLD_STATE)
        if key not in _RUN_STATES:
            _RUN_STATES[key] = deepcopy(DEFAULT_WORLD_STATE)
        return deepcopy(_RUN_STATES[key])


def update_world_state(updates: dict[str, Any], run_id: str | None = None) -> dict[str, Any]:
    """Atualiza recursivamente o estado de uma partida e devolve uma cópia.

    Os valores recebidos são dados técnicos do jogo. Não use esta função para
    transformar hipóteses ou falas da LLM em factos do mundo.
    """
    if not isinstance(updates, dict):
        raise ValueError("updates tem de ser um dicionário.")
    key = _normalise_run_id(run_id)
    with _LOCK:
        target = WORLD_STATE if key is None else _RUN_STATES.setdefault(
            key, deepcopy(DEFAULT_WORLD_STATE)
        )
        _deep_update(target, updates)
        return deepcopy(target)


def _deep_update(target: dict[str, Any], updates: dict[str, Any]) -> None:
    for key, value in updates.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            _deep_update(target[key], value)
        else:
            target[key] = deepcopy(value)


def reset_world_state(run_id: str | None = None) -> dict[str, Any]:
    """Repõe o estado padrão; com run_id, afeta apenas essa partida."""
    key = _normalise_run_id(run_id)
    with _LOCK:
        if key is None:
            WORLD_STATE.clear()
            WORLD_STATE.update(deepcopy(DEFAULT_WORLD_STATE))
            return deepcopy(WORLD_STATE)
        _RUN_STATES[key] = deepcopy(DEFAULT_WORLD_STATE)
        return deepcopy(_RUN_STATES[key])


def remove_run_state(run_id: str) -> bool:
    """Remove o estado isolado de uma partida terminada. Nunca afeta o estado legado."""
    key = _normalise_run_id(run_id)
    if key is None:
        raise ValueError("run_id é obrigatório para remover o estado de uma partida.")
    with _LOCK:
        return _RUN_STATES.pop(key, None) is not None


def set_position(entity: str, x: float, y: float, run_id: str | None = None) -> dict[str, Any]:
    """Atualiza a posição de player, atlas ou ship com coordenadas fornecidas pelo gameplay."""
    if entity not in ("player", "atlas", "ship"):
        raise ValueError("entity tem de ser 'player', 'atlas' ou 'ship'.")
    try:
        x_value, y_value = float(x), float(y)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("As coordenadas têm de ser números válidos.") from exc
    import math
    if not math.isfinite(x_value) or not math.isfinite(y_value):
        raise ValueError("As coordenadas têm de ser finitas.")
    return update_world_state({entity: {"position": {"x": x_value, "y": y_value}}}, run_id)


def set_current_detections(detections: list[dict[str, Any]], run_id: str | None = None) -> dict[str, Any]:
    """Substitui as deteções atuais; não altera o conhecimento histórico do Atlas."""
    if not isinstance(detections, list) or any(not isinstance(item, dict) for item in detections):
        raise ValueError("detections tem de ser uma lista de objetos.")
    return update_world_state({"atlas": {"current_detections": detections}}, run_id)
