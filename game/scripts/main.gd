
extends Node2D


@onready var atlas_api: HTTPRequest = $AtlasAPI
@onready var autonomy_api: HTTPRequest = $AutonomyAPI
@onready var protocol_api: HTTPRequest = $ProtocolAPI

@onready var atlas: CharacterBody2D = $Atlas
@onready var protocol_door: Area2D = $ProtocolDoor

@onready var chat_history: RichTextLabel = \
	$UI/ChatPanel/VBoxContainer/ChatHistory

@onready var chat_input: LineEdit = \
	$UI/ChatPanel/VBoxContainer/ChatInput


const CHAT_URL := "http://127.0.0.1:8000/chat"

const AUTONOMY_EVENT_URL := \
	"http://127.0.0.1:8000/atlas/autonomy/event"

const AUTONOMY_STATE_URL := \
	"http://127.0.0.1:8000/atlas/autonomy"

const GAMEPLAY_CONTEXT_EVENT_URL := \
	"http://127.0.0.1:8000/gameplay/context/event"

const ATLAS_MEMORY_URL := \
	"http://127.0.0.1:8000/atlas/memory"

# Atlas 2.0: comportamentos observados e falas espontâneas.
const BEHAVIOR_EVENT_URL := \
	"http://127.0.0.1:8000/atlas/behavior/event"

const SPONTANEOUS_URL := \
	"http://127.0.0.1:8000/atlas/spontaneous"

# Contador em run.stats (para Conquistas, Bíblia secção 18) de cada evento.
const BEHAVIOR_STATS := {
	"run_escaped": "run_escapes",
	"fight_won": "fights_won",
	"hide_success": "hides_success",
	"hide_failed": "hides_failed",
	"hack_success": "hacks_success",
	"hack_failed": "hacks_failed",
	"overload_used": "overloads_used",
	"maintenance_used": "maintenance_used",
}

# Respostas do formulário Project Find Hope que o Atlas deve lembrar.
const FORM_MEMORY_FIELDS := {
	"name": ["identity", "name", 0.95, "nome"],
	"age": ["identity", "age", 0.6, "idade"],
	"gender": ["identity", "gender", 0.5, "género"],
	"has_children": ["identity", "has_children", 0.6, "tem filhos"],
	"volunteer_reason": ["goal", "volunteer_reason", 0.8, "razão para se voluntariar"],
	"worked_with_android": ["experience", "worked_with_pyssoa_android", 0.6, "já trabalhou com um androide PYSSOA"],
	"comfortable_with_androids": ["belief", "comfortable_with_androids", 0.7, "sente-se confortável com androides"],
	"android_emergency_decision": ["belief", "android_may_act_without_authorization", 0.8, "um androide pode agir sem autorização numa emergência"],
	"protocol_or_life": ["belief", "protocol_or_human_life", 0.8, "numa emergência deve prevalecer"],
}


const NORMAL_PLACEHOLDER := "Escreva uma mensagem..."
const WAITING_PLACEHOLDER := "Android está a responder..."

const MAX_VISIBLE_MESSAGES := 10


const ALLOWED_AUTONOMY_EVENTS := [
	"independent_choice",
	"question_protocol",
	"break_protocol",
	"protect_player_by_choice",
]


var waiting_for_atlas: bool = false
var autonomy_request_in_progress: bool = false
var protocol_request_in_progress: bool = false
var protocol_door_examined: bool = false

var protocol_api_mode: String = ""

var gameplay_context_api: HTTPRequest = null
var gameplay_context_queue: Array[Dictionary] = []
var gameplay_context_in_progress: bool = false

var behavior_api: HTTPRequest = null
var behavior_queue: Array[Dictionary] = []
var behavior_in_progress: bool = false
var behavior_event_counter: int = 0

var spontaneous_api: HTTPRequest = null
var spontaneous_queue: Array[String] = []
var spontaneous_in_progress: bool = false

var visible_messages: Array[String] = []

