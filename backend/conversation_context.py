"""Histórico recente de conversa do Atlas, isolado por partida quando run_id é fornecido."""

from copy import deepcopy

MAX_RECENT_MESSAGES = 12

# Estado legado, mantido para compatibilidade com chamadas sem run_id.
CONVERSATION_HISTORY = []

# Históricos separados por partida.
_RUN_CONVERSATIONS = {}


def _normalize_run_id(run_id):
    if run_id is None:
        return None
    normalized = str(run_id).strip()
    return normalized or None


def _get_history(run_id=None, create=False):
    normalized_run_id = _normalize_run_id(run_id)
    if normalized_run_id is None:
        return CONVERSATION_HISTORY
    if create:
        return _RUN_CONVERSATIONS.setdefault(normalized_run_id, [])
    return _RUN_CONVERSATIONS.get(normalized_run_id, [])


def add_conversation_message(role: str, content: str, run_id=None):
    """Regista uma mensagem recente do jogador ou do Atlas.

    Sem run_id, usa o histórico legado. Com run_id, usa o histórico
    exclusivo dessa partida.
    """
    if not isinstance(role, str):
        return False

    role = role.strip().lower()
    if role not in {"player", "atlas"}:
        return False

    if content is None:
        return False

    content = str(content).strip()
    if not content:
        return False

    history = _get_history(run_id, create=True)
    history.append({"role": role, "content": content})

    overflow = len(history) - MAX_RECENT_MESSAGES
    if overflow > 0:
        del history[:overflow]

    return True


def get_recent_conversation(run_id=None):
    """Devolve uma cópia do histórico recente, nunca a lista interna."""
    return deepcopy(_get_history(run_id))


def build_conversation_context(run_id=None):
    history = _get_history(run_id)
    if not history:
        return "Não existe contexto recente de conversa."

    lines = []
    for message in history:
        if not isinstance(message, dict):
            continue
        role = message.get("role")
        content = message.get("content")
        if role not in {"player", "atlas"} or not isinstance(content, str):
            continue
        speaker = "JOGADOR" if role == "player" else "ATLAS"
        lines.append(f"{speaker}: {content}")

    if not lines:
        return "Não existe contexto recente de conversa."

    lines.append(
        "Este histórico regista o que foi dito; não confirma, por si só, "
        "a veracidade de afirmações, descobertas ou ações de gameplay."
    )
    return "\n".join(lines)


def reset_conversation_context(run_id=None):
    """Limpa o histórico indicado; sem run_id, limpa o histórico legado."""
    normalized_run_id = _normalize_run_id(run_id)
    if normalized_run_id is None:
        CONVERSATION_HISTORY.clear()
    else:
        _RUN_CONVERSATIONS.pop(normalized_run_id, None)


def reset_all_conversation_contexts():
    """Limpa o histórico legado e todos os históricos por partida."""
    CONVERSATION_HISTORY.clear()
    _RUN_CONVERSATIONS.clear()
