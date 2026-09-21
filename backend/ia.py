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

from backend.relationship_engine import (
    apply_relationship_event,
    build_relationship_context,
    get_relationship_state,
    get_relationship_summary,
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

RELAÇÃO:
- A relação é bidirecional: Atlas→jogador e jogador→Atlas.
- Os valores jogador→Atlas representam atitude observada, não leitura mental.
- Confiança, respeito, afinidade, tensão e irritação/hostilidade mudam com eventos.
- A relação influencia o tom e a abertura social, nunca os factos do mundo.
- Irritação alta pode gerar respostas secas, sarcasmo ou palavrões se houver provocação.
- Um pedido de desculpa pode reduzir tensão e irritação, mas não restaura instantaneamente confiança ou respeito.
- NUNCA exponhas ao jogador nomes de variáveis, valores, pontuações, classes ou estados internos.
- NUNCA digas frases como "registei o insulto", "a tensão aumentou", "a confiança diminuiu"
  ou semelhantes. Demonstra a mudança através da fala e do comportamento natural de Atlas.
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
    relationship_context
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

    if relationship_context:
        sections.append(
            "RELAÇÃO:\n"
            + relationship_context
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



def relationship_intensity_from_memory(memory):
    """
    Converte importance do Interpreter em intensidade social.
    Mantém eventos leves relevantes sem deixar qualquer frase
    produzir alterações exageradas.
    """
    try:
        importance = float(memory.get("importance", 0.5))
    except (TypeError, ValueError):
        importance = 0.5

    if importance >= 0.9:
        return 1.5

    if importance >= 0.7:
        return 1.0

    return 0.5


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

        if not isinstance(
            new_memories,
            list
        ):
            new_memories = []

        # =========================================================
        # RELATIONSHIP ENGINE
        # =========================================================

        for memory in new_memories:
            if not isinstance(memory, dict):
                continue

            if memory.get("category") != "relationship":
                continue

            key = str(
                memory.get("key", "")
            ).lower()

            intensity = (
                relationship_intensity_from_memory(
                    memory
                )
            )

            event_type = None

            if (
                "insult" in key
                or "insulto" in key
                or "hostility" in key
                or "hostilidade" in key
            ):
                event_type = "insult"

            elif (
                "threat" in key
                or "ameaça" in key
                or "ameaca" in key
                or "amea" in key
            ):
                event_type = "threat"

            elif (
                "apology" in key
                or "desculp" in key
            ):
                event_type = "apology"

            elif (
                "gratitude" in key
                or "gratid" in key
                or "agradec" in key
            ):
                event_type = "gratitude"

            elif (
                "compliment" in key
                or "elogio" in key
                or "praise" in key
            ):
                event_type = "compliment"

            elif (
                "reassurance" in key
                or "reassur" in key
                or "tranquiliz" in key
            ):
                event_type = "reassurance"

            elif (
                "support" in key
                or "apoio" in key
            ):
                event_type = "support"

            elif (
                "affection" in key
                or "carinho" in key
                or "afeto" in key
            ):
                event_type = "affection"

            elif (
                "cooperation" in key
                or "cooperação" in key
                or "cooperacao" in key
            ):
                event_type = "cooperation"

            elif (
                "broken_promise" in key
                or "broken promise" in key
                or "promessa_quebrada" in key
                or "quebrou_promessa" in key
            ):
                event_type = "broken_promise"

            elif (
                "promise" in key
                or "promessa" in key
            ):
                event_type = "promise"

            elif (
                "betrayal" in key
                or "traição" in key
                or "traicao" in key
            ):
                event_type = "betrayal"

            if event_type:
                apply_relationship_event(
                    event_type,
                    intensity=intensity,
                )

                print(
                    "\nRELATIONSHIP EVENT:",
                    {
                        "event": event_type,
                        "intensity": intensity,
                        "importance": memory.get(
                            "importance"
                        ),
                    },
                )

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

        relationship_context = (
            build_relationship_context()
        )

        print(
            "\nRELATIONSHIP STATE:",
            get_relationship_state()
        )

        print(
            "\nRELATIONSHIP SUMMARY:",
            get_relationship_summary()
        )

        dynamic_context = (
            build_dynamic_context(
                lore_context=lore_context,
                detection_context=detection_context,
                knowledge_context=knowledge_context,
                memory_context=memory_context,
                conversation_context=conversation_context,
                belief_context=belief_context,
                relationship_context=relationship_context,
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