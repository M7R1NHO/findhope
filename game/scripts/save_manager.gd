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

const ATLAS_STATE_URL := "http://127.0.0.1:8000/atlas/state"
const ATLAS_RESET_RUN_URL := "http://127.0.0.1:8000/atlas/reset-run"
const SAVES_API_URL := "http://127.0.0.1:8000/saves"


var profile: Dictionary = {}
var active_run_data: Dictionary = {}
var pending_snapshot: Dictionary = {}

var manual_save_blocks: Dictionary = {}

var backend_state_cache: Dictionary = {}
var backend_request_in_progress: bool = false
var remote_save_metadata: Array = []
var remote_save_metadata_loaded: bool = false


func _ready():
	load_profile()
	# Não bloquear a inicialização do autoload à espera da rede.
	call_deferred("_sync_remote_saves_in_background")

	print("")
	print("SAVE MANAGER READY")
	print("Menu state: ", get_menu_state())
	print("Current autosave: ", has_current_run_save())


func _sync_remote_saves_in_background() -> void:
	await sync_remote_saves_to_local()


func default_profile() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"profile_key": "",
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
		"atlas": {
			"backend_state": {}
		},
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

	ensure_profile_key()
	if str(profile.get("profile_key", "")).is_empty():
		save_profile()


func ensure_profile_key() -> void:
	var existing_key := str(profile.get("profile_key", "")).strip_edges()
	if existing_key.length() >= 32:
		return

	var crypto := Crypto.new()
	profile["profile_key"] = crypto.generate_random_bytes(32).hex_encode()


func save_profile():
	ensure_profile_key()
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

	active_run_data["atlas"] = {
		"backend_state": {}
	}

	backend_state_cache.clear()
	manual_save_blocks.clear()

	profile["has_started_game"] = true

	save_profile()

	print("")
	print("NEW RUN CREATED")
	print("Run ID: ", active_run_data["run_id"])

	await reset_backend_for_new_run()


func reset_backend_for_new_run() -> void:
	var request := HTTPRequest.new()
	request.timeout = 10.0

	add_child(request)

	var error := request.request(
		ATLAS_RESET_RUN_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"run_id": str(active_run_data.get("run_id", ""))})
	)

	if error != OK:
		push_warning(
			"Não foi possível pedir o reinício do estado de Atlas: "
			+ str(error)
		)

		request.queue_free()
		return

	var result = await request.request_completed

	request.queue_free()

	if int(result[1]) != 200:
		push_warning(
			"O backend não confirmou o reinício de Atlas. HTTP: "
			+ str(result[1])
		)
		return

	backend_state_cache.clear()

	print("ATLAS BACKEND RESET FOR NEW RUN")


