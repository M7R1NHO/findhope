def clamp(value, minimum=0.0, maximum=1.0):
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = minimum

    return max(minimum, min(value, maximum))


def evaluate_memory(memory, world_state=None, knowledge=None):
    """
    Avalia como Atlas deve interpretar epistemicamente
    uma memória.

    Importante:
    confidence = confiança de que a informação foi
    corretamente extraída da mensagem.

    plausibility = quão plausível Atlas considera
    o conteúdo da informação.

    Uma memória pode ter confidence = 1.0 e ainda
    assim ter plausibility baixa.

    Retorna:
    {
        "epistemic_status": "...",
        "plausibility": 0.0-1.0,
        "narrative_weight": 0.0-1.0,
        "reaction_hint": "..."
    }
    """

    if not isinstance(memory, dict):
        return {
            "epistemic_status": "unverified",
            "plausibility": 0.5,
            "narrative_weight": 0.5,
            "reaction_hint": "normal"
        }

    memory_type = str(
        memory.get("memory_type", "")
    ).strip().lower()

    entity = str(
        memory.get("entity", "")
    ).strip().lower()

    category = str(
        memory.get("category", "")
    ).strip().lower()

    key = str(
        memory.get("key", "")
    ).strip().lower()

    value = str(
        memory.get("value", "")
    ).strip().lower()

    importance = clamp(
        memory.get("importance", 0.5)
    )

    result = {
        "epistemic_status": "unverified",
        "plausibility": 0.7,
        "narrative_weight": importance,
        "reaction_hint": "normal"
    }

    # --------------------------------------------------
    # 1. DADOS PESSOAIS DO JOGADOR
    # --------------------------------------------------
    #
    # Nome, preferências, emoções e objetivos são
    # normalmente informações autorreferidas.
    #
    # Atlas pode aceitá-las sem exigir prova externa.
    # --------------------------------------------------

    if (
        entity == "player"
        and category in {
            "identity",
            "preference",
            "emotion",
            "goal"
        }
    ):
        result["epistemic_status"] = "accepted"
        result["plausibility"] = 1.0
        result["reaction_hint"] = "normal"

        return result

    # --------------------------------------------------
    # 2. DEFINIÇÕES PARTILHADAS
    # --------------------------------------------------
    #
    # Exemplo:
    #
    # "rt significa quero pizza"
    #
    # Isto não é uma afirmação sobre o mundo.
    # É uma convenção criada entre jogador e Atlas.
    # --------------------------------------------------

    if (
        entity == "shared"
        and category == "definition"
    ):
        result["epistemic_status"] = "accepted"
        result["plausibility"] = 1.0
        result["reaction_hint"] = "acknowledge"

        return result

    # --------------------------------------------------
    # 3. EVENTOS DECLARADOS PELO JOGADOR
    # --------------------------------------------------
    #
    # Atlas pode lembrar-se perfeitamente de que o
    # jogador disse algo sem assumir que aconteceu.
    # --------------------------------------------------

    if (
        entity == "player"
        and memory_type == "episodic"
        and category in {
            "event",
            "experience"
        }
    ):
        result["epistemic_status"] = "unverified"
        result["plausibility"] = 0.5

    # --------------------------------------------------
    # 4. PESO NARRATIVO
    # --------------------------------------------------
    #
    # V1:
    # Alguns acontecimentos devem receber atenção
    # especial mesmo quando não estão confirmados.
    #
    # Esta lista é provisória.
    # Futuramente poderemos substituir isto por um
    # sistema mais contextual.
    # --------------------------------------------------

    serious_terms = {
        "kill",
        "killed",
        "matar",
        "matei",
        "morto",
        "morreu",
        "morte",
        "explodiu",
        "explosion",
        "explosão",
        "destruiu",
        "destroyed",
        "traí",
        "betrayed",
        "abandon",
        "abandonei"
    }

    memory_text = f"{key} {value}"

    if any(
        term in memory_text
        for term in serious_terms
    ):
        result["narrative_weight"] = max(
            result["narrative_weight"],
            0.9
        )

    # --------------------------------------------------
    # 5. CONTEXTO DO WORLD STATE
    # --------------------------------------------------
    #
    # IMPORTANTE:
    #
    # Ausência de deteção NÃO prova que um evento
    # não aconteceu.
    #
    # Ela pode apenas reduzir a plausibilidade de
    # determinadas afirmações muito recentes ou
    # incompatíveis com o contexto conhecido.
    # --------------------------------------------------

    if isinstance(world_state, dict):

        detections = (
            world_state
            .get("atlas", {})
            .get("current_detections", [])
        )

        if not isinstance(detections, list):
            detections = []

        detection_text = " ".join(
            str(item).lower()
            for item in detections
        )

        human_terms = {
            "father",
            "pai",
            "mother",
            "mãe",
            "brother",
            "irmão",
            "sister",
            "irmã",
            "person",
            "pessoa",
            "human",
            "humano"
        }

        mentions_person = any(
            term in memory_text
            for term in human_terms
        )

        detected_person = any(
            term in detection_text
            for term in human_terms
        )

        if (
            mentions_person
            and not detected_person
            and memory_type == "episodic"
        ):
            result["plausibility"] = min(
                result["plausibility"],
                0.2
            )

            result["epistemic_status"] = "doubtful"

    # --------------------------------------------------
    # 6. CONHECIMENTO
    # --------------------------------------------------
    #
    # O parâmetro knowledge já faz parte da interface
    # para permitir evolução futura.
    #
    # Nesta V1 ainda não fazemos inferências fortes
    # automaticamente a partir dele.
    # --------------------------------------------------

    _ = knowledge

    # --------------------------------------------------
    # 7. REAÇÃO RECOMENDADA
    # --------------------------------------------------

    weight = result["narrative_weight"]
    plausibility = result["plausibility"]

    if (
        weight >= 0.8
        and plausibility <= 0.3
    ):
        result["reaction_hint"] = (
            "skeptical_serious"
        )

    elif weight >= 0.8:
        result["reaction_hint"] = "serious"

    elif plausibility <= 0.3:
        result["reaction_hint"] = "skeptical"

    else:
        result["reaction_hint"] = "normal"

    return result