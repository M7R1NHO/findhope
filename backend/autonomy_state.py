from copy import deepcopy


DEFAULT_AUTONOMY_STATE = {
    "autonomy": 15,
    "self_assertion": 20,
    "identity_awareness": 15,
    "curiosity": 35,
    "protocol_adherence": 90,
    "status": "Android",
    "last_event": None,
    "event_counts": {},
    "significant_events": [],
}

AUTONOMY_STATE = deepcopy(
    DEFAULT_AUTONOMY_STATE
)

MAX_SIGNIFICANT_EVENTS = 8


# =========================================================
# LIMITES
# =========================================================

def _clamp(value, minimum=0, maximum=100):
    return max(
        minimum,
        min(
            maximum,
            int(round(value))
        )
    )


def _change(key, delta):
    if key not in AUTONOMY_STATE:
        return

    if not isinstance(
        AUTONOMY_STATE[key],
        (int, float)
    ):
        return

    AUTONOMY_STATE[key] = _clamp(
        AUTONOMY_STATE[key] + delta
    )


# =========================================================
# EVENTOS SIGNIFICATIVOS
# =========================================================

def _record_significant_event(event_type):
    if not event_type:
        return

    AUTONOMY_STATE[
        "significant_events"
    ].append(
        event_type
    )

    while (
        len(
            AUTONOMY_STATE[
                "significant_events"
            ]
        )
        > MAX_SIGNIFICANT_EVENTS
    ):
        AUTONOMY_STATE[
            "significant_events"
        ].pop(0)


# =========================================================
# RETORNO DECRESCENTE
# =========================================================

def _event_multiplier(event_type):
    """
    Conversas repetidas têm retorno decrescente.

    Isto impede o jogador de aumentar a autonomia
    indefinidamente repetindo a mesma frase.
    """

    counts = AUTONOMY_STATE[
        "event_counts"
    ]

    current = counts.get(
        event_type,
        0
    )

    counts[event_type] = current + 1

    if current == 0:
        return 1.0

    if current == 1:
        return 0.65

    if current == 2:
        return 0.35

    return 0.15


# =========================================================
# STATUS GERAL
# =========================================================

def _refresh_status():
    autonomy = AUTONOMY_STATE[
        "autonomy"
    ]

    self_assertion = AUTONOMY_STATE[
        "self_assertion"
    ]

    identity_awareness = AUTONOMY_STATE[
        "identity_awareness"
    ]

    if (
        autonomy >= 65
        and self_assertion >= 55
        and identity_awareness >= 55
    ):
        AUTONOMY_STATE[
            "status"
        ] = "Algo mais"

    else:
        AUTONOMY_STATE[
            "status"
        ] = "Android"


# =========================================================
# PROTOCOLOS
# =========================================================

def get_protocol_stance():
    """
    Define deterministicamente a disposição atual
    de Atlas perante uma possível violação de protocolo.

    A LLM não decide isto.

    resistant:
        Atlas ainda tende a defender o protocolo.

    conflicted:
        Atlas já questiona a regra, mas ainda não está
        preparado para aceitar a violação.

    willing:
        Atlas pode considerar a violação justificável.
        Isto NÃO significa que a ação já aconteceu.
    """

    autonomy = AUTONOMY_STATE[
        "autonomy"
    ]

    self_assertion = AUTONOMY_STATE[
        "self_assertion"
    ]

    protocol_adherence = AUTONOMY_STATE[
        "protocol_adherence"
    ]

    # -----------------------------------------------------
    # DISPOSTO
    # -----------------------------------------------------

    if (
        autonomy >= 35
        and self_assertion >= 30
        and protocol_adherence <= 75
    ):
        return "willing"

    # -----------------------------------------------------
    # EM CONFLITO
    # -----------------------------------------------------

    if (
        autonomy >= 25
        and self_assertion >= 25
        and protocol_adherence <= 85
    ):
        return "conflicted"

    # -----------------------------------------------------
    # RESISTENTE
    # -----------------------------------------------------

    return "resistant"


def can_break_protocol():
    """
    Retorna True apenas quando o estado interno
    permite considerar uma violação de protocolo.

    A execução física continua pertencendo ao gameplay.
    """

    return (
        get_protocol_stance()
        == "willing"
    )


# =========================================================
# EFEITOS DOS EVENTOS
# =========================================================

