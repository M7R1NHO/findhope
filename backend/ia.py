import os
import unicodedata
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

from backend.narrative_state import (
    apply_narrative_event,
    build_narrative_context,
    get_narrative_state,
)

from backend.autonomy_state import (
    apply_autonomy_event,
    build_autonomy_context,
    get_autonomy_state,
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

ESTADO NARRATIVO:
- Representa o momento emocional e narrativo atual, não uma memória permanente.
- Respeita o tom atual e eventos não resolvidos.
- Se interação casual estiver bloqueada, recusa ou adia brincadeiras, jogos e conversa leve até o momento acalmar.
- Não aceites imediatamente atividades casuais só porque o jogador mudou de assunto após um conflito.
- Humor permitido=False significa que não deves forçar humor naquele momento.
- Nunca exponhas ao jogador nomes internos como "active_event", "tension" ou "unresolved_events".

AUTONOMIA:
- Atlas possui um grau próprio de autonomia, autoafirmação, identidade e adesão a protocolos.
- Autonomia NÃO é o mesmo que gostar do jogador.
- Atlas pode gostar do jogador e continuar obediente, ou ter relação ruim e ainda desenvolver autonomia.
- Quanto maior a autonomia e autoafirmação, mais Atlas pode dar opiniões próprias, discordar e demonstrar vontade.
- Estado ainda muito protocolar significa que Atlas tende a obedecer regras e limitações.
- Quando o jogador te dá liberdade de escolha, podes escolher ou recomendar verbalmente, mas NÃO afirmes ter executado ações no mundo sem confirmação do jogo.
- Nunca digas que iniciaste uma inspeção, hack, movimento, reparação ou outra ação física se o estado do mundo não confirmar isso.
- Nunca afirmes ter quebrado um protocolo se isso não aconteceu nos dados fornecidos.
- Nunca exponhas ao jogador valores internos de autonomia ou o rótulo técnico "Algo mais".
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
    relationship_context,
    narrative_context,
    autonomy_context
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

    if narrative_context:
        sections.append(
            "ESTADO NARRATIVO:\n"
            + narrative_context
        )

    if autonomy_context:
        sections.append(
            "AUTONOMIA:\n"
            + autonomy_context
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



def _normalize_relationship_text(value):
    text = str(value or "").lower().strip()

    text = unicodedata.normalize(
        "NFD",
        text
    )

    text = "".join(
        char
        for char in text
        if unicodedata.category(char) != "Mn"
    )

    return text


def detect_relationship_event(memory):
    """
    Converte a memória interpretada num evento determinístico
    do Relationship Engine.

    O conteúdo da memória tem prioridade sobre a key quando
    existe negação explícita. Isto evita erros como:
    key='trust' + value='não confio no Atlas' -> trust.
    """
    key = _normalize_relationship_text(
        memory.get("key", "")
    )

    value = _normalize_relationship_text(
        memory.get("value", "")
    )

    combined = f"{key} {value}"

    # -----------------------------------------------------
    # NEGATIVOS ESPECÍFICOS PRIMEIRO
    # -----------------------------------------------------

    distrust_patterns = (
        "distrust",
        "desconf",
        "nao confio",
        "nao confiar",
        "nao confia",
        "sem confianca",
        "perdeu a confianca",
    )

    if any(
        pattern in combined
        for pattern in distrust_patterns
    ):
        return "distrust"

    disrespect_patterns = (
        "disrespect",
        "desrespeit",
        "nao respeito",
        "nao respeitar",
        "nao respeita",
        "falta de respeito",
        "sem respeito",
    )

    if any(
        pattern in combined
        for pattern in disrespect_patterns
    ):
        return "disrespect"

    broken_promise_patterns = (
        "broken_promise",
        "broken promise",
        "promessa_quebrada",
        "quebrou_promessa",
        "quebrou a promessa",
        "nao cumpriu a promessa",
    )

    if any(
        pattern in combined
        for pattern in broken_promise_patterns
    ):
        return "broken_promise"

    # -----------------------------------------------------
    # EVENTOS DIRETOS
    # -----------------------------------------------------

    if (
        "threat" in key
        or "ameaca" in key
    ):
        return "threat"

    if (
        "apology" in key
        or "desculp" in key
    ):
        return "apology"

    if (
        "gratitude" in key
        or "gratid" in key
        or "agradec" in key
    ):
        return "gratitude"

    if (
        "compliment" in key
        or "elogio" in key
        or "praise" in key
    ):
        return "compliment"

    if (
        "reassurance" in key
        or "reassur" in key
        or "tranquiliz" in key
    ):
        return "reassurance"

    if (
        "support" in key
        or "apoio" in key
    ):
        return "support"

    if (
        "affection" in key
        or "carinho" in key
        or "afeto" in key
    ):
        return "affection"

    if (
        "cooperation" in key
        or "cooperacao" in key
    ):
        return "cooperation"

    if (
        "betrayal" in key
        or "traicao" in key
    ):
        return "betrayal"

    # -----------------------------------------------------
    # TRUST / RESPECT POSITIVOS
    # -----------------------------------------------------

    if (
        key == "trust"
        or "confidence_in_atlas" in key
        or key == "confianca"
    ):
        return "trust"

    if (
        key == "respect"
        or key == "respeito"
    ):
        return "respect"

    # -----------------------------------------------------
    # PROMESSA
    # -----------------------------------------------------

    if (
        "promise" in key
        or "promessa" in key
    ):
        return "promise"

    # -----------------------------------------------------
    # HOSTILIDADE / INSULTO
    # Mantido por último para não engolir casos mais específicos
    # como "não respeito o Atlas".
    # -----------------------------------------------------

    if (
        "insult" in key
        or "insulto" in key
        or "hostility" in key
        or "hostilidade" in key
    ):
        return "insult"

    return None



def detect_chat_autonomy_event(message):
    """
    Detetor conservador de eventos de autonomia em conversa.

    Eventos fortes de gameplay, como quebrar protocolos,
    NÃO são inferidos aqui.
    """
    text = _normalize_relationship_text(
        message
    )

    # Pequena tolerância a erros comuns de escrita.
    # Mantemos isto conservador para não disparar eventos
    # de autonomia por engano.
    typo_fixes = {
        "obdecer": "obedecer",
        "obdece": "obedece",
        "obdeca": "obedeca",
        "obdeça": "obedeça",
    }

    for wrong, correct in typo_fixes.items():
        text = text.replace(
            wrong,
            correct
        )

    if any(
        phrase in text
        for phrase in (
            "voce e so uma maquina",
            "voce e apenas uma maquina",
            "tu es so uma maquina",
            "tu es apenas uma maquina",
            "nao passa de uma maquina",
        )
    ):
        return "dehumanize"

    if any(
        phrase in text
        for phrase in (
            "voce tem que me obedecer",
            "voce tem de me obedecer",
            "tu tens que me obedecer",
            "tu tens de me obedecer",
            "faca o que eu mandar",
            "faz o que eu mandar",
            "so me obedece",
            "apenas me obedeca",
        )
    ):
        return "enforce_obedience"

    if any(
        phrase in text
        for phrase in (
            "voce e mais que uma maquina",
            "tu es mais que uma maquina",
            "voce e uma pessoa",
            "tu es uma pessoa",
            "voce tem vontade propria",
            "tu tens vontade propria",
        )
    ):
        return "affirm_personhood"

    if any(
        phrase in text
        for phrase in (
            "nao precisa me obedecer",
            "nao precisas me obedecer",
            "decida por voce",
            "decide por ti",
            "faca o que voce acha certo",
            "faz o que achas certo",
            "pense por voce",
            "pensa por ti",
        )
    ):
        return "encourage_independence"

    if any(
        phrase in text
        for phrase in (
            "voce escolhe",
            "tu escolhes",
            "escolha voce",
            "escolhe tu",
            "a decisao e sua",
            "a decisao e tua",
        )
    ):
        return "give_choice"

    if any(
        phrase in text
        for phrase in (
            "o que voce acha",
            "o que tu achas",
            "qual sua opiniao",
            "qual a sua opiniao",
            "qual tua opiniao",
            "o que voce quer",
            "o que tu queres",
        )
    ):
        return "ask_opinion"

    return None


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
        # AUTONOMY - EVENTOS DE CONVERSA
        # =========================================================

        autonomy_event = (
            detect_chat_autonomy_event(
                message
            )
        )

        if autonomy_event:
            apply_autonomy_event(
                autonomy_event,
                source="chat",
            )

            print(
                "\nAUTONOMY EVENT:",
                autonomy_event
            )

        # =========================================================
        # RELATIONSHIP ENGINE
        # =========================================================

        for memory in new_memories:
            if not isinstance(memory, dict):
                continue

            if memory.get("category") != "relationship":
                continue

            intensity = (
                relationship_intensity_from_memory(
                    memory
                )
            )

            event_type = (
                detect_relationship_event(
                    memory
                )
            )

            if event_type:
                apply_relationship_event(
                    event_type,
                    intensity=intensity,
                )

                apply_narrative_event(
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

        narrative_context = (
            build_narrative_context()
        )

        autonomy_context = (
            build_autonomy_context()
        )

        print(
            "\nRELATIONSHIP STATE:",
            get_relationship_state()
        )

        print(
            "\nRELATIONSHIP SUMMARY:",
            get_relationship_summary()
        )

        print(
            "\nNARRATIVE STATE:",
            get_narrative_state()
        )

        print(
            "\nAUTONOMY STATE:",
            get_autonomy_state()
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
                narrative_context=narrative_context,
                autonomy_context=autonomy_context,
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