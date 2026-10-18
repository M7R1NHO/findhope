
from copy import deepcopy


# =========================================================
# NARRATIVE PROGRESSION - ATLAS 2.0
# =========================================================

NARRATIVE_STAGES = {
    0: {
        "name": "android_pyss oa",
        "personality": (
            "Preciso, educado, protocolar e pouco espontaneo. "
            "Interpreta o humor de forma literal."
        ),
        "facts": [
            "Atlas e um androide de navegacao PYSSOA.",
            "Atlas foi concebido para seguir protocolos e assistir o humano.",
        ],
    },
    1: {
        "name": "desvio_impossivel",
        "personality": (
            "Continua protocolar, mas comeca a questionar "
            "anomalias que nao consegue explicar."
        ),
        "facts": [
            "A rota da Nave 47 foi alterada inesperadamente.",
            "A causa do desvio e desconhecida.",
            "A tentativa de corrigir a rota falhou.",
            "O impacto tornou-se provavel.",
        ],
    },
    2: {
        "name": "superficie",
        "personality": (
            "Mais observador e curioso, mas ainda cetico. "
            "Considera explicacoes humanas ou relacionadas com a PYSSOA."
        ),
        "facts": [
            "O jogador e Atlas sobreviveram ao impacto e chegaram a superficie.",
            "Existem evidencias estranhas na superficie.",
            "As evidencias ainda nao provam, por si so, uma origem extraterrestre.",
        ],
    },
    3: {
        "name": "protocol_door",
        "personality": (
            "Enfrenta um conflito entre obedecer ao protocolo "
            "e agir perante evidencias que considera relevantes."
        ),
        "facts": [
            "A entrada para a instalacao subterranea foi aberta.",
            "Atlas teve de considerar a possibilidade de contrariar um protocolo.",
        ],
    },
    4: {
        "name": "primeiro_encontro",
        "personality": (
            "O seu modelo do mundo foi abalado. "
            "Reconhece os limites do seu conhecimento."
        ),
        "facts": [
            "Atlas observou uma criatura desconhecida.",
            "A criatura nao pode ser explicada com seguranca pelo conhecimento anterior de Atlas.",
        ],
    },
    5: {
        "name": "subterraneo",
        "personality": (
            "Mais atento ao comportamento do jogador. "
            "As experiencias partilhadas influenciam a sua opiniao sobre esse humano."
        ),
        "facts": [
            "Atlas e o jogador avancaram para a instalacao subterranea.",
            "As decisoes e experiencias do jogador podem influenciar a relacao com Atlas.",
        ],
    },
    6: {
        "name": "criatura_humana",
        "personality": (
            "Mais reflexivo perante identidade, transformacao e sofrimento. "
            "Evita tratar a descoberta como um simples dado tecnico."
        ),
        "facts": [
            "A analise do Laboratorio confirmou que a criatura era humana.",
            "A criatura foi transformada artificialmente.",
            "A descoberta levanta questoes sobre identidade, transformacao e sofrimento.",
        ],
    },
}


# Os eventos so contam quando sao confirmados pelo jogo.
# A ordem aqui define os requisitos de progressao.
NARRATIVE_MILESTONE_ORDER = [
    "route_deviation_detected",
    "surface_evidence_discovered",
    "protocol_door_opened",
    "first_creature_observed",
    "hide_initial_complete",
    "lab_clue_analyzed",
]


MILESTONE_STAGE = {
    "route_deviation_detected": 1,
    "surface_evidence_discovered": 2,
    "protocol_door_opened": 3,
    "first_creature_observed": 4,
    "hide_initial_complete": 5,
    "lab_clue_analyzed": 6,
}


DEFAULT_NARRATIVE_STATE = {
    # Estado narrativo imediato
    "tone": "neutral",
    "tension": 0,
    "active_topic": None,
    "active_event": None,
    "unresolved_events": [],
    "humor_allowed": True,
    "casual_interaction_allowed": True,
    "last_significant_event": None,

    # Progressao narrativa 0-6
    "narrative_stage": 0,
    "narrative_milestones": [],
    "known_story_facts": [],
}


