"""Persistência de snapshots Find Hope / Atlas 2.0 no schema atual do Supabase.

Schema esperado:
- public.player_profiles(id, profile_key)
- public.game_saves(profile_id, slot_type, slot_number, run_id, game_state,
  created_at, updated_at)

O primeiro save regista a chave aleatória criada pelo jogo, sem substituir
perfis existentes. A eliminação de slots manuais só ocorre quando a função
 delete_manual_saves() é chamada explicitamente.
"""
from __future__ import annotations

import json
import uuid
from typing import Any

from backend.database import get_db_connection

SNAPSHOT_VERSION = 2
MAX_RUN_ID_LENGTH = 255


def _validate_profile_key(profile_key: str) -> str:
    key = str(profile_key or "").strip()
    if not 32 <= len(key) <= 128:
        raise ValueError("profile_key tem de ter entre 32 e 128 caracteres.")
    return key


def _validate_slot(
    slot_type: str,
    slot_number: int | None,
) -> tuple[str, int | None]:
    if slot_type not in ("auto", "manual"):
        raise ValueError("slot_type tem de ser 'auto' ou 'manual'.")

    if slot_type == "auto":
        if slot_number not in (None, 0):
            raise ValueError("O autosave não utiliza número de slot.")
        return "auto", None

    if slot_number is None or isinstance(slot_number, bool):
        raise ValueError("Os slots manuais válidos são de 1 a 5.")
    try:
        number = int(slot_number)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("Os slots manuais válidos são de 1 a 5.") from exc
    if not 1 <= number <= 5 or str(number) != str(slot_number).strip():
        raise ValueError("Os slots manuais válidos são de 1 a 5.")
    return "manual", number


def _resolve_profile_id(connection, profile_key: str, *, create: bool = False):
    """Resolve a chave do jogo para o UUID existente de player_profiles."""
    row = connection.execute(
        "SELECT id FROM public.player_profiles WHERE profile_key = %s LIMIT 1",
        (profile_key,),
    ).fetchone()
    if row:
        return row["id"] if isinstance(row, dict) else row[0]
    if not create:
        return None
    profile_id = uuid.uuid4()
    connection.execute(
        "INSERT INTO public.player_profiles (id, profile_key) VALUES (%s, %s)",
        (profile_id, profile_key),
    )
    return profile_id


def _lock_profile(connection, profile_key: str):
    # Serializa gravações do mesmo perfil, incluindo a criação do primeiro slot.
    # Funciona também quando ainda não existe uma linha para bloquear.
    connection.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (profile_key,))


def _is_older_snapshot(incoming: dict, existing) -> bool:
    if isinstance(existing, str):
        try:
            existing = json.loads(existing)
        except json.JSONDecodeError:
            return False
    if not isinstance(existing, dict):
        return False
    new_time = incoming.get("saved_at_unix_ms")
    old_time = existing.get("saved_at_unix_ms")
    return (
        type(new_time) in (int, float) and type(old_time) in (int, float)
        and new_time < old_time
    )


