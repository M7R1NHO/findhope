"""Motor determinístico de relação para Find Hope — Atlas 2.0.

A relação altera a forma como Atlas comunica, não os factos do mundo,
a progressão narrativa ou os resultados do gameplay. O estado pode ser
separado por run_id; sem run_id mantém-se compatibilidade com chamadas antigas.
"""
from copy import deepcopy
from math import isfinite

MIN_VALUE = 0
MAX_VALUE = 100

DEFAULT_RELATIONSHIP_STATE = {
    "atlas_to_player": {
        "trust": 50, "respect": 50, "affinity": 50,
        "tension": 10, "irritation": 0,
    },
    "player_to_atlas": {
        # Atitude inferida de ações/falas observadas, não leitura da mente.
        "trust": 50, "respect": 50, "affinity": 50,
        "tension": 10, "hostility": 0,
    },
}

# Compatibilidade com o estado legado e armazenamento independente por partida.
RELATIONSHIP_STATE = deepcopy(DEFAULT_RELATIONSHIP_STATE)
_RUN_RELATIONSHIP_STATES = {}


def _valid_run_id(run_id):
    if run_id is None:
        return None
    if not isinstance(run_id, str) or not run_id.strip():
        raise ValueError("run_id deve ser uma string não vazia ou None.")
    return run_id.strip()


def _get_state(run_id=None):
    run_id = _valid_run_id(run_id)
    if run_id is None:
        return RELATIONSHIP_STATE
    if run_id not in _RUN_RELATIONSHIP_STATES:
        _RUN_RELATIONSHIP_STATES[run_id] = deepcopy(DEFAULT_RELATIONSHIP_STATE)
    return _RUN_RELATIONSHIP_STATES[run_id]


def _clamp(value):
    try:
        number = float(value)
        if not isfinite(number):
            return MIN_VALUE
        return max(MIN_VALUE, min(MAX_VALUE, int(round(number))))
    except (TypeError, ValueError, OverflowError):
        return MIN_VALUE


def _change(state, direction, key, delta):
    if direction not in state or key not in state[direction]:
        return
    current = state[direction][key]
    state[direction][key] = _clamp(current + delta)


EVENT_EFFECTS = {
    "insult": {
        "atlas_to_player": {
            "trust": -2,
            "respect": -5,
            "affinity": -3,
            "tension": +10,
            "irritation": +2,
        },
        "player_to_atlas": {
            "respect": -7,
            "affinity": -5,
            "tension": +8,
            "hostility": +10,
        },
    },

    "threat": {
        "atlas_to_player": {
            "trust": -7,
            "respect": -5,
            "affinity": -5,
            "tension": +15,
            "irritation": +3,
        },
        "player_to_atlas": {
            "trust": -5,
            "respect": -5,
            "affinity": -6,
            "tension": +12,
            "hostility": +15,
        },
    },

    "apology": {
        "atlas_to_player": {
            "trust": +2,
            "respect": +2,
            "affinity": +2,
            "tension": -8,
            "irritation": -2,
        },
        "player_to_atlas": {
            "respect": +3,
            "affinity": +2,
            "tension": -5,
            "hostility": -5,
        },
    },

    "support": {
        "atlas_to_player": {
            "trust": +4,
            "respect": +3,
            "affinity": +4,
            "tension": -4,
            "irritation": -1,
        },
        "player_to_atlas": {
            "trust": +3,
            "respect": +3,
            "affinity": +4,
            "tension": -3,
            "hostility": -2,
        },
    },

    "affection": {
        "atlas_to_player": {
            "trust": +3,
            "respect": +1,
            "affinity": +6,
            "tension": -4,
            "irritation": -1,
        },
        "player_to_atlas": {
            "trust": +2,
            "respect": +1,
            "affinity": +6,
            "tension": -3,
            "hostility": -3,
        },
    },

    "cooperation": {
        "atlas_to_player": {
            "trust": +3,
            "respect": +3,
            "affinity": +2,
            "tension": -2,
        },
        "player_to_atlas": {
            "trust": +2,
            "respect": +2,
            "affinity": +2,
            "tension": -2,
        },
    },

    "gratitude": {
        "atlas_to_player": {
            "trust": +2,
            "respect": +3,
            "affinity": +3,
            "tension": -3,
            "irritation": -1,
        },
        "player_to_atlas": {
            "trust": +2,
            "respect": +3,
            "affinity": +3,
            "tension": -2,
            "hostility": -2,
        },
    },

    "compliment": {
        "atlas_to_player": {
            "trust": +1,
            "respect": +2,
            "affinity": +4,
            "tension": -2,
            "irritation": -1,
        },
        "player_to_atlas": {
            "respect": +2,
            "affinity": +4,
            "tension": -2,
            "hostility": -1,
        },
    },

    "reassurance": {
        "atlas_to_player": {
            "trust": +4,
            "respect": +2,
            "affinity": +3,
            "tension": -6,
            "irritation": -1,
        },
        "player_to_atlas": {
            "trust": +3,
            "respect": +2,
            "affinity": +2,
            "tension": -5,
            "hostility": -1,
        },
    },

    "trust": {
        "atlas_to_player": {
            "trust": +2,
            "respect": +1,
            "affinity": +2,
            "tension": -2,
        },
        "player_to_atlas": {
            "trust": +7,
            "respect": +2,
            "affinity": +2,
            "tension": -3,
            "hostility": -1,
        },
    },

    "distrust": {
        "atlas_to_player": {
            "trust": -2,
            "affinity": -1,
            "tension": +4,
            "irritation": +1,
        },
        "player_to_atlas": {
            "trust": -9,
            "respect": -2,
            "affinity": -2,
            "tension": +6,
            "hostility": +2,
        },
    },

    "respect": {
        "atlas_to_player": {
            "trust": +1,
            "respect": +3,
            "affinity": +2,
            "tension": -2,
        },
        "player_to_atlas": {
            "trust": +2,
            "respect": +7,
            "affinity": +2,
            "tension": -2,
            "hostility": -1,
        },
    },

    "disrespect": {
        "atlas_to_player": {
            "trust": -1,
            "respect": -4,
            "affinity": -2,
            "tension": +6,
            "irritation": +1,
        },
        "player_to_atlas": {
            "trust": -2,
            "respect": -8,
            "affinity": -3,
            "tension": +6,
            "hostility": +5,
        },
    },

    "promise": {
        "atlas_to_player": {
            "trust": +2,
            "respect": +1,
            "affinity": +1,
            "tension": -2,
        },
        "player_to_atlas": {
            "trust": +2,
            "respect": +1,
            "tension": -1,
        },
    },

    "broken_promise": {
        "atlas_to_player": {
            "trust": -10,
            "respect": -6,
            "affinity": -4,
            "tension": +10,
            "irritation": +2,
        },
        "player_to_atlas": {
            "trust": -5,
            "respect": -4,
            "tension": +6,
            "hostility": +5,
        },
    },

    "betrayal": {
        "atlas_to_player": {
            "trust": -15,
            "respect": -10,
            "affinity": -8,
            "tension": +20,
            "irritation": +4,
        },
        "player_to_atlas": {
            "tension": +10,
            "hostility": +10,
        },
    },
}


