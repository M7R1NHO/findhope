from backend.world_state import WORLD_STATE
from backend.atlas_knowledge import (
    add_confirmed_fact,
    reset_current_detections
)


def get_proximity(distance_px: float) -> str:
    """
    Converte a distância técnica do Godot em uma descrição
    que faça sentido narrativamente para o Atlas.

    Pixels são uma unidade interna do jogo e não devem
    ser tratados como metros.
    """

    if distance_px <= 75:
        return "muito perto"

    if distance_px <= 150:
        return "perto"

    return "dentro do alcance dos sensores"


def process_godot_scan(atlas_position, detections):
    """
    Processa um scan realizado pelo Godot.

    Godot controla:
    - posições físicas
    - alcance
    - distância em pixels
    - objetos detectados

    Backend controla:
    - conhecimento do Atlas
    - interpretação narrativa das deteções
    """

    WORLD_STATE["atlas"]["position"] = {
        "x": atlas_position["x"],
        "y": atlas_position["y"]
    }

    reset_current_detections()

    processed_detections = []

    for detection in detections:

        distance_px = detection["distance_px"]

        proximity = get_proximity(distance_px)

        processed_detection = {
            "id": detection["id"],
            "name": detection["name"],
            "type": detection["type"],
            "proximity": proximity
        }

        processed_detections.append(processed_detection)

        add_confirmed_fact(
            fact_id=detection["id"],
            name=detection["name"],
            source="sensors",
            currently_detected=True,
            extra={
                "type": detection["type"],
                "proximity": proximity
            }
        )

    WORLD_STATE["atlas"]["current_detections"] = processed_detections

    return processed_detections