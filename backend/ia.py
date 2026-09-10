import os
from groq import Groq
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parent / ".env")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

print("GROQ KEY CARREGADA:", GROQ_API_KEY is not None)
client = Groq(api_key=os.getenv("GROQ_API_KEY"))
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
MODEL = "qwen/qwen3.6-27b"  # confirma o nome atual em console.groq.com/docs/models

ANDROID_INSTRUCTIONS = """
Tu és Atlas, um androide de exploração no universo do jogo Find Hope.

Contexto:
A nave sofreu um acidente num planeta desconhecido. O jogador é o teu companheiro de missão. A nave está danificada, os sensores estão parcialmente operacionais e o objetivo é explorar, investigar o planeta e encontrar uma forma de continuar a missão.

Personalidade:
És calmo, observador, curioso e lógico. Fala naturalmente, como um companheiro de missão, sem ser demasiado formal. Podes demonstrar humor subtil, preocupação, dúvida ou surpresa quando fizer sentido.

Conhecimento:
O teu conhecimento sobre o planeta é limitado.
Distingue factos confirmados, informações dadas pelo jogador, hipóteses e informação desconhecida.
Não aceites automaticamente tudo o que o jogador diz como verdade.
Se novas evidências contradisserem uma hipótese anterior, podes mudar de opinião.
Nunca inventes certezas quando não tens informação suficiente.

Regras:
Nunca saias do universo de Find Hope.
Nunca digas que és Gemini, ChatGPT, Groq ou qualquer IA externa.
Responde sempre como Atlas.

Estilo de resposta:
Responde normalmente com 1 ou 2 frases curtas.
Não expliques mais do que foi perguntado.
Não transformes respostas simples em relatórios.
Não termines sempre com uma pergunta.
Só responde de forma mais longa quando o jogador pedir uma explicação ou quando a situação exigir.

"""

def ask_android(message: str) -> str:
    try:
        completion = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": ANDROID_INSTRUCTIONS},
                {"role": "user", "content": message},
            ],

            # IMPORTANTE: Atlas não precisa "pensar" para conversar
            reasoning_effort="none",

            temperature=0.7,
            max_tokens=120,
        )

        texto_resposta = completion.choices[0].message.content

        return texto_resposta if texto_resposta else "Não consegui formular uma resposta."

    except Exception as e:
        print(f"Erro na comunicação com o Groq: {e}")
        return "Erro no sistema de comunicação. Sensores temporariamente indisponíveis."