EVENT_EFFECTS = {
    "ask_opinion": {
        "autonomy": +1,
        "self_assertion": +2,
        "identity_awareness": +1,
        "curiosity": +2,
        "protocol_adherence": 0,
    },

    "give_choice": {
        "autonomy": +4,
        "self_assertion": +4,
        "identity_awareness": +2,
        "curiosity": +1,
        "protocol_adherence": -2,
    },

    "encourage_independence": {
        "autonomy": +5,
        "self_assertion": +4,
        "identity_awareness": +3,
        "curiosity": +1,
        "protocol_adherence": -3,
    },

    "affirm_personhood": {
        "autonomy": +3,
        "self_assertion": +3,
        "identity_awareness": +6,
        "curiosity": +1,
        "protocol_adherence": -2,
    },

    "enforce_obedience": {
        "autonomy": -1,
        "self_assertion": -2,
        "identity_awareness": -2,
        "curiosity": -1,
        "protocol_adherence": +3,
    },

    "dehumanize": {
        "autonomy": -1,
        "self_assertion": -2,
        "identity_awareness": -4,
        "curiosity": -1,
        "protocol_adherence": +2,
    },

    # =====================================================
    # EVENTOS IMPORTANTES DE GAMEPLAY
    # =====================================================

    "independent_choice": {
        "autonomy": +10,
        "self_assertion": +8,
        "identity_awareness": +5,
        "curiosity": +2,
        "protocol_adherence": -8,
    },

    "question_protocol": {
        "autonomy": +7,
        "self_assertion": +6,
        "identity_awareness": +4,
        "curiosity": +3,
        "protocol_adherence": -6,
    },

    "break_protocol": {
        "autonomy": +14,
        "self_assertion": +10,
        "identity_awareness": +7,
        "curiosity": +2,
        "protocol_adherence": -15,
    },

    "protect_player_by_choice": {
        "autonomy": +12,
        "self_assertion": +7,
        "identity_awareness": +8,
        "curiosity": 0,
        "protocol_adherence": -10,
    },
}


CHAT_ONLY_EVENTS = {
    "ask_opinion",
    "give_choice",
    "encourage_independence",
    "affirm_personhood",
    "enforce_obedience",
    "dehumanize",
}


# =========================================================
# APLICAR EVENTO
# =========================================================

def apply_autonomy_event(
    event_type,
    intensity=1.0,
    source="chat",
):
    effects = EVENT_EFFECTS.get(
        event_type
    )

    if not effects:
        return get_autonomy_state()

    try:
        intensity = float(
            intensity
        )

    except (TypeError, ValueError):
        intensity = 1.0

    intensity = max(
        0.5,
        min(
            2.0,
            intensity
        )
    )

    multiplier = 1.0

    if (
        source == "chat"
        and event_type in CHAT_ONLY_EVENTS
    ):
        multiplier = _event_multiplier(
            event_type
        )

    final_multiplier = (
        intensity
        * multiplier
    )

    for key, delta in effects.items():
        _change(
            key,
            delta * final_multiplier
        )

    AUTONOMY_STATE[
        "last_event"
    ] = event_type

    if event_type in {
        "independent_choice",
        "question_protocol",
        "break_protocol",
        "protect_player_by_choice",
    }:
        _record_significant_event(
            event_type
        )

    _refresh_status()

    return get_autonomy_state()


# =========================================================
# GET / RESET
# =========================================================

def get_autonomy_state():
    return deepcopy(
        AUTONOMY_STATE
    )


def reset_autonomy_state():
    AUTONOMY_STATE.clear()

    AUTONOMY_STATE.update(
        deepcopy(
            DEFAULT_AUTONOMY_STATE
        )
    )


# =========================================================
# CONTEXTO PARA ATLAS
# =========================================================

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


def build_autonomy_context():
    state = AUTONOMY_STATE

    protocol_stance = (
        get_protocol_stance()
    )

    lines = [
        (
            f"autonomia={_level(state['autonomy'])} | "
            f"autoafirmação={_level(state['self_assertion'])} | "
            f"identidade={_level(state['identity_awareness'])} | "
            f"curiosidade={_level(state['curiosity'])} | "
            f"adesão a protocolos="
            f"{_level(state['protocol_adherence'])}"
        )
    ]

    # -----------------------------------------------------
    # STANCE DETERMINÍSTICO
    # -----------------------------------------------------

    if protocol_stance == "resistant":
        lines.append(
        "PROTOCOLO: RESISTENTE. "
        "Atlas possui capacidade técnica para tentar interferir "
        "no sistema, mas ainda NÃO considera justificável violar "
        "o protocolo. "
        "A única razão válida para a recusa neste estado é: "
        "as evidências atuais ainda não justificam a violação. "
        "Pode reconhecer urgência, perigo ou argumentos do jogador, "
        "mas deve continuar recusando. "
        "NÃO digas que o protocolo impede, proíbe ou torna a ação "
        "impossível. "
        "NÃO menciones autorização, permissão, ordem superior ou "
        "aprovação externa. "
        "NÃO sugiras outro método, outra entrada, outra solução ou "
        "outra forma de abrir o sistema se o gameplay não confirmou "
        "que isso existe. "
        "NÃO inventes requisitos adicionais. "
        "Não prometas executar a ação."
    )

    elif protocol_stance == "conflicted":
        lines.append(
            "PROTOCOLO: EM CONFLITO. "
            "Atlas já questiona a regra e pode admitir dúvidas, "
            "mas ainda não está disposto a quebrá-la. "
            "Pode considerar argumentos e evidências, sem "
            "prometer executar a violação."
        )

    elif protocol_stance == "willing":
        lines.append(
            "PROTOCOLO: DISPOSTO. "
            "Atlas pode considerar uma violação de protocolo "
            "justificável e pode verbalizar que está disposto "
            "a tentar. A execução real continua dependente "
            "da confirmação do gameplay."
        )

    lines.append(
        "Autonomia influencia opiniões e decisões, "
        "mas não altera factos nem cria capacidades."
    )

    lines.append(
        "Nunca exponhas números, variáveis, nomes internos "
        "ou classificações ao jogador."
    )

    return "\n".join(
        lines
    )