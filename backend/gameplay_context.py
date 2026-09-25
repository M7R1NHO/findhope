# backend/gameplay_context.py

MAX_GAMEPLAY_EVENTS = 20

GAMEPLAY_CONTEXT = {
    "events": {}
}


def register_gameplay_event(
    event_id: str,
    event_type: str,
    description: str,
    active: bool = True,
):
    event_id = str(event_id or "").strip()
    event_type = str(event_type or "").strip()
    description = str(description or "").strip()

    if not event_id or not event_type or not description:
        return False

    GAMEPLAY_CONTEXT["events"][event_id] = {
        "event_id": event_id,
        "event_type": event_type,
        "description": description,
        "active": bool(active),
    }

    # Limite simples em RAM para o protótipo.
    while len(GAMEPLAY_CONTEXT["events"]) > MAX_GAMEPLAY_EVENTS:
        oldest_key = next(
            iter(GAMEPLAY_CONTEXT["events"])
        )
        GAMEPLAY_CONTEXT["events"].pop(
            oldest_key,
            None,
        )

    return True


def set_gameplay_event_active(
    event_id: str,
    active: bool,
):
    event = GAMEPLAY_CONTEXT[
        "events"
    ].get(event_id)

    if event is None:
        return False

    event["active"] = bool(active)

    return True


def get_gameplay_context():
    return GAMEPLAY_CONTEXT


def build_gameplay_context():
    active_events = [
        event
        for event in GAMEPLAY_CONTEXT[
            "events"
        ].values()
        if event.get("active", False)
    ]

    if not active_events:
        return "Nenhum acontecimento de gameplay ativo."

    lines = []

    for event in active_events:
        lines.append(
            f"- {event['description']} "
            f"(tipo={event['event_type']}, "
            f"id={event['event_id']})"
        )

    return "\n".join(lines)


def reset_gameplay_context():
    GAMEPLAY_CONTEXT["events"].clear()
