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


DISCOVERY_STATE = deepcopy(
    DEFAULT_DISCOVERY_STATE
)


# Tipos/IDs aceites pelo sistema de sensores.
# Mantemos aliases explícitos para não confundir destroços
# normais da Nave 47 com os destroços desconhecidos.
DISCOVERY_ALIASES = {
    "unknown_debris": {
        "unknown_debris",
        "foreign_debris",
    },
    "ancient_sculpture": {
        "ancient_sculpture",
        "ancient_statue",
    },
}


REQUIRED_PROTOCOL_DISCOVERIES = (
    "unknown_debris",
    "ancient_sculpture",
)


def _normalize(value):
    text = str(
        value or ""
    ).lower().strip()

    text = unicodedata.normalize(
        "NFD",
        text
    )

    text = "".join(
        char
        for char in text
        if unicodedata.category(char) != "Mn"
    )

    return text.replace(
        " ",
        "_"
    )


def _match_discovery(detection):
    detection_type = _normalize(
        detection.get("type")
    )

    detection_id = _normalize(
        detection.get("id")
    )

    detection_name = _normalize(
        detection.get("name")
    )

    candidates = {
        detection_type,
        detection_id,
        detection_name,
    }

    for discovery_key, aliases in DISCOVERY_ALIASES.items():
        if candidates.intersection(
            aliases
        ):
            return discovery_key

    return None


def register_discovery(
    discovery_key,
    detection=None,
):
    if discovery_key not in DISCOVERY_STATE:
        return False

    entry = DISCOVERY_STATE[
        discovery_key
    ]

    if entry["discovered"]:
        return False

    entry["discovered"] = True

    if isinstance(
        detection,
        dict
    ):
        entry[
            "source_detection_id"
        ] = detection.get(
            "id"
        )

        entry[
            "source_name"
        ] = detection.get(
            "name"
        )

    return True


def process_scan_discoveries(
    detections
):
    """
    Recebe as deteções reais vindas do Godot.

    Uma descoberta só é registada quando o sensor
    realmente envia um tipo/ID reconhecido.
    """

    new_discoveries = []

    for detection in detections:
        if not isinstance(
            detection,
            dict
        ):
            continue

        discovery_key = (
            _match_discovery(
                detection
            )
        )

        if discovery_key is None:
            continue

        created = register_discovery(
            discovery_key,
            detection=detection,
        )

        if created:
            new_discoveries.append(
                discovery_key
            )

    return new_discoveries


def get_discovery_state():
    return deepcopy(
        DISCOVERY_STATE
    )


def get_protocol_evidence():
    discovered = []

    missing = []

    for key in (
        REQUIRED_PROTOCOL_DISCOVERIES
    ):
        if DISCOVERY_STATE[
            key
        ][
            "discovered"
        ]:
            discovered.append(
                key
            )

        else:
            missing.append(
                key
            )

    return {
        "ready": len(missing) == 0,
        "discovered": discovered,
        "missing": missing,
    }


def build_discovery_context():
    lines = []

    if DISCOVERY_STATE[
        "unknown_debris"
    ][
        "discovered"
    ]:
        lines.append(
            "- Foram confirmados destroços de origem "
            "desconhecida que não devem ser tratados "
            "automaticamente como extraterrestres."
        )

    if DISCOVERY_STATE[
        "ancient_sculpture"
    ][
        "discovered"
    ]:
        lines.append(
            "- Foi confirmada uma escultura antiga. "
            "A sua origem e os seus criadores "
            "permanecem desconhecidos."
        )

    return "\n".join(
        lines
    )


def reset_discovery_state():
    DISCOVERY_STATE.clear()

    DISCOVERY_STATE.update(
        deepcopy(
            DEFAULT_DISCOVERY_STATE
        )
    )
