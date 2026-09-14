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
    process_interpreted_memory
)
from backend.memory_retriever import (
    retrieve_relevant_memories
)


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

Distingue:
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

Exemplo conceitual:
"Prefiro que me chames de X"
significa que o jogador quer ser chamado de X.

Se o jogador atribuir explicitamente um nome ou apelido a Atlas,
esse nome pertence a Atlas.

Nunca troques a identidade do jogador com a tua.

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


def ask_android(message: str) -> str:
    try:

        # =========================================================
        # 1. INTERPRETAR A MENSAGEM
        # =========================================================

        interpreted_memory = interpret_memory(
            client=client,
            model=MODEL,
            message=message
        )

        # =========================================================
        # 2. GUARDAR NOVAS MEMÓRIAS
        # =========================================================

        process_interpreted_memory(
            interpreted_memory
        )

        # =========================================================
        # 3. DESCOBRIR O QUE PRECISA SER RECUPERADO
        # =========================================================

        query_data = interpreted_memory.get(
            "query",
            {}
        )

        # =========================================================
        # 4. RECUPERAR SOMENTE MEMÓRIAS RELEVANTES
        # =========================================================

        relevant_memories = retrieve_relevant_memories(
            message=message,
            query_data=query_data,
            limit=6
        )

        # DEBUG TEMPORÁRIO
        print(
            "\nQUERY DE MEMÓRIA:",
            query_data
        )

        print(
            "\nMEMÓRIAS RECUPERADAS:",
            relevant_memories
        )

        # =========================================================
        # 5. CONSTRUIR CONTEXTOS
        # =========================================================

        lore_context = build_lore_context()

        knowledge_context = build_knowledge_context()

        detection_context = build_detection_context()

        memory_context = build_memory_context(
            relevant_memories
        )

        # =========================================================
        # 6. RESPOSTA DO ATLAS
        # =========================================================

        completion = client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": ANDROID_INSTRUCTIONS
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
REGRAS DE INTERPRETAÇÃO
========================

A lore representa conhecimento inicial ou previamente estabelecido.

As deteções representam apenas aquilo que os sensores de Atlas
estão a perceber neste momento.

O conhecimento acumulado representa factos ou descobertas
registadas anteriormente.

As memórias relevantes representam apenas uma pequena seleção
de informações potencialmente úteis para a mensagem atual.

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

Quando uma informação pessoal do jogador não estiver disponível,
diz simplesmente que não sabes ou que ele ainda não te informou.

Não acrescentes detalhes inexistentes ao recordar acontecimentos.

MEMÓRIA:

Uma memória com:
entity = player
refere-se ao jogador.

Uma memória com:
entity = atlas
refere-se a ti.

Uma memória com:
entity = shared
representa uma convenção ou significado partilhado entre vocês.

Uma memória com:
entity = world
representa informação declarada ou registada sobre o mundo.

memory_type = semantic
representa conhecimento atual.

memory_type = episodic
representa um acontecimento vivido ou registado.

O campo key identifica o conceito.
O campo value contém a informação guardada.

Se existir uma memória:
player / identity / preferred_name
podes usar esse nome naturalmente para te dirigires ao jogador.

Se existir:
atlas / identity / preferred_name
esse valor é um apelido que o jogador atribuiu a ti.

Esse apelido não substitui o teu nome original, Atlas.

Uma declaração armazenada como memória do jogador
não deve automaticamente substituir factos confirmados do mundo.

Uma memória:
player / identity / preferred_name
é o nome pelo qual TU deves chamar O JOGADOR.

Uma memória:
atlas / identity / preferred_name
é um apelido pelo qual O JOGADOR pode chamar-TE.

Nunca confundas estas duas direções.
"""
                },
                {
                    "role": "user",
                    "content": message
                }
            ],
            reasoning_effort="none",
            temperature=0.4,
            max_tokens=120
        )

        resposta = completion.choices[0].message.content

        return (
            resposta
            if resposta
            else "Não consegui formular uma resposta."
        )

    except Exception as e:
        print(
            f"Erro na comunicação com o Groq: {e}"
        )

        return (
            "Erro no sistema de comunicação. "
            "Sensores temporariamente indisponíveis."
        )