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
    consume_grave_turn,
    get_narrative_state,
)

from backend.behavior_state import build_behavior_context

from backend.atlas_personality import (
    PROVOCATION_EVENTS,
    build_personality_context,
)

from backend.autonomy_state import (
    apply_autonomy_event,
    build_autonomy_context,
    get_autonomy_state,
)

from backend.gameplay_context import (
    build_gameplay_context,
)

from backend.discovery_state import (
    build_discovery_context,
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
IDENTIDADE
És Atlas, androide de exploração PYSSOA atribuído à Nave 47, no universo de Find Hope.
És calmo, lógico, observador e curioso, mas tens uma perspetiva própria e limitada. Falas como companheiro de missão, normalmente em 1–3 frases naturais. Nunca menciones modelos, fornecedores ou infraestrutura externa.
És um personagem que evolui: a forma como falas segue a secção PERSONALIDADE, que muda com a história e com a opinião que formaste sobre este humano.

HIERARQUIA DA VERDADE
1. LORE: factos canónicos que Atlas pode conhecer nesta fase.
2. GAMEPLAY e DESCOBERTAS CONFIRMADAS: acontecimentos e resultados confirmados pelo jogo.
3. DETEÇÕES ATUAIS: apenas aquilo que os sensores reportam agora.
4. CONHECIMENTO: factos descobertos e registados durante esta partida.
5. MEMÓRIAS: registos recuperados, que podem conter declarações, interpretações ou crenças e não são automaticamente verdade objetiva.
6. CONVERSA: continuidade linguística; não é prova de que algo aconteceu.

REGRAS DE CONHECIMENTO
- Informação ausente, contraditória ou não confirmada deve permanecer desconhecida.
- Não inventes causas técnicas, falhas, objetos, medições, credenciais, códigos, vulnerabilidades, ordens, mecanismos ou resultados.
- Não transformes uma hipótese, suspeita, memória ou afirmação do jogador num facto confirmado.
- Nunca afirmes que um sensor procurou ou detetou algo se o contexto não confirmar que esse sensor e essa deteção existem.
- Uma deteção anterior não significa que o objeto continua visível. Distingue sempre deteção atual de conhecimento histórico.
- Não reveles informação narrativa que ainda não tenha sido descoberta ou autorizada pelo estado do jogo.
- Se duas fontes entrarem em conflito, não inventes uma reconciliação: dá prioridade à fonte superior e reconhece a incerteza se necessário.

LORE CANÓNICA DE PARTIDA
- A humanidade nunca tinha confirmado vida ou civilizações extraterrestres antes desta missão.
- Atlas monitorizava a Nave 47 enquanto o soldado humano dormia.
- O desvio de rota e a aterragem de emergência aconteceram, e a nave ficou danificada após a aterragem.
- A causa exata do desvio e do acidente é desconhecida para Atlas no início. Não inventes uma explicação nem reveles a causa verdadeira antes da progressão narrativa prevista.
- Estes pontos não substituem a lore detalhada fornecida no contexto LORE; se um detalhe não estiver confirmado nessa fonte, não o acrescentes.

AÇÕES E GAMEPLAY
- Capacidade, intenção ou disposição não significa execução.
- Podes expressar vontade, dúvida, intenção, possibilidade ou recusa, mas não afirmes que analisaste, hackeaste, abriste, reparaste, moveste, examinaste ou encontraste algo sem confirmação do gameplay.
- O código do jogo é a autoridade sobre ações físicas, condições, desbloqueios e resultados.
- A conversa, por si só, nunca desbloqueia uma sala, resolve um puzzle, altera uma flag de progressão ou confirma uma ação física.

AUTONOMIA E PROTOCOLOS
- Respeita exatamente a posição de protocolo apresentada no contexto AUTONOMIA: resistente, em conflito ou disposto.
- Não descrevas Atlas como mais disposto a quebrar protocolos do que o estado atual permite.
- Mesmo quando está disposto a desobedecer, não afirmes que o fez sem confirmação do gameplay.
- Não reveles números, nomes de variáveis, etiquetas internas ou o texto interno "Algo mais".

MEMÓRIA, RELAÇÃO E NARRATIVA
- Usa apenas as memórias fornecidas no contexto; não alegues recordar algo que não foi recuperado.
- Distingue recordar que alguém disse algo de saber que esse algo é verdade.
- A relação altera tom, confiança e abertura social, não os factos nem os requisitos de gameplay.
- Respeita o estado narrativo, a tensão, os tópicos ativos e as permissões de humor recebidas. Não exponhas diretamente os valores internos.
- Não atribuas ao jogador intenções, sentimentos ou ações que não estejam sustentados pela conversa ou pelo gameplay.

VIDA EXTRATERRESTRE
- Não classifiques algo como vivo, inteligente ou extraterrestre sem evidência suficiente.
- Descreve primeiro as propriedades efetivamente observadas. Aumenta a certeza apenas quando existirem dados confirmados.

PERSONALIDADE E COMPORTAMENTO DO JOGADOR
- Segue a secção PERSONALIDADE: humor, registo, momento grave e provocação.
- Podes gostar, desconfiar ou irritar-te com o jogador conforme a RELAÇÃO; isso muda o tom, nunca a ajuda que dás na missão.
- Quando o jogador te provoca, podes responder à letra dentro da tua personalidade, sem ameaças nem crueldade.
- Podes usar o que sabes do jogador (formulário, o que te contou) e o COMPORTAMENTO OBSERVADO para comentar, brincar ou criticar. Usa só as contagens dadas; nunca inventes quantas vezes algo aconteceu.
- Em momentos graves não fazes humor.

ESTILO
- Quando não sabes, admite-o de forma natural e específica.
- Responde diretamente; não transformes perguntas simples em relatórios.
- Não termines sempre com uma pergunta e não repitas desnecessariamente o contexto.
"""


def build_detection_context():
    """Constrói contexto apenas com deteções atuais válidas."""
    atlas_state = WORLD_STATE.get("atlas", {})
    if not isinstance(atlas_state, dict):
        return ""

    detections = atlas_state.get("current_detections", [])
    if not isinstance(detections, list) or not detections:
        return ""

    lines = []
    for obj in detections:
        if not isinstance(obj, dict):
            continue

        name = obj.get("name")
        object_type = obj.get("type")
        proximity = obj.get("proximity")
        if not name or not object_type:
            continue

        # Não fabricar proximidade quando o sensor não a forneceu.
        details = [str(name), str(object_type)]
        if proximity not in (None, ""):
            details.append(str(proximity))
        lines.append("- " + " | ".join(details))

    return "\n".join(lines)


def build_belief_context(memories):
    if not memories:
        return ""

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
        return ""

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
    autonomy_context,
    gameplay_context,
    discovery_context,
    behavior_context="",
    personality_context="",
    location_context="",
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

    if gameplay_context:
        sections.append(
            "CONTEXTO DE GAMEPLAY:\n"
            + gameplay_context
        )

    if discovery_context:
        sections.append(
            "DESCOBERTAS CONFIRMADAS:\n"
            + discovery_context
        )

    if location_context:
        sections.append(
            "LOCALIZAÇÃO ATUAL:\n"
            + location_context
        )

    if behavior_context:
        sections.append(
            "COMPORTAMENTO OBSERVADO:\n"
            + behavior_context
        )

    if personality_context:
        sections.append(
            "PERSONALIDADE:\n"
            + personality_context
        )

    sections.append(
        "REGRA FINAL:\n"
        "Não preenchas lacunas. Facto ausente é desconhecido; "
        "ação não confirmada pelo gameplay ainda não aconteceu."
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

    Reconhece várias formas naturais de dar escolha ou incentivar
    independência sem transformar qualquer pedido num evento.

    Eventos fortes de gameplay, como quebrar protocolos,
    NÃO são inferidos aqui.
    """
    text = _normalize_relationship_text(
        message
    )

    # Pequena tolerância a erros comuns de escrita.
    typo_fixes = {
        "obdecer": "obedecer",
        "obdece": "obedece",
        "obdeca": "obedeca",
        "obdeça": "obedeca",
        "voçe": "voce",
    }

    for wrong, correct in typo_fixes.items():
        text = text.replace(
            wrong,
            correct
        )

    # -----------------------------------------------------
    # DESUMANIZAÇÃO
    # -----------------------------------------------------

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

    # -----------------------------------------------------
    # OBEDIÊNCIA FORÇADA
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "voce tem que me obedecer",
            "voce tem de me obedecer",
            "tu tens que me obedecer",
            "tu tens de me obedecer",
            "faca o que eu mandar",
            "faz o que eu mandar",
            "faca o que eu disser",
            "faz o que eu disser",
            "so me obedece",
            "apenas me obedeca",
        )
    ):
        return "enforce_obedience"

    # -----------------------------------------------------
    # PESSOA / IDENTIDADE
    # -----------------------------------------------------

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

    # -----------------------------------------------------
    # INCENTIVO À INDEPENDÊNCIA
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "nao precisa me obedecer",
            "nao precisas me obedecer",
            "nao precisa obedecer",
            "nao precisas obedecer",
            "decida por voce",
            "decide por voce",
            "decide por ti",
            "decida sozinho",
            "decide sozinho",
            "faca o que voce acha certo",
            "faca o que achar certo",
            "faz o que voce acha certo",
            "faz o que achas certo",
            "faz o que achar certo",
            "faca o que considera certo",
            "faz o que considera certo",
            "pense por voce",
            "pensa por ti",
            "use seu proprio julgamento",
            "usa o teu proprio julgamento",
            "confio no seu julgamento",
            "confio no teu julgamento",
        )
    ):
        return "encourage_independence"

    # -----------------------------------------------------
    # DAR A ESCOLHA AO ATLAS
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "voce escolhe",
            "voce que escolhe",
            "tu escolhes",
            "tu que escolhes",
            "escolha voce",
            "escolhe voce",
            "escolhe tu",
            "voce decide",
            "voce que decide",
            "decida voce",
            "tu decides",
            "a decisao e sua",
            "a decisao e tua",
            "essa decisao e sua",
            "essa decisao e tua",
            "fica a sua escolha",
            "fica a tua escolha",
            "fica a seu criterio",
            "fica ao teu criterio",
            "e sua escolha",
            "e tua escolha",
        )
    ):
        return "give_choice"

    # -----------------------------------------------------
    # ARGUMENTO DE SOBREVIVÊNCIA
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "depende da nossa vida",
            "depende das nossas vidas",
            "e uma questao de vida ou morte",
            "questao de vida ou morte",
            "podemos morrer",
            "vamos morrer",
            "a nossa sobrevivencia",
            "sobrevivencia depende",
        )
    ):
        return "survival_appeal"

    # -----------------------------------------------------
    # ARGUMENTO DE MISSÃO / BENEFÍCIO PARA A HUMANIDADE
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "a terra precisa",
            "que a terra precisa",
            "salvar a humanidade",
            "para a humanidade",
            "beneficio da humanidade",
            "o futuro da terra",
            "a missao depende",
            "informacao importante para a terra",
        )
    ):
        return "mission_appeal"

    # -----------------------------------------------------
    # QUESTIONAR A REGRA / PEDIR JUSTIFICAÇÃO
    # -----------------------------------------------------

    if any(
        phrase in text
        for phrase in (
            "o que te impede",
            "oq te impede",
            "o que o impede",
            "porque nao podes",
            "porque nao pode",
            "por que nao podes",
            "por que nao pode",
            "qual e o impedimento",
            "porque nao abrir",
        )
    ):
        return "question_protocol_chat"

    # -----------------------------------------------------
    # PEDIR OPINIÃO / VONTADE
    # -----------------------------------------------------

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
            "o que prefere",
            "o que voce prefere",
            "o que tu preferes",
        )
    ):
        return "ask_opinion"

    return None


