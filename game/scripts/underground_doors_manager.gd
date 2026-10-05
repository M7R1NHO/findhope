extends Node2D


# =========================================================
# SCRIPT DA PORTA
# =========================================================

const DOOR_SCRIPT_PATH := (
	"res://scripts/underground_door.gd"
)


# =========================================================
# CORREDORES INTERNOS
#
# Cada corredor agora possui:
#
# A = porta no início do corredor
# B = porta no fim do corredor
#
# Entrance_Hall não entra aqui porque a entrada principal
# já possui o ProtocolDoor.
# =========================================================

var corridor_paths := {

	"Hall_Storage": [
		Vector2(-300, -1200),
		Vector2(-300, -1650),
		Vector2(-750, -1650)
	],

	"Hall_Technical": [
		Vector2(300, -1200),
		Vector2(300, -1650),
		Vector2(700, -1650)
	],

	"Storage_Support": [
		Vector2(-1450, -1650),
		Vector2(-1850, -1650)
	],

	"Technical_Security": [
		Vector2(1500, -1650),
		Vector2(1850, -1650)
	],

	"Storage_Archives": [
		Vector2(-1100, -1900),
		Vector2(-1100, -2425)
	],

	"Technical_Laboratory": [
		Vector2(1100, -1925),
		Vector2(1100, -2425)
	],

	"Support_Maintenance": [
		Vector2(-2200, -1900),
		Vector2(-2200, -2450)
	],

	"Archives_Sanctuary": [
		Vector2(-1100, -2975),
		Vector2(-1100, -3300),
		Vector2(-1650, -3300),
		Vector2(-1650, -3475)
	],

	"Laboratory_MainCore": [
		Vector2(1100, -2975),
		Vector2(1100, -3300),
		Vector2(1650, -3300),
		Vector2(1650, -3475)
	],

	"Sanctuary_MainCore": [
		Vector2(-1650, -3800),
		Vector2(1650, -3800)
	],

	"Archives_Laboratory": [
		Vector2(-700, -2700),
		Vector2(700, -2700)
	]
}


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
		"DOUBLE DOOR SYSTEM READY"
	)

	print(
		"CORRIDORS: ",
		corridor_paths.size()
	)

	print(
		"EXPECTED DOORS: ",
		corridor_paths.size() * 2
	)

	print(
		"======================================"
	)


# =========================================================
# CRIAR TODAS AS PORTAS
# =========================================================

func create_all_doors():

	var door_script = load(
		DOOR_SCRIPT_PATH
	)


	if door_script == null:

		push_error(
			"Não foi possível carregar "
			+ "underground_door.gd"
		)

		return


	for corridor_id in corridor_paths.keys():

		var path: Array = (
			corridor_paths[
				corridor_id
			]
		)


		if path.size() < 2:
			continue


		# =================================================
		# PORTA A
		# =================================================

		var start_position: Vector2 = (
			path[0]
		)


		var start_direction: Vector2 = (
			path[1]
			- path[0]
		)


		create_corridor_door(
			corridor_id,
			"A",
			start_position,
			start_direction,
			door_script
		)


		# =================================================
		# PORTA B
		# =================================================

		var last_index = (
			path.size() - 1
		)


		var end_position: Vector2 = (
			path[last_index]
		)


		var end_direction: Vector2 = (
			path[last_index]
			- path[last_index - 1]
		)


		create_corridor_door(
			corridor_id,
			"B",
			end_position,
			end_direction,
			door_script
		)


# =========================================================
# CRIAR PORTA DE UM DOS LADOS
# =========================================================

func create_corridor_door(
	corridor_id: String,
	side: String,
	door_position: Vector2,
	corridor_direction: Vector2,
	door_script
):

	var door_name = (
		get_door_name(
			corridor_id,
			side
		)
	)


	# =====================================================
	# PORTA JÁ EXISTE
	# =====================================================

	var existing_door = get_node_or_null(
		door_name
	)


	if existing_door != null:

		existing_door.set_meta(
			"corridor_id",
			corridor_id
		)

		existing_door.set_meta(
			"corridor_side",
			side
		)


		print(
			"DOOR EXISTS: ",
			door_name
		)


		return


	# =====================================================
	# TAMANHO DA PORTA
	# =====================================================

	var door_size = (
		get_door_size(
			corridor_direction
		)
	)


	# =====================================================
	# CRIAR
	# =====================================================

	var door = Area2D.new()


	door.name = door_name


	door.set_script(
		door_script
	)


	door.set(
		"door_id",
		"underground_"
		+ corridor_id.to_lower()
		+ "_"
		+ side.to_lower()
	)


	door.set(
		"door_size",
		door_size
	)


	door.position = (
		door_position
	)


	door.set_meta(
		"corridor_id",
		corridor_id
	)


	door.set_meta(
		"corridor_side",
		side
	)


	add_child(
		door
	)


	print(
		"DOOR CREATED: ",
		door_name,
		" | corridor=",
		corridor_id,
		" | side=",
		side,
		" | position=",
		door_position
	)


# =========================================================
# TAMANHO / ORIENTAÇÃO
# =========================================================

func get_door_size(
	direction: Vector2
) -> Vector2:

	# -----------------------------------------------------
	# CORREDOR HORIZONTAL
	#
	# Porta vertical
	# -----------------------------------------------------

	if abs(direction.x) >= abs(
		direction.y
	):

		return Vector2(
			30,
			160
		)


	# -----------------------------------------------------
	# CORREDOR VERTICAL
	#
	# Porta horizontal
	# -----------------------------------------------------

	return Vector2(
		160,
		30
	)


# =========================================================
# NOME DA PORTA
# =========================================================

func get_door_name(
	corridor_id: String,
	side: String
) -> String:

	# -----------------------------------------------------
	# A nossa Door_01 antiga já ocupa exatamente
	# o lado B de Hall_Technical.
	# -----------------------------------------------------

	if (
		corridor_id == "Hall_Technical"
		and side == "B"
	):

		return "Door_01"


	return (
		"Door_"
		+ corridor_id
		+ "_"
		+ side
	)


# =========================================================
# API PARA OUTROS SISTEMAS
#
# AlienEncounterManager usa isto para descobrir
# qual é a porta da frente.
# =========================================================

func get_door_for_corridor(
	corridor_id: String,
	side: String
) -> Node:

	var door_name = (
		get_door_name(
			corridor_id,
			side
		)
	)


	return get_node_or_null(
		door_name
	)
