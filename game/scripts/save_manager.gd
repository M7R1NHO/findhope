extends Node


signal save_completed(save_type: String, slot: int)
signal load_prepared(save_type: String, slot: int)
signal load_applied
signal save_failed(reason: String)
signal profile_changed


const SAVE_VERSION: int = 1
const SLOT_COUNT: int = 5

const PROFILE_PATH := "user://findhope_profile.json"
const CURRENT_RUN_PATH := "user://findhope_current_run.json"
const MANUAL_SLOT_PATTERN := "user://findhope_slot_%d.json"


var profile: Dictionary = {}
var active_run_data: Dictionary = {}
var pending_snapshot: Dictionary = {}

var manual_save_blocks: Dictionary = {}


func _ready():
	load_profile()

	print("")
	print("SAVE MANAGER READY")
	print("Menu state: ", get_menu_state())
	print("Current autosave: ", has_current_run_save())


func default_profile() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"has_started_game": false,
		"has_full_completion": false,
		"achievements": {},
		"android_diaries": [],
		"options": {}
	}


func default_run_data() -> Dictionary:
	return {
		"run_id": "",
		"created_at": "",
		"updated_at": "",
		"last_checkpoint": "",
		"player_profile": {},
		"story": {},
		"atlas": {},
		"stats": {},
		"password": {},
		"custom": {}
	}


func load_profile():
	if not FileAccess.file_exists(PROFILE_PATH):
		profile = default_profile()
		save_profile()
		return

	var loaded = read_json_file(PROFILE_PATH)

	if loaded.is_empty():
		profile = default_profile()
		save_profile()
		return

	profile = default_profile()

	for key in loaded.keys():
		profile[key] = loaded[key]


func save_profile():
	profile["save_version"] = SAVE_VERSION

	if not write_json_file(
		PROFILE_PATH,
		profile
	):
		push_warning(
			"Não foi possível guardar o perfil global."
		)
		return

	profile_changed.emit()


func start_new_run():
	clear_current_autosave()

	active_run_data = default_run_data()

	active_run_data["run_id"] = create_run_id()
	active_run_data["created_at"] = current_datetime()
	active_run_data["updated_at"] = current_datetime()

	manual_save_blocks.clear()

	profile["has_started_game"] = true

	save_profile()

	print("")
	print("NEW RUN CREATED")
	print("Run ID: ", active_run_data["run_id"])


func reset_active_run():
	clear_current_autosave()

	active_run_data = {}
	pending_snapshot = {}

	manual_save_blocks.clear()

	print("")
	print("ACTIVE RUN RESET")
	print("Manual slots preserved.")
	print("Achievements preserved.")
	print("Android diaries preserved.")


func autosave(
	checkpoint_id: String
) -> bool:
	if active_run_data.is_empty():
		push_warning(
			"Autosave ignorado: nenhuma run ativa."
		)

		save_failed.emit(
			"no_active_run"
		)

		return false

	active_run_data["last_checkpoint"] = checkpoint_id
	active_run_data["updated_at"] = current_datetime()

	var snapshot = create_snapshot(
		"autosave",
		0,
		checkpoint_id
	)

	var success = write_json_file(
		CURRENT_RUN_PATH,
		snapshot
	)

	if not success:
		save_failed.emit(
			"autosave_write_failed"
		)

		return false

	print("")
	print("AUTOSAVE COMPLETE")
	print("Checkpoint: ", checkpoint_id)

	save_completed.emit(
		"autosave",
		0
	)

	return true


