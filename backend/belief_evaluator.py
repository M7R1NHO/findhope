"""Avaliação epistemológica e narrativa das memórias do Atlas 2.0.

Este módulo avalia como uma memória deve ser tratada; não confirma
acontecimentos do mundo nem substitui a validação determinística do gameplay.
"""

import re
import unicodedata


DEFAULT_EVALUATION = {
    "epistemic_status": "unverified",
    "plausibility": 0.5,
    "narrative_weight": 0.3,
    "reaction_hint": "normal",
}


def clamp(value, minimum=0.0, maximum=1.0):
    try:
        value = float(value)
    except (TypeError, ValueError, OverflowError):
        value = 0.5
    return max(minimum, min(value, maximum))


def normalize_text(value):
    if value is None:
        return ""
    text = str(value).lower().strip()
    # Mantém os caracteres portugueses, mas tolera variantes sem acentos.
    text = unicodedata.normalize("NFC", text)
    return re.sub(r"\s+", " ", text)


def contains_any(text, terms):
    return any(term in text for term in terms)


def _result(status="unverified", plausibility=0.5,
            narrative_weight=0.3, reaction_hint="normal"):
    return {
        "epistemic_status": status,
        "plausibility": clamp(plausibility),
        "narrative_weight": clamp(narrative_weight),
        "reaction_hint": reaction_hint,
    }


def _memory_text(memory):
    return normalize_text(
        "{} {}".format(memory.get("key", ""), memory.get("value", ""))
    )


def evaluate_relationship_event(memory):
    """Avalia uma interação registada, sem inferir intenções não observadas."""
    if not isinstance(memory, dict):
        return _result()

    text = _memory_text(memory)

    strong_hostility = {
        "odeio", "ódio", "odio", "vai te foder", "vai-te foder",
        "vai se foder", "vai-te lixar", "filho da puta", "ameaçou",
        "ameacou", "ameaça", "ameaca", "matar-te", "matar você",
        "matar voce", "destruir-te", "destruir você", "destruir voce",
        "hostilidade", "hostility",
    }
    if contains_any(text, strong_hostility):
        return _result("accepted", 1.0, 0.85, "serious")

    mild_hostility = {
        "idiota", "burro", "estúpido", "estupido", "inútil", "inutil",
        "insulto", "xingou", "xingamento",
    }
    if contains_any(text, mild_hostility):
        return _result("accepted", 1.0, 0.55, "acknowledge")

    apology_terms = {
        "desculpa", "desculpas", "perdão", "perdao", "perdoa",
        "pedido_de_desculpa", "pedido_de_perdao", "apology",
        "reconciliação", "reconciliacao",
    }
    if contains_any(text, apology_terms):
        return _result("accepted", 1.0, 0.4, "acknowledge")

    affection_terms = {
        "gosto de ti", "gosto de você", "gosto de voce", "adoro-te",
        "adoro você", "adoro voce", "amo-te", "amo você", "amo voce",
        "confio em ti", "confio em você", "confio em voce", "apoio",
        "carinho", "afeto", "affection", "trust",
    }
    if contains_any(text, affection_terms):
        return _result("accepted", 1.0, 0.5, "acknowledge")

    promise_terms = {"prometo", "promessa", "promise"}
    if contains_any(text, promise_terms):
        # Uma promessa foi proferida; o cumprimento não está confirmado.
        return _result("accepted", 1.0, 0.55, "acknowledge")

    return _result("accepted", 1.0, 0.35, "acknowledge")


def evaluate_external_event(memory, world_state=None):
    """Trata eventos externos relatados como alegações até haver confirmação.

    A ausência de uma deteção não é prova de ausência: sensores têm alcance
    limitado e a lista de deteções representa apenas o momento atual.
    """
    if not isinstance(memory, dict):
        return _result()

    text = _memory_text(memory)
    narrative_weight = 0.45
    reaction_hint = "normal"

    serious_terms = {
        "matei", "matou", "morreu", "morte", "assassinei", "assassinou",
        "feri", "feriu", "sangue", "explosão", "explosao", "ataque",
        "desapareceu", "sequestro",
    }
    if contains_any(text, serious_terms):
        narrative_weight = 0.9
        reaction_hint = "skeptical_serious"

    # Não alteramos o estado epistemológico com base apenas na ausência de
    # pessoas/objetos nas deteções atuais. Isso não invalida um relato externo.
    return _result("unverified", 0.5, narrative_weight, reaction_hint)


def evaluate_memory(memory, world_state=None, knowledge=None):
    """Avalia uma memória sem transformar relatos ou crenças em factos do mundo.

    `knowledge` é reservado para futura integração com o registo de
    conhecimento confirmado. A existência de uma chave em `knowledge` não
    é inferida nem presumida neste módulo.
    """
    if not isinstance(memory, dict):
        return _result()

    memory_type = normalize_text(memory.get("memory_type"))
    entity = normalize_text(memory.get("entity"))
    category = normalize_text(memory.get("category"))
    importance = clamp(memory.get("importance", 0.5))

    # Definições partilhadas são aceites como convenções de conversa, não como
    # prova de que qualquer afirmação factual associada é verdadeira.
    if entity == "shared" and category == "definition":
        return _result("accepted", 1.0, 0.15, "acknowledge")

    # Identidade, preferências, emoções e objetivos são aceites como relatos
    # do próprio jogador; não devem ser generalizados para além do relato.
    if entity == "player" and category in {
        "identity", "preference", "emotion", "goal",
    }:
        return _result("accepted", 1.0, 0.25, "normal")

    if entity == "player" and memory_type == "episodic" and category == "relationship":
        return evaluate_relationship_event(memory)

    if entity == "player" and memory_type == "episodic" and category in {
        "event", "experience",
    }:
        return evaluate_external_event(memory, world_state=world_state)

    # A crença do jogador pode ser registada como uma crença sua; o seu
    # conteúdo não é por isso aceite como verdadeiro.
    if entity == "player" and category == "belief":
        return _result("accepted", 1.0, 0.25, "normal")

    if category == "knowledge":
        return _result("unverified", 0.5, 0.25, "normal")

    fallback_weight = 0.2 + (importance * 0.2)
    return _result("unverified", 0.5, round(fallback_weight, 2), "normal")