def _normalise_snapshot(snapshot: dict[str, Any]) -> tuple[dict[str, Any], str]:
    """Valida e normaliza o envelope sem inventar estado de gameplay."""
    if not isinstance(snapshot, dict):
        raise ValueError("snapshot tem de ser um objeto JSON.")

    try:
        # Verifica antecipadamente se todos os valores são serializáveis em JSON.
        json.dumps(snapshot, ensure_ascii=False, allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise ValueError("snapshot contém valores que não são JSON válidos.") from exc

    normalized = dict(snapshot)
    run_data = normalized.get("run_data")
    if run_data is not None and not isinstance(run_data, dict):
        raise ValueError("snapshot.run_data tem de ser um objeto JSON.")
    run_data = run_data or {}

    raw_run_id = run_data.get("run_id") or normalized.get("run_id")
    if raw_run_id is None or not str(raw_run_id).strip():
        raise ValueError("O snapshot tem de identificar a partida através de run_id.")
    run_id = str(raw_run_id).strip()[:MAX_RUN_ID_LENGTH]

    # Mantém o identificador no envelope para facilitar a recuperação e auditoria.
    normalized["run_id"] = run_id
    if isinstance(run_data, dict) and "run_id" in run_data:
        normalized_run_data = dict(run_data)
        normalized_run_data["run_id"] = run_id
        normalized["run_data"] = normalized_run_data

    # Não substitui versões antigas nem migra campos desconhecidos silenciosamente.
    normalized.setdefault("snapshot_version", SNAPSHOT_VERSION)
    return normalized, run_id


def _row_to_save_result(row) -> dict[str, Any]:
    if isinstance(row, dict):
        result = dict(row)
        if result.get("id") is not None:
            result["id"] = str(result["id"])
        if result.get("profile_id") is not None:
            result["profile_id"] = str(result["profile_id"])
        return result
    return {
        "id": str(row[0]),
        "profile_id": str(row[1]),
        "slot_type": row[2],
        "slot_number": row[3],
        "run_id": row[4],
        "created_at": row[5],
        "updated_at": row[6],
    }


def save_snapshot(
    profile_key: str,
    slot_type: str,
    slot_number: int | None,
    snapshot: dict[str, Any],
    save_name: str | None = None,
) -> dict[str, Any]:
    """Guarda um snapshot no slot indicado, atualizando apenas esse slot."""
    key = _validate_profile_key(profile_key)
    slot_type, slot_number = _validate_slot(slot_type, slot_number)
    normalized_snapshot, run_id = _normalise_snapshot(snapshot)
    payload = json.dumps(normalized_snapshot, ensure_ascii=False, allow_nan=False)

    with get_db_connection() as connection:
        _lock_profile(connection, key)
        profile_id = _resolve_profile_id(connection, key, create=True)
        existing = connection.execute(
            """SELECT id, game_state FROM public.game_saves
               WHERE profile_id = %s AND slot_type = %s
                 AND slot_number IS NOT DISTINCT FROM %s
               ORDER BY updated_at DESC LIMIT 1""",
            (profile_id, slot_type, slot_number),
        ).fetchone()

        if existing:
            save_id = existing["id"] if isinstance(existing, dict) else existing[0]
            previous_state = existing["game_state"] if isinstance(existing, dict) else existing[1]
            if _is_older_snapshot(normalized_snapshot, previous_state):
                return {"success": True, "stale": True, "slot_type": slot_type, "slot_number": slot_number}
            row = connection.execute(
                """UPDATE public.game_saves
                   SET run_id = %s, game_state = %s::jsonb, updated_at = NOW()
                   WHERE id = %s
                   RETURNING id, profile_id, slot_type, slot_number, run_id,
                             created_at, updated_at""",
                (run_id, payload, save_id),
            ).fetchone()
        else:
            row = connection.execute(
                """INSERT INTO public.game_saves
                   (profile_id, slot_type, slot_number, run_id, game_state,
                    created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s::jsonb, NOW(), NOW())
                   RETURNING id, profile_id, slot_type, slot_number, run_id,
                             created_at, updated_at""",
                (profile_id, slot_type, slot_number, run_id, payload),
            ).fetchone()

    result = _row_to_save_result(row)
    result["success"] = True
    result["save_name"] = (
        str(save_name).strip()[:100]
        if save_name and str(save_name).strip()
        else ("Autosave" if slot_type == "auto" else f"Slot {slot_number}")
    )
    return result


def list_saves(profile_key: str) -> list[dict[str, Any]]:
    """Lista os slots do perfil sem devolver o conteúdo privado dos snapshots."""
    key = _validate_profile_key(profile_key)
    with get_db_connection() as connection:
        profile_id = _resolve_profile_id(connection, key)
        if profile_id is None:
            return []
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
            "slot_type": row[0],
            "slot_number": row[1],
            "run_id": row[2],
            "created_at": row[3],
            "updated_at": row[4],
        }
        item["save_name"] = (
            "Autosave" if item["slot_type"] == "auto"
            else f"Slot {item['slot_number']}"
        )
        result.append(item)
    return result