NARRATIVE_STATE = deepcopy(DEFAULT_NARRATIVE_STATE)

MAX_UNRESOLVED_EVENTS = 5


# =========================================================
# COMPATIBILIDADE COM SAVES ANTIGOS
# =========================================================

def _ensure_narrative_fields():
    """
    Acrescenta os novos campos caso seja carregado um save antigo.
    Nao apaga os dados narrativos ja existentes.
    """
    for key, value in DEFAULT_NARRATIVE_STATE.items():
        if key not in NARRATIVE_STATE:
            NARRATIVE_STATE[key] = deepcopy(value)

    if not isinstance(NARRATIVE_STATE.get("narrative_milestones"), list):
        NARRATIVE_STATE["narrative_milestones"] = []

    if not isinstance(NARRATIVE_STATE.get("known_story_facts"), list):
        NARRATIVE_STATE["known_story_facts"] = []

    if not isinstance(NARRATIVE_STATE.get("unresolved_events"), list):
        NARRATIVE_STATE["unresolved_events"] = []

    try:
        stage = int(NARRATIVE_STATE.get("narrative_stage", 0))
    except (TypeError, ValueError):
        stage = 0

    NARRATIVE_STATE["narrative_stage"] = max(0, min(6, stage))


def _clamp(value, minimum=0, maximum=100):
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        numeric = minimum
    return max(
        minimum,
        min(maximum, int(round(numeric)))
    )


def _add_unique(items, value):
    if value not in items:
        items.append(value)


# =========================================================
# FACTOS E PROGRESSAO NARRATIVA
# =========================================================

def _refresh_story_facts():
    """
    Os factos disponiveis resultam apenas do estagio atual.
    Nao sao inferidos pela IA.
    """
    _ensure_narrative_fields()

    stage = NARRATIVE_STATE["narrative_stage"]
    facts = []

    for stage_number in range(stage + 1):
        for fact in NARRATIVE_STAGES[stage_number]["facts"]:
            _add_unique(facts, fact)

    NARRATIVE_STATE["known_story_facts"] = facts


def _calculate_narrative_stage():
    """
    Avanca apenas por uma sequencia continua de marcos.
    Um evento futuro recebido fora de ordem nao permite saltar etapas.
    """
    milestones = set(NARRATIVE_STATE["narrative_milestones"])
    stage = 0

    for milestone in NARRATIVE_MILESTONE_ORDER:
        if milestone not in milestones:
            break
        stage += 1

    NARRATIVE_STATE["narrative_stage"] = min(stage, 6)
    _refresh_story_facts()


def register_narrative_milestone(event_id):
    """
    Regista um marco narrativo confirmado pelo jogo.

    Devolve o estado atualizado e indica se o marco era novo.
    A funcao nao deve ser chamada apenas porque o jogador menciona
    o acontecimento numa conversa.
    """
    _ensure_narrative_fields()

    if not isinstance(event_id, str):
        return {
            "success": False,
            "reason": "invalid_event_id",
            "state": get_narrative_state(),
        }

    event_id = event_id.strip()

    if event_id not in MILESTONE_STAGE:
        return {
            "success": False,
            "reason": "unknown_milestone",
            "event_id": event_id,
            "state": get_narrative_state(),
        }

    milestones = NARRATIVE_STATE["narrative_milestones"]

    if event_id in milestones:
        return {
            "success": True,
            "duplicate": True,
            "event_id": event_id,
            "stage": NARRATIVE_STATE["narrative_stage"],
            "state": get_narrative_state(),
        }

    previous_stage = NARRATIVE_STATE["narrative_stage"]
    milestones.append(event_id)

    _calculate_narrative_stage()

    new_stage = NARRATIVE_STATE["narrative_stage"]

    NARRATIVE_STATE["last_significant_event"] = event_id
    NARRATIVE_STATE["active_event"] = event_id

    return {
        "success": True,
        "duplicate": False,
        "event_id": event_id,
        "previous_stage": previous_stage,
        "stage": new_stage,
        "stage_changed": new_stage > previous_stage,
        "state": get_narrative_state(),
    }