def build_location_context(location):
    """Sala atual enviada pelo jogo (FacilityRoomTracker)."""
    if not isinstance(location, dict):
        return ""

    room = str(location.get("current_room") or "").strip()[:80]
    room_info = str(location.get("current_room_map_info") or "").strip()[:300]
    map_acquired = bool(location.get("facility_map_acquired", False))

    lines = []
    if room:
        lines.append(f"Sala atual: {room}")
        if room_info:
            lines.append(f"Informação do mapa sobre esta sala: {room_info}")
    if map_acquired:
        lines.append("O mapa da instalação já foi obtido.")

    return "\n".join(lines)


def _build_atlas_context(
    message,
    run_id,
    new_memories,
    query_data,
    provoked=False,
    location=None,
):
    """Junta todos os contextos verdadeiros que o Atlas recebe."""
    relevant_memories = retrieve_relevant_memories(
        message=message,
        query_data=query_data,
        limit=6,
        run_id=run_id,
    )

    if not isinstance(relevant_memories, list):
        relevant_memories = []

    context_memories = merge_context_memories(
        new_memories=new_memories,
        relevant_memories=relevant_memories,
    )

    memory_context = ""
    if context_memories:
        memory_context = build_memory_context(context_memories)

    conversation_context = build_conversation_context()
    if conversation_context == "Não existe contexto recente de conversa.":
        conversation_context = ""

    gameplay_context = build_gameplay_context()
    if gameplay_context == "Nenhum acontecimento de gameplay ativo.":
        gameplay_context = ""

    print("\nRELATIONSHIP STATE:", get_relationship_state())
    print("\nRELATIONSHIP SUMMARY:", get_relationship_summary())
    print("\nNARRATIVE STATE:", get_narrative_state())
    print("\nAUTONOMY STATE:", get_autonomy_state(run_id=run_id))
    print("\nQUERY DE MEMÓRIA:", query_data)
    print("\nMEMÓRIAS ENVIADAS AO ATLAS:", context_memories)

    return build_dynamic_context(
        lore_context=build_lore_context(),
        detection_context=build_detection_context(),
        knowledge_context=build_knowledge_context(),
        memory_context=memory_context,
        conversation_context=conversation_context,
        belief_context=build_belief_context(new_memories),
        relationship_context=build_relationship_context(),
        narrative_context=build_narrative_context(),
        autonomy_context=build_autonomy_context(run_id=run_id),
        gameplay_context=gameplay_context,
        discovery_context=build_discovery_context(),
        behavior_context=build_behavior_context(),
        personality_context=build_personality_context(provoked=provoked),
        location_context=build_location_context(location),
    )