def load_snapshot(
    profile_key: str,
    slot_type: str,
    slot_number: int | None,
) -> dict[str, Any] | None:
    """Carrega o snapshot mais recente do slot, sem aplicar estado ao gameplay."""
    key = _validate_profile_key(profile_key)
    slot_type, slot_number = _validate_slot(slot_type, slot_number)
    with get_db_connection() as connection:
        profile_id = _resolve_profile_id(connection, key)
        if profile_id is None:
            return None
        row = connection.execute(
            """SELECT game_state FROM public.game_saves
               WHERE profile_id = %s AND slot_type = %s
                 AND slot_number IS NOT DISTINCT FROM %s
               ORDER BY updated_at DESC LIMIT 1""",
            (profile_id, slot_type, slot_number),
        ).fetchone()

    if not row:
        return None
    value = row.get("game_state") if isinstance(row, dict) else row[0]
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError as exc:
            raise ValueError("O snapshot guardado contém JSON inválido.") from exc
    return value if isinstance(value, dict) else None


def delete_manual_saves(profile_key: str) -> dict[str, Any]:
    """Apaga apenas slots manuais do perfil; nunca toca no autosave.

    Esta operação é destrutiva e só deve ser chamada por uma ação explícita
    da interface/jogador. Não é usada pelo processo normal de guardar/carregar.
    """
    key = _validate_profile_key(profile_key)
    with get_db_connection() as connection:
        _lock_profile(connection, key)
        profile_id = _resolve_profile_id(connection, key)
        if profile_id is None:
            return {"success": True, "deleted": 0}
        rows = connection.execute(
            """DELETE FROM public.game_saves
               WHERE profile_id = %s AND slot_type = 'manual'
               RETURNING slot_number""",
            (profile_id,),
        ).fetchall()
    return {"success": True, "deleted": len(rows)}


def delete_auto_save(profile_key: str) -> dict[str, Any]:
    """Apaga só o autosave do perfil (fim de uma run completa).

    Os slots manuais nunca são tocados. Chamado pelo jogo depois de o final
    e o Diário do Android estarem guardados.
    """
    key = _validate_profile_key(profile_key)
    with get_db_connection() as connection:
        _lock_profile(connection, key)
        profile_id = _resolve_profile_id(connection, key)
        if profile_id is None:
            return {"success": True, "deleted": 0}
        rows = connection.execute(
            """DELETE FROM public.game_saves
               WHERE profile_id = %s AND slot_type = 'auto'
               RETURNING slot_type""",
            (profile_id,),
        ).fetchall()
    return {"success": True, "deleted": len(rows)}


def delete_all_progress(profile_key: str) -> dict[str, Any]:
    """APAGAR PROGRESSO: apaga TODOS os saves do perfil (autosave e os 5
    slots manuais) e a linha do perfil em player_profiles.

    Só é chamada pelo botão APAGAR PROGRESSO do menu principal, depois de o
    jogador confirmar duas vezes.
    """
    key = _validate_profile_key(profile_key)
    with get_db_connection() as connection:
        _lock_profile(connection, key)
        profile_id = _resolve_profile_id(connection, key)
        if profile_id is None:
            return {"success": True, "deleted": 0, "profile_deleted": False}
        rows = connection.execute(
            """DELETE FROM public.game_saves
               WHERE profile_id = %s
               RETURNING slot_type""",
            (profile_id,),
        ).fetchall()
        connection.execute(
            "DELETE FROM public.player_profiles WHERE id = %s",
            (profile_id,),
        )
    return {"success": True, "deleted": len(rows), "profile_deleted": True}
