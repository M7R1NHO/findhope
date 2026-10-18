"""Processamento de scans enviados pelo Godot para o Atlas 2.0.

O Godot continua a ser a autoridade sobre posições, distâncias e deteções.
Este módulo transforma os dados recebidos em contexto narrativo, sem inferir
objetos ou factos que não tenham sido reportados pelo jogo.
"""
from __future__ import annotations

import math
from typing import Any

from backend.world_state import WORLD_STATE
from backend.atlas_knowledge import add_confirmed_fact, reset_current_detections


def _valid_number(value: Any, field_name: str) -> float:
    """Converte um valor numérico e rejeita valores inválidos ou não finitos."""
    if isinstance(value, bool):
        raise ValueError(f"{field_name} tem de ser um número válido.")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field_name} tem de ser um número válido.") from exc
    if not math.isfinite(number):
        raise ValueError(f"{field_name} tem de ser um número finito.")
    return number


def get_proximity(distance_px: float) -> str:
    """Converte distância em pixels numa descrição qualitativa.

    Os pixels são uma unidade interna do jogo; não são convertidos em metros.
    """
    distance = _valid_number(distance_px, "distance_px")
    if distance < 0:
        raise ValueError("distance_px não pode ser negativa.")

    if distance <= 75:
        return "muito perto"
    if distance <= 150:
        return "perto"
    return "dentro do alcance dos sensores"


def process_godot_scan(
    atlas_position: dict[str, Any],
    detections: list[dict[str, Any]],
    run_id: str | None = None,
) -> list[dict[str, Any]]:
    """Processa um scan confirmado pelo Godot.

    Args:
        atlas_position: posição atual de Atlas, fornecida pelo Godot.
        detections: lista de objetos efetivamente detetados pelo jogo.
        run_id: identificador opcional da partida; deve ser propagado pelos
            módulos de estado para manter as partidas isoladas.

    A função não conclui que um objeto existe com base em memória ou diálogo.
    Apenas as deteções presentes neste scan são registadas como atuais.
    """
    if not isinstance(atlas_position, dict):
        raise ValueError("atlas_position tem de ser um objeto com x e y.")
    if not isinstance(detections, list):
        raise ValueError("detections tem de ser uma lista.")

    x = _valid_number(atlas_position.get("x"), "atlas_position.x")
    y = _valid_number(atlas_position.get("y"), "atlas_position.y")

    normalized_run_id = None
    if run_id is not None:
        normalized_run_id = str(run_id).strip()
        if not normalized_run_id:
            raise ValueError("run_id não pode ser vazio.")
        normalized_run_id = normalized_run_id[:255]

    processed_detections: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    # Validar toda a entrada antes de alterar o estado evita atualizações
    # parciais se uma deteção estiver malformada.
    for index, detection in enumerate(detections):
        if not isinstance(detection, dict):
            raise ValueError(f"A deteção {index} tem de ser um objeto.")

        raw_id = detection.get("id")
        raw_name = detection.get("name")
        raw_type = detection.get("type")
        if raw_id is None or not str(raw_id).strip():
            raise ValueError(f"A deteção {index} não tem um id válido.")
        if raw_name is None or not str(raw_name).strip():
            raise ValueError(f"A deteção {index} não tem um nome válido.")
        if raw_type is None or not str(raw_type).strip():
            raise ValueError(f"A deteção {index} não tem um tipo válido.")

        detection_id = str(raw_id).strip()[:255]
        if detection_id in seen_ids:
            raise ValueError(f"Id de deteção duplicado no scan: {detection_id}.")
        seen_ids.add(detection_id)

        distance_px = _valid_number(detection.get("distance_px"), "distance_px")
        if distance_px < 0:
            raise ValueError("distance_px não pode ser negativa.")

        processed_detections.append({
            "id": detection_id,
            "name": str(raw_name).strip()[:255],
            "type": str(raw_type).strip()[:100],
            "proximity": get_proximity(distance_px),
        })

    # Mantém compatibilidade com o estado global atual. A integração completa
    # por run_id depende de WORLD_STATE e dos módulos de conhecimento aceitarem
    # e armazenarem o mesmo identificador.
    WORLD_STATE["atlas"]["position"] = {"x": x, "y": y}
    reset_current_detections(run_id=normalized_run_id)

    for detection in processed_detections:
        add_confirmed_fact(
            fact_id=detection["id"],
            name=detection["name"],
            source="sensors",
            currently_detected=True,
            extra={"type": detection["type"], "proximity": detection["proximity"]},
            run_id=normalized_run_id,
        )

    WORLD_STATE["atlas"]["current_detections"] = [dict(item) for item in processed_detections]
    if normalized_run_id is not None:
        WORLD_STATE["atlas"]["run_id"] = normalized_run_id

    return [dict(item) for item in processed_detections]
