ATLAS_KNOWLEDGE = {
    "confirmed": [],
    "hypotheses": [],
    "player_claims": [],
    "unknowns": []
}


def add_confirmed_fact(
    fact_id,
    name,
    source="unknown",
    extra=None,
    currently_detected=False
):
    """
    Adiciona ou atualiza um facto confirmado no conhecimento do Atlas.
    """

    for fact in ATLAS_KNOWLEDGE["confirmed"]:
        if fact["id"] == fact_id:
            fact["currently_detected"] = currently_detected

            if extra:
                fact["extra"] = extra

            return

    fact = {
        "id": fact_id,
        "name": name,
        "source": source,
        "currently_detected": currently_detected
    }

    if extra:
        fact["extra"] = extra

    ATLAS_KNOWLEDGE["confirmed"].append(fact)


def add_hypothesis(hypothesis_id, text, source="reasoning"):
    for hypothesis in ATLAS_KNOWLEDGE["hypotheses"]:
        if hypothesis["id"] == hypothesis_id:
            return

    ATLAS_KNOWLEDGE["hypotheses"].append({
        "id": hypothesis_id,
        "text": text,
        "source": source
    })


def add_player_claim(claim_id, text):
    for claim in ATLAS_KNOWLEDGE["player_claims"]:
        if claim["id"] == claim_id:
            return

    ATLAS_KNOWLEDGE["player_claims"].append({
        "id": claim_id,
        "text": text,
        "verified": False
    })


def get_atlas_knowledge():
    return ATLAS_KNOWLEDGE


def build_knowledge_context():
    confirmed = ATLAS_KNOWLEDGE["confirmed"]
    hypotheses = ATLAS_KNOWLEDGE["hypotheses"]
    player_claims = ATLAS_KNOWLEDGE["player_claims"]

    lines = []

    if confirmed:
        lines.append("Factos confirmados:")
        for fact in confirmed:
            lines.append(f"- {fact['name']}")

    if hypotheses:
        lines.append("Hipóteses:")
        for hypothesis in hypotheses:
            lines.append(f"- {hypothesis['text']}")

    if player_claims:
        lines.append("Informações dadas pelo jogador:")
        for claim in player_claims:
            status = "confirmada" if claim["verified"] else "não confirmada"
            lines.append(f"- {claim['text']} ({status})")

    if not lines:
        return "Atlas ainda não possui conhecimento adicional relevante."

    return "\n".join(lines)

def reset_current_detections():
    """
    Marca todos os conhecimentos como não detetados atualmente.
    Antes de cada novo scan, o sensor decide quais voltam a True.
    """

    for fact in ATLAS_KNOWLEDGE["confirmed"]:
        fact["currently_detected"] = False

def reset_atlas_knowledge():
    ATLAS_KNOWLEDGE["confirmed"].clear()
    ATLAS_KNOWLEDGE["hypotheses"].clear()
    ATLAS_KNOWLEDGE["player_claims"].clear()
    ATLAS_KNOWLEDGE["unknowns"].clear()