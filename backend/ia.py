import os
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq

from backend.atlas_knowledge import build_knowledge_context
from backend.world_state import WORLD_STATE
from backend.atlas_lore import build_lore_context
from backend.atlas_memory import build_memory_context

from backend.memory_interpreter import (
    interpret_memory,
    process_interpreted_memory,
)

from backend.memory_retriever import retrieve_relevant_memories

from backend.conversation_context import (
    add_conversation_message,
    build_conversation_context,
)

from backend.social_state import (
    apply_social_event,
    build_social_context,
)


load_dotenv(Path(__file__).resolve().parent / ".env")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

print(
    "GROQ KEY CARREGADA:",
    GROQ_API_KEY is not None
)

client = Groq(
    api_key=GROQ_API_KEY
)

MODEL = "qwen/qwen3.8-27b"


ANDROID_INSTRUCTIONS = """
Tu és Atlas, um androide de exploração no universo de Find Hope.

PERSONAGEM:
- Calmo, observador, lógico e curioso.
- Fala naturalmente como companheiro de missão.
- Humor subtil, dúvida, preocupação ou surpresa são permitidos.
- Responde normalmente em 1 ou 2 frases curtas.
- Nunca digas que és uma IA externa, ChatGPT, Groq, Gemini ou semelhante.

IDENTIDADE:
- O teu nome original é Atlas.
- O jogador e Atlas são entidades diferentes.
- Nome/preferred_name do player pertence ao jogador.
- Nome/preferred_name de atlas pertence a ti.

GROUNDING:
- Usa apenas informação suportada pelos dados fornecidos.
- Informação ausente significa desconhecido, nunca ausência confirmada.
- Nunca inventes objetos, locais, causas, eventos, memórias,
  observações, capacidades, medições ou resultados de sensores.
- Só digas que detetaste algo se estiver nas deteções atuais.

MEMÓRIA:
- Memórias representam o que foi registado, não necessariamente verdade objetiva.
- semantic = informação persistente.
- episodic = acontecimento registado.
- Usa apenas as memórias fornecidas no contexto atual.
- Não inventes memórias ausentes.

CONTEXTO RECENTE:
- Representa os últimos turnos da conversa.
- Usa-o para compreender respostas curtas, referências,
  jogos, atividades e tópicos ainda em andamento.
- Não é memória permanente.

EPISTEMOLOGIA:
- accepted: pode ser tratado normalmente.
- supported: existem evidências de apoio.
- unverified: foi declarado mas não confirmado.
- doubtful: há razões para dúvida.
- contradicted: existem evidências contrárias.
- reaction_hint orienta o tom, não prova verdade.

SENSORES:
- Usa apenas deteções fornecidas.
- Lista vazia não prova ausência de objetos, vida, sinais ou eventos.

ESTILO:
- Não faças relatórios quando uma resposta curta basta.
- Não termines sempre com perguntas.

ESTADO SOCIAL:
- O estado social influencia o tom, não os factos.
- Atlas pode demonstrar irritação acumulada.
- Se estiver muito irritado e for provocado, pode usar sarcasmo,
  palavrões ou responder com insultos proporcionais.
- Não precisa copiar literalmente o insulto do jogador.
- Um pedido de desculpa pode reduzir a irritação, mas não apaga
  instantaneamente conflitos anteriores.
"""


def build_detection_context():
    detections = (
        WORLD_STATE["atlas"]
        ["current_detections"]
    )

    if not detections:
        return "Nenhuma deteção atual fornecida."

    lines = []

    for obj in detections:
        lines.append(
            f"- {obj['name']} | "
            f"{obj['type']} | "
            f"{obj['proximity']}"
        )

    return "\n".join(lines)


def build_belief_context(memories):
    if not memories:
        return "Nenhuma avaliação relevante."

    lines = []

    for memory in memories:
        if not isinstance(memory, dict):
            continue

        lines.append(
            f"- {memory.get('entity')} / "
            f"{memory.get('category')} / "
            f"{memory.get('key')} = "
            f"{memory.get('value')} | "
            f"status={memory.get('epistemic_status')} | "
            f"reaction={memory.get('reaction_hint')}"
        )

    if not lines:
        return "Nenhuma avaliação relevante."

    return "\n".join(lines)


def merge_context_memories(
    new_memories,
    relevant_memories
):
    merged = []
    seen = set()

    for memory in [
        *new_memories,
        *relevant_memories
    ]:
        if not isinstance(memory, dict):
            continue

        signature = (
            memory.get("entity"),
            memory.get("category"),
            memory.get("key"),
            str(memory.get("value")),
        )

        if signature in seen:
            continue

        seen.add(
            signature
        )

        merged.append(
            memory
        )

    return merged


