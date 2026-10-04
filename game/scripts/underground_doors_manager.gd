extends Node2D


# =========================================================
# SCRIPT DA PORTA
# =========================================================

const DOOR_SCRIPT_PATH := (
	"res://scripts/underground_door.gd"
)


# =========================================================
# TODAS AS PORTAS DA INSTALAÇÃO
#
# position = posição local dentro do UndergroundRoot
#
# size:
# (30, 160)  = porta vertical
# (160, 30)  = porta horizontal
# =========================================================

var door_definitions := [

	# -----------------------------------------------------
	# HALL → ARMAZÉM
	# -----------------------------------------------------

	{
		"name": "Door_Hall_Storage",
		"id": "underground_door_02",
		"position": Vector2(
			-750,
			-1650
		),
		"size": Vector2(
			30,
			160
		)
	},


	# -----------------------------------------------------
	# HALL → SALA TÉCNICA
	#
	# Esta é a Door_01 que já existe.
	# Se ela estiver na árvore, o manager NÃO duplica.
	# -----------------------------------------------------

	{
		"name": "Door_01",
		"id": "underground_door_01",
		"position": Vector2(
			700,
			-1650
		),
		"size": Vector2(
			30,
			160
		)
	},


	# -----------------------------------------------------
	# ARMAZÉM → SALA DE SUPORTE
	# -----------------------------------------------------

	{
		"name": "Door_Storage_Support",
		"id": "underground_door_03",
		"position": Vector2(
			-1850,
			-1650
		),
		"size": Vector2(
			30,
			160
		)
	},


	# -----------------------------------------------------
	# SALA TÉCNICA → SEGURANÇA
	# -----------------------------------------------------

	{
		"name": "Door_Technical_Security",
		"id": "underground_door_04",
		"position": Vector2(
			1850,
			-1650
		),
		"size": Vector2(
			30,
			160
		)
	},


	# -----------------------------------------------------
	# ARMAZÉM → ARQUIVOS
	# -----------------------------------------------------

	{
		"name": "Door_Storage_Archives",
		"id": "underground_door_05",
		"position": Vector2(
			-1100,
			-2425
		),
		"size": Vector2(
			160,
			30
		)
	},


	# -----------------------------------------------------
	# SALA TÉCNICA → LABORATÓRIO
	# -----------------------------------------------------

	{
		"name": "Door_Technical_Laboratory",
		"id": "underground_door_06",
		"position": Vector2(
			1100,
			-2425
		),
		"size": Vector2(
			160,
			30
		)
	},


	# -----------------------------------------------------
	# SUPORTE → MANUTENÇÃO
	# -----------------------------------------------------

	{
		"name": "Door_Support_Maintenance",
		"id": "underground_door_07",
		"position": Vector2(
			-2200,
			-2450
		),
		"size": Vector2(
			160,
			30
		)
	},


	# -----------------------------------------------------
	# ARQUIVOS → SANTUÁRIO
	# -----------------------------------------------------

	{
		"name": "Door_Archives_Sanctuary",
		"id": "underground_door_08",
		"position": Vector2(
			-1650,
			-3475
		),
		"size": Vector2(
			160,
			30
		)
	},


	# -----------------------------------------------------
	# LABORATÓRIO → NÚCLEO PRINCIPAL
	# -----------------------------------------------------

	{
		"name": "Door_Laboratory_MainCore",
		"id": "underground_door_09",
		"position": Vector2(
			1650,
			-3475
		),
		"size": Vector2(
			160,
			30
		)
	},


	# -----------------------------------------------------
	# ARQUIVOS ↔ LABORATÓRIO
	#
	# Porta no meio do grande corredor horizontal.
	# -----------------------------------------------------

	{
		"name": "Door_Archives_Laboratory",
		"id": "underground_door_10",
		"position": Vector2(
			0,
			-2700
		),
		"size": Vector2(
			30,
			160
		)
	},


	# -----------------------------------------------------
	# SANTUÁRIO ↔ NÚCLEO PRINCIPAL
	#
	# Porta no meio do corredor final.
	# -----------------------------------------------------

	{
		"name": "Door_Sanctuary_MainCore",
		"id": "underground_door_11",
		"position": Vector2(
			0,
			-3800
		),
		"size": Vector2(
			30,
			160
		)
	}
]


# =========================================================
# READY
# =========================================================

func _ready():

	create_all_doors()


	print("")
	print(
		"======================================"
	)

	print(
		"UNDERGROUND DOORS READY"
	)

	print(
		"Total definido: ",
		door_definitions.size()
	)

	print(
		"======================================"
	)


# =========================================================
# CRIAR TODAS
# =========================================================

func create_all_doors():

	var door_script = load(
		DOOR_SCRIPT_PATH
	)


	if door_script == null:

		push_error(
			"Não foi possível carregar underground_door.gd"
		)

		return


	for definition in door_definitions:

		create_door_if_missing(
			definition,
			door_script
		)


# =========================================================
# CRIAR UMA PORTA
# =========================================================

func create_door_if_missing(
	definition: Dictionary,
	door_script
):

	var door_name: String = (
		definition["name"]
	)


	# -----------------------------------------------------
	# NÃO DUPLICAR PORTA JÁ EXISTENTE
	# -----------------------------------------------------

	var existing_door = get_node_or_null(
		door_name
	)


	if existing_door != null:

		print(
			"DOOR EXISTS: ",
			door_name
		)

		return


	# -----------------------------------------------------
	# CRIAR AREA2D
	# -----------------------------------------------------

	var door = Area2D.new()


	door.name = door_name


	door.set_script(
		door_script
	)


	# -----------------------------------------------------
	# CONFIGURAÇÕES ANTES DE ENTRAR NA ÁRVORE
	#
	# Assim _ready() do underground_door.gd
	# já recebe tudo corretamente.
	# -----------------------------------------------------

	door.set(
		"door_id",
		definition["id"]
	)


	door.set(
		"door_size",
		definition["size"]
	)


	door.position = (
		definition["position"]
	)


	# -----------------------------------------------------
	# ADICIONAR
	# -----------------------------------------------------

	add_child(
		door
	)


	print(
		"DOOR CREATED: ",
		door_name,
		" | ",
		definition["position"]
	)
