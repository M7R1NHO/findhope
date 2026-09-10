from fastapi import FastAPI
from pydantic import BaseModel
from backend.world_state import WORLD_STATE
from backend.sensors import scan_world

from backend.ia import ask_android

app = FastAPI(title="Find Hope")


class ChatMessage(BaseModel):
    message: str


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