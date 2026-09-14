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
    add_memory
)

app = FastAPI(title="Find Hope")


class ChatMessage(BaseModel):
    message: str

class MemoryData(BaseModel):
    entity: str
    category: str
    key: str
    value: str
    source: str = "player"
    confidence: float = 1.0
    importance: float = 0.5

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


@app.post("/atlas/memory")
def create_memory(data: MemoryData):
    success = add_memory(
        entity=data.entity,
        category=data.category,
        key=data.key,
        value=data.value,
        source=data.source,
        confidence=data.confidence,
        importance=data.importance
    )

    if not success:
        return {
            "status": "error",
            "message": "Invalid memory data"
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