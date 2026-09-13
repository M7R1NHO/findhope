import json

from backend.atlas_memory import (
    set_player_info,
    set_atlas_info,
    add_event,
    add_important_moment
)


def interpret_memory(client, model, message: str):
    prompt = f"""
Analisa a mensagem do jogador e decide se existe informação que Atlas deve memorizar.

MENSAGEM:
{message}

Tipos possíveis:

1. player_info
Informação explicitamente sobre o jogador.

Exemplos:
"Meu nome é Guilherme"
"Pode me chamar de Gui"
"Eu gosto de pizza"

2. atlas_info
Informação que o jogador define ou escolhe sobre Atlas.

Exemplos:
"Vou te chamar de Roberto"
"Seu apelido vai ser Roberto"
"Quero te chamar de Rob"
"Prefiro chamar você de Roberto"

3. event
Algo que aconteceu durante a missão.

4. important_moment
Um acontecimento emocional ou narrativamente importante.

4. none
Nada que mereça ser guardado.

REGRAS:
- Não inventes informação.
- Guarda apenas informação explicitamente presente na mensagem.
- Perguntas não são memórias.
- Não transformes suposições em factos.
- Conversa casual normalmente deve ser "none".
- Se houver informação útil, extrai apenas o conteúdo necessário.
- Uma única mensagem pode conter várias informações memoráveis.
- Extrai cada informação separadamente.
- O nome real e a forma preferida de tratamento são informações diferentes.
- Usa "name" para o nome do jogador.
- Usa "preferred_name" para apelidos ou nomes pelos quais o jogador prefere ser chamado.
- Preferências podem usar chaves como "likes_food", "favorite_color", "likes", etc.
- Não guardes palpites, piadas ou deduções como factos.
- Se Atlas ou o jogador estiver apenas a tentar adivinhar algo, não o guardes.
- Distingue cuidadosamente quem é o sujeito da informação.
- "meu", "minha", "eu", "me chamo" normalmente referem-se ao jogador.
- "teu", "seu", "você", "te chamar", quando dirigidos a Atlas, referem-se a Atlas.
- Nunca guardes informação sobre Atlas como player_info.
- Nunca guardes informação sobre o jogador como atlas_info.
- "Meu nome é Guilherme, mas pode me chamar de Gui" gera:
  player_info name = Guilherme
  player_info preferred_name = Gui
- "Seu apelido será Roberto" gera:
  atlas_info preferred_name = Roberto
- O nome canónico de Atlas continua a ser Atlas mesmo que o jogador lhe dê um apelido.

Responde APENAS com JSON válido neste formato:

{{
  "memories": [
    {{
      "type": "player_info | atlas_info | event | important_moment",
      "key": null,
      "value": null,
      "id": null,
      "description": null
    }}
  ]
}}

Se não houver nenhuma memória relevante:

{{
  "memories": []
}}
"""

    try:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": "És um sistema interno de interpretação de memória. Responde apenas com JSON válido."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            reasoning_effort="none",
            temperature=0,
            max_tokens=150
        )

        content = completion.choices[0].message.content

        if not content:
            return None

        return json.loads(content)

    except Exception as e:
        print(f"Erro no Memory Interpreter: {e}")
        return None

def process_interpreted_memory(memory_data):
    if not memory_data:
        return

    memories = memory_data.get("memories", [])

    for memory in memories:
        memory_type = memory.get("type")

        if memory_type == "player_info":
            key = memory.get("key")
            value = memory.get("value")

            if key and value:
                set_player_info(key, value)

        elif memory_type == "event":
            event_id = memory.get("id")
            description = memory.get("description")

            if event_id and description:
                add_event(
                    event_id=event_id,
                    description=description,
                    source="player"
                )

        elif memory_type == "atlas_info":
            key = memory.get("key")
            value = memory.get("value")

            if key and value:
                set_atlas_info(key, value)

        elif memory_type == "important_moment":
            moment_id = memory.get("id")
            description = memory.get("description")

            if moment_id and description:
                add_important_moment(
                    moment_id=moment_id,
                    description=description
                )