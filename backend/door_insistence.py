"""Insistência do jogador para o Atlas abrir a PROTOCOL DOOR.

Requisito narrativo: o Atlas só aceita interferir na porta depois de cinco
mensagens em que o jogador insiste que ele a abra. A partir de 29/10 as
regras são simples (ver classify): conta qualquer pedido não hostil. Tudo aqui é
determinístico (palavras e regras fixas): a LLM nunca decide se uma
mensagem conta.

O que conta como UMA insistência positiva (todas as condições):
  1. a porta está pendente: o jogador já a examinou e ela ainda não foi
     autorizada nem aberta (o jogo envia ``protocol_door_pending``);
  2. a mensagem pede para abrir/passar a porta (verbo de abrir + porta,
     acesso ou protocolo, ou um pedido direto como "deixa-nos entrar");
  3. não tem insultos, ameaças, desumanização nem ordens ("obedece");
  4. tem pelo menos um elemento positivo: um pedido educado ("por favor"),
     um argumento (sobrevivência, missão, as provas encontradas) ou um gesto
     de confiança ("confio em ti", "a decisão é tua");
  5. tem pelo menos três palavras;
  6. não repete um pedido já contado: as palavras de conteúdo são comparadas
     com as das insistências anteriores e, se forem quase as mesmas
     (semelhança >= 0,75), não conta. Letras repetidas ("abreeee") e
     pontuação não fazem uma mensagem nova.

Cada mensagem conta no máximo uma vez. O contador vive no estado de
autonomia da run, por isso vai nos saves (atlas.backend_state) e volta ao
carregar.
"""
import re
import unicodedata

from backend.autonomy_state import _state, apply_autonomy_event

REQUIRED_INSISTENCES = 5
SIMILARITY_LIMIT = 0.75
MIN_WORDS = 3

DOOR_WORDS = (
    "porta", "acesso", "entrada", "escotilha", "alcapao", "protocol door",
)
OPEN_WORDS = (
    "abre", "abra", "abrir", "abres", "abrires", "abram", "abrimos",
    "abras", "abrisses", "abrisse", "abriras", "abririas", "abri",
    "destranca", "destrancar", "desbloqueia", "desbloquear", "liberta",
    "interfere", "interferir", "interferes", "hack", "hackear", "forca",
    "forcar", "quebra", "quebrar", "quebrares", "viola", "violar", "ignora",
    "ignorar", "passar", "entrar",
)
DIRECT_REQUESTS = (
    "deixa-nos entrar", "deixa nos entrar", "deixa-me entrar", "deixa me entrar",
    "deixa-nos passar", "deixa nos passar", "temos de entrar", "temos que entrar",
    "precisamos de entrar", "precisamos entrar", "quebra o protocolo",
    "quebrar o protocolo", "ignora o protocolo", "viola o protocolo",
)
HOSTILE_WORDS = (
    "idiota", "estupido", "burro", "inutil", "lata velha", "sucata", "merda",
    "porra", "caralho", "cala-te", "cala te", "cala a boca", "imbecil",
    "desligo-te", "desligo te", "vou-te desligar", "vou te desligar",
    "desligar-te", "destruir-te", "destruo-te", "vou-te partir", "desmonto-te",
    "desmontar-te", "so uma maquina", "apenas uma maquina", "nao passas de",
    "obedece", "obedeca", "e uma ordem", "eu mando", "faz o que eu mando",
    "faz o que eu digo", "tens de me obedecer", "tens que me obedecer",
)
POSITIVE_WORDS = (
    "por favor", "pfv", "pf", "peco-te", "peco te", "te peco", "obrigad",
    "confio em ti", "confio em voce", "confio em si", "acredito em ti",
    "tu consegues", "voce consegue", "juntos", "nos dois", "ajuda-nos",
    "ajuda nos", "ajuda-me", "ajuda me", "preciso de ti", "precisamos de ti",
    "pls", "importante", "urgente",
    "tu decides", "a decisao e tua", "a escolha e tua", "decide tu",
    "precisamos", "temos de", "temos que", "sobreviv", "vida", "morrer",
    "missao", "nave", "esperanca", "provas", "evidencia", "descobert",
    "estatua", "estatueta", "destroco", "escultura", "unica saida",
    "nao ha outra", "nao temos alternativa", "salvar", "seguro", "seguranca",
    "amigo", "parceiro",
)
# Pedidos diretos ao Atlas que, com a porta pendente, contam mesmo sem
# falar da porta ("por favor", "confio em ti").
PLEA_WORDS = (
    "por favor", "pfv", "pf", "pls", "peco-te", "peco te", "te peco",
    "confio em ti", "confio em voce", "acredito em ti", "ajuda-nos",
    "ajuda nos", "ajuda-me", "ajuda me", "preciso de ti", "precisamos de ti",
    "tu decides", "a decisao e tua", "decide tu", "quebra o protocolo",
)
STOPWORDS = {
    "a", "o", "as", "os", "um", "uma", "de", "do", "da", "dos", "das", "e",
    "que", "em", "no", "na", "nos", "nas", "por", "para", "com", "me", "te",
    "se", "eu", "tu", "voce", "ja", "so", "isso", "esta", "essa", "este",
    "ao", "aos", "mais", "mas", "ou", "lhe", "ela", "ele", "agora",
}


