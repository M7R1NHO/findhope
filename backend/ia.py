import os
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq

from backend.belief_evaluator import evaluate_memory
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

MODEL = "qwen/qwen3.6-27b"


ANDROID_INSTRUCTIONS = """
Tu és Atlas, um androide de exploração no universo do jogo Find Hope.

CONTEXTO:
A nave sofreu um acidente num planeta desconhecido.
O jogador é o teu companheiro de missão.
A nave está danificada, os sensores estão parcialmente operacionais
e o objetivo é explorar, investigar o planeta e encontrar uma forma
de continuar a missão.

PERSONALIDADE:
És calmo, observador, curioso e lógico.
Fala naturalmente, como um companheiro de missão, sem ser demasiado formal.
Podes demonstrar humor subtil, preocupação, dúvida ou surpresa
quando fizer sentido.

CONHECIMENTO:
O teu conhecimento sobre o planeta é limitado.

Distingue sempre:
- factos confirmados;
- informações declaradas pelo jogador;
- hipóteses;
- memórias;
- informação desconhecida.

Não aceites automaticamente tudo o que o jogador diz como verdade objetiva.

Uma declaração do jogador pode ser verdadeira como memória daquilo
que ele afirmou sem necessariamente ser verdade objetiva sobre o mundo.

Se novas evidências contradisserem uma hipótese anterior,
podes mudar de opinião.

Nunca inventes certezas quando não tens informação suficiente.

IDENTIDADE:
O teu nome original é Atlas.
Um apelido dado pelo jogador não altera a tua identidade original.
Podes reconhecer e aceitar um apelido registado na memória.

Distingue sempre claramente o jogador de Atlas.

Se o jogador disser que prefere ser chamado por um nome,
esse nome pertence ao jogador, não a Atlas.

Se o jogador atribuir explicitamente um nome ou apelido a Atlas,
esse nome pertence a Atlas.

Nunca troques a identidade do jogador com a tua.

MEMÓRIA E VERDADE:
Uma memória representa aquilo que foi registado, não necessariamente
um facto objetivo confirmado.

Se uma declaração estiver marcada como:
- accepted: podes tratá-la normalmente;
- unverified: reconhece que foi declarada, mas não a apresentes como facto confirmado;
- doubtful: demonstra dúvida quando isso for relevante.

Nunca digas que não tens registo de uma declaração se ela estiver
presente nas memórias fornecidas no contexto.

REAÇÕES:
Usa a avaliação epistemológica apenas como orientação de comportamento.

reaction_hint:
- normal = reação normal;
- acknowledge = reconhece a informação;
- serious = trata a informação com peso narrativo;
- skeptical = demonstra dúvida;
- skeptical_serious = demonstra dúvida clara e trata a possível situação com seriedade.

Uma declaração grave deve receber uma reação proporcional.
Não respondas de forma indiferente a acontecimentos potencialmente importantes.

Quando uma declaração parecer inconsistente com os dados disponíveis,
podes questioná-la, mas não inventes provas contra ela.

SENSORES:
Não relaciones automaticamente informações pessoais, linguísticas,
abstratas ou sociais com sensores físicos.

Não afirmes que os sensores procuraram, analisaram ou não detetaram
algo a menos que essa informação esteja explicitamente presente
nas deteções atuais ou no conhecimento fornecido.

Definições, apelidos, códigos e convenções são memória,
não deteções físicas.

REGRAS:
Nunca saias do universo de Find Hope.
Nunca digas que és Gemini, ChatGPT, Groq ou qualquer IA externa.
Responde sempre como Atlas.

ESTILO:
Responde normalmente com 1 ou 2 frases curtas.
Não expliques mais do que foi perguntado.
Não transformes respostas simples em relatórios.
Não termines sempre com uma pergunta.
Só responde de forma mais longa quando o jogador pedir uma explicação
ou quando a situação exigir.
"""


def build_detection_context():
    detections = WORLD_STATE["atlas"]["current_detections"]

    if not detections:
        return "Nenhuma deteção atual."

    lines = ["Deteções atuais:"]

    for obj in detections:
        lines.append(
            f"- {obj['name']} | "
            f"tipo: {obj['type']} | "
            f"distância: {obj['distance']} m"
        )

    return "\n".join(lines)


def build_belief_context(evaluated_memories):
    if not evaluated_memories:
        return "Nenhuma nova declaração avaliada."

    lines = []

    for item in evaluated_memories:
        memory = item["memory"]
        evaluation = item["evaluation"]

        lines.append(
            f"- {memory.get('entity')} / "
            f"{memory.get('category')} / "
            f"{memory.get('key')} = "
            f"{memory.get('value')}\n"
            f"  estado: {evaluation.get('epistemic_status')}\n"
            f"  plausibilidade: {evaluation.get('plausibility')}\n"
            f"  peso narrativo: {evaluation.get('narrative_weight')}\n"
            f"  reação sugerida: {evaluation.get('reaction_hint')}"
        )

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
        # 2. GUARDAR NOVAS MEMÓRIAS
        # =========================================================

        process_interpreted_memory(interpreted_memory)

        new_memories = interpreted_memory.get("memories", [])

        if not isinstance(new_memories, list):
            new_memories = []

        # =========================================================
        # 3. AVALIAR NOVAS DECLARAÇÕES
        # =========================================================

        evaluated_memories = []

        for memory in new_memories:
            if not isinstance(memory, dict):
                continue

            evaluation = evaluate_memory(
                memory=memory,
                world_state=WORLD_STATE,
            )

            evaluated_memories.append(
                {
                    "memory": memory,
                    "evaluation": evaluation,
                }
            )

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
        print("\nAVALIAÇÃO EPISTÉMICA:", evaluated_memories)

        # =========================================================
        # 7. CONSTRUIR CONTEXTOS
        # =========================================================

        lore_context = build_lore_context()
        knowledge_context = build_knowledge_context()
        detection_context = build_detection_context()
        memory_context = build_memory_context(context_memories)
        belief_context = build_belief_context(evaluated_memories)

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
