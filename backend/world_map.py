# MAPA PROVISÓRIO DE TESTE
# As posições e objetos atuais servem apenas para validar
# sensores, distância, conhecimento e integração com Atlas.
# Serão substituídos pelo mapa definitivo do jogo.

WORLD_MAP = [

    # NAVE
    {
        "id": "ship_crash",
        "name": "Nave da missão",
        "type": "ship",
        "position": {
            "x": 0.0,
            "y": 0.0
        },
        "detectable": True
    },

    # DESTROÇOS
    {
        "id": "ship_debris_01",
        "name": "Destroços da nave",
        "type": "debris",
        "position": {
            "x": 18.0,
            "y": 7.0
        },
        "detectable": True
    },

    # FORMAÇÃO ROCHOSA
    {
        "id": "rock_formation_01",
        "name": "Formação rochosa",
        "type": "natural_structure",
        "position": {
            "x": 42.0,
            "y": -15.0
        },
        "detectable": True
    },

    # COMPONENTE PERDIDO DA NAVE
    {
        "id": "power_module_01",
        "name": "Módulo de energia danificado",
        "type": "ship_component",
        "position": {
            "x": 68.0,
            "y": 25.0
        },
        "detectable": True
    },

    # ESTRUTURA MISTERIOSA
    {
        "id": "buried_structure_01",
        "name": "Estrutura desconhecida",
        "type": "unknown_structure",
        "position": {
            "x": 210.0,
            "y": 60.0
        },
        "detectable": True
    },

    # BASE SUBTERRÂNEA
    {
        "id": "underground_facility_01",
        "name": "Instalação subterrânea",
        "type": "underground_structure",
        "position": {
            "x": 430.0,
            "y": 110.0
        },

        # Radar normal não consegue descobrir diretamente.
        "detectable": False
    }
]