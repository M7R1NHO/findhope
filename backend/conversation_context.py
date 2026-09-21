MAX_RECENT_MESSAGES = 12


CONVERSATION_HISTORY = []


def add_conversation_message(role: str, content: str):
    if role not in {"player", "atlas"}:
        return

    content = str(content).strip()

    if not content:
        return

    CONVERSATION_HISTORY.append({
        "role": role,
        "content": content
    })

    while len(CONVERSATION_HISTORY) > MAX_RECENT_MESSAGES:
        CONVERSATION_HISTORY.pop(0)


def get_recent_conversation():
    return CONVERSATION_HISTORY.copy()


def build_conversation_context():
    if not CONVERSATION_HISTORY:
        return "Não existe contexto recente de conversa."

    lines = []

    for message in CONVERSATION_HISTORY:
        if message["role"] == "player":
            speaker = "JOGADOR"
        else:
            speaker = "ATLAS"

        lines.append(
            f"{speaker}: {message['content']}"
        )

    return "\n".join(lines)


def reset_conversation_context():
    CONVERSATION_HISTORY.clear()