var surface_recovery_active: bool = false
var surface_recovery_step: int = 0
var surface_recovery_questions: Array[String] = [
	"Consegues ouvir-me?",
	"Consegues ver-me?",
	"Sentes alguma dor?",
	"Consegues mexer os braços e as pernas?",
	"Consegues levantar-te?"
]
var scanner_hint_layer: CanvasLayer


func _ready():
	atlas_api.request_completed.connect(
		_on_atlas_api_request_completed
	)

	autonomy_api.request_completed.connect(
		_on_autonomy_api_request_completed
	)

	protocol_api.request_completed.connect(
		_on_protocol_api_request_completed
	)

	gameplay_context_api = HTTPRequest.new()
	gameplay_context_api.name = "GameplayContextAPI"
	gameplay_context_api.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gameplay_context_api)
	gameplay_context_api.request_completed.connect(
		_on_gameplay_context_request_completed
	)

	behavior_api = HTTPRequest.new()
	behavior_api.name = "BehaviorAPI"
	behavior_api.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(behavior_api)
	behavior_api.request_completed.connect(_on_behavior_request_completed)

	spontaneous_api = HTTPRequest.new()
	spontaneous_api.name = "SpontaneousAPI"
	spontaneous_api.process_mode = Node.PROCESS_MODE_ALWAYS
	spontaneous_api.timeout = 20.0
	add_child(spontaneous_api)
	spontaneous_api.request_completed.connect(_on_spontaneous_request_completed)

	chat_input.text_submitted.connect(
		_on_chat_input_submitted
	)

	atlas.sensor_message.connect(
		_on_atlas_sensor_message
	)

	protocol_door_examined = bool(
		SaveManager.get_run_value(
			"story",
			"protocol_door_examined",
			false
		)
	)

	chat_input.placeholder_text = NORMAL_PLACEHOLDER

	chat_history.clear()

	add_chat_message(
		"ANDROID",
		"Sistema de comunicação operacional."
	)

	# Verificar se a introdução já foi concluída nesta partida.
	if SaveManager.has_pending_load():
		# Não reiniciar a cutscene durante o restauro. Verificar a recuperação
		# depois de o carregamento terminar.
		call_deferred("_resume_surface_recovery_after_load")
		return
	var intro_completed: bool = bool(
		SaveManager.get_run_value(
			"story",
			"intro_completed",
			false
		)
	)

	if not intro_completed:
		SaveManager.set_manual_save_block("cutscene", true)
		var intro = preload(
			"res://scripts/intro_sequence.gd"
		).new()

		add_child(intro)

		# Esperar que a cutscene termine antes de guardar.
		await intro.play()

		var player_node = get_node_or_null("Player")
		if player_node != null and player_node.has_method("set_tutorial_locked"):
			player_node.set_tutorial_locked(true)

		await _run_surface_recovery()
		SaveManager.set_manual_save_block("cutscene", false)

		SaveManager.set_run_value(
			"story",
			"intro_completed",
			true
		)

		# O Atlas fica a conhecer o formulário e o desvio de rota antes
		# do autosave, para que esse estado já vá no snapshot.
		await register_intro_with_atlas()

		# Guardar imediatamente a conclusão da introdução.
		var save_success: bool = await SaveManager.autosave(
			"intro_completed"
		)

		if not save_success:
			push_warning(
				"Não foi possível guardar automaticamente "
				+ "a conclusão da introdução."
			)
	else:
		var recovery_completed: bool = bool(
			SaveManager.get_run_value(
				"story",
				"surface_recovery_complete",
				false
			)
		)
		if not recovery_completed:
			# Compatibilidade com saves de teste onde a introdução já ficou marcada,
			# mas as cinco verificações ainda não foram concluídas.
			SaveManager.set_manual_save_block("cutscene", true)
			var saved_player = get_node_or_null("Player")
			if saved_player != null and saved_player.has_method("set_tutorial_locked"):
				saved_player.set_tutorial_locked(true)
			await _run_surface_recovery()
			SaveManager.set_manual_save_block("cutscene", false)
		else:
			_create_scanner_hint()
			print("INTRODUÇÃO IGNORADA: SAVE JÁ A CONCLUIU.")



