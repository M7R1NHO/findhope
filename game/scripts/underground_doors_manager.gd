
extends Node2D


const DOOR_SCRIPT_PATH := "res://scripts/underground_door.gd"

# Ativar apenas quando for necessário investigar problemas nas portas.
const DEBUG_DOORS := false


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


var security_locked_corridors: Dictionary = {}
var main_core_locked_corridors: Dictionary = {}


func _ready():
	create_all_doors()

	call_deferred("reapply_all_corridor_locks")

	if DEBUG_DOORS:
		print(
			"[PORTAS] Sistema iniciado: ",
			corridor_paths.size(),
			" corredores e ",
			corridor_paths.size() * 2,
			" portas esperadas."
		)


func create_all_doors():
	var door_script = load(DOOR_SCRIPT_PATH)

	if door_script == null:
		push_error(
			"[PORTAS] Não foi possível carregar underground_door.gd."
		)
		return

	for corridor_id in corridor_paths.keys():
		var path: Array = corridor_paths[corridor_id]

		if path.size() < 2:
			if DEBUG_DOORS:
				print(
					"[PORTAS] Corredor ignorado por ter menos de 2 pontos: ",
					corridor_id
				)
			continue

		var start_position: Vector2 = path[0]
		var start_direction: Vector2 = path[1] - path[0]

		create_corridor_door(
			corridor_id,
			"A",
			start_position,
			start_direction,
			door_script
		)

		var last_index = path.size() - 1
		var end_position: Vector2 = path[last_index]
		var end_direction: Vector2 = (
			path[last_index] - path[last_index - 1]
		)

		create_corridor_door(
			corridor_id,
			"B",
			end_position,
			end_direction,
			door_script
		)


func create_corridor_door(
	corridor_id: String,
	side: String,
	door_position: Vector2,
	corridor_direction: Vector2,
	door_script
):
	var door_name = get_door_name(corridor_id, side)
	var existing_door = get_node_or_null(door_name)

	if existing_door != null:
		existing_door.set_meta("corridor_id", corridor_id)
		existing_door.set_meta("corridor_side", side)

		apply_pending_locks_to_door(
			existing_door,
			corridor_id
		)

		if DEBUG_DOORS:
			print("[PORTAS] Porta existente: ", door_name)

		return

	var door_size = get_door_size(corridor_direction)
	var door = Area2D.new()

	door.name = door_name
	door.set_script(door_script)
	door.set("door_id", "underground_" + corridor_id.to_lower() + "_" + side.to_lower())
	door.set("door_size", door_size)
	door.position = door_position

	door.set_meta("corridor_id", corridor_id)
	door.set_meta("corridor_side", side)

	add_child(door)

	apply_pending_locks_to_door(
		door,
		corridor_id
	)

	if DEBUG_DOORS:
		print(
			"[PORTAS] Criada: ",
			door_name,
			" | corredor=",
			corridor_id,
			" | lado=",
			side
		)


func get_door_size(direction: Vector2) -> Vector2:
	if abs(direction.x) >= abs(direction.y):
		return Vector2(30, 160)

	return Vector2(160, 30)


func get_door_name(
	corridor_id: String,
	side: String
) -> String:
	if corridor_id == "Hall_Technical" and side == "B":
		return "Door_01"

	return "Door_" + corridor_id + "_" + side


func get_door_for_corridor(
	corridor_id: String,
	side: String
) -> Node:
	var door_name = get_door_name(corridor_id, side)
	return get_node_or_null(door_name)


func set_corridor_security_locked(
	corridor_id: String,
	locked: bool
):
	if locked:
		security_locked_corridors[corridor_id] = true
	else:
		security_locked_corridors.erase(corridor_id)

	apply_locks_to_corridor(corridor_id)


func set_corridor_main_core_locked(
	corridor_id: String,
	locked: bool
):
	if locked:
		main_core_locked_corridors[corridor_id] = true
	else:
		main_core_locked_corridors.erase(corridor_id)

	apply_locks_to_corridor(corridor_id)


func apply_locks_to_corridor(corridor_id: String):
	for side in ["A", "B"]:
		var door = get_door_for_corridor(corridor_id, side)

		if door == null:
			continue

		apply_pending_locks_to_door(
			door,
			corridor_id
		)


func apply_pending_locks_to_door(
	door: Node,
	corridor_id: String
):
	if door == null:
		return

	var security_locked = security_locked_corridors.has(corridor_id)
	var main_core_locked = main_core_locked_corridors.has(corridor_id)

	if door.has_method("set_security_locked"):
		door.set_security_locked(security_locked)

	if door.has_method("set_main_core_locked"):
		door.set_main_core_locked(main_core_locked)


func reapply_all_corridor_locks():
	for corridor_id in corridor_paths.keys():
		apply_locks_to_corridor(corridor_id)

	if DEBUG_DOORS:
		print("[PORTAS] Bloqueios dos corredores reaplicados.")
