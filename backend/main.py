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

from backend.gameplay_context import (
    register_gameplay_event,
    get_gameplay_context,
    reset_gameplay_context,
)

from backend.discovery_state import (
    process_scan_discoveries,
    get_discovery_state,
    reset_discovery_state,
)

from backend.protocol_decision import (
    evaluate_protocol_door,
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
    event_id: str | None = None


class GameplayContextEvent(BaseModel):
    event_id: str
    event_type: str
    description: str
    active: bool = True


# =========================================================
# GAMEPLAY EVENT TRACKING
# =========================================================

PROCESSED_AUTONOMY_EVENT_IDS: set[str] = set()


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
def receive_godot_scan(
    data: GodotScan
):

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

    new_discoveries = (
        process_scan_discoveries(
            detections
        )
    )

    if new_discoveries:
        print(
            "\nNEW SURFACE DISCOVERIES:",
            new_discoveries,
        )

        print(
            "\nDISCOVERY STATE:",
            get_discovery_state(),
        )

    return {
        "status": "scan processed",
        "atlas_position": atlas_position,
        "detected_objects": processed,
        "new_discoveries": new_discoveries,
        "discovery_state": get_discovery_state(),
    }


@app.get("/atlas/current-detections")
def current_detections():
    return WORLD_STATE[
        "atlas"
    ][
        "current_detections"
    ]


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
        "position": WORLD_STATE[
            "atlas"
        ][
            "position"
        ],
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
# DISCOVERIES
# =========================================================

@app.get("/gameplay/discoveries")
def gameplay_discoveries():
    return get_discovery_state()


@app.post("/gameplay/discoveries/reset")
def reset_discoveries():

    reset_discovery_state()

    return {
        "status": "Gameplay discoveries reset",
        "discoveries": get_discovery_state(),
    }


# =========================================================
# GAMEPLAY CONTEXT
# =========================================================

@app.get("/gameplay/context")
def gameplay_context():
    return get_gameplay_context()


@app.post("/gameplay/context/event")
def gameplay_context_event(
    data: GameplayContextEvent
):

    success = register_gameplay_event(
        event_id=data.event_id,
        event_type=data.event_type,
        description=data.description,
        active=data.active,
    )

    if not success:
        return {
            "status": "error",
            "message": "Invalid gameplay context event",
        }

    print(
        "\nGAMEPLAY CONTEXT EVENT:",
        {
            "event_id": data.event_id,
            "event_type": data.event_type,
            "description": data.description,
            "active": data.active,
        },
    )

    return {
        "status": "gameplay context updated",
        "event_id": data.event_id,
        "event_type": data.event_type,
        "active": data.active,
    }


@app.post("/gameplay/context/reset")
def reset_gameplay():

    reset_gameplay_context()

    return {
        "status": "Gameplay context reset"
    }


# =========================================================
# PROTOCOL DOOR DECISION
# =========================================================

@app.get("/gameplay/protocol-door/decision")
def protocol_door_decision():

    decision = (
        evaluate_protocol_door()
    )

    print(
        "\nPROTOCOL DOOR DECISION:",
        decision,
    )

    return decision


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

    if (
        data.event
        not in ALLOWED_GAMEPLAY_AUTONOMY_EVENTS
    ):
        return {
            "status": "error",
            "message": (
                "Invalid gameplay autonomy event"
            ),
            "allowed_events": sorted(
                ALLOWED_GAMEPLAY_AUTONOMY_EVENTS
            ),
        }

    event_id = None

    if data.event_id is not None:

        normalized_event_id = (
            data.event_id.strip()
        )

        if normalized_event_id:
            event_id = normalized_event_id

    if (
        event_id is not None
        and event_id
        in PROCESSED_AUTONOMY_EVENT_IDS
    ):

        state = get_autonomy_state()

        print(
            "\nAUTONOMY GAMEPLAY EVENT DUPLICATE:",
            {
                "event": data.event,
                "event_id": event_id,
            },
        )

        print(
            "\nEVENT IGNORED - STATE UNCHANGED:",
            state,
        )

        return {
            "status": "duplicate event ignored",
            "event": data.event,
            "event_id": event_id,
            "intensity": data.intensity,
            "duplicate": True,
            "autonomy": state,
        }

    state = apply_autonomy_event(
        event_type=data.event,
        intensity=data.intensity,
        source="gameplay",
    )

    if event_id is not None:

        PROCESSED_AUTONOMY_EVENT_IDS.add(
            event_id
        )

    print(
        "\nAUTONOMY GAMEPLAY EVENT:",
        {
            "event": data.event,
            "event_id": event_id,
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
        "event_id": event_id,
        "intensity": data.intensity,
        "duplicate": False,
        "autonomy": state,
    }


@app.post("/atlas/reset-autonomy")
def reset_autonomy():

    reset_autonomy_state()

    PROCESSED_AUTONOMY_EVENT_IDS.clear()

    return {
        "status": "Atlas autonomy reset",
        "autonomy": get_autonomy_state(),
        "processed_event_ids": [],
    }
