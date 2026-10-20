extends Node


signal save_completed(save_type: String, slot: int)
signal load_prepared(save_type: String, slot: int)
signal load_applied
signal save_failed(reason: String)
signal profile_changed
signal remote_saves_updated


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
var last_error: String = ""
var save_in_progress: bool = false
var load_in_progress: bool = false
var remote_upload_in_progress: bool = false
var remote_upload_queue: Dictionary = {}
var last_snapshot_msec: int = 0


func _ready():
	# Os pedidos HTTP e respetivos timeouts têm de funcionar no menu de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if not FileAccess.file_exists(PROFILE_PATH) and not FileAccess.file_exists(PROFILE_PATH + ".bak"):
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

	var previous_key := str(profile.get("profile_key", ""))
	ensure_profile_key()
	if str(profile.get("profile_key", "")) != previous_key:
		save_profile()


func ensure_profile_key() -> void:
	var existing_key := str(profile.get("profile_key", "")).strip_edges()
	if existing_key.length() >= 32 and existing_key.length() <= 128:
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


func start_new_run() -> bool:
	if save_in_progress or load_in_progress:
		return _fail("Aguarda a conclusão da operação em curso.")
	load_in_progress = true
	var previous_run := active_run_data.duplicate(true)
	var previous_cache := backend_state_cache.duplicate(true)
	active_run_data = default_run_data()
	active_run_data["run_id"] = create_run_id()
	active_run_data["created_at"] = current_datetime()
	active_run_data["updated_at"] = current_datetime()
	backend_state_cache.clear()
	if not await reset_backend_for_new_run():
		active_run_data = previous_run
		backend_state_cache = previous_cache
		load_in_progress = false
		return _fail("Não foi possível iniciar o Atlas. Liga o backend antes de iniciar uma nova partida.")
	pending_snapshot.clear()
	clear_current_autosave()
	manual_save_blocks.clear()
	profile["has_started_game"] = true
	save_profile()
	load_in_progress = false
	return true


