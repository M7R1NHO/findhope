import re


# =========================================================
# UTILIDADES
# =========================================================

def clamp(value, minimum=0.0, maximum=1.0):
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = 0.5

    return max(
        minimum,
        min(value, maximum)
    )


def normalize_text(text):
    if not text:
        return ""

    return str(text).lower().strip()


def contains_any(text, terms):
    return any(
        term in text
        for term in terms
    )


# =========================================================
# CLASSIFICAÇÃO DE EVENTOS RELACIONAIS
# =========================================================

def evaluate_relationship_event(memory):
    """
    Avalia acontecimentos que ocorreram diretamente
    na interação jogador <-> Atlas.

    IMPORTANTE:
    importance = vale a pena lembrar?
    narrative_weight = quão emocional/narrativamente
                       pesado é o acontecimento?

    São conceitos diferentes.
    """

    text = normalize_text(
        f"{memory.get('key', '')} "
        f"{memory.get('value', '')}"
    )

    # -----------------------------------------------------
    # HOSTILIDADE FORTE
    # -----------------------------------------------------

    strong_hostility = {
        "odeio",
        "ódio",
        "odio",
        "vai te foder",
        "vai-te foder",
        "vai se foder",
        "vai-te lixar",
        "filho da puta",
        "ameaçou",
        "ameacou",
        "ameaça",
        "ameaca",
        "matar-te",
        "matar você",
        "matar voce",
        "destruir-te",
        "destruir você",
        "destruir voce",
        "hostilidade",
        "hostility"
    }

    if contains_any(
        text,
        strong_hostility
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.85,
            "reaction_hint": "serious"
        }

    # -----------------------------------------------------
    # HOSTILIDADE LEVE / INSULTO
    # -----------------------------------------------------

    mild_hostility = {
        "idiota",
        "burro",
        "estúpido",
        "estupido",
        "inútil",
        "inutil",
        "insulto",
        "xingou",
        "xingamento"
    }

    if contains_any(
        text,
        mild_hostility
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.55,
            "reaction_hint": "acknowledge"
        }

    # -----------------------------------------------------
    # PEDIDO DE DESCULPAS / RECONCILIAÇÃO
    # -----------------------------------------------------

    apology_terms = {
        "desculpa",
        "desculpas",
        "perdão",
        "perdao",
        "perdoa",
        "pedido_de_desculpa",
        "pedido_de_perdao",
        "apology",
        "reconciliação",
        "reconciliacao"
    }

    if contains_any(
        text,
        apology_terms
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.40,
            "reaction_hint": "acknowledge"
        }

    # -----------------------------------------------------
    # AFETO / APOIO
    # -----------------------------------------------------

    affection_terms = {
        "gosto de ti",
        "gosto de você",
        "gosto de voce",
        "adoro-te",
        "adoro você",
        "adoro voce",
        "amo-te",
        "amo você",
        "amo voce",
        "confio em ti",
        "confio em você",
        "confio em voce",
        "apoio",
        "carinho",
        "afeto",
        "affection",
        "trust"
    }

    if contains_any(
        text,
        affection_terms
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.50,
            "reaction_hint": "acknowledge"
        }

    # -----------------------------------------------------
    # PROMESSAS
    # -----------------------------------------------------

    promise_terms = {
        "prometo",
        "promessa",
        "promise"
    }

    if contains_any(
        text,
        promise_terms
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.55,
            "reaction_hint": "acknowledge"
        }

    # -----------------------------------------------------
    # EVENTO RELACIONAL GENÉRICO
    # -----------------------------------------------------

    return {
        "epistemic_status": "accepted",
        "plausibility": 1.0,
        "narrative_weight": 0.35,
        "reaction_hint": "acknowledge"
    }


# =========================================================
# EVENTOS EXTERNOS ALEGADOS PELO JOGADOR
# =========================================================

