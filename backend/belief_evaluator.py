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

    confidence:
        confiança de que a informação foi corretamente
        extraída da mensagem.

    plausibility:
        quão plausível Atlas considera o conteúdo quando
        ele representa uma afirmação sobre algo externo.

    IMPORTANTE:

    Um evento conversacional diretamente recebido por Atlas
    pode ser aceite como acontecimento da conversa sem que
    o conteúdo literal da mensagem seja considerado verdadeiro.

    Exemplo:

        "Vou comer a tua placa-mãe."

    Atlas pode aceitar:
        "O jogador ameaçou Atlas."

    Isso NÃO significa aceitar:
        "O jogador realmente vai comer a placa-mãe."

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
    # 3. EVENTOS CONVERSACIONAIS DIRETAMENTE OBSERVADOS
    # --------------------------------------------------
    #
    # category="relationship" representa uma interação
    # que aconteceu na própria conversa entre jogador
    # e Atlas.
    #
    # Exemplos:
    # - insultou Atlas
    # - pediu desculpa a Atlas
    # - elogiou Atlas
    # - ameaçou Atlas
    # - demonstrou apoio
    #
    # Atlas recebeu diretamente essa interação.
    #
    # Portanto, pode aceitar que A INTERAÇÃO aconteceu.
    #
    # Isto NÃO significa que o conteúdo literal da fala
    # seja objetivamente verdadeiro.
    #
    # "Vou destruir-te."
    #
    # Aceite:
    #   o jogador ameaçou Atlas.
    #
    # Não necessariamente aceite:
    #   o jogador realmente conseguirá destruir Atlas.
    # --------------------------------------------------

    if (
        entity == "player"
        and memory_type == "episodic"
        and category == "relationship"
    ):
        result["epistemic_status"] = "accepted"
        result["plausibility"] = 1.0

        if importance >= 0.8:
            result["reaction_hint"] = "serious"
        else:
            result["reaction_hint"] = "acknowledge"

        return result

    # --------------------------------------------------
    # 4. EVENTOS EXTERNOS DECLARADOS PELO JOGADOR
    # --------------------------------------------------
    #
    # Aqui Atlas lembra que o jogador DISSE que algo
    # aconteceu.
    #
    # Mas Atlas não observou necessariamente o evento.
    #
    # Exemplo:
    # "Eu matei o meu pai."
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
    # 5. PESO NARRATIVO
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
    # 6. CONTEXTO DO WORLD STATE
    # --------------------------------------------------
    #
    # Só aplicamos esta heurística a alegações externas.
    #
    # Eventos relationship NÃO chegam aqui porque já
    # foram tratados como acontecimentos diretamente
    # observados na conversa.
    #
    # IMPORTANTE:
    # ausência de deteção não prova ausência.
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
            and category in {
                "event",
                "experience"
            }
        ):
            result["plausibility"] = min(
                result["plausibility"],
                0.2
            )

            result["epistemic_status"] = "doubtful"

    # --------------------------------------------------
    # 7. CONHECIMENTO
    # --------------------------------------------------

    _ = knowledge

    # --------------------------------------------------
    # 8. REAÇÃO RECOMENDADA
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