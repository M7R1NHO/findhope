from backend.autonomy_state import (
    get_protocol_stance,
)

from backend.discovery_state import (
    get_protocol_evidence,
)


def evaluate_protocol_door():
    """
    A decisão da porta pertence ao código.

    Regras:
    1. Conversa sozinha nunca é suficiente.
    2. As duas descobertas da superfície são obrigatórias.
    3. Depois das evidências, Atlas precisa estar pelo menos
       em conflito com o protocolo.

    A LLM apenas formula a resposta.
    """

    evidence = get_protocol_evidence()

    protocol_stance = (
        get_protocol_stance()
    )

    if not evidence["ready"]:
        return {
            "allowed": False,
            "reason": "missing_surface_evidence",
            "protocol_stance": protocol_stance,
            "evidence_ready": False,
            "discovered": evidence[
                "discovered"
            ],
            "missing": evidence[
                "missing"
            ],
        }

    if protocol_stance == "resistant":
        return {
            "allowed": False,
            "reason": "atlas_not_ready",
            "protocol_stance": protocol_stance,
            "evidence_ready": True,
            "discovered": evidence[
                "discovered"
            ],
            "missing": [],
        }

    return {
        "allowed": True,
        "reason": "protocol_violation_justified",
        "protocol_stance": protocol_stance,
        "evidence_ready": True,
        "discovered": evidence[
            "discovered"
        ],
        "missing": [],
    }
