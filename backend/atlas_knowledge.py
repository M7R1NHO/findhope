"""Gestão do conhecimento do Atlas 2.0 para Find Hope.

Mantém separados factos confirmados, hipóteses, afirmações do jogador e
questões desconhecidas. O estado pode ser isolado por run_id; chamadas sem
run_id continuam a usar o estado predefinido para compatibilidade.
"""

from copy import deepcopy


def _new_knowledge():
    return {
        "confirmed": [],
        "hypotheses": [],
        "player_claims": [],
        "unknowns": [],
    }



ATLAS_KNOWLEDGE = _new_knowledge()

_RUN_KNOWLEDGE = {}


def _get_state(run_id=None):
    if run_id is None:
        return ATLAS_KNOWLEDGE
    key = str(run_id).strip()
    if not key:
        return ATLAS_KNOWLEDGE
    if key not in _RUN_KNOWLEDGE:
        _RUN_KNOWLEDGE[key] = _new_knowledge()
    return _RUN_KNOWLEDGE[key]


def add_confirmed_fact(
    fact_id,
    name,
    source="unknown",
    extra=None,
    currently_detected=False,
    run_id=None,
):
    """Adiciona ou atualiza um facto confirmado.

    ``currently_detected`` representa apenas o estado atual dos sensores; não
    deve ser usado para inferir que algo continua visível entre scans.
    A confirmação deve vir de uma fonte fiável do jogo, não apenas de uma
    hipótese do modelo ou de uma afirmação do jogador.
    """
    if fact_id is None or not str(fact_id).strip():
        raise ValueError("fact_id tem de ser preenchido.")
    if name is None or not str(name).strip():
        raise ValueError("name tem de ser preenchido.")

    state = _get_state(run_id)
    fact_id = str(fact_id).strip()

    for fact in state["confirmed"]:
        if fact.get("id") == fact_id:
            fact["name"] = str(name).strip()
            fact["source"] = source or "unknown"
            fact["currently_detected"] = bool(currently_detected)
            if extra is not None:
                fact["extra"] = extra
            else:
                fact.pop("extra", None)
            return fact

    fact = {
        "id": fact_id,
        "name": str(name).strip(),
        "source": source or "unknown",
        "currently_detected": bool(currently_detected),
    }
    if extra is not None:
        fact["extra"] = extra
    state["confirmed"].append(fact)
    return fact


def add_hypothesis(hypothesis_id, text, source="reasoning", run_id=None):
    """Regista uma hipótese sem a promover a facto confirmado."""
    if hypothesis_id is None or not str(hypothesis_id).strip():
        raise ValueError("hypothesis_id tem de ser preenchido.")
    if text is None or not str(text).strip():
        raise ValueError("text tem de ser preenchido.")

    state = _get_state(run_id)
    hypothesis_id = str(hypothesis_id).strip()
    for hypothesis in state["hypotheses"]:
        if hypothesis.get("id") == hypothesis_id:

            hypothesis["text"] = str(text).strip()
            hypothesis["source"] = source or "reasoning"
            return hypothesis

    hypothesis = {
        "id": hypothesis_id,
        "text": str(text).strip(),
        "source": source or "reasoning",
    }
    state["hypotheses"].append(hypothesis)
    return hypothesis


def add_player_claim(claim_id, text, run_id=None):
    """Regista algo dito pelo jogador como não verificado por omissão."""
    if claim_id is None or not str(claim_id).strip():
        raise ValueError("claim_id tem de ser preenchido.")
    if text is None or not str(text).strip():
        raise ValueError("text tem de ser preenchido.")

    state = _get_state(run_id)
    claim_id = str(claim_id).strip()
    for claim in state["player_claims"]:
        if claim.get("id") == claim_id:
            claim["text"] = str(text).strip()
            return claim

    claim = {
        "id": claim_id,
        "text": str(text).strip(),
        "verified": False,
    }
    state["player_claims"].append(claim)
    return claim


def verify_player_claim(claim_id, verified=True, verification_source=None, run_id=None):
    """Atualiza a verificação de uma afirmação do jogador.

    A chamada deve ocorrer apenas após validação determinística do jogo.
    Verificar uma afirmação não cria automaticamente um facto confirmado:
    o sistema de jogo deve chamar também ``add_confirmed_fact`` se adequado.
    """
    state = _get_state(run_id)
    for claim in state["player_claims"]:
        if claim.get("id") == str(claim_id):
            claim["verified"] = bool(verified)
            if verification_source is not None:
                claim["verification_source"] = verification_source
            elif not verified:
                claim.pop("verification_source", None)
            return claim
    return None


