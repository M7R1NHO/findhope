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


def _event_multiplier(event_type):
    """
    Conversas repetidas têm retorno decrescente.
    Isso impede o jogador de transformar Atlas em "Algo mais"
    apenas repetindo a mesma frase.
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

    # "Algo mais" exige evolução em vários eixos.
    # Conversa sozinha não deve tornar Atlas plenamente autónomo.
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

    # Eventos de gameplay importantes.
    # Estes NÃO devem ser disparados apenas por frases comuns.
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

    return "\n".join([
        (
            f"estado={state['status']} | "
            f"autonomia={_level(state['autonomy'])} | "
            f"autoafirmação={_level(state['self_assertion'])}"
        ),
        (
            f"consciência de identidade="
            f"{_level(state['identity_awareness'])} | "
            f"curiosidade={_level(state['curiosity'])} | "
            f"adesão a protocolos="
            f"{_level(state['protocol_adherence'])}"
        ),
        (
            "Atlas continua sendo Atlas. "
            "Autonomia maior permite opiniões próprias, "
            "discordância e iniciativa, mas não inventa capacidades."
        ),
        (
            "Se estado=Android, mantém forte tendência a protocolos. "
            "Se estado=Algo mais, pode agir com maior independência."
        ),
        (
            "Nunca exponhas números, variáveis ou o rótulo interno "
            "'Algo mais' ao jogador como se fosse uma interface."
        ),
    ])
