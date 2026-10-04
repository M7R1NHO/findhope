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

const PROTOCOL_DECISION_URL := \
	"http://127.0.0.1:8000/gameplay/protocol-door/decision"

const GAMEPLAY_CONTEXT_EVENT_URL := \
	"http://127.0.0.1:8000/gameplay/context/event"


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

var protocol_door_hack_completed: bool = false

var protocol_api_mode: String = ""

var visible_messages: Array[String] = []


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

	chat_input.text_submitted.connect(
		_on_chat_input_submitted
	)

	atlas.sensor_message.connect(
		_on_atlas_sensor_message
	)

	chat_input.placeholder_text = NORMAL_PLACEHOLDER

	chat_history.clear()

	add_chat_message(
		"ANDROID",
		"Sistema de comunicação operacional."
	)


func _input(event):
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var mouse_position = (
			get_viewport()
			.get_mouse_position()
		)

		if not chat_input.get_global_rect().has_point(
			mouse_position
		):
			chat_input.release_focus()


# =========================================================
# CHAT
# =========================================================

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

	send_message_to_atlas(
		message
	)


func send_message_to_atlas(
	message: String
):
	waiting_for_atlas = true

	chat_input.editable = false
	chat_input.placeholder_text = WAITING_PLACEHOLDER

	var headers = [
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"message": message
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
		"ANDROID",
		atlas_response
	)


func finish_waiting_state():
	waiting_for_atlas = false

	chat_input.editable = true
	chat_input.placeholder_text = NORMAL_PLACEHOLDER


# =========================================================
# AUTONOMY / GAMEPLAY BRIDGE
# =========================================================

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

	var body = JSON.stringify({
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


# =========================================================
# GAMEPLAY AUTONOMY EVENTS
# =========================================================

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


# =========================================================
# GAMEPLAY CONTEXT
# =========================================================

func send_gameplay_context_event(
	event_id: String,
	event_type: String,
	description: String,
	active: bool = true
):
	if protocol_request_in_progress:
		print(
			"Gameplay context adiado: "
			+ "ProtocolAPI ocupado."
		)

		return

	protocol_request_in_progress = true
	protocol_api_mode = "gameplay_context"

	var headers = [
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"event_id": event_id,
		"event_type": event_type,
		"description": description,
		"active": active
	})

	var error = protocol_api.request(
		GAMEPLAY_CONTEXT_EVENT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		protocol_request_in_progress = false
		protocol_api_mode = ""

		push_warning(
			"Não foi possível enviar "
			+ "o contexto de gameplay."
		)


# =========================================================
# PROTOCOL DOOR
# =========================================================

func on_protocol_door_interacted():
	if not protocol_door_examined:
		protocol_door_examined = true

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


func check_protocol_door_decision():
	if protocol_request_in_progress:
		return

	protocol_door.set_status_analyzing()

	protocol_request_in_progress = true
	protocol_api_mode = "autonomy_check"

	var error = protocol_api.request(
		PROTOCOL_DECISION_URL
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

	if completed_mode == "gameplay_context":
		print(
			"GAMEPLAY CONTEXT OK: ",
			data
		)

		return

	if completed_mode != "autonomy_check":
		return

	var allowed = bool(
		data.get("allowed", false)
	)

	var reason = str(
		data.get("reason", "")
	)

	if allowed:
		# -------------------------------------------------
		# IMPORTANTE:
		#
		# Atlas ACEITOU quebrar o protocolo.
		# A porta ainda NÃO abre.
		#
		# Agora começa o minigame de hacking.
		# -------------------------------------------------

		add_chat_message(
			"ANDROID",
			"As evidências mudam a situação. "
			+ "Neste caso, considero a violação "
			+ "justificável. Consigo interferir "
			+ "com o sistema de acesso."
		)

		protocol_door.authorize_hack()

		protocol_door.start_protocol_hack()


	else:
		protocol_door.set_status_denied()

		if reason == "missing_surface_evidence":
			add_chat_message(
				"ANDROID",
				"Não. As evidências que temos neste "
				+ "momento ainda não justificam que eu "
				+ "viole esse protocolo."
			)

		elif reason == "atlas_not_ready":
			add_chat_message(
				"ANDROID",
				"As descobertas mudam a situação, "
				+ "mas ainda não considero suficiente "
				+ "para violar esse protocolo."
			)

		else:
			add_chat_message(
				"ANDROID",
				"Ainda não considero justificável "
				+ "violar esse protocolo."
			)


# =========================================================
# PROTOCOL DOOR — HACK CONCLUÍDO
# =========================================================

func on_protocol_door_hack_success():
	if protocol_door_hack_completed:
		return

	protocol_door_hack_completed = true


	# -----------------------------------------------------
	# AGORA SIM ATLAS QUEBROU O PROTOCOLO
	# -----------------------------------------------------

	atlas_broke_protocol(
		"underground_door_01_break_protocol"
	)


	# -----------------------------------------------------
	# ABRIR PORTA
	# -----------------------------------------------------

	protocol_door.open_door()


	# -----------------------------------------------------
	# ATLAS REAGE
	# -----------------------------------------------------

	add_chat_message(
		"ANDROID",
		"Interferência concluída. "
		+ "O sistema aceitou a alteração. "
		+ "O acesso está aberto."
	)


	# -----------------------------------------------------
	# ATUALIZAR CONTEXTO
	# -----------------------------------------------------

	send_gameplay_context_event(
		"underground_door_01_discovered",
		"restricted_access_opened",
		"Atlas violou o protocolo e, com a ajuda "
		+ "do jogador durante a interferência, "
		+ "o acesso subterrâneo foi aberto.",
		true
	)


	print(
		"PROTOCOL DOOR HACK SUCCESS"
	)


# =========================================================
# SENSOR MESSAGE
# =========================================================

func _on_atlas_sensor_message(
	message: String
):
	add_chat_message(
		"ANDROID",
		message
	)


# =========================================================
# CHAT HISTORY
# =========================================================

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
