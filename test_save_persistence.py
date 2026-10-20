
import uuid

from backend.save_persistence import (
    list_saves,
    load_snapshot,
    save_snapshot,
)
from backend.database import get_db_connection


def main():
    # Usa um perfil isolado de teste. O primeiro save também consegue registar
    # uma chave nova quando o perfil ainda não existe.
    profile_key = str(uuid.uuid4())
    profile_id = uuid.uuid4()

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
        with get_db_connection() as connection:
            connection.execute(
                "INSERT INTO public.player_profiles (id, profile_key) VALUES (%s, %s)",
                (profile_id, profile_key),
            )

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

        expected = dict(snapshot, run_id="teste-find-hope-123", snapshot_version=2)
        assert loaded == expected, "O snapshot recuperado é diferente!"

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

