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


var underground_root: Node = null

var doors_manager: Node = null

var security_network_unlocked: bool = false

var main_core_access_unlocked: bool = false


func _ready():
	add_to_group(
		"saveable"
	)

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

	disable_legacy_alien_discovery()

	call_deferred(
		"initialize_progression"
	)


func initialize_progression():
	resolve_doors_manager()

	remove_legacy_barriers()

	apply_progression_state()

	print("")
	print("======================================")
	print("FACILITY PROGRESSION READY")
	print(
		"SECURITY NETWORK UNLOCKED: ",
		security_network_unlocked
	)
	print(
		"MAIN CORE ACCESS UNLOCKED: ",
		main_core_access_unlocked
	)
	print("======================================")


func resolve_doors_manager():
	if underground_root == null:
		return

	doors_manager = (
		underground_root.get_node_or_null(
			"Doors"
		)
	)

	if doors_manager == null:
		push_warning(
			"FacilityProgressionManager "
			+ "não encontrou UndergroundRoot/Doors."
		)


func apply_progression_state():
	if doors_manager == null:
		resolve_doors_manager()

	if doors_manager == null:
		return

	for corridor_id in SECURITY_CORRIDORS:
		if doors_manager.has_method(
			"set_corridor_security_locked"
		):
			doors_manager.set_corridor_security_locked(
				corridor_id,
				not security_network_unlocked
			)

	for corridor_id in MAIN_CORE_CORRIDORS:
		if doors_manager.has_method(
			"set_corridor_main_core_locked"
		):
			doors_manager.set_corridor_main_core_locked(
				corridor_id,
				not main_core_access_unlocked
			)


func unlock_security_network():
	if security_network_unlocked:
		apply_progression_state()
		return

	security_network_unlocked = true

	SaveManager.set_run_value(
		"story",
		"facility_security_unlocked",
		true
	)

	apply_progression_state()

	print("")
	print("======================================")
	print("FACILITY SECURITY NETWORK UNLOCKED")
	print("REGULAR SECTORS AVAILABLE")
	print("MAIN CORE REMAINS LOCKED")
	print("======================================")


func unlock_main_core_access():
	if main_core_access_unlocked:
		apply_progression_state()
		return

	main_core_access_unlocked = true

	SaveManager.set_run_value(
		"story",
		"main_core_access_unlocked",
		true
	)

	apply_progression_state()

	print("")
	print("======================================")
	print("MAIN CORE ACCESS UNLOCKED")
	print("======================================")


func is_security_network_unlocked() -> bool:
	return security_network_unlocked


func is_main_core_access_unlocked() -> bool:
	return main_core_access_unlocked


func disable_legacy_alien_discovery():
	if underground_root == null:
		return

	var legacy_discovery = (
		underground_root.get_node_or_null(
			"AlienLifeDiscovery"
		)
	)

	if legacy_discovery == null:
		return

	if legacy_discovery is Area2D:
		legacy_discovery.monitoring = false
		legacy_discovery.monitorable = false

	if legacy_discovery is CanvasItem:
		legacy_discovery.visible = false

	legacy_discovery.set_process(
		false
	)

	legacy_discovery.set_physics_process(
		false
	)

	print(
		"LEGACY ALIEN LIFE DISCOVERY DISABLED"
	)


func remove_legacy_barriers():
	var children = get_children()

	for child in children:
		if (
			child.name.begins_with(
				"SecurityBarrier_"
			)
			or child.name.begins_with(
				"MainCoreBarrier_"
			)
		):
			child.queue_free()


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	return {
		"security_network_unlocked":
			security_network_unlocked,

		"main_core_access_unlocked":
			main_core_access_unlocked
	}


func load_save_data(
	data: Dictionary
):
	security_network_unlocked = bool(
		data.get(
			"security_network_unlocked",
			false
		)
	)

	main_core_access_unlocked = bool(
		data.get(
			"main_core_access_unlocked",
			false
		)
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

	call_deferred(
		"apply_progression_state"
	)
