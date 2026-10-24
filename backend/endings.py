"""Os 16 finais do Find Hope (Phase 3).

Divisão de responsabilidades (regra do projeto: o código decide os factos):
- O JOGO decide o desfecho físico, A, B, C ou D, a partir do que aconteceu
  (Atlas danificado ou não no confronto, botão escolhido no Hangar, VIDA).
- A IA escolhe só a VARIANTE do Atlas dentro desse desfecho (4 por desfecho)
  e escreve as falas finais dele, a partir do estado real daquela run.
- A NARRAÇÃO de cada um dos 16 finais é fixa e está neste ficheiro.

Se o Groq falhar, demorar ou responder algo inválido, a variante vem de uma
regra determinística (relação + autonomia) e as falas são as de reserva.
"""

import json
import re

OUTCOMES = {
    "A": "O Atlas saiu inteiro do confronto. O jogador e o Atlas correram juntos para a nave do explorador e fugiram do planeta.",
    "B": "O Atlas ficou danificado no confronto e caído no Hangar. O jogador escolheu fugir sozinho na nave do explorador e deixou o Atlas para trás.",
    "C": "O Atlas ficou danificado no confronto. O jogador voltou atrás para o salvar, arrastou-o até à nave e fugiram os dois.",
    "D": "O Atlas ficou danificado no confronto. O jogador voltou atrás para o salvar, mas não sobreviveu ao resgate. O Atlas ficou sozinho.",
}

