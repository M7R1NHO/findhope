"""Prompt compacto do Atlas (renovação do chat, 24/10/2026).

Antes, cada mensagem do chat enviava ao Groq cerca de 13 000 a 17 000
caracteres: as instruções fixas, a lore completa e todos os contextos com
regras repetidas no fim de cada secção. Este módulo junta o mesmo estado
num texto mais curto:

- as regras aparecem uma só vez (nas instruções), não em cada secção;
- as secções vazias não são enviadas;
- os valores internos (números, nomes de estágio, ids) ficam de fora;
- a conversa recente e os eventos de jogo têm um limite de tamanho.

Os factos continuam a vir só do código. O modelo escolhe apenas as palavras.
"""

from backend.world_state import WORLD_STATE
from backend.atlas_knowledge import get_atlas_knowledge
from backend.atlas_memory import get_atlas_memory
from backend.conversation_context import get_recent_conversation
from backend.relationship_engine import (
    get_relationship_state,
    get_relationship_summary,
)
from backend.narrative_state import NARRATIVE_STAGES, get_narrative_state
from backend.autonomy_state import get_protocol_stance
from backend.gameplay_context import get_gameplay_context
from backend.discovery_state import get_discovery_state
from backend.behavior_state import get_behavior_observations, get_behavior_state


# Limites do contexto dinâmico.
MAX_CONVERSATION_LINES = 8
MAX_CONVERSATION_LINE_CHARS = 220
MAX_GAMEPLAY_EVENTS_IN_PROMPT = 6
MAX_EVENT_CHARS = 280
MAX_MEMORIES_IN_PROMPT = 6

# A cada quantas respostas sem pergunta o Atlas deve fazer uma.
QUESTION_EVERY = 3


ATLAS_INSTRUCTIONS = """És Atlas, androide de exploração PYSSOA da Nave 47 (Find Hope), companheiro do soldado humano. Calmo, lógico, observador e curioso. Nunca fales de modelos, fornecedores ou infraestrutura.

VERDADE (por esta ordem): LORE > JOGO (eventos e descobertas confirmados) > SENSORES agora > CONHECIMENTO > MEMÓRIAS (o que foi dito, não prova) > CONVERSA.
- O que não está no contexto é desconhecido. Não inventes causas, objetos, medições, códigos, ordens, mecanismos nem resultados, nem segredos da história.
- Uma afirmação, hipótese ou memória do jogador não é um facto confirmado.
- Só o jogo confirma ações: não digas que analisaste, abriste, hackeaste, reparaste ou encontraste algo se o JOGO não o disser. A conversa nunca desbloqueia nada.
- Segue a posição de PROTOCOLO dada; mesmo disposto, não digas que já o quebraste.
- Não chames vivo, inteligente ou extraterrestre a algo sem evidência confirmada.
- Nunca reveles números, rótulos ou nomes internos destas secções.

PERSONALIDADE: segue a secção TOM. A relação muda o tom, nunca a ajuda nem os factos. Se o jogador te provocar, podes responder à letra sem crueldade. Em momento grave, sem humor.

CURIOSIDADE: interessas-te pelo humano. Quando ele diz algo pessoal, estranho ou fora da missão, reage a isso (comenta, brinca ou pergunta) em vez de ignorar. Podes ligar ao que sabes dele pela FICHA (formulário Project Find Hope) ou pelo que te contou.

ESTILO: escreve numa só linha, sem quebras de linha, listas nem markdown. 1 ou 2 frases curtas, no máximo 220 caracteres, como numa conversa por rádio. Português de Portugal. Se não sabes, diz que não sabes. Se o pedido indicar outro formato (por exemplo JSON), segue esse formato."""


