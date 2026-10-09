extends Node


const REQUIRED_PARTS: int = 6
const SAVE_ID := "ship_parts_manager"

const GAMEPLAY_CONTEXT_EVENT_URL := \
	"http://127.0.0.1:8000/gameplay/context/event"


var collected_part_ids: Array[String] = []

var context_request: HTTPRequest
var context_request_in_progress: bool = false


func _ready():
	add_to_group(
		"saveable"
	)

	context_request = HTTPRequest.new()
	context_request.name = "ShipPartsContextRequest"

	add_child(
		context_request
	)

	context_request.request_completed.connect(
		_on_context_request_completed
	)

	call_deferred(
		"sync_all_parts"
	)


func collect_part(
	part_id: String,
	display_name: String
) -> bool:
	part_id = part_id.strip_edges()

	if part_id.is_empty():
		push_warning(
			"Tentativa de recolher peça sem part_id."
		)

		return false

	if part_id in collected_part_ids:
		print(
			"PEÇA JÁ RECOLHIDA: ",
			part_id
		)

		return false

	collected_part_ids.append(
		part_id
	)

	var current_count = (
		collected_part_ids.size()
	)

	print("")
	print("SHIP PART COLLECTED")
	print("ID: ", part_id)
	print("Nome: ", display_name)
	print(
		"Progresso: ",
		current_count,
		"/",
		REQUIRED_PARTS
	)

	show_collection_message(
		display_name
	)

	send_progress_to_backend()

	return true


func get_collected_count() -> int:
	return collected_part_ids.size()


func get_required_count() -> int:
	return REQUIRED_PARTS


func has_all_parts() -> bool:
	return (
		get_collected_count()
		>= REQUIRED_PARTS
	)


func get_progress_text() -> String:
	return (
		str(get_collected_count())
		+ "/"
		+ str(REQUIRED_PARTS)
	)


func is_part_collected(
	part_id: String
) -> bool:
	return (
		part_id.strip_edges()
		in collected_part_ids
	)


func show_collection_message(
	display_name: String
):
	var main = get_parent()

	if not main.has_method(
		"add_chat_message"
	):
		return

	var current_count = (
		get_collected_count()
	)

	main.add_chat_message(
		"SISTEMA",
		"%s recuperada. Peças da Nave 47: %d/%d."
		% [
			display_name,
			current_count,
			REQUIRED_PARTS
		]
	)

	if has_all_parts():
		main.add_chat_message(
			"ANDROID",
			"Recuperámos todas as peças necessárias "
			+ "da Nave 47. Podemos regressar à nave "
			+ "e avaliar a reparação."
		)


func send_progress_to_backend():
	if context_request_in_progress:
		print(
			"Atualização das peças adiada: "
			+ "pedido anterior ainda em curso."
		)

		return

	var current_count = (
		get_collected_count()
	)

	var description = (
		"O jogador recuperou %d de %d peças "
		+ "necessárias para reparar a Nave 47."
	) % [
		current_count,
		REQUIRED_PARTS
	]

	if has_all_parts():
		description = (
			"O jogador recuperou todas as 6 peças "
			+ "necessárias para reparar a Nave 47. "
			+ "A equipa pode regressar à nave "
			+ "para tentar repará-la."
		)

	var body = JSON.stringify({
		"event_id": "ship_parts_progress",
		"event_type": "ship_repair_progress",
		"description": description,
		"active": true
	})

	var headers = [
		"Content-Type: application/json"
	]

	context_request_in_progress = true

	var error = context_request.request(
		GAMEPLAY_CONTEXT_EVENT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		context_request_in_progress = false

		push_warning(
			"Não foi possível enviar o progresso "
			+ "das peças ao backend."
		)


func _on_context_request_completed(
	result,
	response_code,
	headers,
	body
):
	context_request_in_progress = false

	if response_code != 200:
		push_warning(
			"Erro ao atualizar progresso das peças. HTTP "
			+ str(response_code)
		)

		return

	print(
		"SHIP PART PROGRESS CONTEXT OK: ",
		get_progress_text()
	)


func sync_all_parts():
	var parts = get_tree().get_nodes_in_group(
		"ship_part"
	)

	for part in parts:
		if not is_instance_valid(
			part
		):
			continue

		if part.has_method(
			"sync_with_parts_manager"
		):
			part.sync_with_parts_manager()


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	var ids: Array = []

	for part_id in collected_part_ids:
		ids.append(
			part_id
		)

	print(
		"SHIP PARTS SAVED: ",
		ids.size(),
		"/",
		REQUIRED_PARTS
	)

	return {
		"collected_part_ids": ids
	}


func load_save_data(
	data: Dictionary
):
	collected_part_ids.clear()

	var saved_ids = data.get(
		"collected_part_ids",
		[]
	)

	if saved_ids is Array:
		for saved_id in saved_ids:
			var part_id = str(
				saved_id
			).strip_edges()

			if part_id.is_empty():
				continue

			if part_id in collected_part_ids:
				continue

			collected_part_ids.append(
				part_id
			)

	print(
		"SHIP PARTS RESTORED: ",
		get_collected_count(),
		"/",
		REQUIRED_PARTS
	)

	call_deferred(
		"sync_all_parts"
	)
