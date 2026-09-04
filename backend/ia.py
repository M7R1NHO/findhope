from google import genai
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parent / ".env")

client = genai.Client()


def ask_android(message: str) -> str:
    response = client.models.generate_content(
        model="gemini-3.7-flash",
        contents=message
    )

    return response.text