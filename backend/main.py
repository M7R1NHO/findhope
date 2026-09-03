from fastapi import FastAPI
from pydantic import BaseModel

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