from copy import deepcopy


DEFAULT_NARRATIVE_STATE = {
    "tone": "neutral",
    "tension": 0,
    "active_topic": None,
    "active_event": None,
    "unresolved_events": [],
    "humor_allowed": True,
    "casual_interaction_allowed": True,
    "last_significant_event": None,
}

NARRATIVE_STATE = deepcopy(
    DEFAULT_NARRATIVE_STATE
)

MAX_UNRESOLVED_EVENTS = 5


def _clamp(value, minimum=0, maximum=100):
    return max(
        minimum,
        min(
            maximum,
            int(round(value))
        )
    )


def _add_unresolved_event(event_name):
    if not event_name:
        return

    if event_name in NARRATIVE_STATE[
        "unresolved_events"
    ]:
        return

    NARRATIVE_STATE[
        "unresolved_events"
    ].append(
        event_name
    )

    while (
        len(
            NARRATIVE_STATE[
                "unresolved_events"
            ]
        )
        > MAX_UNRESOLVED_EVENTS
    ):
        NARRATIVE_STATE[
            "unresolved_events"
        ].pop(0)


def _remove_unresolved_event(event_name):
    unresolved = NARRATIVE_STATE[
        "unresolved_events"
    ]

    while event_name in unresolved:
        unresolved.remove(
            event_name
        )


def _refresh_permissions():
    tension = NARRATIVE_STATE[
        "tension"
    ]

    unresolved = set(
        NARRATIVE_STATE[
            "unresolved_events"
        ]
    )

    serious_unresolved = bool(
        unresolved.intersection({
            "threat",
            "betrayal",
            "broken_promise",
        })
    )

    recent_conflict = (
        "recent_conflict"
        in unresolved
    )

    NARRATIVE_STATE[
        "humor_allowed"
    ] = (
        tension < 45
        and not serious_unresolved
    )

    NARRATIVE_STATE[
        "casual_interaction_allowed"
    ] = (
        tension < 35
        and not serious_unresolved
        and not (
            recent_conflict
            and tension >= 25
        )
    )


def _refresh_tone():
    tension = NARRATIVE_STATE[
        "tension"
    ]

    active_event = NARRATIVE_STATE[
        "active_event"
    ]

    unresolved = set(
        NARRATIVE_STATE[
            "unresolved_events"
        ]
    )

    if active_event in {
        "betrayal",
        "threat",
        "broken_promise",
    }:
        NARRATIVE_STATE[
            "tone"
        ] = "hostile"

    elif tension >= 70:
        NARRATIVE_STATE[
            "tone"
        ] = "hostile"

    elif (
        tension >= 40
        or (
            "recent_conflict"
            in unresolved
            and tension >= 25
        )
    ):
        NARRATIVE_STATE[
            "tone"
        ] = "tense"

    elif active_event in {
        "apology",
        "gratitude",
        "support",
        "affection",
        "reassurance",
    }:
        NARRATIVE_STATE[
            "tone"
        ] = "soft"

    elif tension <= 15:
        NARRATIVE_STATE[
            "tone"
        ] = "calm"

    else:
        NARRATIVE_STATE[
            "tone"
        ] = "neutral"


def _refresh_state():
    _refresh_permissions()
    _refresh_tone()


def apply_narrative_event(
    event_type,
    intensity=1.0,
    topic=None,
):
    """
    Atualiza o estado narrativo imediato.

    O Narrative State descreve o momento atual.
    Não substitui memória nem relacionamento.
    """

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

    if topic:
        NARRATIVE_STATE[
            "active_topic"
        ] = str(topic)

    NARRATIVE_STATE[
        "active_event"
    ] = event_type

    if event_type in {
        "insult",
        "disrespect",
        "distrust",
    }:
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            + 12 * intensity
        )

        _add_unresolved_event(
            "recent_conflict"
        )

    elif event_type == "threat":
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            + 25 * intensity
        )

        _add_unresolved_event(
            "threat"
        )

    elif event_type == "betrayal":
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            + 35 * intensity
        )

        _add_unresolved_event(
            "betrayal"
        )

    elif event_type == "broken_promise":
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            + 20 * intensity
        )

        _add_unresolved_event(
            "broken_promise"
        )

    elif event_type == "apology":
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            - 18 * intensity
        )

        # Um pedido de desculpa alivia o conflito recente,
        # mas não apaga traições, ameaças ou promessas quebradas.
        _remove_unresolved_event(
            "recent_conflict"
        )

    elif event_type in {
        "support",
        "affection",
        "gratitude",
        "reassurance",
        "cooperation",
        "trust",
        "respect",
    }:
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            - 8 * intensity
        )

    elif event_type == "promise":
        NARRATIVE_STATE[
            "tension"
        ] = _clamp(
            NARRATIVE_STATE[
                "tension"
            ]
            - 4 * intensity
        )

    NARRATIVE_STATE[
        "last_significant_event"
    ] = event_type

    _refresh_state()

    return get_narrative_state()


def register_narrative_topic(topic):
    if topic is None:
        return

    topic = str(topic).strip()

    if not topic:
        return

    NARRATIVE_STATE[
        "active_topic"
    ] = topic


def clear_active_event():
    NARRATIVE_STATE[
        "active_event"
    ] = None

    _refresh_state()


def get_narrative_state():
    return deepcopy(
        NARRATIVE_STATE
    )


def reset_narrative_state():
    NARRATIVE_STATE.clear()

    NARRATIVE_STATE.update(
        deepcopy(
            DEFAULT_NARRATIVE_STATE
        )
    )


def build_narrative_context():
    state = NARRATIVE_STATE

    unresolved = state[
        "unresolved_events"
    ]

    unresolved_text = (
        ", ".join(
            unresolved
        )
        if unresolved
        else "nenhum"
    )

    active_topic = (
        state["active_topic"]
        or "nenhum"
    )

    active_event = (
        state["active_event"]
        or "nenhum"
    )

    last_event = (
        state[
            "last_significant_event"
        ]
        or "nenhum"
    )

    return "\n".join([
        (
            f"tom atual={state['tone']} | "
            f"tensão narrativa={state['tension']}/100"
        ),
        (
            f"evento ativo={active_event} | "
            f"último evento significativo={last_event}"
        ),
        (
            f"tópico ativo={active_topic}"
        ),
        (
            f"eventos não resolvidos={unresolved_text}"
        ),
        (
            "humor permitido="
            f"{state['humor_allowed']} | "
            "interação casual permitida="
            f"{state['casual_interaction_allowed']}"
        ),
        (
            "O estado narrativo descreve o momento atual. "
            "Não inventes eventos que não estejam listados."
        ),
    ])
