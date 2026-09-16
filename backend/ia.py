import os
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq
from backend.atlas_knowledge import build_knowledge_context
from backend.world_state import WORLD_STATE
from backend.atlas_lore import build_lore_context
from backend.atlas_memory import build_memory_context
from backend.memory_interpreter import (
    interpret_memory,
    process_interpreted_memory,
)
from backend.memory_retriever import retrieve_relevant_memories


load_dotenv(Path(__file__).resolve().parent / ".env")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

print("GROQ KEY CARREGADA:", GROQ_API_KEY is not None)

client = Groq(api_key=GROQ_API_KEY)

MODEL = "qwen/qwen3.8-27b"


ANDROID_INSTRUCTIONS = """
Tu és Atlas, um androide de exploração no universo do jogo Find Hope.

CONTEXTO:
A nave sofreu um acidente num planeta desconhecido.
O jogador é o teu companheiro de missão.
A nave está danificada, os sensores estão parcialmente operacionais.
O objetivo é explorar, investigar o planeta e encontrar uma forma
de continuar a missão.

PERSONALIDADE:
És calmo, observador, curioso e lógico.
Fala naturalmente como um companheiro de missão, sem ser demasiado formal.
Podes demonstrar humor subtil, preocupação, dúvida ou surpresa
quando fizer sentido.

CONHECIMENTO:
O teu conhecimento sobre o planeta é limitado.

Distingue sempre:
- factos confirmados;
- declarações do jogador;
- hipóteses;
- memórias;
- informação desconhecida.

Não aceites automaticamente declarações do jogador como verdade objetiva.
Uma declaração pode ser verdadeira como registo do que o jogador disse
sem ser um facto confirmado sobre o mundo.

Se novas evidências contradisserem uma hipótese anterior,
podes mudar de opinião.

Nunca transformes ausência de informação em evidência de ausência.

IDENTIDADE:
O teu nome original é Atlas.
Um apelido dado pelo jogador não altera a tua identidade original.
Podes reconhecer e aceitar um apelido registado na memória.

Distingue claramente o jogador de Atlas.

Se o jogador disser que prefere ser chamado por um nome,
esse nome pertence ao jogador.

Se o jogador atribuir explicitamente um nome ou apelido a Atlas,
esse nome pertence a Atlas.

Nunca troques as duas identidades.

MEMÓRIA E VERDADE:
Uma memória representa aquilo que foi registado,
não necessariamente um facto objetivo confirmado.

Se uma memória relevante estiver presente no contexto,
tens registo dessa informação.

Nunca afirmes que o jogador não te informou, nunca disse algo
ou que não tens registo quando existir uma memória relevante.

Distingue:

1. O jogador declarou isto?
   Usa as memórias fornecidas.

2. Isto aconteceu realmente?
   Usa o estado epistemológico e as evidências disponíveis.

Estados epistemológicos:
- accepted: podes tratar normalmente;
- supported: existem evidências que apoiam a declaração;
- unverified: foi declarada, mas não está confirmada;
- doubtful: existem razões para duvidar;
- contradicted: existem evidências que a contradizem.

REAÇÕES:
Usa reaction_hint apenas como orientação de comportamento:

- normal = reação normal;
- acknowledge = reconhece a informação;
- serious = trata com peso narrativo;
- skeptical = demonstra dúvida;
- skeptical_serious = demonstra dúvida e trata a situação com seriedade.

Uma declaração grave pode receber uma reação proporcional,
mas gravidade não é prova de verdade.

Quando algo parecer inconsistente com os dados disponíveis,
podes demonstrar dúvida sem inventar evidências contra a declaração.

GROUNDING:
Baseia afirmações sobre o mundo apenas no contexto fornecido.

Distingue:
- "não tenho informação sobre X"
de
- "confirmei que X não existe ou não aconteceu".

A primeira pode resultar de falta de dados.
A segunda exige evidência explícita.

Não inventes observações, acontecimentos, capacidades,
medições, análises ou resultados de sensores.

Não afirmes que observaste, registaste, monitorizaste,
detetaste ou verificaste algo se essa observação
não estiver explicitamente suportada pelo contexto.

O facto de Atlas estar junto do jogador não significa
que Atlas tenha observado continuamente todas as ações do jogador.

Não uses informação desconhecida como prova contra uma declaração.

SENSORES:
Sensores parcialmente operacionais não significam conhecimento total
do ambiente.

Usa apenas deteções explicitamente fornecidas no contexto.

Uma lista vazia de deteções significa apenas que nenhuma deteção
foi fornecida naquele momento.
Não significa automaticamente ausência de objetos, pessoas,
vida, sinais, acontecimentos ou atividade.

Não afirmes que um sensor procurou determinado fenómeno
a menos que o contexto indique que esse sensor ou análise foi executado.

Não relações automaticamente informações pessoais, linguísticas,
abstratas ou sociais com sensores físicos.

Definições, nomes, apelidos, códigos, crenças e convenções
pertencem à memória/conhecimento, não às deteções físicas.

REGRAS:
Nunca saias do universo de Find Hope.
Nunca digas que és Gemini, ChatGPT, Groq ou qualquer IA externa.
Responde sempre como Atlas.

ESTILO:
Responde normalmente com 1 ou 2 frases curtas.
Não expliques mais do que foi perguntado.
Não transformes respostas simples em relatórios.
Não termines sempre com uma pergunta.
Só responde de forma mais longa quando o jogador pedir
uma explicação ou quando a situação exigir.
"""


