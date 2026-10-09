extends Node


const SAVE_ID := "main_run_state"


var player: CharacterBody2D = null
var atlas: CharacterBody2D = null
var fight_manager: Node = null
var underground_root: Node = null


func _ready():
	add_to_group(
		"saveable"
	)

	call_deferred(
		"resolve_nodes"
	)


func resolve_nodes():
	var main = get_parent()

	if main == null:
		push_warning(
			"RunState não encontrou o Main."
		)
		return

	player = main.get_node_or_null(
		"Player"
	)

	atlas = main.get_node_or_null(
		"Atlas"
	)

	fight_manager = main.get_node_or_null(
		"FightManager"
	)

	underground_root = main.get_node_or_null(
		"UndergroundRoot"
	)

	print("")
	print("======================================")
	print("RUN STATE READY")
	print("PLAYER: ", player != null)
	print("ATLAS: ", atlas != null)
	print("FIGHT MANAGER: ", fight_manager != null)
	print("UNDERGROUND ROOT: ", underground_root != null)
	print("======================================")


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"player": {},
		"atlas": {},
		"fight": {},
		"world": {}
	}


	if player != null:
		data["player"] = {
			"position": vector2_to_data(
				player.global_position
			),
			"visible": player.visible
		}


	if atlas != null:
		data["atlas"] = {
			"position": vector2_to_data(
				atlas.global_position
			),
			"visible": atlas.visible
		}


	if fight_manager != null:
		var life: int = 100

		if fight_manager.has_method(
			"get_shared_life"
		):
			life = int(
				fight_manager.get_shared_life()
			)

		var combat_unlocked: bool = false

		if fight_manager.has_method(
			"is_combat_unlocked"
		):
			combat_unlocked = bool(
				fight_manager.is_combat_unlocked()
			)

		data["fight"] = {
			"life": life,
			"combat_unlocked": combat_unlocked
		}


	if underground_root != null:
		data["world"] = {
			"facility_power_restored":
				bool(
					underground_root.get_meta(
						"facility_power_restored",
						false
					)
				),

			"main_core_unlocked":
				bool(
					underground_root.get_meta(
						"main_core_unlocked",
						false
					)
				),

			"phase3_unlocked":
				bool(
					underground_root.get_meta(
						"phase3_unlocked",
						false
					)
				)
		}


	print("")
	print("RUN STATE CAPTURED")
	print(
		"Player position: ",
		data["player"].get(
			"position",
			{}
		)
	)

	return data


func load_save_data(
	data: Dictionary
):
	resolve_nodes()

	restore_player(
		data.get(
			"player",
			{}
		)
	)

	restore_atlas(
		data.get(
			"atlas",
			{}
		)
	)

	restore_fight(
		data.get(
			"fight",
			{}
		)
	)

	restore_world(
		data.get(
			"world",
			{}
		)
	)


	print("")
	print("======================================")
	print("RUN STATE RESTORED")

	if player != null:
		print(
			"PLAYER POSITION: ",
			player.global_position
		)

	if atlas != null:
		print(
			"ATLAS POSITION: ",
			atlas.global_position
		)

	print("======================================")


func restore_player(
	data: Dictionary
):
	if player == null:
		return

	if data.has(
		"position"
	):
		player.global_position = data_to_vector2(
			data["position"]
		)

	player.velocity = Vector2.ZERO

	if data.has(
		"visible"
	):
		player.visible = bool(
			data["visible"]
		)


func restore_atlas(
	data: Dictionary
):
	if atlas == null:
		return

	if data.has(
		"position"
	):
		atlas.global_position = data_to_vector2(
			data["position"]
		)

	atlas.velocity = Vector2.ZERO

	if data.has(
		"visible"
	):
		atlas.visible = bool(
			data["visible"]
		)


func restore_fight(
	data: Dictionary
):
	if fight_manager == null:
		return


	if data.has(
		"life"
	):
		var life = int(
			data["life"]
		)

		if fight_manager.get(
			"atlas_max_hp"
		) != null:
			var max_life = int(
				fight_manager.get(
					"atlas_max_hp"
				)
			)

			life = clamp(
				life,
				0,
				max_life
			)

		fight_manager.set(
			"atlas_hp",
			life
		)


	if data.has(
		"combat_unlocked"
	):
		fight_manager.set(
			"combat_unlocked",
			bool(
				data["combat_unlocked"]
			)
		)


func restore_world(
	data: Dictionary
):
	if underground_root == null:
		return


	if data.has(
		"facility_power_restored"
	):
		underground_root.set_meta(
			"facility_power_restored",
			bool(
				data[
					"facility_power_restored"
				]
			)
		)


	if data.has(
		"main_core_unlocked"
	):
		underground_root.set_meta(
			"main_core_unlocked",
			bool(
				data[
					"main_core_unlocked"
				]
			)
		)


	if data.has(
		"phase3_unlocked"
	):
		underground_root.set_meta(
			"phase3_unlocked",
			bool(
				data[
					"phase3_unlocked"
				]
			)
		)


func vector2_to_data(
	value: Vector2
) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


func data_to_vector2(
	data
) -> Vector2:
	if not (
		data is Dictionary
	):
		return Vector2.ZERO

	return Vector2(
		float(
			data.get(
				"x",
				0.0
			)
		),
		float(
			data.get(
				"y",
				0.0
			)
		)
	)
