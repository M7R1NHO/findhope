from fastapi import FastAPI
from pydantic import BaseModel

from backend.world_state import WORLD_STATE
from backend.sensors import process_godot_scan
from backend.ia import ask_android

from backend.atlas_knowledge import (
    get_atlas_knowledge,
    reset_atlas_knowledge,
)

from backend.atlas_memory import (
    get_atlas_memory,
    reset_atlas_memory,
    add_memory,
)

from backend.autonomy_state import (
    apply_autonomy_event,
    get_autonomy_state,
    reset_autonomy_state,
)


app = FastAPI(title="Find Hope")


# =========================================================
# MODELS
# =========================================================

class ChatMessage(BaseModel):
    message: str


class MemoryData(BaseModel):
    memory_type: str = "semantic"
    entity: str
    category: str
    key: str
    value: str
    source: str = "player"
    confidence: float = 1.0
    importance: float = 0.5


class AtlasPosition(BaseModel):
    x: float
    y: float


class GodotDetection(BaseModel):
    id: str
    name: str
    type: str
    distance_px: float


class GodotScan(BaseModel):
    atlas_position: AtlasPosition
    detections: list[GodotDetection]


class AutonomyGameplayEvent(BaseModel):
    event: str
    intensity: float = 1.0


# =========================================================
# ROOT
# =========================================================

@app.get("/")
def root():
    return {
        "message": "Find Hope API online"
    }


# =========================================================
# CHAT
# =========================================================

@app.post("/chat")
def chat(data: ChatMessage):

    response = ask_android(
        data.message
    )

    return {
        "message": data.message,
        "response": response,
    }


# =========================================================
# GODOT SENSOR BRIDGE
# =========================================================

@app.post("/world/scan")
def receive_godot_scan(data: GodotScan):

    atlas_position = {
        "x": data.atlas_position.x,
        "y": data.atlas_position.y,
    }

    detections = [
        {
            "id": detection.id,
            "name": detection.name,
            "type": detection.type,
            "distance_px": detection.distance_px,
        }
        for detection in data.detections
    ]

    processed = process_godot_scan(
        atlas_position,
        detections,
    )

    return {
        "status": "scan processed",
        "atlas_position": atlas_position,
        "detected_objects": processed,
    }


@app.get("/atlas/current-detections")
def current_detections():
    return WORLD_STATE["atlas"]["current_detections"]


# =========================================================
# ATLAS POSITION
# =========================================================

@app.post("/atlas/position")
def update_atlas_position(
    data: AtlasPosition
):

    WORLD_STATE["atlas"]["position"] = {
        "x": data.x,
        "y": data.y,
    }

    return {
        "status": "Atlas position updated",
        "position": WORLD_STATE["atlas"]["position"],
    }


# =========================================================
# KNOWLEDGE
# =========================================================

@app.get("/atlas/knowledge")
def atlas_knowledge():
    return get_atlas_knowledge()


@app.post("/atlas/reset-knowledge")
def reset_knowledge():

    reset_atlas_knowledge()

    return {
        "status": "Atlas knowledge reset"
    }


# =========================================================
# MEMORY
# =========================================================

@app.get("/atlas/memory")
def atlas_memory():
    return get_atlas_memory()


@app.post("/atlas/memory")
def create_memory(
    data: MemoryData
):

    success = add_memory(
        memory_type=data.memory_type,
        entity=data.entity,
        category=data.category,
        key=data.key,
        value=data.value,
        source=data.source,
        confidence=data.confidence,
        importance=data.importance,
    )

    if not success:
        return {
            "status": "error",
            "message": "Invalid memory data",
        }

    return {
        "status": "Memory stored"
    }


@app.post("/atlas/reset-memory")
def reset_memory():

    reset_atlas_memory()

    return {
        "status": "Atlas memory reset"
    }


# =========================================================
# AUTONOMY / GAMEPLAY BRIDGE
# =========================================================

ALLOWED_GAMEPLAY_AUTONOMY_EVENTS = {
    "independent_choice",
    "question_protocol",
    "break_protocol",
    "protect_player_by_choice",
}


@app.get("/atlas/autonomy")
def atlas_autonomy():
    return get_autonomy_state()


@app.post("/atlas/autonomy/event")
def autonomy_gameplay_event(
    data: AutonomyGameplayEvent
):
    if data.event not in ALLOWED_GAMEPLAY_AUTONOMY_EVENTS:
        return {
            "status": "error",
            "message": "Invalid gameplay autonomy event",
            "allowed_events": sorted(
                ALLOWED_GAMEPLAY_AUTONOMY_EVENTS
            ),
        }

    state = apply_autonomy_event(
        event_type=data.event,
        intensity=data.intensity,
        source="gameplay",
    )

    print(
        "\nAUTONOMY GAMEPLAY EVENT:",
        {
            "event": data.event,
            "intensity": data.intensity,
        },
    )

    print(
        "\nAUTONOMY STATE AFTER GAMEPLAY EVENT:",
        state,
    )

    return {
        "status": "autonomy event processed",
        "event": data.event,
        "intensity": data.intensity,
        "autonomy": state,
    }


@app.post("/atlas/reset-autonomy")
def reset_autonomy():

    reset_autonomy_state()

    return {
        "status": "Atlas autonomy reset",
        "autonomy": get_autonomy_state(),
    }
