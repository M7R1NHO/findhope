def evaluate_memory(memory, world_state=None, knowledge=None):
    """
    Avalia como Atlas deve interpretar epistemicamente uma memória.

    Retorna:
    {
        "epistemic_status": "...",
        "plausibility": 0.0-1.0,
        "narrative_weight": 0.0-1.0,
        "reaction_hint": "..."
    }
    """

    memory_type = memory.get("memory_type")
    entity = memory.get("entity")
    category = memory.get("category")
    key = str(memory.get("key", "")).lower()
    value = str(memory.get("value", "")).lower()

    result = {
        "epistemic_status": "unverified",
        "plausibility": 0.7,
        "narrative_weight": float(
            memory.get("importance", 0.5)
        ),
        "reaction_hint": "normal"
    }

    # --------------------------------------------------
    # 1. MEMÓRIAS PESSOAIS SIMPLES
    # --------------------------------------------------

    # Nome, preferência, gostos etc.
    # Atlas não precisa "provar" estes dados.
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
    # 4. PALAVRAS ASSOCIADAS A EVENTOS GRAVES
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

    if any(term in memory_text for term in serious_terms):
        result["narrative_weight"] = max(
            result["narrative_weight"],
            0.9
        )

    # --------------------------------------------------
    # 5. CONTRADIÇÕES ÓBVIAS COM O WORLD STATE
    # --------------------------------------------------

    if world_state:
        detections = (
            world_state
            .get("atlas", {})
            .get("current_detections", [])
        )

        detection_text = " ".join(
            str(item).lower()
            for item in detections
        )

        # Exemplo:
        # o jogador afirma que acabou de interagir com
        # uma pessoa que Atlas não tem qualquer indicação
        # de estar presente.
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
    # 6. ESCOLHER O TIPO DE REAÇÃO
    # --------------------------------------------------

    weight = result["narrative_weight"]
    plausibility = result["plausibility"]

    if weight >= 0.8 and plausibility <= 0.3:
        result["reaction_hint"] = "skeptical_serious"

    elif weight >= 0.8:
        result["reaction_hint"] = "serious"

    elif plausibility <= 0.3:
        result["reaction_hint"] = "skeptical"

    else:
        result["reaction_hint"] = "normal"

    return result