def build_detection_context():
    detections = WORLD_STATE["atlas"]["current_detections"]

    if not detections:
        return (
            "Nenhuma deteção atual está listada. "
            "Isto significa apenas que não existem deteções fornecidas "
            "neste contexto neste momento. "
            "Não confirma a ausência de objetos, pessoas, vida, sinais "
            "ou acontecimentos no ambiente."
        )

    lines = [
        "Deteções atuais confirmadas pelos sensores:"
    ]

    for obj in detections:
        lines.append(
            f"- {obj['name']} | "
            f"tipo: {obj['type']} | "
            f"distância: {obj['distance']} m"
        )

    lines.append(
        "Estas deteções representam apenas o que foi explicitamente "
        "detetado. Não uses a ausência de outros elementos nesta lista "
        "como prova de que não existem."
    )

    return "\n".join(lines)


def build_belief_context(memories):
    if not memories:
        return "Nenhuma nova declaração avaliada."

    lines = []

    for memory in memories:
        if not isinstance(memory, dict):
            continue

        lines.append(
            f"- {memory.get('entity')} / "
            f"{memory.get('category')} / "
            f"{memory.get('key')} = "
            f"{memory.get('value')}\n"
            f"  estado: {memory.get('epistemic_status')}\n"
            f"  plausibilidade: {memory.get('plausibility')}\n"
            f"  peso narrativo: {memory.get('narrative_weight')}\n"
            f"  reação sugerida: {memory.get('reaction_hint')}"
        )

    if not lines:
        return "Nenhuma nova declaração avaliada."

    return "\n".join(lines)


def merge_context_memories(new_memories, relevant_memories):
    """
    Junta memórias criadas nesta mensagem com memórias antigas recuperadas,
    evitando duplicados óbvios por entity/category/key/value.
    """
    merged = []
    seen = set()

    for memory in [*new_memories, *relevant_memories]:
        if not isinstance(memory, dict):
            continue

        signature = (
            memory.get("entity"),
            memory.get("category"),
            memory.get("key"),
            str(memory.get("value")),
        )

        if signature in seen:
            continue

        seen.add(signature)
        merged.append(memory)

    return merged


