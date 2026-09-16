import json

from backend.atlas_memory import add_memory
from backend.belief_evaluator import evaluate_memory


MEMORY_RESPONSE_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "atlas_memory_interpreter",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "memories": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "memory_type": {
                                "type": "string",
                                "enum": [
                                    "semantic",
                                    "episodic"
                                ]
                            },
                            "entity": {
                                "type": "string",
                                "enum": [
                                    "player",
                                    "atlas",
                                    "shared",
                                    "world"
                                ]
                            },
                            "category": {
                                "type": "string",
                                "enum": [
                                    "identity",
                                    "preference",
                                    "belief",
                                    "relationship",
                                    "event",
                                    "knowledge",
                                    "definition",
                                    "goal",
                                    "emotion",
                                    "experience"
                                ]
                            },
                            "key": {
                                "type": "string"
                            },
                            "value": {
                                "type": "string"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1
                            },
                            "importance": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1
                            }
                        },
                        "required": [
                            "memory_type",
                            "entity",
                            "category",
                            "key",
                            "value",
                            "confidence",
                            "importance"
                        ],
                        "additionalProperties": False
                    }
                },

                "query": {
                    "type": "object",
                    "properties": {
                        "need_memory": {
                            "type": "boolean"
                        },
                        "entity": {
                            "type": "string",
                            "enum": [
                                "player",
                                "atlas",
                                "shared",
                                "world",
                                "any"
                            ]
                        },
                        "category": {
                            "type": "string",
                            "enum": [
                                "identity",
                                "preference",
                                "belief",
                                "relationship",
                                "event",
                                "knowledge",
                                "definition",
                                "goal",
                                "emotion",
                                "experience",
                                "any"
                            ]
                        },
                        "query": {
                            "type": "string"
                        }
                    },
                    "required": [
                        "need_memory",
                        "entity",
                        "category",
                        "query"
                    ],
                    "additionalProperties": False
                }
            },
            "required": [
                "memories",
                "query"
            ],
            "additionalProperties": False
        }
    }
}


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

    memories = data.get(
        "memories",
        []
    )

    query = data.get(
        "query",
        {}
    )

    if not isinstance(memories, list):
        memories = []

    if not isinstance(query, dict):
        query = {}

    if query.get("need_memory") is not True:
        query = {
            "need_memory": False,
            "entity": "any",
            "category": "any",
            "query": ""
        }

    return {
        "memories": memories,
        "query": query
    }


def interpret_memory(
    client,
    model,
    message: str
):
    system_prompt = """
You are Atlas's memory interpreter.

Return:
1. new memories created by the CURRENT message;
2. a query for OLD memories useful for understanding it.

IMPORTANT:
Creating a new memory and retrieving old memories are independent.
A message may do BOTH.

Example:
"desculpa atlas"

This is a CURRENT social action, so create an episodic
player/relationship memory for the apology.

It may ALSO need previous relationship memories to understand
what the player is apologizing for.

Rules:
- Store useful persistent facts and significant events.
- Never invent information.
- Do not store trivial conversation.
- semantic = persistent information.
- episodic = event.
- Significant actions toward Atlas such as insults, apologies,
  threats, promises, affection, hostility and support are
  episodic/player/relationship.
- External events claimed by the player are normally
  episodic/player/event.
- Questions normally do not create memories.
- A question is not memorable merely because its subject is serious.
- "X significa Y" is semantic/shared/definition.
- Player real name: semantic/player/identity, key "name".
- Player preferred name: semantic/player/identity,
  key "preferred_name".

Retrieval:
- Set need_memory=true when OLD information helps understand
  or answer the current message.
- Past, identity, preferences, previous events and relationship
  questions normally require retrieval.
- A current apology, reconciliation or other relationship action
  may retrieve previous relationship context.
- If retrieval is unnecessary:
  entity="any", category="any", query="".
- Write query, key and value in the SAME LANGUAGE as the player.

confidence and importance must be between 0 and 1.
"""

    try:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": system_prompt
                },
                {
                    "role": "user",
                    "content": message
                }
            ],
            response_format=MEMORY_RESPONSE_SCHEMA,
            reasoning_effort="none",
            temperature=0,
            max_tokens=400
        )

        content = (
            completion
            .choices[0]
            .message
            .content
        )

        if not content:
            return default_memory_result()

        data = json.loads(content)

        result = normalize_interpreter_result(
            data
        )

        print(
            "\nINTERPRETER RESULT:",
            result
        )

        return result

    except Exception as e:
        print(
            f"Erro no Memory Interpreter: {e}"
        )

        return default_memory_result()


def process_interpreted_memory(
    memory_data,
    world_state=None,
    knowledge=None
):
    if not memory_data:
        return []

    memories = memory_data.get(
        "memories",
        []
    )

    if not isinstance(memories, list):
        return []

    saved_memories = []

    for memory in memories:
        if not isinstance(memory, dict):
            continue

        evaluation = evaluate_memory(
            memory,
            world_state=world_state,
            knowledge=knowledge
        )

        success = add_memory(
            memory_type=memory["memory_type"],
            entity=memory["entity"],
            category=memory["category"],
            key=memory["key"],
            value=memory["value"],
            source="player",
            confidence=memory["confidence"],
            importance=memory["importance"],
            epistemic_status=evaluation.get(
                "epistemic_status"
            ),
            plausibility=evaluation.get(
                "plausibility"
            ),
            narrative_weight=evaluation.get(
                "narrative_weight"
            ),
            reaction_hint=evaluation.get(
                "reaction_hint"
            )
        )

        if not success:
            print(
                "Memória rejeitada pelo Memory Engine:",
                memory
            )
            continue

        evaluated_memory = dict(memory)
        evaluated_memory.update(evaluation)

        saved_memories.append(
            evaluated_memory
        )

        print(
            "Memória avaliada:",
            evaluated_memory
        )

    return saved_memories