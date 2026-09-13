ATLAS_MEMORY = {
    "events": [],
    "player_info": {},
    "atlas_info": {},
    "important_moments": []
}


def add_event(event_id, description, source="game"):
    """
    Guarda um acontecimento que Atlas presenciou ou aprendeu.
    """

    for event in ATLAS_MEMORY["events"]:
        if event["id"] == event_id:
            return

    ATLAS_MEMORY["events"].append({
        "id": event_id,
        "description": description,
        "source": source
    })


def set_player_info(key, value):
    """
    Guarda ou atualiza informação sobre o jogador.
    """
    ATLAS_MEMORY["player_info"][key] = value


def add_important_moment(moment_id, description):
    """
    Guarda acontecimentos narrativamente importantes.
    """

    for moment in ATLAS_MEMORY["important_moments"]:
        if moment["id"] == moment_id:
            return

    ATLAS_MEMORY["important_moments"].append({
        "id": moment_id,
        "description": description
    })


def get_atlas_memory():
    return ATLAS_MEMORY


def reset_atlas_memory():
    ATLAS_MEMORY["events"].clear()
    ATLAS_MEMORY["player_info"].clear()
    ATLAS_MEMORY["atlas_info"].clear()
    ATLAS_MEMORY["important_moments"].clear()

def set_atlas_info(key, value):
    """
    Guarda informação personalizada sobre o próprio Atlas.
    """
    ATLAS_MEMORY["atlas_info"][key] = value

def build_memory_context():
    lines = []

    # Eventos
    if ATLAS_MEMORY["events"]:
        lines.append("EVENTOS RECORDADOS:")

        for event in ATLAS_MEMORY["events"]:
            lines.append(
                f"- {event['description']} "
                f"(fonte: {event['source']})"
            )
    else:
        lines.append("EVENTOS RECORDADOS:")
        lines.append("- Nenhum evento relevante registado.")

    # Jogador
    lines.append("\nINFORMAÇÕES SOBRE O JOGADOR:")

    if ATLAS_MEMORY["player_info"]:
        for key, value in ATLAS_MEMORY["player_info"].items():
            lines.append(f"- {key}: {value}")
    else:
        lines.append("- Nenhuma informação pessoal registada.")

    lines.append("\nINFORMAÇÕES PERSONALIZADAS SOBRE ATLAS:")

    if ATLAS_MEMORY["atlas_info"]:
        for key, value in ATLAS_MEMORY["atlas_info"].items():
            lines.append(f"- {key}: {value}")
    else:
        lines.append("- Nenhuma informação personalizada registada.")

    # Momentos importantes
    lines.append("\nMOMENTOS IMPORTANTES:")

    if ATLAS_MEMORY["important_moments"]:
        for moment in ATLAS_MEMORY["important_moments"]:
            lines.append(f"- {moment['description']}")
    else:
        lines.append("- Nenhum momento importante registado.")

    return "\n".join(lines)