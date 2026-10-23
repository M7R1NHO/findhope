"""Comportamento observado do jogador — Atlas 2.0 (Bíblia, secção 6.3).

O jogo é a única fonte destes factos: cada contador só sobe quando o Godot
envia um evento de gameplay. O modelo de linguagem recebe os números e as
observações já calculadas e escolhe apenas como Atlas fala delas.

O estado vive dentro do estado do Atlas (campo "behavior"), por isso é
guardado no snapshot, restaurado ao carregar e revertido pelo Game Over.
"""

from copy import deepcopy


# Contadores que o jogo pode incrementar.
COUNTER_EVENTS = {
    "run_escaped": "run_escapes",
    "fight_won": "fights_won",
    "hide_success": "hides_success",
    "hide_failed": "hides_failed",
    "hack_success": "hacks_success",
    "hack_failed": "hacks_failed",  # cada tentativa errada num minigame
    "overload_used": "overloads_used",
    "maintenance_used": "maintenance_used",
}

# Além dos contadores, "room_entered" regista as salas visitadas.
ALLOWED_BEHAVIOR_EVENTS = set(COUNTER_EVENTS) | {"room_entered"}

# Efeito na relação: só comportamentos que dizem algo sobre a forma como o
# jogador trata o Atlas. Fugir ou lutar, por si só, não é bom nem mau.
RELATIONSHIP_EFFECTS = {
    "hide_success": ("followed_guidance", 1.0),
    "hide_failed": ("ignored_guidance", 1.0),
    "fight_won": ("cooperation", 0.5),
}

MAX_PROCESSED_EVENT_IDS = 200
MAX_ROOMS = 30
MAX_ROOM_NAME = 60


def _new_state():
    return {
        "counters": {name: 0 for name in COUNTER_EVENTS.values()},
        # RUN seguidos sem nenhum FIGHT pelo meio.
        "run_streak": 0,
        "rooms_visited": [],
        # Gatilhos de mensagens espontâneas já usados (os de uso único).
        "spontaneous_used": [],
        "spontaneous_count": 0,
        "processed_event_ids": [],
    }


BEHAVIOR_STATE = _new_state()


def _ensure_fields():
    """Acrescenta campos em falta (saves antigos ou estados parciais)."""
    default = _new_state()
    for key, value in default.items():
        if key not in BEHAVIOR_STATE or not isinstance(
            BEHAVIOR_STATE[key], type(value)
        ):
            BEHAVIOR_STATE[key] = deepcopy(value)

    counters = BEHAVIOR_STATE["counters"]
    for name in default["counters"]:
        try:
            counters[name] = max(0, int(counters.get(name, 0)))
        except (TypeError, ValueError):
            counters[name] = 0

    try:
        BEHAVIOR_STATE["run_streak"] = max(0, int(BEHAVIOR_STATE["run_streak"]))
    except (TypeError, ValueError):
        BEHAVIOR_STATE["run_streak"] = 0

    try:
        BEHAVIOR_STATE["spontaneous_count"] = max(
            0, int(BEHAVIOR_STATE["spontaneous_count"])
        )
    except (TypeError, ValueError):
        BEHAVIOR_STATE["spontaneous_count"] = 0


def reset_behavior_state():
    BEHAVIOR_STATE.clear()
    BEHAVIOR_STATE.update(_new_state())


def get_behavior_state():
    _ensure_fields()
    return deepcopy(BEHAVIOR_STATE)


def is_duplicate_event(event_id):
    _ensure_fields()
    return bool(event_id) and event_id in BEHAVIOR_STATE["processed_event_ids"]


def _remember_event_id(event_id):
    if not event_id:
        return
    ids = BEHAVIOR_STATE["processed_event_ids"]
    ids.append(event_id)
    if len(ids) > MAX_PROCESSED_EVENT_IDS:
        del ids[: len(ids) - MAX_PROCESSED_EVENT_IDS]