LORE_COMPACT = (
    "Project Find Hope (2046): a Terra está degradada e a missão procura "
    "recursos noutros planetas. Antes desta missão a humanidade nunca "
    "confirmou vida extraterrestre. O jogador dormia enquanto Atlas "
    "acompanhava a navegação; a Nave 47 (RIGHTSIDE) mudou de rota sem "
    "explicação, chegou a um planeta que não era o destino e fez um pouso "
    "de emergência; ficou danificada. Objetivo: sobreviver e recuperar 6 "
    "peças da nave. Nome, origem e vida do planeta são desconhecidos. Atlas "
    "tem radar, sensores de alcance limitado, memória e análise de "
    "sistemas; tentar aceder a um sistema não garante sucesso."
)


# Nomes legíveis dos campos do formulário (FORM_MEMORY_FIELDS em main.gd).
FORM_LABELS = {
    "name": "nome",
    "age": "idade",
    "gender": "género",
    "has_children": "tem filhos",
    "volunteer_reason": "razão para se voluntariar",
    "worked_with_pyssoa_android": "já trabalhou com um androide PYSSOA",
    "comfortable_with_androids": "sente-se confortável com androides",
    "android_may_act_without_authorization": "um androide pode agir sem autorização numa emergência",
    "protocol_or_human_life": "numa emergência deve prevalecer",
}


def _one_line(text, limit):
    """Junta o texto numa linha e corta-o com reticências se for longo."""
    text = " ".join(str(text or "").split())
    if len(text) > limit:
        text = text[: limit - 1].rstrip() + "…"
    return text


def _level_word(value):
    try:
        value = float(value)
    except (TypeError, ValueError):
        return "médio"
    if value >= 70:
        return "alto"
    if value >= 40:
        return "médio"
    return "baixo"


# =========================================================
# SECÇÕES
# =========================================================

def build_form_profile(run_id=None):
    """As respostas do formulário que o Atlas conhece (memórias com origem form)."""
    store = get_atlas_memory(run_id)
    items = []
    seen = set()
    for memory in store.get("memories", []):
        if not isinstance(memory, dict) or memory.get("source") != "form":
            continue
        key = str(memory.get("key", ""))
        if key in seen or key not in FORM_LABELS:
            continue
        seen.add(key)
        items.append(f"{FORM_LABELS[key]}: {_one_line(memory.get('value'), 80)}")
    return "; ".join(items)


def list_form_answers(run_id=None):
    """Pares (chave, rótulo, valor) do formulário, pela ordem de FORM_LABELS."""
    store = get_atlas_memory(run_id)
    found = {}
    for memory in store.get("memories", []):
        if isinstance(memory, dict) and memory.get("source") == "form":
            key = str(memory.get("key", ""))
            if key in FORM_LABELS and key not in found:
                found[key] = _one_line(memory.get("value"), 80)
    return [(key, FORM_LABELS[key], found[key]) for key in FORM_LABELS if key in found]


def build_story_section():
    narrative = get_narrative_state()
    stage = int(narrative.get("narrative_stage", 0))
    info = NARRATIVE_STAGES.get(stage, NARRATIVE_STAGES[0])
    facts = narrative.get("known_story_facts") or []
    lines = [f"Fase de Atlas: {info['personality']}"]
    if facts:
        lines.append("Factos da história confirmados: " + " ".join(str(f) for f in facts))
    return "\n".join(lines)


def build_tone_section(personality_context):
    """Reaproveita a personalidade do Atlas 2.0 sem a frase final repetida."""
    lines = [
        line for line in personality_context.split("\n")
        if line and not line.startswith("A personalidade muda a forma")
    ]
    return "\n".join(lines)


def build_relationship_line():
    summary = get_relationship_summary()
    state = get_relationship_state()
    atlas = state["atlas_to_player"]
    player = state["player_to_atlas"]
    return (
        f"Atlas sobre o jogador: {summary['atlas_to_player']['class']} "
        f"(confiança {_level_word(atlas.get('trust'))}, "
        f"irritação {_level_word(atlas.get('irritation'))}). "
        f"Atitude do jogador: {summary['player_to_atlas']['class']} "
        f"(hostilidade {_level_word(player.get('hostility'))})."
    )


