import math

from backend.world_map import WORLD_MAP


def calculate_distance(position_a, position_b):
    dx = position_a["x"] - position_b["x"]
    dy = position_a["y"] - position_b["y"]

    return math.sqrt(dx ** 2 + dy ** 2)


def scan_world(atlas_position, radar_range):
    detected_objects = []

    for obj in WORLD_MAP:

        if not obj["detectable"]:
            continue

        distance = calculate_distance(
            atlas_position,
            obj["position"]
        )

        if distance <= radar_range:
            detected_objects.append({
                "id": obj["id"],
                "name": obj["name"],
                "type": obj["type"],
                "distance": round(distance, 1)
            })

    return detected_objects