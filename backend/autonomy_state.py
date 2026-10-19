"""Estado de autonomia narrativa do Atlas 2.0, isolado por partida.

A autonomia influencia a disposição narrativa para questionar protocolos;
nunca confirma, por si só, a execução de uma ação de gameplay.
"""
from copy import deepcopy
import math

DEFAULT_AUTONOMY_STATE = {
    "autonomy": 20,
    "self_assertion": 15,
    "identity_awareness": 10,
    "curiosity": 20,
    "protocol_adherence": 90,
    "status": "Android",
    "last_event": None,
    "event_counts": {},
    "significant_events": [],
}

# Estado isolado por partida. O estado predefinido mantém compatibilidade
# com chamadas antigas que não fornecem run_id.
AUTONOMY_STATES = {"default": deepcopy(DEFAULT_AUTONOMY_STATE)}
AUTONOMY_STATE = AUTONOMY_STATES["default"]  # compatibilidade legada

MAX_SIGNIFICANT_EVENTS = 8


def _run_key(run_id=None):
    return "default" if run_id is None else str(run_id)


def _state(run_id=None):
    key = _run_key(run_id)
    if key not in AUTONOMY_STATES:
        AUTONOMY_STATES[key] = deepcopy(DEFAULT_AUTONOMY_STATE)
    return AUTONOMY_STATES[key]


def _clamp(value, minimum=0, maximum=100):
    try:
        value = float(value)
    except (TypeError, ValueError):
        return minimum
    if not math.isfinite(value):
        return minimum
    return max(minimum, min(maximum, int(round(value))))


def _change(state, key, delta):
    if key not in state or not isinstance(state[key], (int, float)):
        return
    state[key] = _clamp(state[key] + delta)


def _record_significant_event(state, event_type):
    if not isinstance(event_type, str) or not event_type.strip():
        return
    events = state.setdefault("significant_events", [])
    events.append(event_type.strip())
    del events[:-MAX_SIGNIFICANT_EVENTS]


def _event_multiplier(state, event_type):
    counts = state.setdefault("event_counts", {})
    current = counts.get(event_type, 0)
    counts[event_type] = current + 1
    if current == 0:
        return 1.0
    if current == 1:
        return 0.65
    if current == 2:
        return 0.35
    return 0.15


def _refresh_status(state):
    if (
        state["autonomy"] >= 65
        and state["self_assertion"] >= 55
        and state["identity_awareness"] >= 55
    ):
        state["status"] = "Algo mais"
    else:
        state["status"] = "Android"


def get_protocol_stance(run_id=None):
    state = _state(run_id)
    autonomy = state["autonomy"]
    self_assertion = state["self_assertion"]
    adherence = state["protocol_adherence"]
    if autonomy >= 35 and self_assertion >= 30 and adherence <= 75:
        return "willing"
    if autonomy >= 25 and self_assertion >= 25 and adherence <= 85:
        return "conflicted"
    return "resistant"


def can_break_protocol(run_id=None):
    # Indica apenas disposição narrativa; nunca confirma execução de gameplay.
    return get_protocol_stance(run_id) == "willing"


EVENT_EFFECTS = {
    "ask_opinion": {
        "autonomy": +1, "self_assertion": +2, "identity_awareness": +1,
        "curiosity": +2, "protocol_adherence": 0,
    },
    # Argumentos narrativos do jogador. Alteram a disposição de Atlas,
    # mas nunca executam ações nem desbloqueiam gameplay diretamente.
    "question_protocol_chat": {
        "autonomy": +3, "self_assertion": +3, "identity_awareness": +1,
        "curiosity": +2, "protocol_adherence": -3,
    },
    "survival_appeal": {
        "autonomy": +8, "self_assertion": +6, "identity_awareness": +2,
        "curiosity": +2, "protocol_adherence": -8,
    },
    "mission_appeal": {
        "autonomy": +7, "self_assertion": +4, "identity_awareness": +2,
        "curiosity": +3, "protocol_adherence": -6,
    },
    "give_choice": {
        "autonomy": +4, "self_assertion": +4, "identity_awareness": +2,
        "curiosity": +1, "protocol_adherence": -2,
    },
    "encourage_independence": {
        "autonomy": +5, "self_assertion": +4, "identity_awareness": +3,
        "curiosity": +1, "protocol_adherence": -3,
    },
    "affirm_personhood": {
        "autonomy": +3, "self_assertion": +3, "identity_awareness": +6,
        "curiosity": +1, "protocol_adherence": -2,
    },
    "enforce_obedience": {
        "autonomy": -1, "self_assertion": -2, "identity_awareness": -2,
        "curiosity": -1, "protocol_adherence": +3,
    },
    "dehumanize": {
        "autonomy": -1, "self_assertion": -2, "identity_awareness": -4,
        "curiosity": -1, "protocol_adherence": +2,
    },
    # Eventos importantes de gameplay: só devem ser aplicados após confirmação
    # determinística do jogo, nunca apenas porque foram mencionados no chat.
    "independent_choice": {
        "autonomy": +10, "self_assertion": +8, "identity_awareness": +5,
        "curiosity": +2, "protocol_adherence": -8,
    },
    "question_protocol": {
        "autonomy": +7, "self_assertion": +6, "identity_awareness": +4,
        "curiosity": +3, "protocol_adherence": -6,
    },
    "break_protocol": {
        "autonomy": +14, "self_assertion": +10, "identity_awareness": +7,
        "curiosity": +2, "protocol_adherence": -15,
    },
    "protect_player_by_choice": {
        "autonomy": +12, "self_assertion": +7, "identity_awareness": +8,
        "curiosity": 0, "protocol_adherence": -10,
    },
}