def add_unknown(unknown_id, text, source="game", run_id=None):
    """Regista explicitamente uma questão ainda sem resposta confirmada."""
    if unknown_id is None or not str(unknown_id).strip():
        raise ValueError("unknown_id tem de ser preenchido.")
    if text is None or not str(text).strip():
        raise ValueError("text tem de ser preenchido.")

    state = _get_state(run_id)
    unknown_id = str(unknown_id).strip()
    for unknown in state["unknowns"]:
        if unknown.get("id") == unknown_id:
            unknown["text"] = str(text).strip()
            unknown["source"] = source or "game"
            return unknown

    unknown = {
        "id": unknown_id,
        "text": str(text).strip(),
        "source": source or "game",
    }
    state["unknowns"].append(unknown)
    return unknown


def resolve_unknown(unknown_id, run_id=None):
    """Remove uma questão da lista de desconhecidos após resolução validada."""
    state = _get_state(run_id)
    before = len(state["unknowns"])
    state["unknowns"][:] = [
        item for item in state["unknowns"] if item.get("id") != str(unknown_id)
    ]
    return len(state["unknowns"]) != before


def set_current_detection(fact_id, detected=True, run_id=None):
    """Atualiza apenas a deteção atual de um facto já confirmado.

    Não cria conhecimento novo e não altera a confirmação do facto.
    """
    state = _get_state(run_id)
    for fact in state["confirmed"]:
        if fact.get("id") == str(fact_id):
            fact["currently_detected"] = bool(detected)
            return True
    return False


def get_atlas_knowledge(run_id=None, copy=False):
    """Devolve o estado de conhecimento da partida.

    Por compatibilidade, devolve a referência original por omissão. Use
    ``copy=True`` quando precisar de uma cópia que não possa alterar o estado.
    """
    state = _get_state(run_id)
    return deepcopy(state) if copy else state


def build_knowledge_context(run_id=None):
    """Cria contexto textual sem misturar factos, hipóteses e alegações."""
    state = _get_state(run_id)
    lines = []

    confirmed = state.get("confirmed", [])
    hypotheses = state.get("hypotheses", [])
    player_claims = state.get("player_claims", [])
    unknowns = state.get("unknowns", [])

    if confirmed:
        lines.append("Factos confirmados (não confundir com deteção atual):")
        for fact in confirmed:
            if not isinstance(fact, dict):
                continue
            name = fact.get("name", "Facto sem descrição")
            detected = bool(fact.get("currently_detected", False))
            status = "detetado neste momento" if detected else "não detetado neste momento"
            lines.append(f"- {name} [{status}]")

    if hypotheses:
        lines.append("Hipóteses não confirmadas:")
        for hypothesis in hypotheses:
            if isinstance(hypothesis, dict):
                lines.append(f"- {hypothesis.get('text', 'Hipótese sem descrição')}")

    if player_claims:
        lines.append("Afirmações do jogador (não são factos por si só):")
        for claim in player_claims:
            if not isinstance(claim, dict):
                continue
            status = "verificada pelo sistema" if claim.get("verified", False) else "não verificada"
            lines.append(f"- {claim.get('text', 'Afirmação sem descrição')} ({status})")

    if unknowns:
        lines.append("Questões ainda desconhecidas:")
        for unknown in unknowns:
            if isinstance(unknown, dict):
                lines.append(f"- {unknown.get('text', 'Questão sem descrição')}")

    if not lines:
        return "Atlas ainda não possui conhecimento adicional relevante confirmado."

    lines.append(
        "Regra: não transformar hipóteses, afirmações não verificadas ou questões "
        "desconhecidas em factos. A ausência de deteção atual não prova que algo deixou de existir."
    )
    return "\n".join(lines)


def reset_current_detections(run_id=None):
    """Limpa o estado de deteção antes de um novo scan dos sensores."""
    state = _get_state(run_id)
    for fact in state["confirmed"]:
        if isinstance(fact, dict):
            fact["currently_detected"] = False


def reset_atlas_knowledge(run_id=None):
    """Limpa o conhecimento de uma partida sem afetar outras partidas."""
    if run_id is None or not str(run_id).strip():
        ATLAS_KNOWLEDGE.clear()
        ATLAS_KNOWLEDGE.update(_new_knowledge())
    else:
        _RUN_KNOWLEDGE[str(run_id).strip()] = _new_knowledge()


def remove_run_knowledge(run_id):
    """Remove o estado isolado de uma partida, por exemplo ao terminar a run."""
    if run_id is None:
        return False
    return _RUN_KNOWLEDGE.pop(str(run_id).strip(), None) is not None