func save_manual_slot(
	slot: int
) -> bool:
	if not is_valid_slot(slot):
		save_failed.emit(
			"invalid_slot"
		)

		return false

	if active_run_data.is_empty():
		save_failed.emit(
			"no_active_run"
		)

		return false

	if not can_manual_save():
		var reason = get_manual_save_block_reason()

		save_failed.emit(
			"manual_save_blocked:"
			+ reason
		)

		return false

	active_run_data["updated_at"] = current_datetime()

	var snapshot = create_snapshot(
		"manual",
		slot,
		"manual_save"
	)

	var path = get_manual_slot_path(slot)

	var success = write_json_file(
		path,
		snapshot
	)

	if not success:
		save_failed.emit(
			"manual_save_write_failed"
		)

		return false

	print("")
	print("MANUAL SAVE COMPLETE")
	print("Slot: ", slot)

	save_completed.emit(
		"manual",
		slot
	)

	return true


func set_manual_save_block(
	block_id: String,
	blocked: bool
):
	block_id = block_id.strip_edges()

	if block_id.is_empty():
		return

	if blocked:
		manual_save_blocks[block_id] = true
	else:
		manual_save_blocks.erase(
			block_id
		)


func can_manual_save() -> bool:
	if active_run_data.is_empty():
		return false

	return manual_save_blocks.is_empty()


func get_manual_save_block_reason() -> String:
	if active_run_data.is_empty():
		return "Nenhuma run ativa."

	if manual_save_blocks.is_empty():
		return ""

	var names: Array[String] = []

	for block_id in manual_save_blocks.keys():
		match str(block_id):

			"run":
				names.append("RUN")

			"fight":
				names.append("FIGHT")

			"hide":
				names.append("HIDE")

			"cutscene":
				names.append("CUTSCENE")

			_:
				names.append(
					str(block_id).to_upper()
				)

	return (
		"Não é possível salvar durante: "
		+ ", ".join(names)
		+ "."
	)


func get_manual_save_blocks() -> Array:
	return manual_save_blocks.keys()


func create_snapshot(
	save_type: String,
	slot: int,
	checkpoint_id: String
) -> Dictionary:
	var scene_path := ""

	if get_tree().current_scene != null:
		scene_path = (
			get_tree()
			.current_scene
			.scene_file_path
		)

	var snapshot = {
		"save_version": SAVE_VERSION,
		"save_type": save_type,
		"slot": slot,
		"saved_at": current_datetime(),
		"scene_path": scene_path,
		"checkpoint": checkpoint_id,
		"run_data": active_run_data.duplicate(true),
		"nodes": capture_saveable_nodes()
	}

	return snapshot


func capture_saveable_nodes() -> Dictionary:
	var saved_nodes: Dictionary = {}

	var nodes = get_tree().get_nodes_in_group(
		"saveable"
	)

	for node in nodes:
		if not is_instance_valid(node):
			continue

		if not node.has_method(
			"get_save_data"
		):
			continue

		var node_data = node.get_save_data()

		if not (
			node_data is Dictionary
		):
			push_warning(
				"get_save_data() precisa retornar Dictionary em "
				+ str(node.get_path())
			)

			continue

		var save_id = get_node_save_id(
			node
		)

		saved_nodes[save_id] = (
			node_data.duplicate(true)
		)

	return saved_nodes


func get_node_save_id(
	node: Node
) -> String:
	if node.has_method(
		"get_save_id"
	):
		var custom_id = str(
			node.get_save_id()
		).strip_edges()

		if not custom_id.is_empty():
			return custom_id

	return str(
		node.get_path()
	)


func prepare_current_run_load() -> bool:
	if not has_current_run_save():
		return false

	var snapshot = read_json_file(
		CURRENT_RUN_PATH
	)

	if not validate_snapshot(
		snapshot
	):
		return false

	pending_snapshot = (
		snapshot.duplicate(true)
	)

	active_run_data = (
		snapshot.get(
			"run_data",
			default_run_data()
		)
		.duplicate(true)
	)

	manual_save_blocks.clear()

	load_prepared.emit(
		"autosave",
		0
	)

	return true


