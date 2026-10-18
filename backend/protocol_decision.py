"""Avaliação determinística das condições narrativas para a porta do protocolo.

A autorização é calculada pelo backend; a LLM não pode conceder acesso.
As descobertas têm de estar registadas pelo gameplay e a disposição do
Atlas tem de ter ultrapassado o estado resistente.
"""
from backend.autonomy_state import get_protocol_stance
from backend.discovery_state import get_protocol_evidence


VALID_STANCES = {"resistant", "conflicted", "willing"}


def evaluate_protocol_door(run_id=None):
    """Avalia a porta e devolve a decisão e as evidências que a sustentam.

    ``run_id`` é opcional para manter compatibilidade com chamadas antigas.
    Deve ser o mesmo identificador de partida usado pelos módulos de estado.
    """
    evidence = get_protocol_evidence(run_id=run_id)
    protocol_stance = get_protocol_stance(run_id=run_id)

    # Validar a estrutura recebida, sem presumir que evidência malformada
    # significa que os requisitos foram cumpridos.
    if not isinstance(evidence, dict):
        evidence = {}

    discovered = evidence.get("discovered", [])
    missing = evidence.get("missing", [])
    ready = evidence.get("ready") is True

    if not isinstance(discovered, list):
        discovered = []
    if not isinstance(missing, list):
        missing = []

    # Falhar em segurança: se a evidência estiver incompleta ou inconsistente,
    # a porta permanece bloqueada.
    if not ready or missing:
        return {
            "allowed": False,
            "reason": "missing_surface_evidence",
            "protocol_stance": protocol_stance,
            "evidence_ready": False,
            "discovered": discovered,
            "missing": missing,
        }

    if protocol_stance not in VALID_STANCES:
        return {
            "allowed": False,
            "reason": "invalid_protocol_stance",
            "protocol_stance": protocol_stance,
            "evidence_ready": True,
            "discovered": discovered,
            "missing": [],
        }

    if protocol_stance == "resistant":
        return {
            "allowed": False,
            "reason": "atlas_not_ready",
            "protocol_stance": protocol_stance,
            "evidence_ready": True,
            "discovered": discovered,
            "missing": [],
        }

    return {
        "allowed": True,
        "reason": "protocol_violation_justified",
        "protocol_stance": protocol_stance,
        "evidence_ready": True,
        "discovered": discovered,
        "missing": [],
    }
