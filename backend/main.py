import json
import os
from copy import deepcopy
from typing import Literal
from threading import RLock

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from backend.save_persistence import (
    list_saves,
    load_snapshot,
    save_snapshot,
)

from backend.world_state import WORLD_STATE
from backend import (
    atlas_knowledge as atlas_knowledge_module,
    atlas_memory as atlas_memory_module,
    autonomy_state as autonomy_state_module,
    conversation_context as conversation_context_module,
    discovery_state as discovery_state_module,
    gameplay_context as gameplay_context_module,
    narrative_state as narrative_state_module,
    relationship_engine as relationship_engine_module,
    social_state as social_state_module,
)
from backend.sensors import process_godot_scan
from backend.ia import ask_android

from backend.atlas_knowledge import (
    get_atlas_knowledge,
    reset_atlas_knowledge,
)

from backend.atlas_memory import (
    get_atlas_memory,
    reset_atlas_memory,
    add_memory,
)

from backend.autonomy_state import (
    apply_autonomy_event,
    get_autonomy_state,
    reset_autonomy_state,
)

from backend.gameplay_context import (
    register_gameplay_event,
    get_gameplay_context,
    reset_gameplay_context,
)

from backend.discovery_state import (
    process_scan_discoveries,
    get_discovery_state,
    reset_discovery_state,
)

from backend.protocol_decision import evaluate_protocol_door


app = FastAPI(title="Find Hope")


# =========================================================
# MODELS
# =========================================================

class ChatMessage(BaseModel):
    message: str
    run_id: str | None = None


class SaveRequest(BaseModel):
    profile_key: str
    slot_type: Literal["auto", "manual"]
    slot_number: int | None = None
    snapshot: dict
    save_name: str | None = None


class MemoryData(BaseModel):
    memory_type: str = "semantic"
    entity: str
    category: str
    key: str
    value: str
    source: str = "player"
    confidence: float = 1.0
    importance: float = 0.5


class AtlasPosition(BaseModel):
    x: float
    y: float


class GodotDetection(BaseModel):
    id: str
    name: str
    type: str
    distance_px: float


class GodotScan(BaseModel):
    atlas_position: AtlasPosition
    detections: list[GodotDetection]
    run_id: str | None = None


class AutonomyGameplayEvent(BaseModel):
    event: str
    intensity: float = 1.0
    event_id: str | None = None
    run_id: str | None = None


class GameplayContextEvent(BaseModel):
    event_id: str
    event_type: str
    description: str
    active: bool = True
    run_id: str | None = None


# =========================================================
# GAMEPLAY EVENT TRACKING
# =========================================================

PROCESSED_AUTONOMY_EVENT_IDS: set[str] = set()


# =========================================================
# ATLAS SAVE / LOAD STATE
# =========================================================

ATLAS_STATE_VERSION = 1


def _export_atlas_state(run_id=None):
    """Cria uma cópia independente dos estados necessários para restaurar Atlas."""
    return {
        "version": ATLAS_STATE_VERSION,
        "world_state": deepcopy(WORLD_STATE),
        "knowledge": deepcopy(atlas_knowledge_module.ATLAS_KNOWLEDGE),
        "memory": deepcopy(atlas_memory_module.ATLAS_MEMORY),
        "run_memory": deepcopy(
            atlas_memory_module._RUN_MEMORIES.get(
                run_id,
                {"memories": [], "next_id": 1},
            )
        ) if run_id else {"memories": [], "next_id": 1},
        "autonomy": deepcopy(autonomy_state_module.get_autonomy_state(run_id=run_id)),
        "gameplay_context": deepcopy(gameplay_context_module.GAMEPLAY_CONTEXT),
        "discoveries": deepcopy(discovery_state_module.DISCOVERY_STATE),
        "narrative": deepcopy(narrative_state_module.NARRATIVE_STATE),
        "relationship": deepcopy(relationship_engine_module.RELATIONSHIP_STATE),
        "social": deepcopy(social_state_module.SOCIAL_STATE),
        "conversation_history": deepcopy(
            conversation_context_module.CONVERSATION_HISTORY
        ),
        "processed_autonomy_event_ids": sorted(
            PROCESSED_AUTONOMY_EVENT_IDS
        ),
    }