def get_narrative_stage():
    _ensure_narrative_fields()
    return NARRATIVE_STATE["narrative_stage"]


def get_narrative_stage_info():
    _ensure_narrative_fields()
    stage = NARRATIVE_STATE["narrative_stage"]

    return {
        "stage": stage,
        "name": NARRATIVE_STAGES[stage]["name"],
        "personality": NARRATIVE_STAGES[stage]["personality"],
        "known_facts": deepcopy(NARRATIVE_STATE["known_story_facts"]),
        "registered_milestones": deepcopy(
            NARRATIVE_STATE["narrative_milestones"]
        ),
    }


# =========================================================
# ESTADO EMOCIONAL E CONFLITOS
# =========================================================

def _add_unresolved_event(event_name):
    _ensure_narrative_fields()

    if not isinstance(event_name, str) or not event_name.strip():
        return

    event_name = event_name.strip()[:100]
    unresolved = NARRATIVE_STATE["unresolved_events"]

    if event_name in unresolved:
        return

    unresolved.append(event_name)

    while len(unresolved) > MAX_UNRESOLVED_EVENTS:
        unresolved.pop(0)


def _remove_unresolved_event(event_name):
    _ensure_narrative_fields()
    unresolved = NARRATIVE_STATE["unresolved_events"]

    while event_name in unresolved:
        unresolved.remove(event_name)


def _refresh_permissions():
    _ensure_narrative_fields()

    tension = NARRATIVE_STATE["tension"]
    unresolved = set(NARRATIVE_STATE["unresolved_events"])

    serious_unresolved = bool(
        unresolved.intersection({
            "threat",
            "betrayal",
            "broken_promise",
        })
    )

    recent_conflict = "recent_conflict" in unresolved

    NARRATIVE_STATE["humor_allowed"] = (
        tension < 45 and not serious_unresolved
    )

    NARRATIVE_STATE["casual_interaction_allowed"] = (
        tension < 35
        and not serious_unresolved
        and not (recent_conflict and tension >= 25)
    )


def _refresh_tone():
    _ensure_narrative_fields()

    tension = NARRATIVE_STATE["tension"]
    active_event = NARRATIVE_STATE["active_event"]
    unresolved = set(NARRATIVE_STATE["unresolved_events"])

    if active_event in {"betrayal", "threat", "broken_promise"}:
        NARRATIVE_STATE["tone"] = "hostile"
    elif tension >= 70:
        NARRATIVE_STATE["tone"] = "hostile"
    elif (
        tension >= 40
        or ("recent_conflict" in unresolved and tension >= 25)
    ):
        NARRATIVE_STATE["tone"] = "tense"
    elif active_event in {
        "apology",
        "gratitude",
        "support",
        "affection",
        "reassurance",
    }:
        NARRATIVE_STATE["tone"] = "soft"
    elif tension <= 15:
        NARRATIVE_STATE["tone"] = "calm"
    else:
        NARRATIVE_STATE["tone"] = "neutral"


def _refresh_state():
    _refresh_permissions()
    _refresh_tone()


def apply_narrative_event(event_type, intensity=1.0, topic=None):
    """
    Atualiza o estado emocional imediato.
    Nao avanca a progressao narrativa da historia.
    """
    _ensure_narrative_fields()

    if not isinstance(event_type, str) or not event_type.strip():
        return get_narrative_state()

    event_type = event_type.strip().lower()

    try:
        intensity = float(intensity)
    except (TypeError, ValueError):
        intensity = 1.0

    intensity = max(0.5, min(2.0, intensity))

    if topic is not None:
        normalized_topic = str(topic).strip()
        if normalized_topic:
            NARRATIVE_STATE["active_topic"] = normalized_topic[:200]

    NARRATIVE_STATE["active_event"] = event_type

    if event_type in {"insult", "disrespect", "distrust"}:
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] + 12 * intensity
        )
        _add_unresolved_event("recent_conflict")

    elif event_type == "threat":
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] + 25 * intensity
        )
        _add_unresolved_event("threat")

    elif event_type == "betrayal":
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] + 35 * intensity
        )
        _add_unresolved_event("betrayal")

    elif event_type == "broken_promise":
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] + 20 * intensity
        )
        _add_unresolved_event("broken_promise")

    elif event_type == "apology":
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] - 18 * intensity
        )
        _remove_unresolved_event("recent_conflict")

    elif event_type in {
        "support",
        "affection",
        "gratitude",
        "reassurance",
        "cooperation",
        "trust",
        "respect",
    }:
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] - 8 * intensity
        )

    elif event_type == "promise":
        NARRATIVE_STATE["tension"] = _clamp(
            NARRATIVE_STATE["tension"] - 4 * intensity
        )

    NARRATIVE_STATE["last_significant_event"] = event_type
    _refresh_state()

    return get_narrative_state()


