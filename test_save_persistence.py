
import uuid

from backend.save_persistence import (
    list_saves,
    load_snapshot,
    save_snapshot,
)
from backend.database import get_db_connection


def main():
    profile_key = str(uuid.uuid4())

    snapshot = {
        "save_version": 1,
        "save_type": "manual",
        "slot": 1,
        "run_data": {
            "run_id": "teste-find-hope-123",
            "story": {"checkpoint": "teste"},
        },
        "atlas_backend_state": {
            "narrative": {"stage": 2},
            "memory": {"items": ["teste"]},
        },
    }

    try:
        result = save_snapshot(
            profile_key=profile_key,
            slot_type="manual",
            slot_number=1,
            snapshot=snapshot,
            save_name="Teste de persistência",
        )

        print("Gravação:", result)

        loaded = load_snapshot(
            profile_key=profile_key,
            slot_type="manual",
            slot_number=1,
        )

        assert loaded == snapshot, "O snapshot recuperado é diferente!"

        print("SUCESSO: snapshot guardado e recuperado corretamente.")
        print("Lista de saves:", list_saves(profile_key))

    finally:
        # Limpa apenas os dados temporários deste teste.
        with get_db_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    DELETE FROM public.player_profiles
                    WHERE profile_key = %s;
                    """,
                    (profile_key,),
                )

        print("Dados temporários eliminados.")


if __name__ == "__main__":
    main()