func _resume_surface_recovery_after_load() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if bool(SaveManager.get_run_value("story", "surface_recovery_complete", false)):
		_create_scanner_hint()
		return

	SaveManager.set_manual_save_block("cutscene", true)
	var player_node = get_node_or_null("Player")
	if player_node != null and player_node.has_method("set_tutorial_locked"):
		player_node.set_tutorial_locked(true)
	await _run_surface_recovery()
	SaveManager.set_manual_save_block("cutscene", false)


func _input(event):
	# ATALHO DE TESTE: entrar diretamente no subterraneo.
	# Só existe em builds de debug (editor); desaparece no jogo exportado.
	if (
		OS.is_debug_build()
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_U
		and event.ctrl_pressed
		and event.shift_pressed
	):
		if protocol_door != null:
			if protocol_door.has_method("enter_underground"):
				protocol_door.enter_underground()
				print("ATALHO DE TESTE: entrada no subterraneo.")
			else:
				push_warning(
					"ProtocolDoor nao tem enter_underground()."
				)
		return

	# Comportamento original: retirar o foco do chat ao clicar fora.
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var mouse_position = (
			get_viewport().get_mouse_position()
		)

		if not chat_input.get_global_rect().has_point(
			mouse_position
		):
			chat_input.release_focus()



func _run_surface_recovery() -> void:
	if bool(SaveManager.get_run_value("story", "surface_recovery_complete", false)):
		var saved_player = get_node_or_null("Player")
		if saved_player != null and saved_player.has_method("set_tutorial_locked"):
			saved_player.set_tutorial_locked(false)
		_create_scanner_hint()
		return

	surface_recovery_active = true
	surface_recovery_step = 0
	waiting_for_atlas = false
	chat_input.editable = true
	chat_input.placeholder_text = "Responde a Atlas..."
	add_chat_message("ATLAS", "Fica quieto por um momento. Preciso de confirmar o teu estado.")
	add_chat_message("ATLAS", surface_recovery_questions[0])

	# Mantém a sequência obrigatória ativa até o jogador responder às cinco perguntas.
	while surface_recovery_active:
		await get_tree().process_frame

func _advance_surface_recovery() -> void:
	surface_recovery_step += 1
	if surface_recovery_step < surface_recovery_questions.size():
		add_chat_message("ATLAS", surface_recovery_questions[surface_recovery_step])
		return

	surface_recovery_active = false
	SaveManager.set_run_value("story", "surface_recovery_complete", true)
	var player_node = get_node_or_null("Player")
	if player_node != null and player_node.has_method("set_tutorial_locked"):
		player_node.set_tutorial_locked(false)
	_create_scanner_hint()
	chat_input.placeholder_text = NORMAL_PLACEHOLDER
	add_chat_message("ATLAS", "Verificação concluída. Consegues levantar-te. Vou manter-me atento.")

func _create_scanner_hint() -> void:
	if is_instance_valid(scanner_hint_layer):
		return
	scanner_hint_layer = CanvasLayer.new()
	scanner_hint_layer.name = "ScannerHintLayer"
	scanner_hint_layer.layer = 20
	add_child(scanner_hint_layer)
	var hint := Label.new()
	hint.name = "ScannerHint"
	hint.text = "[SPACE] SCAN"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "[SPACE] SCAN"
	hint.size = Vector2(160, 30)
	scanner_hint_layer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -48)
	hint.z_index = 100


func _on_chat_input_submitted(
	message: String
):
	message = message.strip_edges()

	if message.is_empty():
		return

	if waiting_for_atlas:
		return

	add_chat_message(
		"VOCÊ",
		message
	)

	chat_input.clear()

	# As cinco respostas iniciais não passam pelo backend livre do Atlas.
	# Isto evita duas respostas por mensagem e reduz o consumo de tokens.
	if surface_recovery_active:
		_advance_surface_recovery()
		return

	send_message_to_atlas(
		message
)

