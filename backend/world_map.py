"""Mapa provisório de teste do Find Hope / Atlas 2.0.

As posições e os objetos servem apenas para validar sensores, distâncias,
conhecimento e integração com Atlas. Não representam o mapa definitivo.
"""
from copy import deepcopy

WORLD_MAP = [
    {
        "id": "ship_crash",
        "name": "Nave da missão",
        "type": "ship",
        "position": {"x": 0.0, "y": 0.0},
        "detectable": True,
    },
    {
        "id": "ship_debris_01",
        "name": "Destroços da nave",
        "type": "debris",
        "position": {"x": 18.0, "y": 7.0},
        "detectable": True,
    },
    {
        "id": "rock_formation_01",
        "name": "Formação rochosa",
        "type": "natural_structure",
        "position": {"x": 42.0, "y": -15.0},
        "detectable": True,
    },
    {
        "id": "power_module_01",
        "name": "Módulo de energia danificado",
        "type": "ship_component",
        "position": {"x": 68.0, "y": 25.0},
        "detectable": True,
    },
    {
        "id": "buried_structure_01",
        "name": "Estrutura desconhecida",
        "type": "unknown_structure",
        "position": {"x": 210.0, "y": 60.0},
        "detectable": True,
    },
    {
        "id": "underground_facility_01",
        "name": "Instalação subterrânea",
        "type": "underground_structure",
        "position": {"x": 430.0, "y": 110.0},
        # O radar normal não consegue descobrir diretamente esta instalação.
        "detectable": False,
    },
]


def get_world_map():
    """Devolve uma cópia do mapa para evitar alterações acidentais ao original."""
    return deepcopy(WORLD_MAP)


def get_detectable_objects():
    """Devolve cópias dos objetos que podem ser detetados pelo radar normal."""
    return [deepcopy(obj) for obj in WORLD_MAP if obj.get("detectable") is True]


def get_object_by_id(object_id: str):
    """Procura um objeto pelo identificador, sem expor o dicionário interno."""
    if not isinstance(object_id, str) or not object_id.strip():
        return None
    for obj in WORLD_MAP:
        if obj["id"] == object_id:
            return deepcopy(obj)
    return None


def validate_world_map() -> bool:
    """Confirma a estrutura mínima do mapa de teste; não valida o mapa definitivo."""
    seen_ids = set()
    for obj in WORLD_MAP:
        if not isinstance(obj, dict):
            return False
        object_id = obj.get("id")
        position = obj.get("position")
        if not isinstance(object_id, str) or not object_id.strip() or object_id in seen_ids:
            return False
        if not isinstance(position, dict) or not isinstance(position.get("x"), (int, float)) or isinstance(position.get("x"), bool):
            return False
        if not isinstance(position.get("y"), (int, float)) or isinstance(position.get("y"), bool):
            return False
        if not isinstance(obj.get("detectable"), bool):
            return False
        if not isinstance(obj.get("name"), str) or not isinstance(obj.get("type"), str):
            return False
        seen_ids.add(object_id)
    return True