def evaluate_external_event(
    memory,
    world_state=None
):
    """
    O jogador pode afirmar que algo aconteceu fora
    da conversa.

    Atlas sabe que a declaração foi feita,
    mas isso não significa que o conteúdo seja
    objetivamente verdadeiro.
    """

    text = normalize_text(
        f"{memory.get('key', '')} "
        f"{memory.get('value', '')}"
    )

    narrative_weight = 0.45
    plausibility = 0.5
    epistemic_status = "unverified"
    reaction_hint = "normal"

    # -----------------------------------------------------
    # EVENTOS GRAVES
    # -----------------------------------------------------

    serious_terms = {
        "matei",
        "matou",
        "morreu",
        "morte",
        "assassinei",
        "assassinou",
        "feri",
        "feriu",
        "sangue",
        "explosão",
        "explosao",
        "ataque",
        "desapareceu",
        "sequestro"
    }

    if contains_any(
        text,
        serious_terms
    ):
        narrative_weight = 0.90
        reaction_hint = "skeptical_serious"

    # -----------------------------------------------------
    # HEURÍSTICA PROVISÓRIA DO MUNDO
    # -----------------------------------------------------

    human_terms = {
        "pai",
        "mãe",
        "mae",
        "irmão",
        "irmao",
        "irmã",
        "irma",
        "homem",
        "mulher",
        "pessoa",
        "humano"
    }

    if (
        world_state
        and contains_any(
            text,
            human_terms
        )
    ):
        detections = (
            world_state
            .get("atlas", {})
            .get("current_detections", [])
        )

        detection_text = " ".join(
            normalize_text(
                f"{item.get('name', '')} "
                f"{item.get('type', '')}"
            )
            for item in detections
            if isinstance(item, dict)
        )

        human_detected = contains_any(
            detection_text,
            human_terms
        )

        if not human_detected:
            epistemic_status = "doubtful"
            plausibility = 0.2
            reaction_hint = (
                "skeptical_serious"
                if narrative_weight >= 0.8
                else "skeptical"
            )

    return {
        "epistemic_status": epistemic_status,
        "plausibility": plausibility,
        "narrative_weight": narrative_weight,
        "reaction_hint": reaction_hint
    }


# =========================================================
# AVALIAÇÃO PRINCIPAL
# =========================================================

def evaluate_memory(
    memory,
    world_state=None,
    knowledge=None
):
    """
    Avalia uma memória depois de o Memory Interpreter
    extrair o seu significado.

    O Interpreter responde:
        "O que foi dito / aconteceu?"

    Este módulo responde:
        "Como Atlas deve tratar epistemologicamente
         e narrativamente essa memória?"
    """

    if not isinstance(memory, dict):
        return {
            "epistemic_status": "unverified",
            "plausibility": 0.5,
            "narrative_weight": 0.3,
            "reaction_hint": "normal"
        }

    memory_type = normalize_text(
        memory.get("memory_type")
    )

    entity = normalize_text(
        memory.get("entity")
    )

    category = normalize_text(
        memory.get("category")
    )

    # A importância vem do Interpreter,
    # mas NÃO será usada automaticamente
    # como peso narrativo.
    importance = clamp(
        memory.get(
            "importance",
            0.5
        )
    )

    # -----------------------------------------------------
    # DEFINIÇÕES PARTILHADAS
    # -----------------------------------------------------

    if (
        entity == "shared"
        and category == "definition"
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.15,
            "reaction_hint": "acknowledge"
        }

    # -----------------------------------------------------
    # IDENTIDADE / PREFERÊNCIAS / OBJETIVOS / EMOÇÕES
    # -----------------------------------------------------

    if (
        entity == "player"
        and category in {
            "identity",
            "preference",
            "emotion",
            "goal"
        }
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.25,
            "reaction_hint": "normal"
        }

    # -----------------------------------------------------
    # EVENTOS RELACIONAIS DIRETAMENTE OBSERVADOS
    # -----------------------------------------------------

    if (
        entity == "player"
        and memory_type == "episodic"
        and category == "relationship"
    ):
        return evaluate_relationship_event(
            memory
        )

    # -----------------------------------------------------
    # EVENTOS / EXPERIÊNCIAS EXTERNAS
    # -----------------------------------------------------

    if (
        entity == "player"
        and memory_type == "episodic"
        and category in {
            "event",
            "experience"
        }
    ):
        return evaluate_external_event(
            memory,
            world_state=world_state
        )

    # -----------------------------------------------------
    # CRENÇAS DO JOGADOR
    # -----------------------------------------------------

    if (
        entity == "player"
        and category == "belief"
    ):
        return {
            "epistemic_status": "accepted",
            "plausibility": 1.0,
            "narrative_weight": 0.25,
            "reaction_hint": "normal"
        }

    # -----------------------------------------------------
    # CONHECIMENTO DECLARADO
    # -----------------------------------------------------

    if category == "knowledge":
        return {
            "epistemic_status": "unverified",
            "plausibility": 0.5,
            "narrative_weight": 0.25,
            "reaction_hint": "normal"
        }

    # -----------------------------------------------------
    # FALLBACK
    # -----------------------------------------------------

    # importance pode dar um PEQUENO aumento,
    # mas nunca define sozinho a intensidade.
    fallback_weight = (
        0.20
        + (importance * 0.20)
    )

    return {
        "epistemic_status": "unverified",
        "plausibility": 0.5,
        "narrative_weight": round(
            fallback_weight,
            2
        ),
        "reaction_hint": "normal"
    }