func prepare_manual_slot_load(
	slot: int
) -> bool:
	if not is_valid_slot(slot):
		return false

	var path = get_manual_slot_path(
		slot
	)

	if not FileAccess.file_exists(path):
		return false

	var snapshot = read_json_file(
		path
	)

	if not validate_snapshot(
		snapshot
	):
		return false

	pending_snapshot = (
		snapshot.duplicate(true)
	)

	active_run_data = (
		snapshot.get(
			"run_data",
			default_run_data()
		)
		.duplicate(true)
	)

	manual_save_blocks.clear()

	load_prepared.emit(
		"manual",
		slot
	)

	return true


func has_pending_load() -> bool:
	return not pending_snapshot.is_empty()


func get_pending_scene_path() -> String:
	if pending_snapshot.is_empty():
		return ""

	return str(
		pending_snapshot.get(
			"scene_path",
			""
		)
	)

func load_prepared_scene(
	fallback_scene_path: String = ""
) -> bool:
	if pending_snapshot.is_empty():
		push_warning(
			"Não existe save preparado para carregar."
		)
		return false

	var scene_path = (
		get_pending_scene_path()
		.strip_edges()
	)

	if scene_path.is_empty():
		scene_path = (
			fallback_scene_path
			.strip_edges()
		)

	if scene_path.is_empty():
		push_warning(
			"O save não possui uma cena válida."
		)
		return false

	print("")
	print("======================================")
	print("LOADING PREPARED SAVE")
	print("SCENE: ", scene_path)
	print("======================================")

	get_tree().paused = false

	var error = (
		get_tree()
		.change_scene_to_file(
			scene_path
		)
	)

	if error != OK:
		push_warning(
			"Não foi possível carregar a cena do save."
		)
		return false

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	apply_pending_snapshot()

	return true

func apply_pending_snapshot():
	if pending_snapshot.is_empty():
		return

	var saved_nodes: Dictionary = (
		pending_snapshot.get(
			"nodes",
			{}
		)
	)

	for save_id in saved_nodes.keys():
		var node = find_saveable_node(
			str(save_id)
		)

		if node == null:
			push_warning(
				"Saveable não encontrado ao carregar: "
				+ str(save_id)
			)

			continue

		if not node.has_method(
			"load_save_data"
		):
			continue

		node.load_save_data(
			saved_nodes[save_id]
		)

	pending_snapshot = {}

	print("")
	print("SAVE SNAPSHOT APPLIED")

	load_applied.emit()


func find_saveable_node(
	save_id: String
) -> Node:
	var nodes = get_tree().get_nodes_in_group(
		"saveable"
	)

	for node in nodes:
		if not is_instance_valid(node):
			continue

		if get_node_save_id(node) == save_id:
			return node

	return null


func has_current_run_save() -> bool:
	return FileAccess.file_exists(
		CURRENT_RUN_PATH
	)


func has_manual_slot(
	slot: int
) -> bool:
	if not is_valid_slot(slot):
		return false

	return FileAccess.file_exists(
		get_manual_slot_path(slot)
	)


func get_manual_slot_info(
	slot: int
) -> Dictionary:
	if not has_manual_slot(slot):
		return {}

	var snapshot = read_json_file(
		get_manual_slot_path(slot)
	)

	if snapshot.is_empty():
		return {}

	var run_data: Dictionary = snapshot.get(
		"run_data",
		{}
	)

	return {
		"slot": slot,
		"saved_at": snapshot.get(
			"saved_at",
			""
		),
		"checkpoint": snapshot.get(
			"checkpoint",
			""
		),
		"run_id": run_data.get(
			"run_id",
			""
		),
		"player_profile": run_data.get(
			"player_profile",
			{}
		)
	}


func get_all_manual_slots() -> Array:
	var slots: Array = []

	for slot in range(
		1,
		SLOT_COUNT + 1
	):
		slots.append(
			get_manual_slot_info(slot)
		)

	return slots


