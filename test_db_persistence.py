# Teste de persistência de dados JSONB no PostgreSQL do Supabase
import os
from uuid import uuid4

import psycopg
from dotenv import load_dotenv

load_dotenv()

database_url = os.getenv("DATABASE_URL")

if not database_url:
    raise RuntimeError("DATABASE_URL não encontrada.")

profile_key = f"test-{uuid4()}"
save_name = "Teste de persistência"
test_state = {
    "run_id": str(uuid4()),
    "atlas": {
        "narrative_stage": 2,
        "relationship": {"trust": 0.4},
    },
}

try:
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO public.player_profiles (profile_key)
                VALUES (%s)
                RETURNING id;
                """,
                (profile_key,),
            )
            profile_id = cur.fetchone()[0]

            cur.execute(
                """
                INSERT INTO public.game_saves
                    (profile_id, slot_type, slot_number, save_name, game_state)
                VALUES (%s, 'manual', 1, %s, %s)
                RETURNING id;
                """,
                (profile_id, save_name, psycopg.types.json.Jsonb(test_state)),
            )
            save_id = cur.fetchone()[0]

            cur.execute(
                """
                SELECT game_state
                FROM public.game_saves
                WHERE id = %s;
                """,
                (save_id,),
            )
            loaded_state = cur.fetchone()[0]

            assert loaded_state == test_state, (
                f"Estado diferente: {loaded_state}"
            )

            # Limpar apenas os dados deste teste.
            cur.execute(
                "DELETE FROM public.player_profiles WHERE id = %s;",
                (profile_id,),
            )

    print("SUCESSO: gravação e leitura JSONB confirmadas.")
    print("SUCESSO: dados de teste eliminados.")

except Exception:
    print("ERRO no teste de persistência. Verifica a mensagem abaixo.")
    raise