def register_behavior_event(event, room=None, event_id=None):
    """Aplica um evento de gameplay. Devolve (aceite, efeito_na_relação).

    efeito_na_relação é None ou (evento_da_relação, intensidade); quem chama
    é que o aplica, para manter este módulo independente do motor de relação.
    """
    _ensure_fields()

    if event not in ALLOWED_BEHAVIOR_EVENTS:
        return False, None

    if is_duplicate_event(event_id):
        return False, None

    counters = BEHAVIOR_STATE["counters"]

    if event == "room_entered":
        name = str(room or "").strip()[:MAX_ROOM_NAME]
        if not name:
            return False, None
        rooms = BEHAVIOR_STATE["rooms_visited"]
        if name not in rooms and len(rooms) < MAX_ROOMS:
            rooms.append(name)
        _remember_event_id(event_id)
        return True, None

    counters[COUNTER_EVENTS[event]] += 1

    if event == "run_escaped":
        BEHAVIOR_STATE["run_streak"] += 1
    elif event == "fight_won":
        BEHAVIOR_STATE["run_streak"] = 0

    _remember_event_id(event_id)
    return True, RELATIONSHIP_EFFECTS.get(event)


def mark_spontaneous_used(trigger, once):
    _ensure_fields()
    BEHAVIOR_STATE["spontaneous_count"] += 1
    if once and trigger not in BEHAVIOR_STATE["spontaneous_used"]:
        BEHAVIOR_STATE["spontaneous_used"].append(trigger)


def was_spontaneous_used(trigger):
    _ensure_fields()
    return trigger in BEHAVIOR_STATE["spontaneous_used"]


# =========================================================
# OBSERVAÇÕES (regras fixas, não inferidas pela IA)
# =========================================================

def get_behavior_observations():
    """Traduz os contadores em observações que o Atlas pode usar."""
    _ensure_fields()
    c = BEHAVIOR_STATE["counters"]
    observations = []

    runs = c["run_escapes"]
    fights = c["fights_won"]

    if runs >= 4 and fights == 0:
        observations.append(
            "O jogador tem fugido sempre da criatura e nunca a enfrentou."
        )
    elif runs >= 3 and runs >= fights * 2:
        observations.append(
            "O jogador foge da criatura muito mais vezes do que a enfrenta."
        )

    if fights >= 3 and fights > runs:
        observations.append(
            "O jogador prefere enfrentar a criatura em vez de fugir."
        )

    if BEHAVIOR_STATE["run_streak"] >= 3:
        observations.append(
            f"As últimas {BEHAVIOR_STATE['run_streak']} situações de perigo "
            "acabaram em fuga."
        )

    if c["hides_success"] >= 2 and c["hides_failed"] == 0:
        observations.append(
            "O jogador tem seguido Atlas até aos esconderijos sem falhar."
        )
    if c["hides_failed"] >= 2 and c["hides_failed"] > c["hides_success"]:
        observations.append(
            "O jogador falhou mais esconderijos do que acertou: "
            "não costuma seguir Atlas quando ele indica onde se esconder."
        )

    if c["hacks_failed"] >= 6 and c["hacks_failed"] > c["hacks_success"] * 2:
        observations.append("O jogador erra muitas vezes nos hacks.")

    if c["overloads_used"] >= 3:
        observations.append(
            "O jogador já pediu várias vezes a Atlas que se sobrecarregasse, "
            "à custa de VIDA."
        )

    if len(BEHAVIOR_STATE["rooms_visited"]) >= 7:
        observations.append(
            "O jogador explorou grande parte da instalação."
        )

    return observations


def build_behavior_context():
    _ensure_fields()
    c = BEHAVIOR_STATE["counters"]

    has_data = any(c.values()) or BEHAVIOR_STATE["rooms_visited"]
    if not has_data:
        return ""

    rooms = BEHAVIOR_STATE["rooms_visited"]
    lines = [
        "Contagens registadas pelo jogo nesta partida (são factos):",
        f"- fugas (RUN) concluídas: {c['run_escapes']}",
        f"- criatura afastada com o equipamento sonoro (FIGHT): {c['fights_won']}",
        f"- esconderijos bem-sucedidos: {c['hides_success']}",
        f"- esconderijos falhados: {c['hides_failed']}",
        f"- hacks concluídos: {c['hacks_success']} | tentativas erradas: {c['hacks_failed']}",
        f"- sobrecargas de Atlas: {c['overloads_used']}",
        f"- manutenção usada: {c['maintenance_used']}",
        "- salas visitadas: " + (", ".join(rooms) if rooms else "nenhuma registada"),
    ]

    observations = get_behavior_observations()
    if observations:
        lines.append("Observações de Atlas sobre o comportamento do jogador:")
        lines.extend(f"- {item}" for item in observations)

    lines.append(
        "Podes comentar, brincar ou criticar com base nestes números, mas "
        "nunca inventes contagens nem acontecimentos que não estejam aqui."
    )
    return "\n".join(lines)