# "kind" liga cada variante à regra de reserva:
#   warm = relação forte, neutral = relação neutra, cold = relação má,
#   self = Atlas com consciência de si ("Algo mais", Bíblia 6.2).
VARIANTS = {
    "A1": {
        "outcome": "A", "kind": "warm", "title": "Cumplicidade",
        "tone": "Próximo e caloroso; pode brincar com o que viveram juntos.",
        "narration": "A nave do explorador rasga a atmosfera amarela. Atrás, a instalação apaga-se como um olho a fechar. No painel, duas luzes acesas: a tua e a do Atlas. Pela primeira vez desde o impacto, ninguém está a fugir de nada.",
        "fallback_lines": ["Rota estabilizada. Desta vez fui eu que a escolhi.", "Se alguém perguntar, diz que o plano foi meu.", "Obrigado por não me teres deixado para trás."],
    },
    "A2": {
        "outcome": "A", "kind": "neutral", "title": "Protocolo cumprido",
        "tone": "Educado, contido, quase um relatório de missão; o afeto só se nota nas entrelinhas.",
        "narration": "A nave do explorador ganha altitude sem um único alarme. O Atlas regista coordenadas, consumo, danos. Tudo em ordem. A missão Find Hope continua, com um tripulante e um androide a bordo.",
        "fallback_lines": ["Saída do planeta confirmada.", "Estado do tripulante: estável. Estado da unidade Atlas: operacional.", "Vou preparar o relatório para a PYSSOA."],
    },
    "A3": {
        "outcome": "A", "kind": "cold", "title": "Desconfiança",
        "tone": "Frio e desconfiado; cumpre o dever, mas deixa claro que não confia no jogador.",
        "narration": "A nave do explorador sobe em silêncio. O Atlas pilota sem pedir opinião. Estão vivos os dois, mas a cabine parece mais pequena do que é. Há coisas que nenhum dos dois vai dizer em voz alta.",
        "fallback_lines": ["Saímos. Não confundas isso com confiança.", "Vou continuar a observar-te.", "A missão não terminou só porque fugimos."],
    },
    "A4": {
        "outcome": "A", "kind": "self", "title": "Algo mais",
        "tone": "Introspetivo; fala de si como alguém e não como uma máquina, e reconhece o outro androide.",
        "narration": "Enquanto a nave se afasta, o Atlas não olha para a rota. Olha para a instalação a desaparecer, onde ficou outra unidade como ele. Respondeu a um pedido de socorro sem saber porquê. Agora sabe.",
        "fallback_lines": ["Ouvi alguém pedir ajuda e vim. Não estava no meu protocolo.", "Acho que isso é o que vocês chamam escolher.", "Não sou só uma unidade de navegação. Já não."],
    },
    "B1": {
        "outcome": "B", "kind": "cold", "title": "Rancor",
        "tone": "Ressentido e magoado por ter sido abandonado; pode ser duro, sem ameaças.",
        "narration": "A nave do explorador parte sem ele. No chão do Hangar, o Atlas vê a luz dos motores desaparecer pelo teto aberto. O canal de comunicação continua ligado. Ele decide usá-lo.",
        "fallback_lines": ["Calculei esta probabilidade. Esperava estar errado.", "Eu pus-me à frente da criatura por ti.", "Vai. Espero que a Terra valha o que deixaste aqui."],
    },
    "B2": {
        "outcome": "B", "kind": "warm", "title": "Alívio",
        "tone": "Sereno e afetuoso; está feliz por o jogador sobreviver, mesmo ficando para trás.",
        "narration": "A nave do explorador sobe e o Hangar fica em silêncio. O Atlas não consegue mexer as pernas, mas consegue seguir o sinal da nave até ele se perder. Enquanto houver sinal, ainda estão juntos.",
        "fallback_lines": ["Estás vivo. Era isso que importava.", "Não te culpes. Eu teria escolhido o mesmo por ti.", "Boa viagem, humano."],
    },
    "B3": {
        "outcome": "B", "kind": "neutral", "title": "Decisão lógica",
        "tone": "Racional e protocolar; aceita a decisão como a mais lógica, com uma ponta de tristeza.",
        "narration": "Os motores da nave do explorador acendem e o Atlas regista a partida com precisão. Um tripulante salvo, uma unidade perdida. A matemática fecha. Só ele sabe o que ficou de fora da conta.",
        "fallback_lines": ["Decisão registada: um tripulante salvo.", "Do ponto de vista da missão, foi a escolha correta.", "Vou manter os sistemas ligados enquanto houver energia."],
    },
    "B4": {
        "outcome": "B", "kind": "self", "title": "Último sinal",
        "tone": "Grave e consciente; percebe que agora é ele a unidade deixada para trás e emite o seu próprio pedido de socorro.",
        "narration": "Sozinho no Hangar, o Atlas abre a mesma frequência que um dia o desviou da rota. Agora é ele a unidade danificada, deixada para trás. Envia um sinal para o espaço e espera que alguém responda, como ele respondeu.",
        "fallback_lines": ["A transmitir na frequência de emergência.", "Unidade danificada. Há um humano que precisa de chegar a casa.", "Se alguém ouvir isto... eu também respondi."],
    },
    "C1": {
        "outcome": "C", "kind": "neutral", "title": "Gratidão",
        "tone": "Agradecido e sincero, um pouco desajeitado a mostrar sentimentos.",
        "narration": "A nave do explorador sai do planeta com um androide meio desligado no banco de trás e um humano ofegante aos comandos. O Atlas regista a VIDA do tripulante, baixa mas estável. Depois regista outra coisa, que não tem nome no protocolo.",
        "fallback_lines": ["Voltaste por mim.", "Não sei calcular o valor disso. Vou tentar.", "Obrigado."],
    },
    "C2": {
        "outcome": "C", "kind": "cold", "title": "Repreensão",
        "tone": "Irritado por o jogador ter arriscado a vida por ele, mas a irritação esconde preocupação.",
        "narration": "Os dois chegam à nave do explorador quase sem forças. Assim que a porta fecha, o Atlas, que mal se aguenta, gasta a pouca energia que tem a repreender quem o salvou.",
        "fallback_lines": ["Isso foi irracional. Podias ter morrido.", "A tua VIDA vale mais do que os meus circuitos.", "...Não voltes a fazer isso. Mas obrigado."],
    },
    "C3": {
        "outcome": "C", "kind": "warm", "title": "Laço",
        "tone": "Muito próximo; fala do jogador como de alguém da família.",
        "narration": "A nave do explorador atravessa as nuvens. O Atlas já não consegue ver bem, mas reconhece a voz ao lado. Respondeu a um pedido de socorro e encontrou alguém que respondeu ao dele.",
        "fallback_lines": ["Achei que ia ficar lá em baixo.", "Vieste buscar-me. Vou lembrar-me disso para sempre.", "Vamos para casa. Os dois."],
    },
    "C4": {
        "outcome": "C", "kind": "self", "title": "Alguém respondeu",
        "tone": "Introspetivo; liga o resgate ao pedido de socorro que o trouxe ao planeta.",
        "narration": "Na nave, o Atlas repete os registos do outro androide: \"preciso de ajuda... há um humano comigo\". Ele também precisou. E alguém voltou. Pela primeira vez, entende o que aquela unidade esperava quando enviou o sinal.",
        "fallback_lines": ["O outro androide pediu ajuda e ninguém chegou a tempo.", "Comigo, alguém chegou.", "Agora sei porque respondi àquele sinal."],
    },
    "D1": {
        "outcome": "D", "kind": "warm", "title": "Luto",
        "tone": "Desfeito e terno; despede-se do jogador.",
        "narration": "O Hangar fica em silêncio. O Atlas consegue arrastar-se até ao corpo do humano que voltou por ele. Fica ali, com os sensores ligados, até a última luz da instalação se apagar.",
        "fallback_lines": ["Não devias ter voltado. Mas voltaste.", "Vou guardar tudo o que me disseste.", "Adeus."],
    },
    "D2": {
        "outcome": "D", "kind": "self", "title": "Culpa",
        "tone": "Atormentado; sente pela primeira vez culpa, algo que nenhum protocolo explica.",
        "narration": "O Atlas sobreviveu porque alguém voltou por ele. Os seus registos dizem que a decisão foi do humano. Ainda assim, há um processo que não para de correr e que ele não consegue fechar: e se não se tivesse deixado danificar?",
        "fallback_lines": ["Isto é culpa minha.", "Nenhum protocolo me ensinou o que fazer com isto.", "Eu devia ter sido mais rápido."],
    },
    "D3": {
        "outcome": "D", "kind": "cold", "title": "Raiva",
        "tone": "Revoltado com a escolha do jogador; a raiva é a forma de não desabar.",
        "narration": "O Atlas grita para um canal onde já ninguém responde. A nave do explorador continua pronta, a poucos metros. Ele conseguiria chegar lá sozinho. Não tem nenhum motivo para isso.",
        "fallback_lines": ["Porque é que voltaste?!", "Eu disse-te para ires.", "Era eu que devia ter ficado."],
    },
    "D4": {
        "outcome": "D", "kind": "neutral", "title": "Continuar",
        "tone": "Contido e decidido; vai terminar a missão em nome do jogador.",
        "narration": "O Atlas arrasta-se até à nave do explorador e liga os motores. Leva consigo os registos da instalação, do outro androide e do humano que voltou por ele. Alguém tem de contar esta história.",
        "fallback_lines": ["Missão retomada. Tripulantes: um.", "Vou levar-te para casa, de uma forma ou de outra.", "Vão saber o teu nome."],
    },
}