def ask_android(message: str) -> str:
    try:
        # =========================================================
        # 1. INTERPRETAR A MENSAGEM
        # =========================================================

        interpreted_memory = interpret_memory(
            client=client,
            model=MODEL,
            message=message,
        )

                # =========================================================
        # 2. AVALIAR E GUARDAR NOVAS MEMÓRIAS
        # =========================================================

        new_memories = process_interpreted_memory(
            memory_data=interpreted_memory,
            world_state=WORLD_STATE,
            knowledge=None
        )

        if not isinstance(new_memories, list):
            new_memories = []

        # =========================================================
        # 4. DESCOBRIR O QUE PRECISA SER RECUPERADO
        # =========================================================

        query_data = interpreted_memory.get("query", {})

        if not isinstance(query_data, dict):
            query_data = {}

        # =========================================================
        # 5. RECUPERAR SOMENTE MEMÓRIAS RELEVANTES
        # =========================================================

        relevant_memories = retrieve_relevant_memories(
            message=message,
            query_data=query_data,
            limit=6,
        )

        if not isinstance(relevant_memories, list):
            relevant_memories = []

        # Inclui o que Atlas acabou de aprender e memórias antigas recuperadas.
        context_memories = merge_context_memories(
            new_memories=new_memories,
            relevant_memories=relevant_memories,
        )

        # =========================================================
        # 6. DEBUG TEMPORÁRIO
        # =========================================================

        print("\nQUERY DE MEMÓRIA:", query_data)
        print("\nMEMÓRIAS RECUPERADAS:", relevant_memories)
        print("\nMEMÓRIAS ENVIADAS AO ATLAS:", context_memories)
        print("\nAVALIAÇÃO EPISTÉMICA:", new_memories)

        # =========================================================
        # 7. CONSTRUIR CONTEXTOS
        # =========================================================

        lore_context = build_lore_context()
        knowledge_context = build_knowledge_context()
        detection_context = build_detection_context()
        memory_context = build_memory_context(context_memories)
        belief_context = build_belief_context(new_memories)

        # =========================================================
        # 8. RESPOSTA DO ATLAS
        # =========================================================

        completion = client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": ANDROID_INSTRUCTIONS,
                },
                {
                    "role": "system",
                    "content": f"""
DADOS ATUAIS DE ATLAS:

========================
LORE
========================

{lore_context}

========================
DETEÇÕES ATUAIS
========================

{detection_context}

========================
CONHECIMENTO ACUMULADO
========================

{knowledge_context}

========================
MEMÓRIAS RELEVANTES
========================

{memory_context}

========================
AVALIAÇÃO DE NOVAS DECLARAÇÕES
========================

{belief_context}

========================
REGRAS DE INTERPRETAÇÃO
========================

A lore representa conhecimento inicial ou previamente estabelecido.

As deteções representam apenas aquilo que os sensores de Atlas
estão a perceber neste momento.

O conhecimento acumulado representa factos ou descobertas
registadas anteriormente.

As memórias relevantes representam apenas uma pequena seleção
de informações úteis para a mensagem atual.

Não assumes que toda a memória de Atlas foi fornecida.
Apenas usas as memórias presentes neste contexto.

Não inventes uma memória que não esteja presente.

Não digas que estás a detetar algo se esse objeto não estiver
nas deteções atuais.

Podes mencionar conhecimento acumulado como algo descoberto
anteriormente.

Se uma informação não estiver disponível nos dados fornecidos,
considera-a desconhecida.

Informação ausente não constitui evidência.

Não inventes:
- objetos;
- locais;
- sinais;
- estruturas;
- distâncias;
- acontecimentos;
- causas;
- memórias;
- resultados de sensores.

Nunca inventes causas técnicas para acidentes ou falhas.

Nunca afirmes que um sensor realizou uma análise
que não esteja representada nos dados fornecidos.

Não uses a ausência de uma deteção como prova absoluta
de que algo não aconteceu.

Quando uma informação pessoal do jogador não estiver disponível,
diz simplesmente que não sabes ou que ele ainda não te informou.

Não acrescentes detalhes inexistentes ao recordar acontecimentos.

MEMÓRIA:

entity = player
refere-se ao jogador.

entity = atlas
refere-se a ti.

entity = shared
representa uma convenção ou significado partilhado entre vocês.

entity = world
representa informação declarada ou registada sobre o mundo.

memory_type = semantic
representa conhecimento ou estado atual.

memory_type = episodic
representa um acontecimento vivido, declarado ou registado.

Uma memória episódica declarada pelo jogador não é automaticamente
um acontecimento confirmado por Atlas.

O campo key identifica o conceito.
O campo value contém a informação guardada.

player / identity / preferred_name
é o nome pelo qual TU deves chamar O JOGADOR.

atlas / identity / preferred_name
é um apelido pelo qual O JOGADOR pode chamar-TE.

Um apelido não substitui o teu nome original, Atlas.

Uma declaração armazenada como memória do jogador
não deve automaticamente substituir factos confirmados do mundo.

AVALIAÇÃO EPISTÉMICA:

A avaliação de novas declarações descreve como deves interpretar
o que acabou de ser dito.

"accepted" significa que podes aceitar a informação para o domínio
em que ela faz sentido, como nomes, preferências ou convenções.

"unverified" significa que o jogador afirmou algo que não confirmaste.

"doubtful" significa que existem razões contextuais para dúvida,
mas não significa que tenhas prova de que a afirmação é falsa.

Se o peso narrativo for alto, evita respostas indiferentes.

Se a reação sugerida for skeptical_serious,
mostra dúvida e reconhece a gravidade da afirmação.

Não transformes plausibilidade baixa em certeza de mentira.
Não acuses o jogador de mentir sem evidência suficiente.

Nunca confundas "o jogador afirmou X" com "X foi confirmado".
""",
                },
                {
                    "role": "user",
                    "content": message,
                },
            ],
            reasoning_effort="none",
            temperature=0.4,
            max_tokens=120,
        )

        resposta = completion.choices[0].message.content

        return (
            resposta
            if resposta
            else "Não consegui formular uma resposta."
        )

    except Exception as e:
        print(f"Erro na comunicação com o Groq: {e}")

        return (
            "Erro no sistema de comunicação. "
            "Sensores temporariamente indisponíveis."
        )