def _replace_dict(target, source, field_name):
    if not isinstance(source, dict):
        raise HTTPException(
            status_code=422,
            detail=f"O campo '{field_name}' tem de ser um objeto JSON.",
        )

    target.clear()
    target.update(deepcopy(source))


def _restore_atlas_state(state, run_id: str | None = None):
    """Restaura o estado de Atlas sem substituir os objetos globais."""

    if not isinstance(state, dict):
        raise HTTPException(
            status_code=422,
            detail="'state' tem de ser um objeto JSON.",
        )

    version = state.get("version", ATLAS_STATE_VERSION)

    if version != ATLAS_STATE_VERSION:
        raise HTTPException(
            status_code=422,
            detail=f"Versão de estado não suportada: {version}.",
        )

    run_memory = state.get(
        "run_memory",
        {"memories": [], "next_id": 1},
    )

    if not isinstance(run_memory, dict):
        raise HTTPException(
            status_code=422,
            detail="'run_memory' tem de ser um objeto JSON.",
        )

    if not isinstance(run_memory.get("memories"), list):
        raise HTTPException(
            status_code=422,
            detail="'run_memory.memories' tem de ser uma lista JSON.",
        )

    if (
        not isinstance(run_memory.get("next_id"), int)
        or isinstance(run_memory.get("next_id"), bool)
    ):
        raise HTTPException(
            status_code=422,
            detail="'run_memory.next_id' tem de ser um número inteiro.",
        )

    required_dicts = {
        "world_state": WORLD_STATE,
        "knowledge": atlas_knowledge_module.ATLAS_KNOWLEDGE,
        "memory": atlas_memory_module.ATLAS_MEMORY,
        "autonomy": autonomy_state_module.AUTONOMY_STATE,
        "gameplay_context": gameplay_context_module.GAMEPLAY_CONTEXT,
        "discoveries": discovery_state_module.DISCOVERY_STATE,
        "narrative": narrative_state_module.NARRATIVE_STATE,
        "relationship": relationship_engine_module.RELATIONSHIP_STATE,
        "social": social_state_module.SOCIAL_STATE,
    }

    # Validar antes de alterar qualquer estado.
    for field_name in required_dicts:
        if field_name in state and not isinstance(state[field_name], dict):
            raise HTTPException(
                status_code=422,
                detail=f"O campo '{field_name}' tem de ser um objeto JSON.",
            )

    history = state.get(
        "conversation_history",
        conversation_context_module.CONVERSATION_HISTORY,
    )

    if not isinstance(history, list):
        raise HTTPException(
            status_code=422,
            detail="O campo 'conversation_history' tem de ser uma lista JSON.",
        )

    event_ids = state.get("processed_autonomy_event_ids", [])

    if (
        not isinstance(event_ids, list)
        or not all(isinstance(item, str) for item in event_ids)
    ):
        raise HTTPException(
            status_code=422,
            detail=(
                "O campo 'processed_autonomy_event_ids' "
                "tem de ser uma lista de textos."
            ),
        )

    for field_name, target in required_dicts.items():
        if field_name in state:
            _replace_dict(target, state[field_name], field_name)

    # A autonomia mantém um dicionário por run além do estado global legado.
    # Sincroniza ambos ao restaurar uma gravação/estado isolado.
    if "autonomy" in state:
        autonomy_key = str(run_id) if run_id is not None else "default"
        if autonomy_key == "default":
            autonomy_state_module.AUTONOMY_STATES["default"] = autonomy_state_module.AUTONOMY_STATE
        else:
            autonomy_state_module.AUTONOMY_STATES[autonomy_key] = deepcopy(state["autonomy"])

    conversation_context_module.CONVERSATION_HISTORY.clear()
    conversation_context_module.CONVERSATION_HISTORY.extend(
        deepcopy(history)
    )

    PROCESSED_AUTONOMY_EVENT_IDS.clear()
    PROCESSED_AUTONOMY_EVENT_IDS.update(event_ids)

    if run_id:
        atlas_memory_module._RUN_MEMORIES[run_id] = deepcopy(
            run_memory
        )

    return _export_atlas_state(run_id)