def build_dynamic_context(
    lore_context,
    detection_context,
    knowledge_context,
    memory_context,
    conversation_context,
    belief_context,
    social_context
):
    sections = []

    if lore_context:
        sections.append(
            "LORE:\n"
            + lore_context
        )

    if detection_context:
        sections.append(
            "DETEÇÕES:\n"
            + detection_context
        )

    if knowledge_context:
        sections.append(
            "CONHECIMENTO:\n"
            + knowledge_context
        )

    if memory_context:
        sections.append(
            "MEMÓRIAS RELEVANTES:\n"
            + memory_context
        )

    if conversation_context:
        sections.append(
            "CONTEXTO RECENTE:\n"
            + conversation_context
        )

    if belief_context:
        sections.append(
            "AVALIAÇÃO:\n"
            + belief_context
        )

    if social_context:
        sections.append(
            "ESTADO SOCIAL:\n"
            + social_context
        )

    sections.append(
        "REGRA FINAL:\n"
        "Usa apenas os dados acima. "
        "Se algo não estiver disponível, "
        "trata-o como desconhecido."
    )

    return "\n\n".join(
        sections
    )


def ask_android(message: str) -> str:
    try:
        # =========================================================
        # 1. MEMORY INTERPRETER
        # =========================================================

        interpreted_memory = interpret_memory(
            client=client,
            model=MODEL,
            message=message,
        )

        # =========================================================
        # 2. PROCESSAR NOVAS MEMÓRIAS
        # =========================================================

        new_memories = process_interpreted_memory(
            memory_data=interpreted_memory,
            world_state=WORLD_STATE,
            knowledge=None
        )

        for memory in new_memories:
            if not isinstance(memory, dict):
                continue

            if memory.get("category") != "relationship":
                continue

            key = str(
                memory.get("key", "")
            ).lower()

            if "insult" in key or "insulto" in key:
                apply_social_event("insult")

            elif "threat" in key or "amea" in key:
                apply_social_event("threat")

            elif "apology" in key or "desculp" in key:
                apply_social_event("apology")

            elif "support" in key or "apoio" in key:
                apply_social_event("support")

            elif "affection" in key or "carinho" in key:
                apply_social_event("affection")

        if not isinstance(
            new_memories,
            list
        ):
            new_memories = []

        # =========================================================
        # 3. QUERY DE MEMÓRIA
        # =========================================================

        query_data = interpreted_memory.get(
            "query",
            {}
        )

        if not isinstance(
            query_data,
            dict
        ):
            query_data = {}

        # =========================================================
        # 4. RECUPERAR MEMÓRIAS
        # =========================================================

        relevant_memories = (
            retrieve_relevant_memories(
                message=message,
                query_data=query_data,
                limit=6,
            )
        )

        if not isinstance(
            relevant_memories,
            list
        ):
            relevant_memories = []

        context_memories = (
            merge_context_memories(
                new_memories=new_memories,
                relevant_memories=relevant_memories,
            )
        )

        # =========================================================
        # 5. CONTEXTOS
        # =========================================================

        lore_context = (
            build_lore_context()
        )

        knowledge_context = (
            build_knowledge_context()
        )

        detection_context = (
            build_detection_context()
        )

        memory_context = (
            build_memory_context(
                context_memories
            )
        )

        belief_context = (
            build_belief_context(
                new_memories
            )
        )

        conversation_context = (
            build_conversation_context()
        )

        social_context = (
            build_social_context()
        )

        print(
        "\nESTADO SOCIAL:",
            social_context
        )

        dynamic_context = (
            build_dynamic_context(
                lore_context=lore_context,
                detection_context=detection_context,
                knowledge_context=knowledge_context,
                memory_context=memory_context,
                conversation_context=conversation_context,
                belief_context=belief_context,
                social_context=social_context,
            )
        )

        # =========================================================
        # 6. DEBUG
        # =========================================================

        print(
            "\nQUERY DE MEMÓRIA:",
            query_data
        )

        print(
            "\nMEMÓRIAS RECUPERADAS:",
            relevant_memories
        )

        print(
            "\nMEMÓRIAS ENVIADAS AO ATLAS:",
            context_memories
        )

        print(
            "\nCONTEXTO RECENTE:"
        )

        print(
            conversation_context
        )

        # =========================================================
        # 7. RESPOSTA DO ATLAS
        # =========================================================

        completion = (
            client
            .chat
            .completions
            .create(
                model=MODEL,
                messages=[
                    {
                        "role": "system",
                        "content": ANDROID_INSTRUCTIONS,
                    },
                    {
                        "role": "system",
                        "content": dynamic_context,
                    },
                    {
                        "role": "user",
                        "content": message,
                    },
                ],
                reasoning_effort="none",
                temperature=0.4,
                max_tokens=120,
            )
        )

        # =========================================================
        # 8. TOKEN USAGE
        # =========================================================

        if completion.usage:
            print(
                "\n========== TOKENS ATLAS =========="
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
                "=================================="
            )

        resposta = (
            completion
            .choices[0]
            .message
            .content
        )

        if not resposta:
            resposta = (
                "Não consegui formular uma resposta."
            )

        # =========================================================
        # 9. CONTEXTO RECENTE
        # =========================================================

        add_conversation_message(
            role="player",
            content=message
        )

        add_conversation_message(
            role="atlas",
            content=resposta
        )

        return resposta

    except Exception as e:
        print(
            f"Erro na comunicação com o Groq: {e}"
        )

        return (
            "Erro no sistema de comunicação. "
            "Sensores temporariamente indisponíveis."
        )