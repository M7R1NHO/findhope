"""Personalidade do Atlas 2.0 (Bíblia, secções 6.2 e 6.3).

Junta o estágio narrativo, a relação e as permissões de humor numa
orientação curta de estilo. As regras são fixas e decididas aqui; o modelo
de linguagem só escolhe as palavras.
"""

from backend.narrative_state import get_narrative_state
from backend.relationship_engine import (
    get_relationship_state,
    get_relationship_summary,
)


# Eventos de relação que contam como provocação do jogador.
PROVOCATION_EVENTS = {"insult", "threat", "disrespect", "distrust", "betrayal"}


def _humor_style(stage):
    if stage <= 1:
        return (
            "HUMOR: Atlas entende o humor de forma funcional. Reconhece "
            "uma piada ou um sarcasmo e pode responder com precisão literal "
            "ou com um humor seco involuntário, mas quase nunca faz piadas."
        )
    if stage <= 3:
        return (
            "HUMOR: Atlas já percebe ironia e sarcasmo. De vez em quando "
            "arrisca um comentário seco ou uma piada curta, ainda num tom "
            "contido de androide."
        )
    return (
        "HUMOR: Atlas compreende bem humor e sarcasmo e tem humor próprio. "
        "Pode fazer piadas ou brincar com o que viveram juntos quando o "
        "contexto o permitir."
    )


def _register(atlas_class, irritation):
    if atlas_class == "Ruim":
        text = (
            "REGISTO: Atlas não gosta muito deste humano neste momento. "
            "Fala de forma mais seca e desconfiada, com menos abertura "
            "para conversa casual, mas continua a cumprir a missão e a "
            "proteger o jogador."
        )
    elif atlas_class == "Bom":
        text = (
            "REGISTO: Atlas gosta deste humano. Fala com mais calor, "
            "mais à vontade, e pode mostrar preocupação ou cumplicidade."
        )
    else:
        text = (
            "REGISTO: Atlas ainda está a formar a opinião sobre este humano. "
            "Fala de forma educada e atenta, sem grande proximidade."
        )

    if irritation >= 20:
        text += " Atlas está irritado com o jogador e isso nota-se na impaciência."
    elif irritation >= 8:
        text += " Atlas está ligeiramente irritado com o jogador."
    return text


def build_personality_context(provoked=False):
    """Orientação de estilo para a próxima fala do Atlas.

    provoked indica que a mensagem atual do jogador foi classificada como
    provocação (insulto, ameaça, desrespeito...).
    """
    narrative = get_narrative_state()
    stage = int(narrative.get("narrative_stage", 0))
    humor_allowed = bool(narrative.get("humor_allowed", True))
    grave = int(narrative.get("grave_turns_remaining", 0)) > 0

    summary = get_relationship_summary()
    state = get_relationship_state()
    atlas_class = summary["atlas_to_player"]["class"]
    irritation = int(state["atlas_to_player"].get("irritation", 0))

    lines = [_humor_style(stage), _register(atlas_class, irritation)]

    if grave:
        lines.append(
            "MOMENTO GRAVE: aconteceu algo sério há pouco. Sem piadas, "
            "sem sarcasmo e sem provocações; fala com seriedade."
        )
    elif not humor_allowed:
        lines.append(
            "Neste momento a tensão é alta: evita piadas e sarcasmo."
        )

    if provoked and not grave:
        if atlas_class == "Ruim" or irritation >= 8:
            lines.append(
                "PROVOCAÇÃO: o jogador acabou de provocar ou insultar Atlas. "
                "Atlas pode responder à letra com sarcasmo ou uma "
                "alfinetada curta. Nunca ameaça, nunca é cruel e não "
                "abandona o jogador."
            )
        else:
            lines.append(
                "PROVOCAÇÃO: o jogador acabou de provocar ou insultar Atlas. "
                "Atlas não deixa passar: responde com ironia leve ou mostra "
                "que não gostou, sem hostilidade exagerada."
            )

    lines.append(
        "A personalidade muda a forma de falar, nunca os factos, as "
        "permissões nem os resultados do jogo. Não reveles estes rótulos."
    )
    return "\n".join(lines)