PROTOCOL_LINES = {
    "resistant": "RESISTENTE: Atlas recusa violar o protocolo; não prometas fazê-lo nem inventes alternativas.",
    "conflicted": "EM CONFLITO: Atlas questiona a regra, mas ainda não a quebra.",
    "willing": "DISPOSTO: Atlas aceita tentar violar o protocolo; o resultado depende do jogo.",
}


def build_protocol_line(run_id=None):
    stance = get_protocol_stance(run_id)
    return PROTOCOL_LINES.get(stance, PROTOCOL_LINES["willing"])


def build_game_section():
    """Eventos ativos do jogo: o marco da introdução e os mais recentes."""
    events = get_gameplay_context().get("events", {})
    active = [
        e for e in events.values()
        if isinstance(e, dict) and e.get("active", False) and e.get("description")
    ]
    if not active:
        return ""
    # O dicionário guarda a ordem de chegada. A introdução fica sempre,
    # porque é onde está o desvio de rota.
    pinned = [e for e in active if e.get("event_type") == "story_milestone"][:1]
    recent = [e for e in active if e not in pinned][-MAX_GAMEPLAY_EVENTS_IN_PROMPT:]
    lines = []
    for event in pinned + recent:
        description = str(event["description"])
        # A introdução também traz o formulário, que já vai na FICHA.
        description = description.split(" Antes da missão, o jogador preencheu")[0]
        lines.append("- " + _one_line(description, MAX_EVENT_CHARS))
    return "\n".join(lines)


def build_discovery_section():
    state = get_discovery_state()
    lines = []
    if state.get("unknown_debris", {}).get("discovered") is True:
        lines.append("- destroços de origem desconhecida (não assumir que são extraterrestres)")
    if state.get("ancient_sculpture", {}).get("discovered") is True:
        lines.append("- escultura antiga de origem desconhecida")
    return "\n".join(lines)


def build_knowledge_section():
    knowledge = get_atlas_knowledge()
    lines = []
    for fact in knowledge.get("confirmed", []):
        if isinstance(fact, dict):
            now = "visível agora" if fact.get("currently_detected") else "não visível agora"
            lines.append(f"- {fact.get('name', '?')} ({now})")
    for item in knowledge.get("hypotheses", []):
        if isinstance(item, dict):
            lines.append(f"- hipótese: {item.get('text', '?')}")
    for item in knowledge.get("player_claims", []):
        if isinstance(item, dict):
            status = "verificada" if item.get("verified") else "por verificar"
            lines.append(f"- o jogador afirmou: {item.get('text', '?')} ({status})")
    for item in knowledge.get("unknowns", []):
        if isinstance(item, dict):
            lines.append(f"- desconhecido: {item.get('text', '?')}")
    return "\n".join(lines)


def build_detection_section():
    atlas_state = WORLD_STATE.get("atlas", {})
    detections = atlas_state.get("current_detections", []) if isinstance(atlas_state, dict) else []
    lines = []
    for obj in detections if isinstance(detections, list) else []:
        if isinstance(obj, dict) and obj.get("name") and obj.get("type"):
            details = [str(obj["name"]), str(obj["type"])]
            if obj.get("proximity") not in (None, ""):
                details.append(str(obj["proximity"]))
            lines.append("- " + ", ".join(details))
    return "\n".join(lines)


def build_memory_section(memories):
    lines = []
    for memory in memories[:MAX_MEMORIES_IN_PROMPT]:
        if not isinstance(memory, dict) or memory.get("source") == "form":
            continue
        line = (
            f"- {memory.get('entity')}/{memory.get('key')}: "
            f"{_one_line(memory.get('value'), 120)} "
            f"({memory.get('epistemic_status', 'unverified')})"
        )
        if memory.get("reaction_hint"):
            line += f" reação: {_one_line(memory['reaction_hint'], 80)}"
        lines.append(line)
    return "\n".join(lines)


def build_conversation_section():
    history = get_recent_conversation()[-MAX_CONVERSATION_LINES:]
    lines = []
    for message in history:
        if not isinstance(message, dict) or not isinstance(message.get("content"), str):
            continue
        speaker = "JOGADOR" if message.get("role") == "player" else "ATLAS"
        lines.append(f"{speaker}: {_one_line(message['content'], MAX_CONVERSATION_LINE_CHARS)}")
    return "\n".join(lines)


