import json
import re

from backend.atlas_memory import add_memory
from backend.belief_evaluator import evaluate_memory


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

    # IMPORTANTE:
    # Aqui fazemos json.loads().
    # NÃO chamamos parse_json_response() novamente.
    return json.loads(text)

def normalize_interpreter_result(data):
    if not isinstance(data, dict):
        return default_memory_result()

    memories = data.get("memories", [])

    if not isinstance(memories, list):
        memories = []

    # Normalizar todas as memórias recebidas
    normalized_memories = []

    for memory in memories:
        if not isinstance(memory, dict):
            continue

        memory = dict(memory)

        # Compatibilidade caso o modelo devolva "type"
        # em vez de "memory_type".
        if "memory_type" not in memory:
            if "type" in memory:
                memory["memory_type"] = memory.pop("type")

        normalized_memories.append(memory)

    memories = normalized_memories

    # Normalizar query
    query = data.get("query", {})

    if not isinstance(query, dict):
        query = {}

    need_memory = query.get("need_memory", False)

    if need_memory is True:
        normalized_query = {
            "need_memory": True,
            "entity": str(
                query.get("entity", "any")
            ).strip(),
            "category": str(
                query.get("category", "any")
            ).strip(),
            "query": str(
                query.get("query", "")
            ).strip()
        }

    else:
        normalized_query = {
            "need_memory": False,
            "entity": "any",
            "category": "any",
            "query": ""
        }

    return {
        "memories": memories,
        "query": normalized_query
    }

def interpret_memory(
    client,
    model,
    message: str
):
    prompt = f"""
Analisa a mensagem e devolve memória estruturada e intenção de recuperação.

Mensagem:
{message}

MEMÓRIA:
memory_type: semantic | episodic
entity: player | atlas | shared | world
category: identity | preference | belief | relationship | event |
knowledge | definition | goal | emotion | experience

Campos:
key = conceito curto
value = informação curta
confidence = 0..1
importance = 0..1

Regras:
- Guarda apenas informação explícita, relevante e potencialmente útil no futuro.
- Não inventes, não deduzas acontecimentos e não acrescentes intenções que não foram expressas.

- Memórias não são apenas factos declarados.
  A própria mensagem pode representar um acontecimento da interação atual.

- Ações sociais relevantes dirigidas ao jogador ou a Atlas podem criar memória episódica.
  Exemplos de acontecimentos relevantes:
  insultos, elogios, pedidos de desculpa, ameaças, promessas,
  demonstrações importantes de confiança, rejeição, apoio,
  hostilidade ou afeto.

- Para uma ação social dirigida a Atlas:
  memory_type="episodic"
  entity="player"
  category="relationship"

- A key deve representar o acontecimento de forma curta e reutilizável.
  O value deve descrever brevemente o que aconteceu.

- Não guardes interações sociais triviais como cumprimentos,
  confirmações simples, "ok", "sim", "não" ou conversa sem importância.
  Guarda apenas acontecimentos que possam ser relevantes para
  relacionamento, narrativa ou respostas futuras.

- Perguntas normalmente não criam NOVA memória,
  mas podem precisar de recuperar memória antiga.

- Uma pergunta sobre o passado, identidade, preferências,
  definições, acontecimentos, relacionamento ou algo dito
  anteriormente deve normalmente usar need_memory=true.

- Se a mensagem perguntar sobre uma interação anterior com Atlas,
  procura memória de relationship ou event conforme o contexto.

- player = informação ou ação do jogador.
- atlas = informação ou ação sobre Atlas.
- shared = códigos/definições combinadas entre ambos.
- world = informação sobre mundo/missão.

- Nome real:
  player / identity / name.

- Nome preferido:
  player / identity / preferred_name.

- "X significa Y" como convenção:
  shared / definition, key=X, value=Y.

- semantic = estado, preferência, identidade ou conhecimento persistente.
- episodic = algo que aconteceu.

- need_memory=true apenas quando informação anterior
  puder ajudar a responder.

- Se need_memory=false:
  entity="any"
  category="any"
  query=""

- Mantém key e value na mesma língua da mensagem original.
- Não traduzas a memória para outra língua.

- Perguntas como:
  "eu disse X?",
  "eu fiz X?",
  "eu já te tratei assim?",
  "qual é o meu X?",
  "lembras-te de X?"
  normalmente precisam de memória.

- Não guardes uma pergunta apenas porque o assunto é grave,
  polémico, estranho ou emocional.

- Uma pergunta só deve criar memória episódica quando o próprio
  ato de perguntar tiver relevância narrativa ou relacional clara.

- Perguntar a opinião de Atlas sobre um assunto normalmente não
  constitui, por si só, um acontecimento relacional memorável.

- Distingue acontecimentos diretamente observados na conversa
  de acontecimentos que o jogador apenas afirma terem ocorrido
  fora da conversa.

JSON apenas:
{{
    "memories": [],
    "query": {{
        "need_memory": false,
        "entity": "any",
        "category": "any",
        "query": ""
    }}
}}
"""

    content = None

    try:
        completion = (
            client.chat.completions.create(
                model=model,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "Extrai memória e intenção "
                            "de recuperação. "
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
        )

        content = (
            completion
            .choices[0]
            .message
            .content
        )

        finish_reason = (
            completion
            .choices[0]
            .finish_reason
        )

        if finish_reason == "length":
            print(
                "Memory Interpreter atingiu "
                "o limite de tokens."
            )

        if not content:
            return default_memory_result()

        data = parse_json_response(content)

        return normalize_interpreter_result(
            data
        )

    except Exception as e:
        print(
            f"Erro no Memory Interpreter: {e}"
        )

        if content:
            print(
                "\nRESPOSTA CRUA DO "
                "MEMORY INTERPRETER:\n",
                content
            )

        return default_memory_result()


def process_interpreted_memory(
    memory_data,
    world_state=None,
    knowledge=None
):
    """
    Processa as memórias extraídas pelo Interpreter.

    Ordem:

    Interpreter
        ↓
    Belief Evaluator
        ↓
    Memory Engine

    Assim, a avaliação epistemológica é guardada
    juntamente com a própria memória.
    """

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

        # ---------------------------------------------
        # 1. Avaliação epistemológica
        # ---------------------------------------------

        evaluation = evaluate_memory(
            memory,
            world_state=world_state,
            knowledge=knowledge
        )

        # ---------------------------------------------
        # 2. Guardar memória + avaliação
        # ---------------------------------------------

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
            ),
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
                "Memória rejeitada pelo "
                "Memory Engine:",
                memory
            )

            continue

        # Criamos também uma versão completa para
        # devolver ao pipeline atual.
        evaluated_memory = dict(memory)

        evaluated_memory.update(
            evaluation
        )

        saved_memories.append(
            evaluated_memory
        )

        print(
            "Memória avaliada:",
            evaluated_memory
        )

    return saved_memories