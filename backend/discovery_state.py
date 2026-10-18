"""Registo determinístico de descobertas confirmadas pelos sensores do jogo.

O módulo distingue deteções atuais de descobertas já registadas. Uma descoberta
só é criada a partir de dados de deteção fornecidos pelo gameplay/sensores; o
texto do Atlas não pode criar descobertas por si só.

O argumento opcional run_id permite manter estados separados por partida. As
chamadas antigas, sem run_id, continuam a usar o estado predefinido.
"""

from copy import deepcopy
import unicodedata


DEFAULT_DISCOVERY_STATE = {
    "unknown_debris": {
        "discovered": False,
        "source_detection_id": None,
        "source_name": None,
    },
    "ancient_sculpture": {
        "discovered": False,
        "source_detection_id": None,
        "source_name": None,
    },
}

DISCOVERY_STATE = deepcopy(DEFAULT_DISCOVERY_STATE)
_DISCOVERY_STATES_BY_RUN = {}

# Apenas estes IDs/tipos explícitos podem confirmar estas descobertas.
# Destroços normais da Nave 47 não são equivalentes a destroços desconhecidos.
DISCOVERY_ALIASES = {
    "unknown_debris": {"unknown_debris", "foreign_debris"},
    "ancient_sculpture": {"ancient_sculpture", "ancient_statue"},
}

REQUIRED_PROTOCOL_DISCOVERIES = (
    "unknown_debris",
    "ancient_sculpture",
)


def _normalize_run_id(run_id=None):
    if run_id is None:
        return None
    normalized = str(run_id).strip()
    return normalized or None


def _get_state(run_id=None):
    normalized = _normalize_run_id(run_id)
    if normalized is None:
        return DISCOVERY_STATE
    if normalized not in _DISCOVERY_STATES_BY_RUN:
        _DISCOVERY_STATES_BY_RUN[normalized] = deepcopy(DEFAULT_DISCOVERY_STATE)
    return _DISCOVERY_STATES_BY_RUN[normalized]


def _normalize(value):
    text = str(value or "").lower().strip()
    text = unicodedata.normalize("NFD", text)
    text = "".join(
        char for char in text
        if unicodedata.category(char) != "Mn"
    )
    return text.replace(" ", "_")


def _match_discovery(detection):
    if not isinstance(detection, dict):
        return None

    candidates = {
        _normalize(detection.get("type")),
        _normalize(detection.get("id")),
        _normalize(detection.get("name")),
    }
    candidates.discard("")

    for discovery_key, aliases in DISCOVERY_ALIASES.items():
        if candidates.intersection(aliases):
            return discovery_key
    return None


def register_discovery(discovery_key, detection=None, run_id=None):
    state = _get_state(run_id)
    if discovery_key not in state:
        return False

    entry = state[discovery_key]
    if entry.get("discovered") is True:
        return False

    entry["discovered"] = True
    if isinstance(detection, dict):
        entry["source_detection_id"] = detection.get("id")
        entry["source_name"] = detection.get("name")
    return True


def process_scan_discoveries(detections, run_id=None):
    """Regista novas descobertas a partir das deteções reais do gameplay."""
    if not isinstance(detections, (list, tuple)):
        return []

    new_discoveries = []
    for detection in detections:
        if not isinstance(detection, dict):
            continue
        discovery_key = _match_discovery(detection)
        if discovery_key is None:
            continue
        if register_discovery(discovery_key, detection=detection, run_id=run_id):
            new_discoveries.append(discovery_key)
    return new_discoveries


def get_discovery_state(run_id=None):
    return deepcopy(_get_state(run_id))


def get_protocol_evidence(run_id=None):
    state = _get_state(run_id)
    discovered = []
    missing = []

    for key in REQUIRED_PROTOCOL_DISCOVERIES:
        if state.get(key, {}).get("discovered") is True:
            discovered.append(key)
        else:
            missing.append(key)

    return {
        "ready": not missing,
        "discovered": discovered,
        "missing": missing,
    }


def build_discovery_context(run_id=None):
    state = _get_state(run_id)
    lines = []

    if state.get("unknown_debris", {}).get("discovered") is True:
        lines.append(
            "- Foram confirmados destroços de origem desconhecida. "
            "Não devem ser classificados automaticamente como extraterrestres."
        )

    if state.get("ancient_sculpture", {}).get("discovered") is True:
        lines.append(
            "- Foi confirmada uma escultura antiga. A sua origem e os seus "
            "criadores permanecem desconhecidos, salvo confirmação posterior."
        )

    if not lines:
        return "Ainda não existem descobertas relevantes confirmadas."
    return "\n".join(lines)


def reset_discovery_state(run_id=None):
    normalized = _normalize_run_id(run_id)
    if normalized is None:
        DISCOVERY_STATE.clear()
        DISCOVERY_STATE.update(deepcopy(DEFAULT_DISCOVERY_STATE))
        _DISCOVERY_STATES_BY_RUN.clear()
    else:
        _DISCOVERY_STATES_BY_RUN[normalized] = deepcopy(DEFAULT_DISCOVERY_STATE)