# Estado isolado por partida. O lock é necessário porque os módulos Atlas usam
# dicionários globais internamente. Os pedidos com run_id são serializados.
RUN_STATES: dict[str, dict] = {}
RUN_STATE_LOCK = RLock()

# O --reload do uvicorn reinicia o processo sempre que um .py muda e apagaria
# RUN_STATES. Guardamos uma cópia em disco (ficheiro .json: não dispara reload).
RUN_STATES_PATH = os.path.join(os.path.dirname(__file__), ".run_states.json")


def _persist_run_states():
    try:
        tmp_path = RUN_STATES_PATH + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(RUN_STATES, f, ensure_ascii=False, default=str)
        os.replace(tmp_path, RUN_STATES_PATH)
    except Exception as e:
        print(f"Aviso: não foi possível persistir RUN_STATES: {e}")


def _load_run_states():
    try:
        with open(RUN_STATES_PATH, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            RUN_STATES.update(
                {k: v for k, v in data.items() if isinstance(v, dict)}
            )
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"Aviso: não foi possível ler {RUN_STATES_PATH}: {e}")


_load_run_states()

def _normalise_run_id(value) -> str | None:
    if value is None:
        return None
    run_id = str(value).strip()
    if not run_id:
        return None
    if len(run_id) > 128:
        raise HTTPException(status_code=422, detail="run_id não pode exceder 128 caracteres.")
    return run_id


def _run_in_isolated_state(run_id: str | None, operation):
    """Executa uma operação no estado da partida e repõe o estado anterior."""
    run_id = _normalise_run_id(run_id)
    if not run_id:
        return operation()

    with RUN_STATE_LOCK:
        stored = RUN_STATES.get(run_id)
        if stored is None:
            raise HTTPException(
                status_code=409,
                detail=(
                    "Estado da partida não inicializado. "
                    "Restaure uma gravação ou inicialize a run antes do chat."
                ),
            )

        previous = _export_atlas_state()
        try:
            _restore_atlas_state(stored, run_id=run_id)
            result = operation()
            RUN_STATES[run_id] = _export_atlas_state(run_id)
            _persist_run_states()
            return result
        finally:
            _restore_atlas_state(previous)




@app.post("/atlas/reset-run")
def reset_atlas_run(payload: dict | None = None):
    """Reinicia uma partida; se receber run_id, apenas essa sessão é reiniciada."""
    run_id = _normalise_run_id((payload or {}).get("run_id"))

    def do_reset(run_id=None):
        reset_atlas_knowledge()
        reset_atlas_memory(run_id=run_id)
        reset_autonomy_state(run_id=run_id)
        reset_gameplay_context()
        reset_discovery_state()
        narrative_state_module.reset_narrative_state()
        relationship_engine_module.reset_relationship_state()
        social_state_module.reset_social_state()
        conversation_context_module.reset_conversation_context()
        PROCESSED_AUTONOMY_EVENT_IDS.clear()
        WORLD_STATE.clear()
        WORLD_STATE.update({
            "player": {"position": {"x": 0.0, "y": 0.0}},
            "atlas": {"position": {"x": 2.0, "y": 0.0}, "radar_range": 50.0, "current_detections": []},
            "ship": {"status": "damaged", "position": {"x": 0.0, "y": 0.0}},
            "environment": {"planet_name": None, "weather": "unknown", "time_of_day": "unknown"},
            "mission": {"current_objective": "evaluate_crash_site"},
        })
        return {
            "status": "Atlas run reset",
            "state": _export_atlas_state(run_id),
        }

    if not run_id:
        return do_reset()

    with RUN_STATE_LOCK:
        previous = _export_atlas_state()
        try:
            result = do_reset(run_id)
            RUN_STATES[run_id] = _export_atlas_state(run_id)
            _persist_run_states()
            return result
        finally:
            _restore_atlas_state(previous)



