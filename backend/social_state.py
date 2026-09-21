SOCIAL_STATE = {
    "atlas_irritation": 0
}


def clamp_irritation():
    SOCIAL_STATE["atlas_irritation"] = max(
        0,
        min(
            SOCIAL_STATE["atlas_irritation"],
            10
        )
    )


def apply_social_event(event_type: str):
    if event_type == "insult":
        SOCIAL_STATE["atlas_irritation"] += 1

    elif event_type == "threat":
        SOCIAL_STATE["atlas_irritation"] += 2

    elif event_type == "apology":
        SOCIAL_STATE["atlas_irritation"] -= 1

    elif event_type == "support":
        SOCIAL_STATE["atlas_irritation"] -= 1

    elif event_type == "affection":
        SOCIAL_STATE["atlas_irritation"] -= 1

    clamp_irritation()


def get_irritation():
    return SOCIAL_STATE["atlas_irritation"]


def build_social_context():
    irritation = get_irritation()

    if irritation <= 1:
        return (
            "Atlas está calmo. "
            "Não reage com hostilidade desnecessária."
        )

    if irritation <= 3:
        return (
            "Atlas está ligeiramente irritado com o jogador. "
            "Pode responder de forma mais seca ou sarcástica."
        )

    if irritation <= 5:
        return (
            "Atlas está irritado com o jogador. "
            "Pode responder com impaciência, sarcasmo "
            "ou um insulto leve se for provocado."
        )

    if irritation <= 7:
        return (
            "Atlas está bastante irritado com o jogador. "
            "Pode responder na mesma moeda, usar palavrões "
            "e demonstrar hostilidade proporcional."
        )

    return (
        "Atlas está extremamente irritado com o jogador. "
        "Pode responder de forma agressiva, sarcástica "
        "e com palavrões quando provocado, "
        "sem abandonar completamente a sua personalidade."
    )


def reset_social_state():
    SOCIAL_STATE["atlas_irritation"] = 0