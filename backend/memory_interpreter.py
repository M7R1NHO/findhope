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


JSON_SHAPE_HINT = (
    "\n\nRespond ONLY with a JSON object of exactly this shape: "
    '{"memories": [{"memory_type": "semantic|episodic", '
    '"entity": "player|atlas|shared|world", "category": "...", '
    '"key": "...", "value": "...", "confidence": 0-1, '
    '"importance": 0-1}], "query": {"need_memory": true|false, '
    '"entity": "...", "category": "...", "query": "..."}}. '
    "Use the key \"memories\" (an array) at the top level."
)


def _create_with_fallback(client, model, system_prompt, message):
    """O modo json_schema estrito do Groq falha de vez em quando
    (json_validate_failed, ex.: o modelo escreve '{preferences').
    Tenta 2x com o schema e depois em modo json_object, para que uma
    falha do interpretador não faça a memória perder-se em silêncio."""
    attempts = [
        (MEMORY_RESPONSE_SCHEMA, system_prompt),
        (MEMORY_RESPONSE_SCHEMA, system_prompt),
        ({"type": "json_object"}, system_prompt + JSON_SHAPE_HINT),
    ]
    last_error = None

    for response_format, prompt in attempts:
        try:
            return client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": message}
                ],
                response_format=response_format,
                reasoning_effort="none",
                temperature=0,
                max_tokens=400
            )
        except Exception as e:
            last_error = e
            print(f"Interpreter: tentativa falhou ({e}); a repetir.")

    raise last_error


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
        completion = _create_with_fallback(
            client,
            model,
            system_prompt,
            message
        )

        # =========================================================
        # TOKEN USAGE
        # =========================================================

        if completion.usage:
            print(
                "\n========== TOKENS INTERPRETER =========="
            )

            print(
                "Prompt:",
                completion.usage.prompt_tokens
            )

            print(
                "Resposta:",
                completion.usage.completion_tokens
            )

            print(
                "Total:",
                completion.usage.total_tokens
            )

            print(
                "========================================"
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