func get_backend_state_url() -> String:
	var run_id := str(active_run_data.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		return ATLAS_STATE_URL
	return ATLAS_STATE_URL + "?run_id=" + run_id.uri_encode()


func capture_backend_state() -> bool:
	if backend_request_in_progress:
		return false

	backend_request_in_progress = true

	var request := HTTPRequest.new()
	request.timeout = 10.0

	add_child(request)

	var error := request.request(
		get_backend_state_url()
	)

	if error != OK:
		push_warning(
			"Não foi possível obter o estado do backend: "
			+ str(error)
		)

		request.queue_free()
		backend_request_in_progress = false
		return false

	var result = await request.request_completed

	request.queue_free()
	backend_request_in_progress = false

	if int(result[1]) != 200:
		push_warning(
			"Falha ao obter o estado do backend. HTTP: "
			+ str(result[1])
		)
		return false

	var parsed = JSON.parse_string(
		result[3].get_string_from_utf8()
	)

	if not (parsed is Dictionary):
		push_warning(
			"O backend devolveu uma resposta inválida."
		)
		return false

	if not (parsed.get("state", {}) is Dictionary):
		push_warning(
			"O backend devolveu um estado inválido."
		)
		return false

	backend_state_cache = parsed["state"].duplicate(true)

	if not active_run_data.is_empty():
		if not (active_run_data.get("atlas", {}) is Dictionary):
			active_run_data["atlas"] = {}

		active_run_data["atlas"]["backend_state"] = (
			backend_state_cache.duplicate(true)
		)
	return true


func restore_backend_state(state: Dictionary) -> bool:
	if state.is_empty():
		await reset_backend_for_new_run()
		return true

	var request := HTTPRequest.new()
	request.timeout = 10.0

	add_child(request)

	var body := JSON.stringify({
		"run_id": str(active_run_data.get("run_id", "")),
		"state": state
	})

	var error := request.request(
		ATLAS_STATE_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_warning(
			"Não foi possível restaurar o estado do backend: "
			+ str(error)
		)

		request.queue_free()
		return false

	var result = await request.request_completed

	request.queue_free()

	if int(result[1]) != 200:
		push_warning(
			"Falha ao restaurar o estado do backend. HTTP: "
			+ str(result[1])
		)
		return false

	backend_state_cache = state.duplicate(true)

	print("ATLAS BACKEND STATE RESTORED")
	return true


func reset_active_run():
	clear_current_autosave()

	active_run_data = {}
	pending_snapshot = {}

	backend_state_cache.clear()
	manual_save_blocks.clear()

	print("")
	print("ACTIVE RUN RESET")
	print("Manual slots preserved.")
	print("Achievements preserved.")
	print("Android diaries preserved.")


func save_snapshot_remote(snapshot: Dictionary, save_type: String, slot: int) -> bool:
	var profile_key := str(profile.get("profile_key", "")).strip_edges()
	if profile_key.length() < 32:
		push_warning("Não foi possível sincronizar: profile_key inválida.")
		return false

	var slot_type := "auto" if save_type == "autosave" else "manual"
	@warning_ignore("incompatible_ternary")
	var slot_number = null if slot_type == "auto" else slot
	var body := JSON.stringify({
		"profile_key": profile_key,
		"slot_type": slot_type,
		"slot_number": slot_number,
		"snapshot": snapshot,
		"save_name": "Autosave" if slot_type == "auto" else "Slot " + str(slot)
	})

	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)

	var error := request.request(
		SAVES_API_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_warning("Falha ao iniciar sincronização do save: " + str(error))
		request.queue_free()
		return false

	var result = await request.request_completed
	request.queue_free()

	if int(result[1]) != 200:
		push_warning("O save ficou guardado localmente, mas a sincronização falhou. HTTP: " + str(result[1]))
		return false

	var response = JSON.parse_string(result[3].get_string_from_utf8())
	if not (response is Dictionary) or not bool(response.get("success", false)):
		push_warning("O servidor não confirmou a sincronização do save.")
		return false

	print("SAVE SINCRONIZADO COM SUPABASE: ", slot_type, " / ", slot)
	return true


func _sync_snapshot_remote_background(snapshot: Dictionary, save_type: String, slot: int) -> void:
	var remote_ok: bool = await save_snapshot_remote(snapshot, save_type, slot)
	if not remote_ok:
		push_warning("Save local concluído; a sincronização remota falhou para " + save_type + " " + str(slot) + ".")


# =========================================================
# CARREGAMENTO REMOTO (SUPABASE) + FALLBACK LOCAL
# =========================================================

func fetch_remote_snapshot(save_type: String, slot: int) -> Dictionary:
	var profile_key := str(profile.get("profile_key", "")).strip_edges()
	if profile_key.length() < 32:
		push_warning("Não foi possível carregar o save remoto: profile_key inválida.")
		return {}

	var slot_type := "auto" if save_type == "autosave" else "manual"
	var slot_number := 0 if slot_type == "auto" else slot
	var url := SAVES_API_URL + "/" + profile_key + "/" + slot_type + "/" + str(slot_number)

	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)
	var error := request.request(url)
	if error != OK:
		push_warning("Não foi possível iniciar o carregamento remoto: " + str(error))
		request.queue_free()
		return {}

	var result = await request.request_completed
	request.queue_free()
	if int(result[1]) != 200:
		if int(result[1]) != 404:
			push_warning("Falha ao carregar save remoto. HTTP: " + str(result[1]))
		return {}

	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	if not (parsed is Dictionary):
		push_warning("O servidor devolveu uma resposta inválida ao carregar o save.")
		return {}

	var snapshot = parsed.get("snapshot", {})
	if not (snapshot is Dictionary) or not validate_snapshot(snapshot):
		push_warning("O save remoto não contém um snapshot válido.")
		return {}
	return snapshot.duplicate(true)


func prepare_snapshot_for_load(snapshot: Dictionary, save_type: String, slot: int) -> bool:
	if not validate_snapshot(snapshot):
		return false

	pending_snapshot = snapshot.duplicate(true)
	active_run_data = snapshot.get("run_data", default_run_data()).duplicate(true)
	var run_data_atlas = active_run_data.get("atlas", {})
	if not (run_data_atlas is Dictionary):
		run_data_atlas = {}
	var state = snapshot.get("atlas_backend_state", run_data_atlas.get("backend_state", {}))
	if not (state is Dictionary):
		state = {}
	backend_state_cache = state.duplicate(true)
	manual_save_blocks.clear()
	load_prepared.emit(save_type, slot)
	return true


func prepare_current_run_load_any() -> bool:
	# Primeiro tenta a cópia remota; se não existir ou a rede falhar, usa o ficheiro local.
	var remote_snapshot := await fetch_remote_snapshot("autosave", 0)
	if not remote_snapshot.is_empty():
		if not write_json_file(CURRENT_RUN_PATH, remote_snapshot):
			push_warning("O autosave remoto foi carregado, mas não foi possível atualizar a cópia local.")
		return prepare_snapshot_for_load(remote_snapshot, "autosave", 0)
	# Fallback local sem chamar o wrapper, para evitar recursividade.
	var local_snapshot := read_json_file(CURRENT_RUN_PATH)
	if local_snapshot.is_empty():
		return false
	return prepare_snapshot_for_load(local_snapshot, "autosave", 0)


func prepare_manual_slot_load_any(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	var remote_snapshot := await fetch_remote_snapshot("manual", slot)
	if not remote_snapshot.is_empty():
		if not write_json_file(get_manual_slot_path(slot), remote_snapshot):
			push_warning("O slot remoto foi carregado, mas não foi possível atualizar a cópia local.")
		return prepare_snapshot_for_load(remote_snapshot, "manual", slot)
	# Fallback local sem chamar o wrapper, para evitar recursividade.
	var local_snapshot := read_json_file(get_manual_slot_path(slot))
	if local_snapshot.is_empty():
		return false
	return prepare_snapshot_for_load(local_snapshot, "manual", slot)


func list_remote_saves() -> Array:
	var profile_key := str(profile.get("profile_key", "")).strip_edges()
	if profile_key.length() < 32:
		return []
	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)
	var error := request.request(SAVES_API_URL + "/" + profile_key)
	if error != OK:
		push_warning("Não foi possível iniciar a listagem de saves remotos: " + str(error))
		request.queue_free()
		return []
	var result = await request.request_completed
	request.queue_free()
	if int(result[1]) != 200:
		push_warning("Falha ao listar saves remotos. HTTP: " + str(result[1]))
		return []
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	if not (parsed is Dictionary):
		return []
	var saves = parsed.get("saves", [])
	remote_save_metadata = saves.duplicate(true) if saves is Array else []
	remote_save_metadata_loaded = true
	return remote_save_metadata.duplicate(true)


func sync_remote_saves_to_local() -> void:
	# A interface só precisa dos metadados. O snapshot completo é descarregado
	# apenas quando o jogador escolhe um slot, evitando vários pedidos em série.
	await list_remote_saves()


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

	if not await capture_backend_state():
		save_failed.emit("atlas_state_capture_failed")
		return false

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

	# O save local já está concluído. Sincronizar em segundo plano para não
	# bloquear o jogo/menu enquanto o servidor responde.
	call_deferred("_sync_snapshot_remote_background", snapshot.duplicate(true), "autosave", 0)

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

	if not await capture_backend_state():
		save_failed.emit("atlas_state_capture_failed")
		return false

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

	# O save local já está concluído. A sincronização remota não deve bloquear
	# o botão Confirmar nem a interface de pausa.
	call_deferred("_sync_snapshot_remote_background", snapshot.duplicate(true), "manual", slot)

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
		"atlas_backend_state": backend_state_cache.duplicate(true),
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
	return await prepare_current_run_load_any()

func prepare_manual_slot_load(slot: int) -> bool:
	return await prepare_manual_slot_load_any(slot)

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

	if not await apply_pending_snapshot():
		return false

	return true


func apply_pending_snapshot() -> bool:
	if pending_snapshot.is_empty():
		return false

	var saved_nodes: Dictionary = (
		pending_snapshot.get(
			"nodes",
			{}
		)
	)

	var run_data: Dictionary = pending_snapshot.get(
		"run_data",
		{}
	)

	var atlas_data = run_data.get(
		"atlas",
		{}
	)

	if not (atlas_data is Dictionary):
		atlas_data = {}

	var saved_backend_state = pending_snapshot.get(
		"atlas_backend_state",
		atlas_data.get(
			"backend_state",
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

	if saved_backend_state is Dictionary:
		if not await restore_backend_state(saved_backend_state):
			save_failed.emit("atlas_state_restore_failed")
			return false

	pending_snapshot = {}

	print("")
	print("SAVE SNAPSHOT APPLIED")

	load_applied.emit()
	return true


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


func has_manual_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	if FileAccess.file_exists(get_manual_slot_path(slot)):
		return true
	for entry in remote_save_metadata:
		if not (entry is Dictionary):
			continue
		if str(entry.get("slot_type", "")) == "manual" and int(entry.get("slot_number", 0)) == slot:
			return true
	return false


func get_manual_slot_info(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	# Preferir o snapshot local, se existir, para mostrar informação detalhada.
	if FileAccess.file_exists(get_manual_slot_path(slot)):
		var snapshot: Dictionary = read_json_file(get_manual_slot_path(slot))
		if not snapshot.is_empty():
			var run_data: Dictionary = snapshot.get("run_data", {})
			return {
				"slot": slot,
				"saved_at": snapshot.get("saved_at", ""),
				"checkpoint": snapshot.get("checkpoint", ""),
				"run_id": run_data.get("run_id", ""),
				"player_profile": run_data.get("player_profile", {})
			}
	# Sem cache local, usar os metadados recebidos da API.
	for entry in remote_save_metadata:
		if not (entry is Dictionary):
			continue
		if str(entry.get("slot_type", "")) != "manual" or int(entry.get("slot_number", 0)) != slot:
			continue
		return {
			"slot": slot,
			"saved_at": str(entry.get("updated_at", entry.get("created_at", ""))),
			"checkpoint": str(entry.get("save_name", "Save manual")),
			"run_id": str(entry.get("run_id", "")),
			"player_profile": {}
		}
	return {}


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

func delete_all_manual_slots() -> bool:
	print("[SAVES] A iniciar eliminação dos slots.")
	var all_deleted := true

	for slot in range(1, SLOT_COUNT + 1):
		var path := get_manual_slot_path(slot)
		print("[SAVES] Slot ", slot, ": ", path)
		print("[SAVES] Existe antes de apagar: ", FileAccess.file_exists(path))

		if not FileAccess.file_exists(path):
			continue

		var absolute_path := ProjectSettings.globalize_path(path)
		var error := DirAccess.remove_absolute(absolute_path)
		print("[SAVES] Resultado da eliminação: ", error)
		print("[SAVES] Existe depois de apagar: ", FileAccess.file_exists(path))

		if error != OK:
			all_deleted = false
			push_warning(
				"Não foi possível apagar o Slot "
				+ str(slot)
				+ ". Erro: "
				+ str(error)
			)

	if all_deleted:
		print("TODOS OS SLOTS MANUAIS FORAM APAGADOS.")

	return all_deleted

func set_run_value(
	section: String,
	key: String,
	value
):
	if active_run_data.is_empty():
		push_warning(
			"SaveManager: não foi possível guardar '"
			+ key
			+ "' porque não existe uma run ativa."
		)
		return

	if not active_run_data.has(section):
		active_run_data[section] = {}

	if not (active_run_data[section] is Dictionary):
		active_run_data[section] = {}

	active_run_data[section][key] = value
	active_run_data["updated_at"] = current_datetime()

	print(
		"[SAVE MANAGER] ",
		section,
		".",
		key,
		" = ",
		value
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
	
	