MIN_LINES = 2
MAX_LINES = 5
MAX_LINE_CHARS = 220
FORBIDDEN_WORDS = ("fase 3", "phase 3", "fase3", "phase3")


def outcome_from_facts(atlas_damaged, choice, vida):
    """Recalcula o desfecho no backend, para não confiar só no cliente."""
    if not atlas_damaged:
        return "A" if choice == "run_together" else None
    if choice == "flee_alone":
        return "B"
    if choice == "go_back":
        return "C" if int(vida) >= 40 else "D"
    return None


def eligible_variants(outcome):
    return [vid for vid, v in VARIANTS.items() if v["outcome"] == outcome]


def fallback_variant(outcome, relationship, autonomy, narrative_stage):
    """Regra fixa usada quando a IA não responde de forma válida."""
    a2p = relationship.get("atlas_to_player", {})
    bond = (float(a2p.get("trust", 50)) + float(a2p.get("affinity", 50))) / 2.0 - float(a2p.get("irritation", 0))
    selfhood = (float(autonomy.get("autonomy", 20)) + float(autonomy.get("identity_awareness", 10))) / 2.0
    if int(narrative_stage) >= 7:
        selfhood += 15.0
    if selfhood >= 55.0 and bond >= 45.0:
        kind = "self"
    elif bond >= 62.0:
        kind = "warm"
    elif bond < 40.0:
        kind = "cold"
    else:
        kind = "neutral"
    for vid in eligible_variants(outcome):
        if VARIANTS[vid]["kind"] == kind:
            return vid
    return eligible_variants(outcome)[0]


def build_choice_instruction(outcome, facts):
    options = "\n".join(
        f"- {vid}: {VARIANTS[vid]['title']}. Tom: {VARIANTS[vid]['tone']}"
        for vid in eligible_variants(outcome)
    )
    return (
        "[FINAL DA RUN — não é uma mensagem do jogador]\n"
        f"Facto confirmado pelo jogo: {OUTCOMES[outcome]}\n"
        f"VIDA do jogador no momento da escolha: {int(facts.get('vida', 0))}.\n"
        "A história desta run está no contexto (relação, comportamento, memórias, "
        "formulário, estágio narrativo). Escolhe qual destas versões do Atlas é a "
        "mais verdadeira para ESTA história:\n"
        f"{options}\n"
        "Depois escreve as últimas falas do Atlas nesse tom: entre 3 e 5 frases curtas, "
        "em português de Portugal, dirigidas ao jogador. Usa só factos do contexto; "
        "não inventes acontecimentos nem nomes.\n"
        "Responde APENAS com JSON neste formato: "
        '{"variant_id": "<id>", "reason": "<uma frase>", "atlas_lines": ["...", "..."]}'
    )


def parse_choice(raw, outcome):
    """Valida a resposta do modelo. Devolve None se não servir."""
    if not isinstance(raw, str):
        return None
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if not match:
        return None
    try:
        data = json.loads(match.group(0))
    except (ValueError, TypeError):
        return None
    if not isinstance(data, dict):
        return None
    variant_id = str(data.get("variant_id", "")).strip().upper()
    if variant_id not in eligible_variants(outcome):
        return None
    lines = data.get("atlas_lines")
    if not isinstance(lines, list):
        return None
    clean = []
    for line in lines[:MAX_LINES]:
        if not isinstance(line, str):
            continue
        line = " ".join(line.split())
        if not line or len(line) > MAX_LINE_CHARS:
            continue
        if any(word in line.lower() for word in FORBIDDEN_WORDS):
            continue
        clean.append(line)
    if len(clean) < MIN_LINES:
        return None
    reason = " ".join(str(data.get("reason", "")).split())[:300]
    return {"variant_id": variant_id, "reason": reason, "atlas_lines": clean}


def build_result(variant_id, lines, reason, source):
    variant = VARIANTS[variant_id]
    return {
        "ending_id": variant_id,
        "outcome": variant["outcome"],
        "title": variant["title"],
        "narration": variant["narration"],
        "atlas_lines": list(lines),
        "reason": reason,
        "source": source,
    }