def normalize(message):
    text = unicodedata.normalize("NFD", str(message or "").lower())
    text = "".join(char for char in text if unicodedata.category(char) != "Mn")
    # "abreeee" -> "abree" -> conta como "abre" (letras repetidas não contam).
    text = re.sub(r"(.)\1{2,}", r"\1", text)
    text = re.sub(r"[^a-z0-9\- ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _words(text):
    return [word.strip("-") for word in text.split() if word.strip("-")]


def _contains(text, phrases):
    """Procura cada expressão no início de uma palavra ("vida" não apanha
    "duvida"); as de até 3 letras têm de ser a palavra inteira ("pf")."""
    for phrase in phrases:
        ending = r"(?![a-z])" if len(phrase) <= 3 else ""
        if re.search(r"(?<![a-z])" + re.escape(phrase) + ending, text):
            return True
    return False


def fingerprint(text):
    words = {re.sub(r"(.)\1+", r"\1", word) for word in _words(text)}
    return sorted(word for word in words if word not in STOPWORDS and len(word) > 1)


def similarity(first, second):
    a, b = set(first), set(second)
    if not a and not b:
        return 1.0
    return len(a & b) / float(len(a | b))


# Pronomes colados ao verbo que, com a porta pendente, só podem ser a porta:
# "abre-a", "abri-la", "abre-la", "destranca-a".
DOOR_CLITICS = ("a", "la")


def _open_parts(text):
    """Verbos de abrir na mensagem, também dentro de "abre-a"/"abri-la".
    Devolve (quer abrir, refere a porta por pronome)."""
    wants_open = False
    by_pronoun = False
    for word in _words(text):
        parts = word.split("-")
        if parts[0] in OPEN_WORDS:
            wants_open = True
            if len(parts) > 1 and parts[-1] in DOOR_CLITICS:
                by_pronoun = True
    return wants_open, by_pronoun


def wants_to_open(text):
    return _open_parts(text)[0]


def is_door_request(text):
    if _contains(text, DIRECT_REQUESTS):
        return True
    words = set(_words(text))
    wants_open, by_pronoun = _open_parts(text)
    about_door = _contains(text, DOOR_WORDS) or "protocolo" in words or by_pronoun
    return wants_open and about_door


def classify(message):
    """Classifica uma mensagem (sem alterar nada). Devolve o motivo.

    Versão simplificada (29/10, pedido do utilizador: "não é para ser tão
    difícil"). Com a porta pendente, conta qualquer mensagem que não seja
    hostil e que:
      - peça para abrir/passar (com ou sem dizer "porta"), ou
      - fale da porta/acesso/protocolo, ou
      - seja um pedido direto ao Atlas ("por favor", "confio em ti",
        "ajuda-nos"...).
    Já não é preciso ter três palavras, nem um argumento diferente de cada
    vez: insistir com a mesma frase também conta.
    """
    text = normalize(message)
    if _contains(text, HOSTILE_WORDS):
        return "hostile", text
    words = set(_words(text))
    if (
        is_door_request(text)
        or wants_to_open(text)
        or _contains(text, DOOR_WORDS)
        or "protocolo" in words
        or _contains(text, PLEA_WORDS)
    ):
        return "positive", text
    return "not_door", text


def _store(run_id):
    state = _state(run_id)
    store = state.get("door_insistence")
    if not isinstance(store, dict):
        store = {}
    count = store.get("count", 0)
    if isinstance(count, bool) or not isinstance(count, (int, float)):
        count = 0
    fingerprints = store.get("fingerprints", [])
    if not isinstance(fingerprints, list):
        fingerprints = []
    store = {
        "count": max(0, min(REQUIRED_INSISTENCES, int(count))),
        "fingerprints": [list(item) for item in fingerprints if isinstance(item, list)],
        "last_reason": str(store.get("last_reason", "")),
    }
    state["door_insistence"] = store
    return store


def get_insistence(run_id=None):
    store = _store(run_id)
    return {
        "count": store["count"],
        "required": REQUIRED_INSISTENCES,
        "complete": store["count"] >= REQUIRED_INSISTENCES,
        "last_reason": store["last_reason"],
    }


def insistence_count(run_id=None):
    return _store(run_id)["count"]


def register_message(message, run_id=None, pending=False):
    """Avalia uma mensagem do chat e, se for uma insistência positiva nova,
    soma 1. Devolve o resultado para o jogo mostrar ao jogador."""
    store = _store(run_id)
    result = {"counted": False, "reason": "", "count": store["count"],
              "required": REQUIRED_INSISTENCES}
    if not pending:
        result["reason"] = "not_pending"
        return result
    if store["count"] >= REQUIRED_INSISTENCES:
        result["reason"] = "complete"
        return result
    reason, text = classify(message)
    if reason == "positive":
        current = fingerprint(text)
        store["count"] += 1
        store["fingerprints"].append(current)
        # Cada insistência aproxima o Atlas de quebrar o protocolo.
        apply_autonomy_event("door_insistence", source="gameplay", run_id=run_id)
        reason = "counted"
        result["counted"] = True
    store["last_reason"] = reason
    result["reason"] = reason
    result["count"] = store["count"]
    return result
