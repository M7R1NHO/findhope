
extends Node2D

const SAVE_ID := "facility_progression_manager"

const SECURITY_CORRIDORS := [
	"Hall_Storage",
	"Storage_Support",
	"Storage_Archives",
	"Technical_Laboratory",
	"Support_Maintenance",
	"Archives_Sanctuary",
	"Archives_Laboratory"
]

const MAIN_CORE_CORRIDORS := [
	"Laboratory_MainCore",
	"Sanctuary_MainCore"
]

const CLUE_IDS := [
	"laboratory",
	"archives",
	"sanctuary"
]

var underground_root: Node = null
var doors_manager: Node = null

var security_network_unlocked: bool = false
var main_core_access_unlocked: bool = false

var analyzed_clues: Dictionary = {
	"laboratory": false,
	"archives": false,
	"sanctuary": false
}


func _ready() -> void:
	add_to_group("saveable")
	underground_root = get_parent()

	security_network_unlocked = bool(
		SaveManager.get_run_value(
			"story",
			"facility_security_unlocked",
			false
		)
	)

	main_core_access_unlocked = bool(
		SaveManager.get_run_value(
			"story",
			"main_core_access_unlocked",
			false
		)
	)

	for clue_id in CLUE_IDS:
		analyzed_clues[clue_id] = bool(
			SaveManager.get_run_value(
				"story",
				"maincore_clue_" + clue_id,
				false
			)
		)

	disable_legacy_alien_discovery()
	call_deferred("initialize_progression")


func initialize_progression() -> void:
	resolve_doors_manager()
	remove_legacy_barriers()
	apply_progression_state()

	print("FACILITY PROGRESSION READY")
	print("SECURITY: ", security_network_unlocked)
	print("MAIN CORE ACCESS: ", main_core_access_unlocked)
	print("ANALYZED CLUES: ", analyzed_clues)


func resolve_doors_manager() -> void:
	if underground_root == null:
		return

	doors_manager = underground_root.get_node_or_null("Doors")

	if doors_manager == null:
		push_warning(
			"FacilityProgressionManager não encontrou UndergroundRoot/Doors."
		)


func apply_progression_state() -> void:
	if doors_manager == null:
		resolve_doors_manager()

	if doors_manager == null:
		return

	for corridor_id in SECURITY_CORRIDORS:
		if doors_manager.has_method("set_corridor_security_locked"):
			doors_manager.set_corridor_security_locked(
				corridor_id,
				not security_network_unlocked
			)

	for corridor_id in MAIN_CORE_CORRIDORS:
		if doors_manager.has_method("set_corridor_main_core_locked"):
			doors_manager.set_corridor_main_core_locked(
				corridor_id,
				not main_core_access_unlocked
			)


func unlock_security_network() -> void:
	security_network_unlocked = true

	SaveManager.set_run_value(
		"story",
		"facility_security_unlocked",
		true
	)

	apply_progression_state()


func register_clue_analyzed(clue_id: String) -> bool:
	if not CLUE_IDS.has(clue_id):
		push_warning("ID de pista inválido: " + clue_id)
		return false

	if bool(analyzed_clues.get(clue_id, false)):
		return true

	analyzed_clues[clue_id] = true

	SaveManager.set_run_value(
		"story",
		"maincore_clue_" + clue_id,
		true
	)

	print("MAINCORE CLUE ANALYZED: ", clue_id)

	if has_all_clues():
		SaveManager.set_run_value(
			"story",
			"maincore_all_clues_analyzed",
			true
		)

		print("MAINCORE: AS TRÊS PISTAS FORAM ANALISADAS.")

		# A autenticação física é permitida agora.
		# A palavra-senha continua a ser resolvida no terminal.
		unlock_main_core_access()

	return true


func has_clue_been_analyzed(clue_id: String) -> bool:
	return bool(analyzed_clues.get(clue_id, false))


func has_all_clues() -> bool:
	for clue_id in CLUE_IDS:
		if not bool(analyzed_clues.get(clue_id, false)):
			return false

	return true


func unlock_main_core_access() -> void:
	if not has_all_clues():
		push_warning(
			"MainCore bloqueado: ainda faltam pistas por analisar."
		)
		return

	main_core_access_unlocked = true

	SaveManager.set_run_value(
		"story",
		"main_core_access_unlocked",
		true
	)

	apply_progression_state()

	print("MAIN CORE: AUTENTICAÇÃO FÍSICA AUTORIZADA.")


func is_security_network_unlocked() -> bool:
	return security_network_unlocked


func is_main_core_access_unlocked() -> bool:
	return main_core_access_unlocked


func disable_legacy_alien_discovery() -> void:
	if underground_root == null:
		return

	var legacy_discovery = underground_root.get_node_or_null(
		"AlienLifeDiscovery"
	)

	if legacy_discovery == null:
		return

	if legacy_discovery is Area2D:
		legacy_discovery.monitoring = false
		legacy_discovery.monitorable = false

	if legacy_discovery is CanvasItem:
		legacy_discovery.visible = false

	legacy_discovery.set_process(false)
	legacy_discovery.set_physics_process(false)


func remove_legacy_barriers() -> void:
	for child in get_children():
		if (
			child.name.begins_with("SecurityBarrier_")
			or child.name.begins_with("MainCoreBarrier_")
		):
			child.queue_free()


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	return {
		"security_network_unlocked": security_network_unlocked,
		"main_core_access_unlocked": main_core_access_unlocked,
		"analyzed_clues": analyzed_clues.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	security_network_unlocked = bool(
		data.get("security_network_unlocked", false)
	)

	main_core_access_unlocked = bool(
		data.get("main_core_access_unlocked", false)
	)

	var saved_clues: Dictionary = data.get(
		"analyzed_clues",
		{}
	)

	for clue_id in CLUE_IDS:
		analyzed_clues[clue_id] = bool(
			saved_clues.get(clue_id, false)
		)

		SaveManager.set_run_value(
			"story",
			"maincore_clue_" + clue_id,
			analyzed_clues[clue_id]
		)

	SaveManager.set_run_value(
		"story",
		"facility_security_unlocked",
		security_network_unlocked
	)

	SaveManager.set_run_value(
		"story",
		"main_core_access_unlocked",
		main_core_access_unlocked
	)

	SaveManager.set_run_value(
		"story",
		"maincore_all_clues_analyzed",
		has_all_clues()
	)

	call_deferred("apply_progression_state")
