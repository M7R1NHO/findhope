"""Persistência de snapshots Find Hope compatível com o schema atual do Supabase.

Usa public.player_profiles(id, profile_key) e public.game_saves(profile_id,
slot_type, slot_number, run_id, game_state, created_at, updated_at).
Não altera nem elimina gravações existentes.
"""
from __future__ import annotations

import json
from typing import Any

from backend.database import get_db_connection


def _validate_profile_key(profile_key: str) -> str:
    key = str(profile_key or "").strip()
    if not 32 <= len(key) <= 128:
        raise ValueError("profile_key tem de ter entre 32 e 128 caracteres.")
    return key


def _validate_slot(slot_type: str, slot_number: int | None) -> tuple[str, int | None]:
    if slot_type not in ("auto", "manual"):
        raise ValueError("slot_type tem de ser 'auto' ou 'manual'.")
    if slot_type == "auto":
        if slot_number not in (None, 0):
            raise ValueError("O autosave não utiliza número de slot.")
        return "auto", None
    if slot_number is None or isinstance(slot_number, bool):
        raise ValueError("Os slots manuais válidos são de 1 a 5.")
    number = int(slot_number)
    if not 1 <= number <= 5:
        raise ValueError("Os slots manuais válidos são de 1 a 5.")
    return "manual", number


def _resolve_profile_id(connection, profile_key: str):
    """Resolve a chave enviada pelo jogo para o UUID de player_profiles."""
    row = connection.execute(
        "SELECT id FROM public.player_profiles WHERE profile_key = %s LIMIT 1",
        (profile_key,),
    ).fetchone()
    if not row:
        raise ValueError(
            "O perfil do jogo não existe em player_profiles. Não foi criado automaticamente "
            "para evitar associar gravações ao perfil errado."
        )
    return row[0] if not isinstance(row, dict) else row["id"]


def save_snapshot(
    profile_key: str,
    slot_type: str,
    slot_number: int | None,
    snapshot: dict[str, Any],
    save_name: str | None = None,
) -> dict[str, Any]:
    key = _validate_profile_key(profile_key)
    slot_type, slot_number = _validate_slot(slot_type, slot_number)
    if not isinstance(snapshot, dict):
        raise ValueError("snapshot tem de ser um objeto JSON.")

    run_data = snapshot.get("run_data") or {}
    run_id = str(run_data.get("run_id") or snapshot.get("run_id") or "unknown")[:255]
    payload = json.dumps(snapshot, ensure_ascii=False)

    with get_db_connection() as connection:
        profile_id = _resolve_profile_id(connection, key)
        # IS NOT DISTINCT FROM permite localizar corretamente o autosave (NULL).
        existing = connection.execute(
            """SELECT id FROM public.game_saves
               WHERE profile_id = %s AND slot_type = %s
                 AND slot_number IS NOT DISTINCT FROM %s
               ORDER BY updated_at DESC LIMIT 1""",
            (profile_id, slot_type, slot_number),
        ).fetchone()

        if existing:
            save_id = existing[0] if not isinstance(existing, dict) else existing["id"]
            row = connection.execute(
                """UPDATE public.game_saves
                   SET run_id = %s, game_state = %s::jsonb, updated_at = NOW()
                   WHERE id = %s
                   RETURNING id, profile_id, slot_type, slot_number, run_id, created_at, updated_at""",
                (run_id, payload, save_id),
            ).fetchone()
        else:
            row = connection.execute(
                """INSERT INTO public.game_saves
                   (profile_id, slot_type, slot_number, run_id, game_state, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s::jsonb, NOW(), NOW())
                   RETURNING id, profile_id, slot_type, slot_number, run_id, created_at, updated_at""",
                (profile_id, slot_type, slot_number, run_id, payload),
            ).fetchone()

    result = dict(row) if isinstance(row, dict) else {
        "id": str(row[0]), "profile_id": str(row[1]), "slot_type": row[2],
        "slot_number": row[3], "run_id": row[4], "created_at": row[5], "updated_at": row[6],
    }
    result["success"] = True
    if save_name:
        result["save_name"] = save_name
    return result


def list_saves(profile_key: str) -> list[dict[str, Any]]:
    key = _validate_profile_key(profile_key)
    with get_db_connection() as connection:
        profile_id = _resolve_profile_id(connection, key)
        rows = connection.execute(
            """SELECT slot_type, slot_number, run_id, created_at, updated_at
               FROM public.game_saves
               WHERE profile_id = %s
               ORDER BY CASE WHEN slot_type = 'auto' THEN 0 ELSE 1 END,
                        slot_number ASC NULLS FIRST""",
            (profile_id,),
        ).fetchall()
    result = []
    for row in rows:
        item = dict(row) if isinstance(row, dict) else {
            "slot_type": row[0], "slot_number": row[1], "run_id": row[2],
            "created_at": row[3], "updated_at": row[4],
        }
        item["save_name"] = "Autosave" if item["slot_type"] == "auto" else f"Slot {item['slot_number']}"
        result.append(item)
    return result


def load_snapshot(profile_key: str, slot_type: str, slot_number: int | None) -> dict[str, Any] | None:
    key = _validate_profile_key(profile_key)
    slot_type, slot_number = _validate_slot(slot_type, slot_number)
    with get_db_connection() as connection:
        profile_id = _resolve_profile_id(connection, key)
        row = connection.execute(
            """SELECT game_state FROM public.game_saves
               WHERE profile_id = %s AND slot_type = %s
                 AND slot_number IS NOT DISTINCT FROM %s
               ORDER BY updated_at DESC LIMIT 1""",
            (profile_id, slot_type, slot_number),
        ).fetchone()
    if not row:
        return None
    value = row[0] if not isinstance(row, dict) else row.get("game_state")
    if isinstance(value, str):
        value = json.loads(value)
    return value if isinstance(value, dict) else None