func set_run_value(
	section: String,
	key: String,
	value
):
	if active_run_data.is_empty():
		return

	if not active_run_data.has(section):
		active_run_data[section] = {}

	if not (
		active_run_data[section]
		is Dictionary
	):
		active_run_data[section] = {}

	active_run_data[section][key] = value

	active_run_data["updated_at"] = (
		current_datetime()
	)


func get_run_value(
	section: String,
	key: String,
	default_value = null
):
	if active_run_data.is_empty():
		return default_value

	if not active_run_data.has(section):
		return default_value

	if not (
		active_run_data[section]
		is Dictionary
	):
		return default_value

	return active_run_data[section].get(
		key,
		default_value
	)


func set_player_profile(
	player_profile: Dictionary
):
	if active_run_data.is_empty():
		return

	active_run_data["player_profile"] = (
		player_profile.duplicate(true)
	)

	active_run_data["updated_at"] = (
		current_datetime()
	)


func get_player_profile() -> Dictionary:
	if active_run_data.is_empty():
		return {}

	return (
		active_run_data.get(
			"player_profile",
			{}
		)
		.duplicate(true)
	)


func register_achievement(
	achievement_id: String
):
	if achievement_id.strip_edges().is_empty():
		return

	var achievements: Dictionary = profile.get(
		"achievements",
		{}
	)

	achievements[achievement_id] = {
		"unlocked": true,
		"unlocked_at": current_datetime()
	}

	profile["achievements"] = achievements

	save_profile()


func add_android_diary(
	diary_data: Dictionary
):
	var diaries: Array = profile.get(
		"android_diaries",
		[]
	)

	diaries.append(
		diary_data.duplicate(true)
	)

	profile["android_diaries"] = diaries

	save_profile()


func mark_full_completion():
	profile["has_full_completion"] = true

	save_profile()


func get_menu_state() -> String:
	if bool(
		profile.get(
			"has_full_completion",
			false
		)
	):
		return "completed"

	if bool(
		profile.get(
			"has_started_game",
			false
		)
	):
		return "standard"

	return "initial"


func clear_current_autosave():
	if not FileAccess.file_exists(
		CURRENT_RUN_PATH
	):
		return

	var absolute_path = (
		ProjectSettings.globalize_path(
			CURRENT_RUN_PATH
		)
	)

	var error = DirAccess.remove_absolute(
		absolute_path
	)

	if error != OK:
		push_warning(
			"Não foi possível apagar o autosave atual."
		)


func validate_snapshot(
	snapshot: Dictionary
) -> bool:
	if snapshot.is_empty():
		return false

	if not snapshot.has(
		"save_version"
	):
		return false

	if int(
		snapshot.get(
			"save_version",
			0
		)
	) > SAVE_VERSION:
		push_warning(
			"O save pertence a uma versão mais recente."
		)

		return false

	if not snapshot.has(
		"run_data"
	):
		return false

	return true


func is_valid_slot(
	slot: int
) -> bool:
	return (
		slot >= 1
		and slot <= SLOT_COUNT
	)


func get_manual_slot_path(
	slot: int
) -> String:
	return (
		MANUAL_SLOT_PATTERN
		% slot
	)


func create_run_id() -> String:
	return (
		str(
			Time.get_unix_time_from_system()
		)
		+ "_"
		+ str(
			randi()
		)
	)


func current_datetime() -> String:
	return Time.get_datetime_string_from_system()


func write_json_file(
	path: String,
	data: Dictionary
) -> bool:
	var file = FileAccess.open(
		path,
		FileAccess.WRITE
	)

	if file == null:
		push_warning(
			"Não foi possível abrir para escrita: "
			+ path
		)

		return false

	file.store_string(
		JSON.stringify(
			data,
			"\t"
		)
	)

	file.close()

	return true


func read_json_file(
	path: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return {}

	var content = file.get_as_text()

	file.close()

	var parsed = JSON.parse_string(
		content
	)

	if not (
		parsed is Dictionary
	):
		push_warning(
			"JSON inválido em: "
			+ path
		)

		return {}

	return parsed