@app.get("/atlas/state")
def export_atlas_state(run_id: str | None = None):
    """Exporta o estado global legado ou o estado de uma partida específica."""
    run_id = _normalise_run_id(run_id)
    if run_id:
        with RUN_STATE_LOCK:
            state = RUN_STATES.get(run_id)
            if state is None:
                # Nunca fabricar o estado de uma run desconhecida a partir do
                # global: após um reinício do backend isso gravaria um estado
                # vazio por cima de um save bom, com HTTP 200.
                raise HTTPException(
                    status_code=404,
                    detail="Estado desta run não carregado no backend.",
                )
            return {"status": "ok", "run_id": run_id, "state": deepcopy(state)}
    return {"status": "ok", "state": _export_atlas_state()}


@app.post("/atlas/state")
def restore_atlas_state(payload: dict):
    """Restaura o estado. Opcionalmente aceita run_id para isolar a partida."""
    if not isinstance(payload, dict):
        raise HTTPException(status_code=422, detail="O corpo tem de ser um objeto JSON.")
    run_id = _normalise_run_id(payload.get("run_id"))
    state = payload.get("state", payload)
    if not run_id:
        restored = _restore_atlas_state(state, run_id=run_id)
        return {"status": "Atlas state restored", "state": restored}
    with RUN_STATE_LOCK:
        previous = _export_atlas_state()
        try:
            restored = _restore_atlas_state(state, run_id=run_id)
            RUN_STATES[run_id] = _export_atlas_state(run_id)
            _persist_run_states()
            return {
                "status": "Atlas state restored",
                "run_id": run_id,
                "state": restored,
            }
        finally:
            _restore_atlas_state(previous)


# =========================================================
# SAVE PERSISTENCE (POSTGRESQL)
# =========================================================