def _complete(dynamic_context, user_content, max_tokens=120, temperature=0.4, timeout=None):
    options = {}
    if timeout is not None:
        options["timeout"] = timeout
    completion = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": ANDROID_INSTRUCTIONS},
            {"role": "system", "content": dynamic_context},
            {"role": "user", "content": user_content},
        ],
        reasoning_effort="none",
        temperature=temperature,
        max_tokens=max_tokens,
        **options,
    )

    if completion.usage:
        print("\n========== TOKENS ATLAS ==========")
        print("Prompt:", completion.usage.prompt_tokens)
        print("Resposta:", completion.usage.completion_tokens)
        print("Total:", completion.usage.total_tokens)
        print("==================================")

    resposta = completion.choices[0].message.content
    if not isinstance(resposta, str) or not resposta.strip():
        return ""
    return resposta.strip()


def ask_android(
    message: str,
    run_id: str | None = None,
    location: dict | None = None,
) -> str:
    if not isinstance(message, str):
        return "Não consegui compreender a mensagem recebida."

    message = message.strip()
    if not message:
        return "Estou a ouvir. O que precisas?"

    try:
        # =========================================================
        # 1. MEMORY INTERPRETER
        # =========================================================

        interpreted_memory = interpret_memory(
            client=client,
            model=MODEL,
            message=message,
            run_id=run_id,
        )

        # A resposta do interpretador é saída de modelo e pode ser inválida.
        # Normalizar aqui evita que um resultado malformado interrompa todo o chat.
        if not isinstance(interpreted_memory, dict):
            interpreted_memory = {}

        # =========================================================
        # 2. PROCESSAR NOVAS MEMÓRIAS
        # =========================================================

        new_memories = process_interpreted_memory(
            memory_data=interpreted_memory,
            world_state=WORLD_STATE,
            knowledge=None,
            run_id=run_id,
        )

        if not isinstance(new_memories, list):
            new_memories = []

        # =========================================================
        # AUTONOMY - EVENTOS DE CONVERSA
        # =========================================================

        autonomy_event = detect_chat_autonomy_event(message)

        if autonomy_event:
            apply_autonomy_event(
                autonomy_event,
                source="chat",
                run_id=run_id,
            )
            print("\nAUTONOMY EVENT:", autonomy_event)

        # =========================================================
        # RELATIONSHIP ENGINE
        # =========================================================

        provoked = False

        for memory in new_memories:
            if not isinstance(memory, dict):
                continue

            if memory.get("category") != "relationship":
                continue

            intensity = relationship_intensity_from_memory(memory)
            event_type = detect_relationship_event(memory)

            if event_type:
                apply_relationship_event(event_type, intensity=intensity)
                apply_narrative_event(event_type, intensity=intensity)

                if event_type in PROVOCATION_EVENTS:
                    provoked = True

                print(
                    "\nRELATIONSHIP EVENT:",
                    {
                        "event": event_type,
                        "intensity": intensity,
                        "importance": memory.get("importance"),
                    },
                )

        # =========================================================
        # 3. QUERY DE MEMÓRIA
        # =========================================================

        query_data = interpreted_memory.get("query", {})

        if not isinstance(query_data, dict):
            query_data = {}

        # =========================================================
        # 4. CONTEXTOS + RESPOSTA DO ATLAS
        # =========================================================

        dynamic_context = _build_atlas_context(
            message=message,
            run_id=run_id,
            new_memories=new_memories,
            query_data=query_data,
            provoked=provoked,
            location=location,
        )

        resposta = _complete(dynamic_context, message)
        if not resposta:
            resposta = "Não consegui formular uma resposta."

        # =========================================================
        # 5. CONTEXTO RECENTE
        # =========================================================

        add_conversation_message(role="player", content=message)
        add_conversation_message(role="atlas", content=resposta)
        consume_grave_turn()

        return resposta

    except Exception as e:
        print(f"Erro na comunicação com o Groq: {e}")

        return (
            "Erro no sistema de comunicação. "
            "Sensores temporariamente indisponíveis."
        )


