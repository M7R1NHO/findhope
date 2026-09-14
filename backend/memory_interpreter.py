import json
import re
from backend.atlas_memory import add_memory


def interpret_memory(client, model, message: str):
    prompt = f"""
Analisa a mensagem e devolve memória estruturada e intenção de recuperação.

Mensagem:
{message}

MEMÓRIA:
type: semantic | episodic
entity: player | atlas | shared | world
category: identity | preference | belief | relationship | event |
knowledge | definition | goal | emotion | experience

Campos:
key = conceito curto
value = informação curta
confidence = 0..1
importance = 0..1

Regras:
- Guarda apenas informação explícita e útil.
- Não inventes nem deduzas.
- Perguntas normalmente não criam memória.
- player = sobre jogador; atlas = sobre Atlas.
- shared = códigos/definições combinadas entre ambos.
- world = sobre mundo/missão.
- Nome real: identity/name.
- Nome preferido: identity/preferred_name.
- "X significa Y" como convenção: shared/definition, key=X, value=Y.
- semantic = estado/conhecimento; episodic = acontecimento.
- need_memory=true apenas se informação anterior ajudar a responder.
- Se false: entity/category="any" e query="".

JSON apenas:
{{
 "memories": [
   {{
    "memory_type":"semantic",
    "entity":"player",
    "category":"identity",
    "key":"name",
    "value":"Guilherme",
    "source":"player",
    "confidence":1.0,
    "importance":0.8
   }}
 ],
 "query": {{
   "need_memory":false,
   "entity":"any",
   "category":"any",
   "query":""
 }}
}}
"""

    try:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Extrai memória e intenção de recuperação. "
                        "Responde apenas JSON válido."
                    )
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            reasoning_effort="none",
            temperature=0,
            max_tokens=500
        )

        content = completion.choices[0].message.content

        if not content:
            return default_memory_result()

        data = json.loads(content)

        return normalize_interpreter_result(data)

    except Exception as e:
        print(
            f"Erro no Memory Interpreter: {e}"
        )

        if content:
            print(
                "\nRESPOSTA CRUA DO MEMORY INTERPRETER:\n",
                content
            )

        return default_memory_result()


def default_memory_result():
    return {
        "memories": [],
        "query": {
            "need_memory": False,
            "entity": "any",
            "category": "any",
            "query": ""
        }
    }


def normalize_interpreter_result(data):
    if not isinstance(data, dict):
        return default_memory_result()

    memories = data.get("memories", [])

    if not isinstance(memories, list):
        memories = []

    query = data.get("query", {})

    if not isinstance(query, dict):
        query = {}

    need_memory = query.get("need_memory", False)

    if need_memory is not True:
        normalized_query = {
            "need_memory": False,
            "entity": "any",
            "category": "any",
            "query": ""
        }
    else:
        normalized_query = {
            "need_memory": True,
            "entity": query.get("entity", "any"),
            "category": query.get("category", "any"),
            "query": str(
                query.get("query", "")
            ).strip()
        }

    return {
        "memories": memories,
        "query": normalized_query
    }


def process_interpreted_memory(memory_data):
    if not memory_data:
        return

    memories = memory_data.get("memories", [])

    if not isinstance(memories, list):
        return

    for memory in memories:
        if not isinstance(memory, dict):
            continue

        success = add_memory(
            memory_type=memory.get(
                "memory_type",
                "semantic"
            ),
            entity=memory.get("entity"),
            category=memory.get("category"),
            key=memory.get("key"),
            value=memory.get("value"),
            source=memory.get(
                "source",
                "player"
            ),
            confidence=memory.get(
                "confidence",
                1.0
            ),
            importance=memory.get(
                "importance",
                0.5
            )
        )

        if not success:
            print(
                "Memória rejeitada pelo Memory Engine:",
                memory
            )

def parse_json_response(content: str):
    if not content:
        raise ValueError("Resposta vazia.")

    text = content.strip()

    # Remove blocos ```json ... ```
    if text.startswith("```"):
        text = re.sub(
            r"^```(?:json)?\s*",
            "",
            text,
            flags=re.IGNORECASE
        )

        text = re.sub(
            r"\s*```$",
            "",
            text
        )

    # Mantém apenas o objeto JSON principal
    start = text.find("{")
    end = text.rfind("}")

    if start == -1 or end == -1:
        raise ValueError(
            f"Nenhum objeto JSON encontrado: {text}"
        )

    text = text[start:end + 1]

    # Remove trailing commas:
    # {"a": 1,}
    # [1, 2,]
    text = re.sub(
        r",\s*([}\]])",
        r"\1",
        text
    )

    return parse_json_response(content) 