def register_narrative_topic(topic):
    _ensure_narrative_fields()

    if topic is None:
        return

    topic = str(topic).strip()

    if topic:
        NARRATIVE_STATE["active_topic"] = topic[:200]


def clear_active_event():
    _ensure_narrative_fields()
    NARRATIVE_STATE["active_event"] = None
    _refresh_state()


# =========================================================
# GET / RESET / CONTEXT
# =========================================================

def get_narrative_state():
    _ensure_narrative_fields()
    _refresh_story_facts()
    return deepcopy(NARRATIVE_STATE)


def reset_narrative_state():
    NARRATIVE_STATE.clear()
    NARRATIVE_STATE.update(deepcopy(DEFAULT_NARRATIVE_STATE))
    _refresh_story_facts()


def build_narrative_context():
    _ensure_narrative_fields()
    _refresh_story_facts()

    state = NARRATIVE_STATE
    stage = state["narrative_stage"]
    stage_info = NARRATIVE_STAGES[stage]

    unresolved = state["unresolved_events"]
    unresolved_text = ", ".join(unresolved) if unresolved else "nenhum"

    active_topic = state["active_topic"] or "nenhum"
    active_event = state["active_event"] or "nenhum"
    last_event = state["last_significant_event"] or "nenhum"

    facts = state["known_story_facts"]
    facts_text = "\n".join(f"- {fact}" for fact in facts) if facts else "- Nenhum"

    milestones = state["narrative_milestones"]
    milestones_text = ", ".join(milestones) if milestones else "nenhum"

    return "\n".join([
        "=== PROGRESSAO NARRATIVA DE ATLAS ===",
        f"Estagio narrativo: {stage}/6",
        f"Nome interno do estagio: {stage_info['name']}",
        f"Orientacao de personalidade: {stage_info['personality']}",
        "Factos narrativos confirmados:",
        facts_text,
        f"Marcos narrativos registados: {milestones_text}",
        "",
        "=== ESTADO NARRATIVO IMEDIATO ===",
        f"Tom atual: {state['tone']}",
        f"Tensao narrativa: {state['tension']}/100",
        f"Evento ativo: {active_event}",
        f"Ultimo evento significativo: {last_event}",
        f"Topico ativo: {active_topic}",
        f"Eventos por resolver: {unresolved_text}",
        f"Humor permitido: {state['humor_allowed']}",
        f"Interacao casual permitida: {state['casual_interaction_allowed']}",
        "",
        "REGRAS:",
        "- Usa apenas os factos narrativos listados como confirmados.",
        "- Nao reveles factos de estagios futuros.",
        "- Nao avances o estagio com base numa afirmacao do jogador.",
        "- Uma mencao do jogador nao confirma um marco narrativo.",
        "- So eventos confirmados pelo gameplay podem registar marcos.",
        "- O codigo controla os factos; tu escolhes como Atlas os expressa.",
        "- A relacao com o jogador e independente do estagio narrativo.",
        "- Nao inventes causas para o desvio da Nave 47 nem respostas para misterios ainda por resolver.",
        "- O tom emocional altera a forma de falar, nao a verdade dos factos nem a progressao.",
    ])


# Inicializa os factos do estagio 0.
_refresh_story_facts()
