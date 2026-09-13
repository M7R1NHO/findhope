from fastapi import FastAPI
from pydantic import BaseModel
from backend.world_state import WORLD_STATE
from backend.sensors import scan_world
from backend.atlas_knowledge import get_atlas_knowledge
from backend.ia import ask_android
from backend.atlas_knowledge import (
    get_atlas_knowledge,
    reset_atlas_knowledge
)
from backend.atlas_memory import (
    get_atlas_memory,
    reset_atlas_memory,
    add_event,
    set_player_info,
    add_important_moment
)

app = FastAPI(title="Find Hope")


class ChatMessage(BaseModel):
    message: str

class MemoryEvent(BaseModel):
    id: str
    description: str
    source: str = "game"


class PlayerInfo(BaseModel):
    key: str
    value: str


class ImportantMoment(BaseModel):
    id: str
    description: str

@app.get("/")
def root():
    return {"message": "Find Hope API online"}


@app.post("/chat")
def chat(data: ChatMessage):
    response = ask_android(data.message)

    return {
        "message": data.message,
        "response": response
    }

@app.get("/world/scan")
def scan():
    atlas = WORLD_STATE["atlas"]

    detected = scan_world(
        atlas["position"],
        atlas["radar_range"]
    )

    return {
        "atlas_position": atlas["position"],
        "radar_range": atlas["radar_range"],
        "detected_objects": detected
    }

@app.get("/atlas/knowledge")
def atlas_knowledge():
    return get_atlas_knowledge()

@app.post("/atlas/reset-knowledge")
def reset_knowledge():
    reset_atlas_knowledge()

    return {
        "status": "Atlas knowledge reset"
    }

@app.get("/atlas/current-detections")
def current_detections():
    return WORLD_STATE["atlas"]["current_detections"]


class AtlasPosition(BaseModel):
    x: float
    y: float


@app.post("/atlas/position")
def update_atlas_position(data: AtlasPosition):
    WORLD_STATE["atlas"]["position"] = {
        "x": data.x,
        "y": data.y
    }

    return {
        "status": "Atlas position updated",
        "position": WORLD_STATE["atlas"]["position"]
    }

@app.get("/atlas/memory")
def atlas_memory():
    return get_atlas_memory()


@app.post("/atlas/memory/event")
def create_memory_event(data: MemoryEvent):
    add_event(
        event_id=data.id,
        description=data.description,
        source=data.source
    )

    return {
        "status": "Event stored"
    }


@app.post("/atlas/memory/player-info")
def create_player_info(data: PlayerInfo):
    set_player_info(
        key=data.key,
        value=data.value
    )

    return {
        "status": "Player information stored"
    }


@app.post("/atlas/memory/important")
def create_important_memory(data: ImportantMoment):
    add_important_moment(
        moment_id=data.id,
        description=data.description
    )

    return {
        "status": "Important moment stored"
    }


@app.post("/atlas/reset-memory")
def reset_memory():
    reset_atlas_memory()

    return {
        "status": "Atlas memory reset"
    }