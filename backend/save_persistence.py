
from typing import Any

from psycopg.types.json import Jsonb

from backend.database import get_db_connection


def _validate_profile_key(profile_key: str) -> str:
    key = profile_key.strip()

    if len(key) < 32 or len(key) > 128:
        raise ValueError("A chave do perfil deve ter entre 32 e 128 caracteres.")

    return key


def _validate_slot(slot_type: str, slot_number: int | None) -> None:
    if slot_type == "auto":
        if slot_number is not None:
            raise ValueError("O autosave não deve ter número de slot.")
    elif slot_type == "manual":
        if slot_number is None or not 1 <= slot_number <= 5:
            raise ValueError("O slot manual deve estar entre 1 e 5.")
    else:
        raise ValueError("Tipo de save inválido.")


def _get_or_create_profile(cursor, profile_key: str):
    cursor.execute(
        """
        INSERT INTO public.player_profiles (profile_key)
        VALUES (%s)
        ON CONFLICT (profile_key)
        DO UPDATE SET updated_at = NOW()
        RETURNING id;
        """,
        (profile_key,),
    )

    result = cursor.fetchone()

    if result is None:
        raise RuntimeError("Não foi possível obter o perfil.")

    return result[0]


def save_snapshot(
    profile_key: str,
    slot_type: str,
    slot_number: int | None,
    snapshot: dict[str, Any],
    save_name: str | None = None,
) -> dict[str, Any]:
    profile_key = _validate_profile_key(profile_key)
    _validate_slot(slot_type, slot_number)

    if not isinstance(snapshot, dict):
        raise ValueError("O snapshot tem de ser um objeto JSON.")

    run_data = snapshot.get("run_data", {})
    run_id = run_data.get("run_id") if isinstance(run_data, dict) else None

    if not isinstance(run_id, str) or not run_id.strip():
        run_id = "unknown"

    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            profile_id = _get_or_create_profile(cursor, profile_key)

            if slot_type == "auto":
                cursor.execute(
                    """
                    INSERT INTO public.game_saves (
                        profile_id,
                        slot_type,
                        slot_number,
                        run_id,
                        save_name,
                        game_state,
                        updated_at
                    )
                    VALUES (%s, 'auto', NULL, %s, %s, %s, NOW())
                    ON CONFLICT (profile_id)
                    WHERE slot_type = 'auto'
                    DO UPDATE SET
                        run_id = EXCLUDED.run_id,
                        save_name = EXCLUDED.save_name,
                        game_state = EXCLUDED.game_state,
                        updated_at = NOW()
                    RETURNING id, updated_at;
                    """,
                    (
                        profile_id,
                        run_id,
                        save_name,
                        Jsonb(snapshot),
                    ),
                )
            else:
                cursor.execute(
                    """
                    INSERT INTO public.game_saves (
                        profile_id,
                        slot_type,
                        slot_number,
                        run_id,
                        save_name,
                        game_state,
                        updated_at
                    )
                    VALUES (%s, 'manual', %s, %s, %s, %s, NOW())
                    ON CONFLICT (profile_id, slot_type, slot_number)
                    DO UPDATE SET
                        run_id = EXCLUDED.run_id,
                        save_name = EXCLUDED.save_name,
                        game_state = EXCLUDED.game_state,
                        updated_at = NOW()
                    RETURNING id, updated_at;
                    """,
                    (
                        profile_id,
                        slot_number,
                        run_id,
                        save_name,
                        Jsonb(snapshot),
                    ),
                )

            row = cursor.fetchone()

            if row is None:
                raise RuntimeError("Não foi possível guardar o save.")

            return {
                "success": True,
                "save_id": str(row[0]),
                "slot_type": slot_type,
                "slot_number": slot_number,
                "updated_at": row[1].isoformat(),
            }


def load_snapshot(
    profile_key: str,
    slot_type: str,
    slot_number: int | None,
) -> dict[str, Any] | None:
    profile_key = _validate_profile_key(profile_key)
    _validate_slot(slot_type, slot_number)

    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            if slot_type == "auto":
                cursor.execute(
                    """
                    SELECT gs.game_state
                    FROM public.game_saves AS gs
                    JOIN public.player_profiles AS pp
                      ON pp.id = gs.profile_id
                    WHERE pp.profile_key = %s
                      AND gs.slot_type = 'auto'
                    LIMIT 1;
                    """,
                    (profile_key,),
                )
            else:
                cursor.execute(
                    """
                    SELECT gs.game_state
                    FROM public.game_saves AS gs
                    JOIN public.player_profiles AS pp
                      ON pp.id = gs.profile_id
                    WHERE pp.profile_key = %s
                      AND gs.slot_type = 'manual'
                      AND gs.slot_number = %s
                    LIMIT 1;
                    """,
                    (profile_key, slot_number),
                )

            row = cursor.fetchone()

            if row is None:
                return None

            return row[0]


def list_saves(profile_key: str) -> list[dict[str, Any]]:
    profile_key = _validate_profile_key(profile_key)

    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    gs.slot_type,
                    gs.slot_number,
                    gs.save_name,
                    gs.run_id,
                    gs.created_at,
                    gs.updated_at
                FROM public.game_saves AS gs
                JOIN public.player_profiles AS pp
                  ON pp.id = gs.profile_id
                WHERE pp.profile_key = %s
                ORDER BY
                    CASE WHEN gs.slot_type = 'auto' THEN 0 ELSE 1 END,
                    gs.slot_number;
                """,
                (profile_key,),
            )

            rows = cursor.fetchall()

            return [
                {
                    "slot_type": row[0],
                    "slot_number": row[1],
                    "save_name": row[2],
                    "run_id": row[3],
                    "created_at": row[4].isoformat(),
                    "updated_at": row[5].isoformat(),
                }
                for row in rows
            ]
