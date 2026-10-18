"""Estado social do Atlas para Find Hope — compatível com Atlas 2.0.

A irritação afeta apenas o tom social. Não altera factos, deteções,
conhecimento, decisões de gameplay ou progressão narrativa.
"""
from copy import deepcopy

MIN_IRRITATION = 0
MAX_IRRITATION = 10
DEFAULT_SOCIAL_STATE = {"atlas_irritation": 0}

# Estado legado para chamadas sem run_id.
SOCIAL_STATE = deepcopy(DEFAULT_SOCIAL_STATE)
# Estados separados quando o jogo fornece um identificador de partida.
_SOCIAL_STATES_BY_RUN: dict[str, dict[str, int]] = {}


def _normalise_run_id(run_id=None):
    if run_id is None:
        return None
    value = str(run_id).strip()
    if not value:
        raise ValueError("run_id não pode estar vazio.")
    return value[:255]


def _get_state(run_id=None):
    key = _normalise_run_id(run_id)
    if key is None:
        return SOCIAL_STATE
    if key not in _SOCIAL_STATES_BY_RUN:
        _SOCIAL_STATES_BY_RUN[key] = deepcopy(DEFAULT_SOCIAL_STATE)
    return _SOCIAL_STATES_BY_RUN[key]


def clamp_irritation(run_id=None):
    state = _get_state(run_id)
    try:
        value = int(round(float(state.get("atlas_irritation", 0))))
    except (TypeError, ValueError, OverflowError):
        value = 0
    state["atlas_irritation"] = max(MIN_IRRITATION, min(value, MAX_IRRITATION))
    return state["atlas_irritation"]


_SOCIAL_EVENT_DELTAS = {
    "insult": 1,
    "threat": 2,
    "apology": -1,
    "support": -1,
    "affection": -1,
}


def apply_social_event(event_type: str, run_id=None):
    """Aplica um evento social reconhecido e devolve a irritação atual.

    Eventos desconhecidos não alteram o estado. A confirmação de que um
    evento ocorreu deve vir do jogo/backend determinístico, não da LLM.
    """
    if not isinstance(event_type, str):
        return get_irritation(run_id)

    event = event_type.strip().lower()
    delta = _SOCIAL_EVENT_DELTAS.get(event)
    if delta is None:
        return get_irritation(run_id)

    state = _get_state(run_id)
    state["atlas_irritation"] = state.get("atlas_irritation", 0) + delta
    return clamp_irritation(run_id)


def get_irritation(run_id=None):
    clamp_irritation(run_id)
    return _get_state(run_id)["atlas_irritation"]


def build_social_context(run_id=None):
    irritation = get_irritation(run_id)

    if irritation <= 1:
        return (
            "Atlas está calmo. Não reage com hostilidade desnecessária. "
            "Mantém uma comunicação lógica, observadora e respeitosa."
        )

    if irritation <= 3:
        return (
            "Atlas está ligeiramente irritado com o jogador. "
            "Pode responder de forma mais seca, mantendo o controlo. "
            "O humor subtil só deve surgir se o contexto narrativo o permitir."
        )

    if irritation <= 5:
        return (
            "Atlas está irritado com o jogador. Pode demonstrar impaciência "
            "ou sarcasmo moderado quando provocado, sem inventar factos "
            "nem transformar a irritação numa hostilidade automática."
        )

    if irritation <= 7:
        return (
            "Atlas está bastante irritado com o jogador. Pode responder de "
            "forma mais firme e demonstrar hostilidade proporcional à situação, "
            "sem abandonar a sua personalidade calma e lógica."
        )

    return (
        "Atlas está extremamente irritado com o jogador. Pode responder de "
        "forma muito seca e firme quando provocado, mas mantém o controlo, "
        "a capacidade de observação e a personalidade central. A irritação "
        "não autoriza ameaças, ações físicas ou decisões de gameplay."
    )


def reset_social_state(run_id=None):
    """Repõe apenas o estado social da partida indicada (ou o estado legado)."""
    key = _normalise_run_id(run_id)
    if key is None:
        SOCIAL_STATE.clear()
        SOCIAL_STATE.update(deepcopy(DEFAULT_SOCIAL_STATE))
    else:
        _SOCIAL_STATES_BY_RUN[key] = deepcopy(DEFAULT_SOCIAL_STATE)
    return deepcopy(_get_state(run_id))


def get_social_state(run_id=None):
    """Devolve uma cópia do estado, evitando alterações externas acidentais."""
    clamp_irritation(run_id)
    return deepcopy(_get_state(run_id))