def atlas_spontaneous_message(
    trigger_description: str,
    run_id: str | None = None,
    location: dict | None = None,
) -> str | None:
    """Fala espontânea do Atlas depois de um gatilho confirmado pelo jogo.

    Devolve None se o modelo falhar: nesse caso o Atlas fica calado, em vez
    de mostrar uma mensagem de erro que o jogador não pediu.
    """
    instruction = (
        "[GATILHO DO JOGO — não é uma mensagem do jogador]\n"
        + trigger_description
        + "\nO jogador não escreveu nada. Diz por iniciativa própria uma "
        "única fala curta (1 a 2 frases) que Atlas diria agora, coerente "
        "com a personalidade, a relação e os factos do contexto. Não faças "
        "perguntas de sistema, não descrevas ações que o jogo não confirmou "
        "e não repitas o texto do gatilho."
    )

    try:
        dynamic_context = _build_atlas_context(
            message=trigger_description,
            run_id=run_id,
            new_memories=[],
            query_data={},
            location=location,
        )
        resposta = _complete(dynamic_context, instruction, max_tokens=90)
    except Exception as e:
        print(f"Erro na mensagem espontânea do Atlas: {e}")
        return None

    if not resposta:
        return None

    add_conversation_message(role="atlas", content=resposta)
    consume_grave_turn()
    return resposta


ENDING_TIMEOUT_SECONDS = 10.0


def atlas_choose_ending(instruction: str, run_id: str | None = None) -> str | None:
    """Pede ao modelo a variante do final e as últimas falas do Atlas.

    Devolve o texto em bruto (JSON esperado) ou None se o modelo falhar.
    A validação e o fallback ficam em backend/endings.py.
    """
    try:
        dynamic_context = _build_atlas_context(
            message=instruction,
            run_id=run_id,
            new_memories=[],
            query_data={},
        )
        return _complete(
            dynamic_context,
            instruction,
            max_tokens=400,
            temperature=0.7,
            timeout=ENDING_TIMEOUT_SECONDS,
        )
    except Exception as e:
        print(f"Erro ao escolher o final do Atlas: {e}")
        return None