def apply_relationship_event(event_type, intensity=1.0, run_id=None):
    """Aplica um evento reconhecido; eventos desconhecidos não alteram o estado."""
    state = _get_state(run_id)
    if not isinstance(event_type, str):
        return get_relationship_state(run_id=run_id)
    event_type = event_type.strip().lower()
    effects = EVENT_EFFECTS.get(event_type)
    if not effects:
        return get_relationship_state(run_id=run_id)

    try:
        intensity = float(intensity)
        if not isfinite(intensity):
            intensity = 1.0
    except (TypeError, ValueError, OverflowError):
        intensity = 1.0
    intensity = max(0.5, min(2.0, intensity))

    for direction, changes in effects.items():
        for key, delta in changes.items():
            _change(state, direction, key, delta * intensity)
    return get_relationship_state(run_id=run_id)


def get_relationship_state(run_id=None):
    return deepcopy(_get_state(run_id))


def reset_relationship_state(run_id=None):
    run_id = _valid_run_id(run_id)
    if run_id is None:
        RELATIONSHIP_STATE.clear()
        RELATIONSHIP_STATE.update(deepcopy(DEFAULT_RELATIONSHIP_STATE))
    else:
        _RUN_RELATIONSHIP_STATES[run_id] = deepcopy(DEFAULT_RELATIONSHIP_STATE)
    return get_relationship_state(run_id=run_id)


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


def _relationship_score(state, direction):
    data = state[direction]
    trust = data.get("trust", 50)
    respect = data.get("respect", 50)
    affinity = data.get("affinity", 50)
    tension = data.get("tension", 0)
    penalty_key = "irritation" if direction == "atlas_to_player" else "hostility"
    penalty = data.get(penalty_key, 0)
    score = (
        trust * 0.35 + respect * 0.30 + affinity * 0.35
        - tension * 0.20 - penalty * 0.20
    )
    return _clamp(score)


def _relationship_class(score):
    if score < 40:
        return "Ruim"
    if score < 65:
        return "Ok"
    return "Bom"


def get_relationship_summary(run_id=None):
    state = _get_state(run_id)
    atlas_score = _relationship_score(state, "atlas_to_player")
    player_score = _relationship_score(state, "player_to_atlas")
    return {
        "atlas_to_player": {
            "score": atlas_score, "class": _relationship_class(atlas_score),
        },
        "player_to_atlas": {
            "score": player_score, "class": _relationship_class(player_score),
        },
    }


def build_relationship_context(run_id=None):
    state = _get_state(run_id)
    atlas = state["atlas_to_player"]
    player = state["player_to_atlas"]
    summary = get_relationship_summary(run_id=run_id)
    return "\\n".join([
        (
            "ATLAS → JOGADOR: "
            f"relação={summary['atlas_to_player']['class']} | "
            f"confiança={_level(atlas['trust'])} | "
            f"respeito={_level(atlas['respect'])} | "
            f"afinidade={_level(atlas['affinity'])} | "
            f"tensão={_level(atlas['tension'])} | "
            f"irritação={_level(atlas['irritation'])}"
        ),
        (
            "JOGADOR → ATLAS (atitude observada): "
            f"relação={summary['player_to_atlas']['class']} | "
            f"confiança={_level(player['trust'])} | "
            f"respeito={_level(player['respect'])} | "
            f"afinidade={_level(player['affinity'])} | "
            f"tensão={_level(player['tension'])} | "
            f"hostilidade={_level(player['hostility'])}"
        ),
        (
            "A relação influencia tom, abertura, confiança e disposição social; "
            "não altera factos do mundo, conhecimento confirmado, nem progressão. "
            "Não atribuir ao jogador intenções ou sentimentos que não tenham sido observados."
        ),
    ])