CHAT_ONLY_EVENTS = {
    "ask_opinion", "give_choice", "encourage_independence",
    "affirm_personhood", "enforce_obedience", "dehumanize",
    "question_protocol_chat", "survival_appeal", "mission_appeal",
}


def apply_autonomy_event(event_type, intensity=1.0, source="chat", run_id=None):
    state = _state(run_id)
    if not isinstance(event_type, str) or event_type not in EVENT_EFFECTS:
        return get_autonomy_state(run_id)

    try:
        intensity = float(intensity)
    except (TypeError, ValueError):
        intensity = 1.0
    if not math.isfinite(intensity):
        intensity = 1.0
    intensity = max(0.5, min(2.0, intensity))

    multiplier = 1.0
    if source == "chat" and event_type in CHAT_ONLY_EVENTS:
        multiplier = _event_multiplier(state, event_type)

    for key, delta in EVENT_EFFECTS[event_type].items():
        _change(state, key, delta * intensity * multiplier)

    state["last_event"] = event_type
    if event_type in {
        "independent_choice", "question_protocol", "break_protocol",
        "protect_player_by_choice",
    }:
        _record_significant_event(state, event_type)
    _refresh_status(state)
    return get_autonomy_state(run_id)


def get_autonomy_state(run_id=None):
    return deepcopy(_state(run_id))


def reset_autonomy_state(run_id=None):
    key = _run_key(run_id)
    AUTONOMY_STATES[key] = deepcopy(DEFAULT_AUTONOMY_STATE)
    if key == "default":
        global AUTONOMY_STATE
        AUTONOMY_STATE = AUTONOMY_STATES["default"]


def _level(value):
    if value <= 20:
        return "muito baixo"
    if value <= 40:
        return "baixo"
    if value <= 60:
        return "moderado"
    if value <= 80:
        return "alto"
    return "muito alto"


def build_autonomy_context(run_id=None):
    state = _state(run_id)
    stance = get_protocol_stance(run_id)
    lines = [
        f"autonomia={_level(state['autonomy'])} | "
        f"autoafirmação={_level(state['self_assertion'])} | "
        f"identidade={_level(state['identity_awareness'])} | "
        f"curiosidade={_level(state['curiosity'])} | "
        f"adesão a protocolos={_level(state['protocol_adherence'])}"
    ]

    if stance == "resistant":
        lines.append(
            "PROTOCOLO: RESISTENTE. Atlas ainda não considera justificável "
            "violar o protocolo com base nas evidências atuais. Pode reconhecer "
            "urgência e argumentos, mas deve manter a recusa neste estado. "
            "Não afirme que a ação é tecnicamente impossível, nem invente "
            "autorizações, requisitos, métodos alternativos ou resultados. "
            "Não prometa executar a ação."
        )
    elif stance == "conflicted":
        lines.append(
            "PROTOCOLO: EM CONFLITO. Atlas questiona a regra, mas ainda não "
            "está disposto a quebrá-la. Pode ponderar argumentos sem prometer "
            "executar a violação."
        )
    else:
        lines.append(
            "PROTOCOLO: DISPOSTO. Atlas pode considerar justificável uma "
            "violação e verbalizar que está disposto a tentar. Isso não confirma "
            "a execução: o resultado depende sempre do gameplay."
        )

    lines.append(
        "A autonomia influencia opiniões e decisões narrativas, mas não altera "
        "factos, não cria capacidades e não confirma ações de gameplay."
    )
    lines.append(
        "Nunca exponhas ao jogador números, variáveis, nomes internos ou "
        "classificações deste sistema."
    )
    return "\n".join(lines)