func reset_backend_for_new_run() -> bool:
	var run_id := str(active_run_data.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		push_warning("Não foi possível reiniciar Atlas: run_id vazio.")
		return false

	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
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
		return false

	var result = await request.request_completed

	request.queue_free()

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		push_warning(
			"O backend não confirmou o reinício de Atlas. HTTP: "
			+ str(result[1])
		)
		return false

	var response = JSON.parse_string(result[3].get_string_from_utf8())
	if not (response is Dictionary) or str(response.get("status", "")) != "Atlas run reset":
		push_warning("O backend devolveu uma confirmação inválida ao reiniciar Atlas.")
		return false

	var reset_state = response.get("state", {})
	if not (reset_state is Dictionary):
		push_warning("O backend devolveu um estado inválido ao reiniciar Atlas.")
		return false
	backend_state_cache = reset_state.duplicate(true)

	print("ATLAS BACKEND RESET FOR NEW RUN")
	return true


func get_backend_state_url() -> String:
	var run_id := str(active_run_data.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		return ""
	return ATLAS_STATE_URL + "?run_id=" + run_id.uri_encode()


func capture_backend_state() -> bool:
	# Dois saves quase simultâneos (duplo clique, autosave + manual) não devem
	# falhar: o segundo espera pelo primeiro em vez de devolver false.
	var wait_until := Time.get_ticks_msec() + 12000
	while backend_request_in_progress and Time.get_ticks_msec() < wait_until:
		await get_tree().process_frame

	if backend_request_in_progress:
		return false

	var state_url := get_backend_state_url()
	var requested_run_id := str(active_run_data.get("run_id", ""))
	if state_url.is_empty():
		push_warning("Não foi possível obter o estado do Atlas: run_id vazio.")
		return false

	backend_request_in_progress = true

	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 10.0

	add_child(request)

	var error := request.request(
		state_url
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

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
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

	if str(parsed.get("run_id", "")) != requested_run_id or str(active_run_data.get("run_id", "")) != requested_run_id:
		return false
	if not (parsed.get("state") is Dictionary):
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
	var run_id := str(active_run_data.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		push_warning("Não foi possível restaurar Atlas: run_id vazio.")
		return false

	if state.is_empty():
		# Um estado vazio só é aceite se o backend confirmar o reset.
		return await reset_backend_for_new_run()

	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 10.0

	add_child(request)

	var body := JSON.stringify({
		"run_id": run_id,
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

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		push_warning(
			"Falha ao restaurar o estado do backend. HTTP: "
			+ str(result[1])
		)
		return false

	var response = JSON.parse_string(result[3].get_string_from_utf8())
	if not (response is Dictionary) or not (response.get("state") is Dictionary):
		push_warning("O backend não devolveu o estado restaurado de Atlas.")
		return false
	if str(response.get("run_id", "")) != run_id:
		push_warning("O backend confirmou uma run diferente da selecionada.")
		return false

	backend_state_cache = response["state"].duplicate(true)
	if not (active_run_data.get("atlas", {}) is Dictionary):
		active_run_data["atlas"] = {}
	active_run_data["atlas"]["backend_state"] = backend_state_cache.duplicate(true)

	print("ATLAS BACKEND STATE RESTORED: ", run_id)
	return true


func reset_active_run():
	clear_current_autosave()
	save_profile()

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
	request.process_mode = Node.PROCESS_MODE_ALWAYS
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

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		push_warning("O save ficou guardado localmente, mas a sincronização falhou. HTTP: " + str(result[1]))
		return false

	var response = JSON.parse_string(result[3].get_string_from_utf8())
	if not (response is Dictionary) or not bool(response.get("success", false)):
		push_warning("O servidor não confirmou a sincronização do save.")
		return false

	print("SAVE SINCRONIZADO COM SUPABASE: ", slot_type, " / ", slot)
	return true


func _sync_snapshot_remote_background(snapshot: Dictionary, save_type: String, slot: int) -> void:
	if not validate_snapshot(snapshot):
		return
	var queue_key := save_type + ":" + str(slot)
	if remote_upload_queue.has(queue_key):
		var queued: Dictionary = remote_upload_queue[queue_key]["snapshot"]
		if _prefer_local_snapshot(queued, snapshot):
			return
	remote_upload_queue[queue_key] = {
		"snapshot": snapshot.duplicate(true), "save_type": save_type, "slot": slot
	}
	if remote_upload_in_progress:
		return
	remote_upload_in_progress = true
	while not remote_upload_queue.is_empty():
		var key = remote_upload_queue.keys()[0]
		var item: Dictionary = remote_upload_queue[key]
		remote_upload_queue.erase(key)
		var remote_ok := await save_snapshot_remote(item["snapshot"], item["save_type"], item["slot"])
		if not remote_ok:
			push_warning("Save local concluído; sincronização remota pendente para " + str(key) + ".")
	remote_upload_in_progress = false


func fetch_remote_snapshot(save_type: String, slot: int) -> Dictionary:
	var profile_key := str(profile.get("profile_key", "")).strip_edges()
	if profile_key.length() < 32:
		push_warning("Não foi possível carregar o save remoto: profile_key inválida.")
		return {}

	var slot_type := "auto" if save_type == "autosave" else "manual"
	var slot_number := 0 if slot_type == "auto" else slot
	var url := SAVES_API_URL + "/" + profile_key + "/" + slot_type + "/" + str(slot_number)

	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 15.0
	add_child(request)
	var error := request.request(url)
	if error != OK:
		push_warning("Não foi possível iniciar o carregamento remoto: " + str(error))
		request.queue_free()
		return {}

	var result = await request.request_completed
	request.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
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
		return _fail("A gravação selecionada está incompleta ou pertence a outra versão.")
	pending_snapshot = snapshot.duplicate(true)
	# A seleção do slot não altera a partida que ainda está no ecrã.
	pending_snapshot["save_type"] = save_type
	pending_snapshot["slot"] = slot
	load_prepared.emit(save_type, slot)
	return true


func _snapshot_saved_at(snapshot: Dictionary) -> String:
	return str(snapshot.get("saved_at", "")).strip_edges()


func prepare_current_run_load_any() -> bool:
	return await _prepare_slot_load("autosave", 0, CURRENT_RUN_PATH)


func prepare_manual_slot_load_any(slot: int) -> bool:
	if not is_valid_slot(slot):
		return _fail("O slot selecionado é inválido.")
	return await _prepare_slot_load("manual", slot, get_manual_slot_path(slot))


func list_remote_saves() -> Array:
	var profile_key := str(profile.get("profile_key", "")).strip_edges()
	if profile_key.length() < 32:
		return []
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 15.0
	add_child(request)
	var error := request.request(SAVES_API_URL + "/" + profile_key)
	if error != OK:
		push_warning("Não foi possível iniciar a listagem de saves remotos: " + str(error))
		request.queue_free()
		return []
	var result = await request.request_completed
	request.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		push_warning("Falha ao listar saves remotos. HTTP: " + str(result[1]))
		return []
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	if not (parsed is Dictionary):
		return []
	var saves = parsed.get("saves", [])
	remote_save_metadata = saves.duplicate(true) if saves is Array else []
	remote_save_metadata_loaded = true
	remote_saves_updated.emit()
	return remote_save_metadata.duplicate(true)


func sync_remote_saves_to_local() -> void:
	# A interface só precisa dos metadados. O snapshot completo é descarregado
	# apenas quando o jogador escolhe um slot, evitando vários pedidos em série.
	await list_remote_saves()


func autosave(checkpoint_id: String) -> bool:
	return await _save_game("autosave", 0, checkpoint_id)


func save_manual_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return _fail("O slot selecionado é inválido.")
	if not can_manual_save():
		return _fail(get_manual_save_block_reason())
	return await _save_game("manual", slot, "manual_save")


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

	return manual_save_blocks.is_empty() and _runtime_save_block_reason().is_empty()


func get_manual_save_block_reason() -> String:
	if active_run_data.is_empty():
		return "Nenhuma run ativa."

	if manual_save_blocks.is_empty():
		return _runtime_save_block_reason()

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


func _runtime_save_block_reason() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "Aguarda a abertura da partida."
	var checks := {
		"FightManager": ["fight_active"],
		"HackManager": ["hack_active"],
		"UndergroundRoot/AlienEncounterManager": [
			"encounter_active", "hide_initial_active", "hide_initial_waiting_for_run",
			"run_minigame_active", "run_closing_active", "hide_event_active"
		]
	}
	for node_path in checks:
		var node := scene.get_node_or_null(NodePath(node_path))
		if node == null:
			continue
		for property_name in checks[node_path]:
			if bool(node.get(property_name)):
				return "Conclui o combate, perseguição ou minijogo antes de guardar."
	return ""


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
		"saved_at_unix_ms": _next_snapshot_msec(),
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


func load_prepared_scene(fallback_scene_path: String = "") -> bool:
	if load_in_progress or save_in_progress:
		return _fail("Aguarda a conclusão da gravação ou do carregamento em curso.")
	if not validate_snapshot(pending_snapshot):
		return _fail("Não existe uma gravação válida preparada para carregar.")
	var scene_path := get_pending_scene_path().strip_edges()
	if scene_path.is_empty():
		scene_path = fallback_scene_path.strip_edges()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return _fail("A cena desta gravação não existe no projeto.")

	load_in_progress = true
	last_error = ""
	var was_paused := get_tree().paused
	var previous_run := active_run_data.duplicate(true)
	var previous_cache := backend_state_cache.duplicate(true)
	get_tree().paused = true
	active_run_data = pending_snapshot["run_data"].duplicate(true)
	var atlas_data: Dictionary = active_run_data.get("atlas", {})
	var state: Dictionary = pending_snapshot.get("atlas_backend_state", atlas_data.get("backend_state", {}))

	# Confirmar Atlas antes de destruir a cena atual. Uma falha mantém o jogador no menu.
	if not await restore_backend_state(state):
		active_run_data = previous_run
		backend_state_cache = previous_cache
		pending_snapshot.clear()
		get_tree().paused = was_paused
		load_in_progress = false
		return _fail("Não foi possível recuperar o Atlas. Confirma que o backend está ligado e volta a carregar.")

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		active_run_data = previous_run
		backend_state_cache = previous_cache
		if not previous_run.is_empty():
			await restore_backend_state(previous_cache)
		get_tree().paused = was_paused
		load_in_progress = false
		return _fail("Não foi possível abrir a cena da gravação.")
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	# Permitir a criação diferida de portas e os resolve_nodes(), sem física em curso.
	await get_tree().process_frame
	manual_save_blocks.clear()
	var applied := await apply_pending_snapshot()
	load_in_progress = false
	get_tree().paused = false
	return applied


func apply_pending_snapshot() -> bool:
	if pending_snapshot.is_empty():
		return false

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

	# Depois de carregar um slot manual, esse estado passa a ser o autosave da
	# run. Assim CONTINUAR JOGO retoma onde carregaste (local e remoto) e não
	# um checkpoint antigo.
	if str(pending_snapshot.get("save_type", "")) == "manual":
		var as_autosave: Dictionary = pending_snapshot.duplicate(true)
		as_autosave["save_type"] = "autosave"
		as_autosave["slot"] = 0
		as_autosave["saved_at"] = current_datetime()
		as_autosave["saved_at_unix_ms"] = _next_snapshot_msec()
		as_autosave["run_data"] = active_run_data.duplicate(true)
		profile["ignore_remote_autosave"] = false
		save_profile()
		if not write_json_file(CURRENT_RUN_PATH, as_autosave):
			push_warning("Não foi possível atualizar o autosave local após carregar o slot.")
		call_deferred("_sync_snapshot_remote_background", as_autosave.duplicate(true), "autosave", 0)

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
	if not _read_valid_snapshot(CURRENT_RUN_PATH).is_empty():
		return true
	if bool(profile.get("ignore_remote_autosave", false)):
		return false
	for entry in remote_save_metadata:
		if entry is Dictionary and str(entry.get("slot_type", "")) == "auto":
			return true
	return false


func has_manual_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	if not _read_valid_snapshot(get_manual_slot_path(slot)).is_empty():
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
	if has_manual_slot(slot):
		var snapshot: Dictionary = _read_valid_snapshot(get_manual_slot_path(slot))
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
	if save_in_progress or load_in_progress:
		return _fail("Aguarda a conclusão da operação em curso.")
	load_in_progress = true
	# Terminar pedidos anteriores antes do DELETE, para não recriarem os slots.
	while remote_upload_in_progress:
		await get_tree().process_frame
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 15.0
	add_child(request)
	var error := request.request(
		SAVES_API_URL + "/" + str(profile.get("profile_key", "")) + "/manual",
		[], HTTPClient.METHOD_DELETE
	)
	if error != OK:
		request.queue_free()
		load_in_progress = false
		return _fail("Não foi possível apagar as cópias remotas. Os slots locais foram preservados.")
	var result = await request.request_completed
	request.queue_free()
	var response = JSON.parse_string(result[3].get_string_from_utf8())
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200 or not (response is Dictionary) or not bool(response.get("success", false)):
		load_in_progress = false
		return _fail("Não foi possível apagar as cópias remotas. Os slots locais foram preservados.")
	var all_deleted := true
	for slot in range(1, SLOT_COUNT + 1):
		var path := get_manual_slot_path(slot)
		for candidate in [path, path + ".bak", path + ".tmp"]:
			if FileAccess.file_exists(candidate):
				if DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate)) != OK:
					all_deleted = false
	remote_save_metadata = remote_save_metadata.filter(
		func(entry): return entry is Dictionary and str(entry.get("slot_type", "")) != "manual"
	)
	load_in_progress = false
	remote_saves_updated.emit()
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
	# Um autosave remoto de uma partida anterior não deve reaparecer em CONTINUAR.
	profile["ignore_remote_autosave"] = true
	remote_upload_queue.erase("autosave:0")
	for path in [CURRENT_RUN_PATH, CURRENT_RUN_PATH + ".bak", CURRENT_RUN_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				push_warning("Não foi possível apagar o autosave atual.")


func validate_snapshot(snapshot: Dictionary) -> bool:
	var version = snapshot.get("save_version")
	if not (version is int or version is float) or version < 1 or version > SAVE_VERSION or float(int(version)) != version:
		return false
	var run_data = snapshot.get("run_data")
	if not (run_data is Dictionary) or str(run_data.get("run_id", "")).strip_edges().is_empty():
		return false
	if not (snapshot.get("scene_path", "") is String):
		return false
	for key in ["atlas", "story", "player_profile", "stats", "password", "custom"]:
		if run_data.has(key) and not (run_data[key] is Dictionary):
			return false
	var atlas_data: Dictionary = run_data.get("atlas", {})
	if not (snapshot.get("atlas_backend_state", atlas_data.get("backend_state", {})) is Dictionary):
		return false
	var nodes = snapshot.get("nodes", {})
	if not (nodes is Dictionary):
		return false
	for value in nodes.values():
		if not (value is Dictionary):
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


func write_json_file(path: String, data: Dictionary) -> bool:
	# Só substituir a gravação depois de escrever e validar a cópia temporária.
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_json_exact(temp_path).is_empty():
		return false
	var previous := _read_json_exact(path)
	var previous_valid := not previous.is_empty()
	if path != PROFILE_PATH:
		previous_valid = validate_snapshot(previous)
	if previous_valid:
		var backup_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")
		)
		if backup_error != OK:
			return false
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path)
	) == OK


func read_json_file(path: String) -> Dictionary:
	var result := _read_json_exact(path)
	if result.is_empty():
		result = _read_json_exact(path + ".bak")
	return result


func _read_json_exact(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not (parser.data is Dictionary):
		return {}
	return parser.data


func _read_valid_snapshot(path: String) -> Dictionary:
	var snapshot := _read_json_exact(path)
	if validate_snapshot(snapshot):
		return snapshot
	snapshot = _read_json_exact(path + ".bak")
	return snapshot if validate_snapshot(snapshot) else {}


func _prefer_local_snapshot(local: Dictionary, remote: Dictionary) -> bool:
	if not validate_snapshot(local):
		return false
	if not validate_snapshot(remote):
		return true
	if local.has("saved_at_unix_ms") and remote.has("saved_at_unix_ms"):
		return int(local["saved_at_unix_ms"]) >= int(remote["saved_at_unix_ms"])
	return _snapshot_saved_at(local) >= _snapshot_saved_at(remote)


func _prepare_slot_load(save_type: String, slot: int, path: String) -> bool:
	if load_in_progress or save_in_progress:
		return _fail("Aguarda a conclusão da operação em curso.")
	load_in_progress = true
	last_error = ""
	var local := _read_valid_snapshot(path)
	var remote: Dictionary = {}
	if save_type != "autosave" or not bool(profile.get("ignore_remote_autosave", false)):
		remote = await fetch_remote_snapshot(save_type, slot)
	# Pode ter chegado uma gravação ao disco durante o pedido de rede.
	local = _read_valid_snapshot(path)
	load_in_progress = false
	var chosen: Dictionary = local if _prefer_local_snapshot(local, remote) else remote
	if chosen.is_empty():
		return _fail("Não foi encontrada uma cópia válida desta gravação. Confirma a ligação ao backend.")
	if chosen == remote and remote != local:
		if not write_json_file(path, chosen):
			push_warning("Não foi possível atualizar a cópia local da gravação remota.")
	return prepare_snapshot_for_load(chosen, save_type, slot)


func _next_snapshot_msec() -> int:
	last_snapshot_msec = maxi(last_snapshot_msec + 1, int(Time.get_unix_time_from_system() * 1000.0))
	return last_snapshot_msec


func _save_game(save_type: String, slot: int, checkpoint_id: String) -> bool:
	if active_run_data.is_empty():
		return _fail("Não existe uma partida ativa para guardar.")
	if load_in_progress or has_pending_load():
		return _fail("Aguarda o carregamento da partida antes de guardar.")
	var run_id := str(active_run_data.get("run_id", ""))
	var scene := get_tree().current_scene
	while save_in_progress:
		await get_tree().process_frame
	if load_in_progress or has_pending_load() or run_id != str(active_run_data.get("run_id", "")) or scene != get_tree().current_scene:
		return _fail("A partida mudou durante a gravação. Tenta guardar novamente.")
	if save_type == "manual" and not can_manual_save():
		return _fail(get_manual_save_block_reason())
	save_in_progress = true
	last_error = ""
	if not await capture_backend_state():
		save_in_progress = false
		return _fail("Não foi possível obter o estado do Atlas. Confirma que o backend está ligado e tenta novamente.")
	if not is_instance_valid(scene) or scene != get_tree().current_scene or run_id != str(active_run_data.get("run_id", "")):
		save_in_progress = false
		return _fail("A cena mudou antes de terminar a gravação.")
	active_run_data["updated_at"] = current_datetime()
	if save_type == "autosave":
		active_run_data["last_checkpoint"] = checkpoint_id
	var snapshot := create_snapshot(save_type, slot, checkpoint_id)
	var path := CURRENT_RUN_PATH if save_type == "autosave" else get_manual_slot_path(slot)
	var success := write_json_file(path, snapshot)
	save_in_progress = false
	if not success:
		return _fail("Não foi possível escrever a gravação no disco. A cópia anterior foi preservada.")
	if save_type == "autosave":
		profile["ignore_remote_autosave"] = false
		save_profile()
	call_deferred("_sync_snapshot_remote_background", snapshot.duplicate(true), save_type, slot)
	save_completed.emit(save_type, slot)
	return true


func _fail(message: String) -> bool:
	last_error = message
	push_warning(message)
	save_failed.emit(message)
	return false