@app.post("/saves")
def create_or_update_save(data: SaveRequest):
    """Guarda ou atualiza um autosave ou um dos cinco slots manuais."""
    try:
        return save_snapshot(
            profile_key=data.profile_key,
            slot_type=data.slot_type,
            slot_number=data.slot_number,
            snapshot=data.snapshot,
            save_name=data.save_name,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        print(f"Erro ao guardar save: {type(exc).__name__}: {exc!r}")
        raise HTTPException(
            status_code=500,
            detail="Não foi possível guardar o save.",
        ) from exc


@app.get("/saves/{profile_key}")
def get_player_saves(profile_key: str):
    """Lista os slots guardados para um perfil."""
    try:
        return {"saves": list_saves(profile_key)}
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        print(f"Erro ao listar saves: {type(exc).__name__}: {exc!r}")
        raise HTTPException(
            status_code=500,
            detail="Não foi possível listar os saves.",
        ) from exc


@app.get("/saves/{profile_key}/{slot_type}/{slot_number}")
def get_player_save(
    profile_key: str,
    slot_type: Literal["auto", "manual"],
    slot_number: int,
):
    """Carrega um save; usar 0 como número do autosave."""
    resolved_slot_number = (
        None if slot_type == "auto" and slot_number == 0 else slot_number
    )

    try:
        snapshot = load_snapshot(
            profile_key=profile_key,
            slot_type=slot_type,
            slot_number=resolved_slot_number,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        print("Erro ao carregar save:", type(exc).__name__)
        raise HTTPException(
            status_code=500,
            detail="Não foi possível carregar o save.",
        ) from exc

    if snapshot is None:
        raise HTTPException(status_code=404, detail="Save não encontrado.")

    return {"snapshot": snapshot}


# =========================================================
# ROOT
# =========================================================

@app.get("/")
def root():
    return {"message": "Find Hope API online"}


# =========================================================
# CHAT
# =========================================================

@app.post("/chat")
def chat(data: ChatMessage):
    def ask():
        return ask_android(data.message, run_id=data.run_id)

    response = _run_in_isolated_state(data.run_id, ask)
    return {
        "message": data.message,
        "response": response,
        "run_id": data.run_id,
    }


# =========================================================
# GODOT SENSOR BRIDGE
# =========================================================

@app.post("/world/scan")
def receive_godot_scan(data: GodotScan):
    run_id = _normalise_run_id(data.run_id)

    def process():
        atlas_position = {"x": data.atlas_position.x, "y": data.atlas_position.y}
        detections = [
            {"id": d.id, "name": d.name, "type": d.type, "distance_px": d.distance_px}
            for d in data.detections
        ]
        processed = process_godot_scan(atlas_position, detections)
        new_discoveries = process_scan_discoveries(detections)
        if new_discoveries:
            print("\\nNEW SURFACE DISCOVERIES:", new_discoveries)
            print("\\nDISCOVERY STATE:", get_discovery_state())
        return {
            "status": "scan processed",
            "run_id": run_id,
            "atlas_position": atlas_position,
            "detected_objects": processed,
            "new_discoveries": new_discoveries,
            "discovery_state": get_discovery_state(),
        }

    return _run_in_isolated_state(run_id, process)


@app.get("/atlas/current-detections")
def current_detections(run_id: str | None = None):
    return _run_in_isolated_state(
        run_id, lambda: deepcopy(WORLD_STATE["atlas"]["current_detections"])
    )


@app.post("/atlas/position")
def update_atlas_position(data: AtlasPosition, run_id: str | None = None):
    def update():
        WORLD_STATE["atlas"]["position"] = {"x": data.x, "y": data.y}
        return {"status": "Atlas position updated", "position": deepcopy(WORLD_STATE["atlas"]["position"])}
    return _run_in_isolated_state(run_id, update)


# =========================================================
# KNOWLEDGE
# =========================================================

@app.get("/atlas/knowledge")
def atlas_knowledge(run_id: str | None = None):
    return _run_in_isolated_state(run_id, get_atlas_knowledge)


@app.post("/atlas/reset-knowledge")
def reset_knowledge(run_id: str | None = None):
    def reset():
        reset_atlas_knowledge()
        return {"status": "Atlas knowledge reset"}
    return _run_in_isolated_state(run_id, reset)


# =========================================================
# MEMORY
# =========================================================

@app.get("/atlas/memory")
def atlas_memory(run_id: str | None = None):
    normalized_run_id = _normalise_run_id(run_id)
    return _run_in_isolated_state(
        normalized_run_id,
        lambda: get_atlas_memory(run_id=normalized_run_id),
    )


@app.post("/atlas/memory")
def create_memory(data: MemoryData, run_id: str | None = None):
    normalized_run_id = _normalise_run_id(run_id)

    def create():
        success = add_memory(
            memory_type=data.memory_type,
            entity=data.entity,
            category=data.category,
            key=data.key,
            value=data.value,
            source=data.source,
            confidence=data.confidence,
            importance=data.importance,
            run_id=normalized_run_id,
        )
        if not success:
            return {"status": "error", "message": "Invalid memory data"}
        return {"status": "Memory stored"}

    return _run_in_isolated_state(normalized_run_id, create)


@app.post("/atlas/reset-memory")
def reset_memory(run_id: str | None = None):
    normalized_run_id = _normalise_run_id(run_id)

    def reset():
        reset_atlas_memory(run_id=normalized_run_id)
        return {"status": "Atlas memory reset"}

    return _run_in_isolated_state(normalized_run_id, reset)


# =========================================================
# DISCOVERIES
# =========================================================

@app.get("/gameplay/discoveries")
def gameplay_discoveries(run_id: str | None = None):
    return _run_in_isolated_state(run_id, get_discovery_state)


@app.post("/gameplay/discoveries/reset")
def reset_discoveries(run_id: str | None = None):
    def reset():
        reset_discovery_state()
        return {"status": "Gameplay discoveries reset", "discoveries": get_discovery_state()}
    return _run_in_isolated_state(run_id, reset)


# =========================================================
# GAMEPLAY CONTEXT
# =========================================================

@app.get("/gameplay/context")
def gameplay_context(run_id: str | None = None):
    return _run_in_isolated_state(run_id, get_gameplay_context)


@app.post("/gameplay/context/event")
def gameplay_context_event(data: GameplayContextEvent):
    run_id = _normalise_run_id(data.run_id)
    def register():
        success = register_gameplay_event(
            event_id=data.event_id, event_type=data.event_type,
            description=data.description, active=data.active,
        )
        if not success:
            return {"status": "error", "message": "Invalid gameplay context event"}
        print("\\nGAMEPLAY CONTEXT EVENT:", {
            "event_id": data.event_id, "event_type": data.event_type,
            "description": data.description, "active": data.active, "run_id": run_id,
        })
        return {"status": "gameplay context updated", "event_id": data.event_id,
                "event_type": data.event_type, "active": data.active, "run_id": run_id}
    return _run_in_isolated_state(run_id, register)


@app.post("/gameplay/context/reset")
def reset_gameplay(run_id: str | None = None):
    def reset():
        reset_gameplay_context()
        return {"status": "Gameplay context reset"}
    return _run_in_isolated_state(run_id, reset)


# =========================================================
# PROTOCOL DOOR DECISION
# =========================================================

@app.get("/gameplay/protocol-door/decision")
def protocol_door_decision(run_id: str | None = None):
    decision = _run_in_isolated_state(run_id, evaluate_protocol_door)
    print("\\nPROTOCOL DOOR DECISION:", decision)
    return decision


# =========================================================
# AUTONOMY / GAMEPLAY BRIDGE
# =========================================================

ALLOWED_GAMEPLAY_AUTONOMY_EVENTS = {
    "independent_choice", "question_protocol", "break_protocol",
    "protect_player_by_choice",
}


@app.get("/atlas/autonomy")
def atlas_autonomy(run_id: str | None = None):
    normalized_run_id = _normalise_run_id(run_id)
    return _run_in_isolated_state(
        normalized_run_id,
        lambda: get_autonomy_state(run_id=normalized_run_id),
    )


@app.post("/atlas/autonomy/event")
def autonomy_gameplay_event(data: AutonomyGameplayEvent):
    run_id = _normalise_run_id(data.run_id)
    if data.event not in ALLOWED_GAMEPLAY_AUTONOMY_EVENTS:
        return {"status": "error", "message": "Invalid gameplay autonomy event",
                "allowed_events": sorted(ALLOWED_GAMEPLAY_AUTONOMY_EVENTS)}

    event_id = data.event_id.strip() if data.event_id and data.event_id.strip() else None

    def process_event():
        if event_id is not None and event_id in PROCESSED_AUTONOMY_EVENT_IDS:
            state = get_autonomy_state(run_id=run_id)
            return {"status": "duplicate event ignored", "event": data.event,
                    "event_id": event_id, "intensity": data.intensity,
                    "duplicate": True, "autonomy": state, "run_id": run_id}

        state = apply_autonomy_event(
            event_type=data.event,
            intensity=data.intensity,
            source="gameplay",
            run_id=run_id,
        )
        if event_id is not None:
            PROCESSED_AUTONOMY_EVENT_IDS.add(event_id)
        print("\\nAUTONOMY GAMEPLAY EVENT:", {
            "event": data.event, "event_id": event_id,
            "intensity": data.intensity, "run_id": run_id,
        })
        print("\\nAUTONOMY STATE AFTER GAMEPLAY EVENT:", state)
        return {"status": "autonomy event processed", "event": data.event,
                "event_id": event_id, "intensity": data.intensity,
                "duplicate": False, "autonomy": state, "run_id": run_id}

    return _run_in_isolated_state(run_id, process_event)


@app.post("/atlas/reset-autonomy")
def reset_autonomy(run_id: str | None = None):
    def reset():
        reset_autonomy_state(run_id=run_id)
        PROCESSED_AUTONOMY_EVENT_IDS.clear()
        return {"status": "Atlas autonomy reset", "autonomy": get_autonomy_state(run_id=run_id),
                "processed_event_ids": []}
    return _run_in_isolated_state(run_id, reset)