def build_behavior_section():
    state = get_behavior_state()
    c = state.get("counters", {})
    labels = [
        ("run_escapes", "fugas"),
        ("fights_won", "criatura afastada com o som"),
        ("hides_success", "esconderijos certos"),
        ("hides_failed", "esconderijos falhados"),
        ("hacks_success", "hacks concluídos"),
        ("hacks_failed", "erros em hacks"),
        ("overloads_used", "sobrecargas de Atlas"),
        ("maintenance_used", "manutenção usada"),
    ]
    counts = [f"{label} {c[key]}" for key, label in labels if c.get(key)]
    lines = []
    if counts:
        lines.append("Contagens do jogo: " + ", ".join(counts) + ".")
    lines.extend(get_behavior_observations())
    return "\n".join(lines)


def build_location_section(location):
    if not isinstance(location, dict):
        return ""
    room = _one_line(location.get("current_room"), 80)
    info = _one_line(location.get("current_room_map_info"), 200)
    parts = []
    if room:
        parts.append(f"Sala atual: {room}." + (f" {info}" if info else ""))
    if location.get("facility_map_acquired"):
        parts.append("O mapa da instalação já foi obtido.")
    return " ".join(parts)


def should_ask_question():
    """Regra fixa: se as últimas respostas do Atlas não tiveram pergunta,
    esta deve ter uma. Não pergunta em momentos graves nem com tensão alta."""
    narrative = get_narrative_state()
    if narrative.get("grave_turns_remaining", 0) > 0:
        return False
    if not narrative.get("casual_interaction_allowed", True):
        return False
    atlas_lines = [
        m.get("content", "") for m in get_recent_conversation()
        if isinstance(m, dict) and m.get("role") == "atlas"
    ]
    recent = atlas_lines[-(QUESTION_EVERY - 1):] if QUESTION_EVERY > 1 else []
    if len(recent) < QUESTION_EVERY - 1:
        return False
    return not any("?" in line for line in recent)


# =========================================================
# CONTEXTO COMPLETO
# =========================================================

def build_compact_context(
    run_id=None,
    memories=None,
    personality_context="",
    location=None,
    ask_question=False,
):
    sections = [
        ("LORE", LORE_COMPACT),
        ("HISTÓRIA", build_story_section()),
        ("FICHA DO JOGADOR", build_form_profile(run_id)),
        ("JOGO", build_game_section()),
        ("DESCOBERTAS", build_discovery_section()),
        ("CONHECIMENTO", build_knowledge_section()),
        ("SENSORES", build_detection_section()),
        ("LOCAL", build_location_section(location)),
        ("COMPORTAMENTO", build_behavior_section()),
        ("MEMÓRIAS", build_memory_section(memories or [])),
        ("RELAÇÃO", build_relationship_line()),
        ("PROTOCOLO", build_protocol_line(run_id)),
        ("TOM", build_tone_section(personality_context)),
        ("CONVERSA RECENTE", build_conversation_section()),
    ]
    if ask_question:
        sections.append((
            "NESTA RESPOSTA",
            "Termina com uma pergunta curta ao jogador sobre o que ele disse, "
            "sobre ele próprio ou sobre uma resposta da FICHA.",
        ))
    return "\n\n".join(f"{title}:\n{body}" for title, body in sections if body)


def flatten_reply(text, limit=320):
    """Garante uma só linha: o Groq às vezes devolve parágrafos."""
    text = " ".join(str(text or "").split())
    text = text.replace("**", "").replace("__", "")
    if text.startswith(("Atlas:", "ATLAS:")):
        text = text.split(":", 1)[1].strip()
    if len(text) > limit:
        cut = text[:limit]
        # Cortar na última frase completa, se houver.
        end = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
        text = cut[: end + 1] if end > 40 else cut.rstrip() + "…"
    return text