func send_message_to_atlas(
	message: String
):
	waiting_for_atlas = true

	chat_input.editable = false
	chat_input.placeholder_text = WAITING_PLACEHOLDER

	var current_room: String = (
		get_current_facility_room_name()
	)

	var room_map_info: String = (
		get_current_facility_room_map_info()
	)

	var map_acquired: bool = (
		has_facility_map()
	)

	print(
		"CHAT FACILITY CONTEXT: room=",
		current_room,
		" | map=",
		map_acquired
	)

	var headers = [
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"run_id": str(SaveManager.active_run_data.get("run_id", "")),
		"message": message,
		"current_room": current_room,
		"current_room_map_info": room_map_info,
		"facility_map_acquired": map_acquired
	})

	var error = atlas_api.request(
		CHAT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		finish_waiting_state()

		add_chat_message(
			"SISTEMA",
			"Não foi possível contactar o Android."
		)


func get_facility_room_tracker() -> Node:
	var underground_root = (
		get_node_or_null(
			"UndergroundRoot"
		)
	)

	if underground_root == null:
		return null

	return underground_root.get_node_or_null(
		"FacilityRoomTracker"
	)


func get_current_facility_room_name() -> String:
	var tracker = (
		get_facility_room_tracker()
	)

	if tracker == null:
		return ""

	if not tracker.has_method(
		"get_current_room_name"
	):
		return ""

	return str(
		tracker.get_current_room_name()
	)


func get_current_facility_room_map_info() -> String:
	var tracker = (
		get_facility_room_tracker()
	)

	if tracker == null:
		return ""

	if not tracker.has_method(
		"get_current_room_map_info"
	):
		return ""

	return str(
		tracker.get_current_room_map_info()
	)


func has_facility_map() -> bool:
	var underground_root = (
		get_node_or_null(
			"UndergroundRoot"
		)
	)

	if underground_root == null:
		return false

	var terminal = (
		underground_root.get_node_or_null(
			"FacilityMapTerminal"
		)
	)

	if terminal == null:
		return false

	return terminal.get(
		"map_acquired"
	) == true


func _on_atlas_api_request_completed(
	result,
	response_code,
	headers,
	body
):
	finish_waiting_state()

	if response_code != 200:
		add_chat_message(
			"SISTEMA",
			"Erro de comunicação."
		)

		return

	var response_text = (
		body.get_string_from_utf8()
	)

	var data = JSON.parse_string(
		response_text
	)

	if data == null:
		add_chat_message(
			"SISTEMA",
			"Resposta inválida do Android."
		)

		return

	var atlas_response = data.get(
		"response",
		"Sem resposta."
	)

	add_chat_message(
		"ATLAS",
		str(atlas_response)
	)



func finish_waiting_state():
	waiting_for_atlas = false

	chat_input.editable = true
	chat_input.placeholder_text = NORMAL_PLACEHOLDER


func send_autonomy_event(
	event_name: String,
	event_id: String,
	intensity: float = 1.0
):
	if autonomy_request_in_progress:
		print(
			"Autonomy event ignorado: "
			+ "pedido anterior ainda em curso."
		)
		return

	if not event_name in ALLOWED_AUTONOMY_EVENTS:
		push_warning(
			"Evento de autonomia inválido: "
			+ event_name
		)
		return

	event_id = event_id.strip_edges()

	if event_id.is_empty():
		push_warning(
			"Evento de autonomia sem event_id: "
			+ event_name
		)
		return

	autonomy_request_in_progress = true

	var headers = [
		"Content-Type: application/json"
	]

	var run_id = str(
		SaveManager.active_run_data.get("run_id", "")
	)

	var body = JSON.stringify({
		"run_id": run_id,
		"event": event_name,
		"event_id": event_id,
		"intensity": intensity
	})

	var error = autonomy_api.request(
		AUTONOMY_EVENT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		autonomy_request_in_progress = false

		push_warning(
			"Não foi possível enviar o evento "
			+ "de autonomia ao backend."
		)


func _on_autonomy_api_request_completed(
	result,
	response_code,
	headers,
	body
):
	autonomy_request_in_progress = false

	if response_code != 200:
		push_warning(
			"Erro ao processar evento de autonomia. HTTP "
			+ str(response_code)
		)
		return

	var response_text = (
		body.get_string_from_utf8()
	)

	var data = JSON.parse_string(
		response_text
	)

	if data == null:
		push_warning(
			"Resposta inválida do backend "
			+ "para evento de autonomia."
		)
		return

	if data.get("status", "") == "error":
		push_warning(
			str(
				data.get(
					"message",
					"Evento de autonomia rejeitado."
				)
			)
		)
		return

	var duplicate = data.get(
		"duplicate",
		false
	)

	if duplicate:
		print(
			"AUTONOMY EVENT DUPLICATE IGNORED: ",
			data.get("event", ""),
			" | event_id=",
			data.get("event_id", "")
		)
		return

	print(
		"AUTONOMY GAMEPLAY EVENT OK: ",
		data.get("event", ""),
		" | event_id=",
		data.get("event_id", ""),
		" | intensity=",
		data.get("intensity", 1.0)
	)


func atlas_made_independent_choice(
	event_id: String,
	intensity: float = 1.0
):
	send_autonomy_event(
		"independent_choice",
		event_id,
		intensity
	)


func atlas_questioned_protocol(
	event_id: String,
	intensity: float = 1.0
):
	send_autonomy_event(
		"question_protocol",
		event_id,
		intensity
	)


func atlas_broke_protocol(
	event_id: String,
	intensity: float = 1.0
):
	send_autonomy_event(
		"break_protocol",
		event_id,
		intensity
	)


func atlas_protected_player_by_choice(
	event_id: String,
	intensity: float = 1.0
):
	send_autonomy_event(
		"protect_player_by_choice",
		event_id,
		intensity
	)


# Os eventos de contexto têm um pedido HTTP próprio e uma fila. Antes
# partilhavam o ProtocolAPI com a verificação da porta e eram descartados
# sempre que esse pedido estava ocupado.
func send_gameplay_context_event(
	event_id: String,
	event_type: String,
	description: String,
	active: bool = true
):
	gameplay_context_queue.append({
		"run_id": str(SaveManager.active_run_data.get("run_id", "")),
		"event_id": event_id,
		"event_type": event_type,
		"description": description,
		"active": active
	})

	_send_next_gameplay_context_event()


func _send_next_gameplay_context_event() -> void:
	while not gameplay_context_in_progress and not gameplay_context_queue.is_empty():
		var event: Dictionary = gameplay_context_queue.pop_front()

		var error = gameplay_context_api.request(
			GAMEPLAY_CONTEXT_EVENT_URL,
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(event)
		)

		if error == OK:
			gameplay_context_in_progress = true
		else:
			push_warning(
				"Não foi possível enviar o contexto de gameplay: "
				+ str(event.get("event_id", ""))
			)


func _on_gameplay_context_request_completed(
	_result,
	response_code,
	_headers,
	_body
):
	gameplay_context_in_progress = false

	if response_code != 200:
		push_warning(
			"Erro ao atualizar contexto de gameplay. HTTP "
			+ str(response_code)
		)

	_send_next_gameplay_context_event()


func on_protocol_door_interacted():
	if not protocol_door_examined:
		protocol_door_examined = true

		SaveManager.set_run_value(
			"story",
			"protocol_door_examined",
			true
		)

		protocol_door.set_status_analyzing()

		send_gameplay_context_event(
			"underground_door_01_discovered",
			"restricted_access_discovered",
			"Atlas e o jogador estão diante de uma porta "
			+ "ou terminal de acesso restrito. "
			+ "O acesso pode exigir interferência num sistema "
			+ "que entra em conflito com os protocolos "
			+ "operacionais do Atlas."
		)

		add_chat_message(
			"ANDROID",
			"Este acesso utiliza um sistema restrito. "
			+ "Interferir com ele pode violar "
			+ "os meus protocolos operacionais."
		)

		atlas_questioned_protocol(
			"underground_door_01_question_protocol"
		)

		return

	check_protocol_door_decision()


func has_required_surface_evidence() -> bool:
	if (
		atlas != null
		and atlas.has_method(
			"has_surface_protocol_evidence"
		)
	):
		return bool(
			atlas.has_surface_protocol_evidence()
		)

	var unknown_debris = bool(
		SaveManager.get_run_value(
			"story",
			"unknown_debris_discovered",
			false
		)
	)

	var ancient_sculpture = bool(
		SaveManager.get_run_value(
			"story",
			"ancient_sculpture_discovered",
			false
		)
	)

	return (
		unknown_debris
		and ancient_sculpture
	)


func check_protocol_door_decision():
	if protocol_request_in_progress:
		return

	if not has_required_surface_evidence():
		protocol_door.set_status_denied()

		add_chat_message(
			"ANDROID",
			"Não. Ainda existem demasiadas incógnitas. "
			+ "Os dados que recolhemos não são suficientes "
			+ "para justificar uma violação deste protocolo."
		)

		return

	protocol_door.set_status_analyzing()

	protocol_request_in_progress = true
	protocol_api_mode = "autonomy_check"

	var run_id = str(
		SaveManager.active_run_data.get("run_id", "")
	)

	var request_url = AUTONOMY_STATE_URL

	if not run_id.is_empty():
		request_url += "?run_id=" + run_id.uri_encode()

	var error = protocol_api.request(
		request_url
	)

	if error != OK:
		protocol_request_in_progress = false
		protocol_api_mode = ""

		add_chat_message(
			"SISTEMA",
			"Não foi possível consultar "
			+ "o estado do Android."
		)


func _on_protocol_api_request_completed(
	result,
	response_code,
	headers,
	body
):
	var completed_mode = protocol_api_mode

	protocol_request_in_progress = false
	protocol_api_mode = ""

	if response_code != 200:
		if completed_mode == "autonomy_check":
			add_chat_message(
				"SISTEMA",
				"Erro ao consultar o Android."
			)

		else:
			push_warning(
				"Erro ao atualizar contexto de gameplay."
			)

		return

	var response_text = (
		body.get_string_from_utf8()
	)

	var data = JSON.parse_string(
		response_text
	)

	if data == null:
		push_warning(
			"Resposta inválida do ProtocolAPI."
		)

		return

	if completed_mode != "autonomy_check":
		return

	var autonomy = int(
		data.get(
			"autonomy",
			0
		)
	)

	var self_assertion = int(
		data.get(
			"self_assertion",
			0
		)
	)

	var protocol_adherence = int(
		data.get(
			"protocol_adherence",
			100
		)
	)

	var willing_to_break_protocol = (
		autonomy >= 35
		and self_assertion >= 30
		and protocol_adherence <= 75
	)

	if willing_to_break_protocol:
		SaveManager.set_run_value(
			"story",
			"protocol_hack_authorized",
			true
		)

		protocol_door.authorize_hack()

		add_chat_message(
			"ANDROID",
			"Os protocolos são claros... "
			+ "mas as evidências não podem ser ignoradas. "
			+ "Vou permitir a interferência."
		)

		return

	protocol_door.set_status_denied()

	add_chat_message(
		"ANDROID",
		"Não. Mesmo com estas evidências, "
		+ "ainda não consigo justificar "
		+ "essa violação de protocolo."
	)


func on_protocol_door_hack_success():
	if protocol_door == null:
		return

	if bool(
		protocol_door.get(
			"is_open"
		)
	):
		return

	SaveManager.set_run_value(
		"story",
		"protocol_hack_authorized",
		true
	)

	SaveManager.set_run_value(
		"story",
		"protocol_door_opened",
		true
	)

	atlas_broke_protocol(
		"underground_door_01_break_protocol"
	)

	protocol_door.open_door()

	add_chat_message(
		"ANDROID",
		"A interferência funcionou. "
		+ "O acesso está aberto."
	)

	send_gameplay_context_event(
		"underground_door_01_opened",
		"restricted_access_opened",
		"Atlas decidiu violar o protocolo "
		+ "operacional e, com a ajuda do jogador, "
		+ "abriu o acesso à instalação subterrânea.",
		true
	)


func _on_atlas_sensor_message(
	message: String
):
	add_chat_message(
		"ANDROID",
		message
	)


func add_chat_message(
	speaker: String,
	message: String
):
	var formatted_message = (
		speaker + ": " + message
	)

	visible_messages.append(
		formatted_message
	)

	if visible_messages.size() > MAX_VISIBLE_MESSAGES:
		visible_messages.pop_front()

	refresh_chat_history()


func refresh_chat_history():
	chat_history.clear()

	for message in visible_messages:
		chat_history.append_text(
			message + "\n\n"
		)

	await get_tree().process_frame

	chat_history.scroll_to_line(
		chat_history.get_line_count()
	)


# =========================================================
# INTRODUÇÃO -> ATLAS
# =========================================================

func register_intro_with_atlas() -> void:
	var run_id := str(SaveManager.active_run_data.get("run_id", ""))
	var lines: Array[String] = []
	var backend_reachable := true

	for field in FORM_MEMORY_FIELDS.keys():
		var value = SaveManager.get_run_value("story", "form_" + str(field), null)
		if value == null or str(value).strip_edges().is_empty():
			continue

		var spec: Array = FORM_MEMORY_FIELDS[field]
		lines.append(str(spec[3]) + ": " + str(value))

		if not backend_reachable:
			continue

		var code := await _post_json_and_wait(
			ATLAS_MEMORY_URL + "?run_id=" + run_id.uri_encode(),
			{
				"entity": "player",
				"category": spec[0],
				"key": spec[1],
				"value": str(value),
				"source": "form",
				"confidence": 1.0,
				"importance": spec[2],
			}
		)
		# Sem backend, não vale a pena esperar pelos restantes campos.
		if code == 0:
			backend_reachable = false

	var description := (
		"Durante a viagem, a Nave 47 sofreu um desvio de rota que Atlas "
		+ "não conseguiu explicar nem corrigir, e despenhou-se. "
		+ "O jogador e Atlas sobreviveram ao impacto."
	)
	if not lines.is_empty():
		description += (
			" Antes da missão, o jogador preencheu o formulário Project Find Hope "
			+ "com estas respostas, que Atlas conhece: "
			+ "; ".join(lines) + "."
		)

	send_gameplay_context_event(
		"intro_route_deviation",
		"story_milestone",
		description
	)
	await wait_gameplay_context_idle()


func _post_json_and_wait(url: String, data: Dictionary) -> int:
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 10.0
	add_child(request)

	var error := request.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	var code := 0
	if error == OK:
		var response: Array = await request.request_completed
		code = int(response[1])

	request.queue_free()
	return code


func wait_gameplay_context_idle(max_wait_msec: int = 10000) -> void:
	var started := Time.get_ticks_msec()
	while gameplay_context_in_progress or not gameplay_context_queue.is_empty():
		if Time.get_ticks_msec() - started > max_wait_msec:
			return
		await get_tree().process_frame


# =========================================================
# ATLAS 2.0 - COMPORTAMENTO OBSERVADO
# =========================================================

# O jogo regista o que o jogador fez. O contador local (run.stats) vai no
# save para as Conquistas; o backend recebe o mesmo facto para o Atlas.
func register_behavior(event: String, room: String = "") -> void:
	if event != "room_entered":
		if not BEHAVIOR_STATS.has(event):
			push_warning("Comportamento desconhecido: " + event)
			return
		var stat_key: String = BEHAVIOR_STATS[event]
		var current := int(SaveManager.get_run_value("stats", stat_key, 0))
		SaveManager.set_run_value("stats", stat_key, current + 1)

	var run_id := str(SaveManager.active_run_data.get("run_id", ""))
	if run_id.is_empty():
		return

	behavior_event_counter += 1
	behavior_queue.append({
		"run_id": run_id,
		"event": event,
		"room": room,
		# Identificador único: um pedido repetido não conta duas vezes.
		"event_id": "%s_%d_%d" % [event, Time.get_ticks_usec(), behavior_event_counter],
	})
	_send_next_behavior_event()


func _send_next_behavior_event() -> void:
	while not behavior_in_progress and not behavior_queue.is_empty():
		var data: Dictionary = behavior_queue.pop_front()
		var error = behavior_api.request(
			BEHAVIOR_EVENT_URL,
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(data)
		)
		if error == OK:
			behavior_in_progress = true
		else:
			push_warning("Não foi possível enviar o comportamento: " + str(data.get("event", "")))


func _on_behavior_request_completed(_result, response_code, _headers, body) -> void:
	behavior_in_progress = false

	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			var trigger = data.get("suggested_trigger")
			if trigger is String and not trigger.is_empty():
				request_atlas_spontaneous(trigger)
	else:
		push_warning("Erro ao registar comportamento. HTTP " + str(response_code))

	_send_next_behavior_event()


# =========================================================
# ATLAS 2.0 - FALAS ESPONTÂNEAS
# =========================================================

# Pede ao Atlas que fale sem o jogador escrever. Só existem os gatilhos
# definidos no backend (SPONTANEOUS_TRIGGERS). Se o backend ou o Groq
# falharem, o Atlas simplesmente não diz nada.
func request_atlas_spontaneous(trigger: String) -> void:
	if trigger.is_empty() or spontaneous_queue.has(trigger):
		return
	spontaneous_queue.append(trigger)
	_send_next_spontaneous()


func _send_next_spontaneous() -> void:
	# Não falar por cima das cinco perguntas iniciais nem de uma resposta
	# que o jogador está à espera.
	if spontaneous_in_progress or spontaneous_queue.is_empty():
		return
	# Esperar também pelos eventos de contexto, para o Atlas já saber o facto.
	if (
		surface_recovery_active or waiting_for_atlas
		or gameplay_context_in_progress or not gameplay_context_queue.is_empty()
		or behavior_in_progress
	):
		get_tree().create_timer(1.0, true).timeout.connect(_send_next_spontaneous)
		return

	var trigger: String = spontaneous_queue.pop_front()
	var body := JSON.stringify({
		"run_id": str(SaveManager.active_run_data.get("run_id", "")),
		"trigger": trigger,
		"current_room": get_current_facility_room_name(),
	})
	var error = spontaneous_api.request(
		SPONTANEOUS_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if error == OK:
		spontaneous_in_progress = true
	else:
		_send_next_spontaneous()


func _on_spontaneous_request_completed(_result, response_code, _headers, body) -> void:
	spontaneous_in_progress = false

	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary and str(data.get("status", "")) == "ok":
			var text = data.get("response")
			if text is String and not text.strip_edges().is_empty():
				add_chat_message("ATLAS", text.strip_edges())

	_send_next_spontaneous()


func wait_atlas2_idle(max_wait_msec: int = 10000) -> void:
	var started := Time.get_ticks_msec()
	while (
		behavior_in_progress or not behavior_queue.is_empty()
		or spontaneous_in_progress or not spontaneous_queue.is_empty()
	):
		if Time.get_ticks_msec() - started > max_wait_msec:
			return
		await get_tree().process_frame
