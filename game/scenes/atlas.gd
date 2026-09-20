extends CharacterBody2D


signal sensor_message(message: String)


@export var speed: float = 140.0
@export var follow_start_distance: float = 180.0
@export var follow_stop_distance: float = 110.0
@export var sensor_range: float = 250.0

@export var scan_cooldown: float = 1.0


var player: CharacterBody2D
var is_following: bool = false

var scan_request: HTTPRequest

var scan_in_progress: bool = false
var scan_cooldown_active: bool = false


const SCAN_URL := "http://127.0.0.1:8000/world/scan"


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	player = get_parent().get_node("Player")

	scan_request = HTTPRequest.new()
	scan_request.name = "ScanRequest"

	add_child(scan_request)

	scan_request.request_completed.connect(
		_on_scan_request_completed
	)


func _physics_process(_delta):
	if player == null:
		return

	var distance_to_player = global_position.distance_to(
		player.global_position
	)

	if not is_following and distance_to_player >= follow_start_distance:
		is_following = true

	if is_following and distance_to_player <= follow_stop_distance:
		is_following = false

	if is_following:
		var direction = global_position.direction_to(
			player.global_position
		)

		velocity = direction * speed

	else:
		velocity = Vector2.ZERO

	move_and_slide()


# =========================================================
# SENSOR
# =========================================================

func scan_environment():
	if scan_in_progress:
		sensor_message.emit(
			"Os sensores ainda estão a processar o scan."
		)

		return

	if scan_cooldown_active:
		return

	scan_in_progress = true
	scan_cooldown_active = true

	start_scan_cooldown()

	var detectable_objects = get_tree().get_nodes_in_group(
		"detectable"
	)

	var detections: Array = []

	print("")
	print("========== ATLAS SENSOR SCAN ==========")

	for obj in detectable_objects:
		var distance_px = global_position.distance_to(
			obj.global_position
		)

		if distance_px <= sensor_range:
			var object_type = get_object_type(
				str(obj.name)
			)

			var detection = {
				"id": str(obj.name).to_lower(),
				"name": get_object_display_name(
					str(obj.name)
				),
				"type": object_type,
				"distance_px": distance_px
			}

			detections.append(
				detection
			)

			print(
				obj.name,
				" | distância interna: ",
				round(distance_px),
				" px"
			)

	if detections.is_empty():
		print(
			"Nenhum objeto detectado."
		)

	print(
		"======================================="
	)

	send_scan_to_backend(
		detections
	)


func start_scan_cooldown():
	await get_tree().create_timer(
		scan_cooldown
	).timeout

	scan_cooldown_active = false


# =========================================================
# OBJECT METADATA
# =========================================================

func get_object_type(
	object_name: String
) -> String:

	if object_name == "Ship":
		return "ship"

	if object_name.begins_with(
		"Debris"
	):
		return "debris"

	return "unknown"


func get_object_display_name(
	object_name: String
) -> String:

	if object_name == "Ship":
		return "Nave 47"

	if object_name.begins_with(
		"Debris"
	):
		return "Destroço da nave"

	return object_name


# =========================================================
# BACKEND
# =========================================================

func send_scan_to_backend(
	detections: Array
):
	var body = {
		"atlas_position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"detections": detections
	}

	var json_body = JSON.stringify(
		body
	)

	var headers = [
		"Content-Type: application/json"
	]

	var error = scan_request.request(
		SCAN_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:
		scan_in_progress = false

		print(
			"Erro ao enviar scan para backend: ",
			error
		)

		sensor_message.emit(
			"Não consegui processar o scan."
		)


func _on_scan_request_completed(
	result,
	response_code,
	headers,
	body
):
	scan_in_progress = false

	print("")
	print("========== BACKEND SENSOR ==========")
	print(
		"HTTP: ",
		response_code
	)

	if response_code != 200:
		print(
			"Erro ao processar scan."
		)

		sensor_message.emit(
			"O sistema de sensores encontrou um erro."
		)

		return

	var response_text = body.get_string_from_utf8()

	var data = JSON.parse_string(
		response_text
	)

	if data == null:
		print(
			"Resposta inválida do backend."
		)

		sensor_message.emit(
			"Recebi dados inválidos dos sensores."
		)

		return

	print(
		"Scan recebido pelo Atlas Core."
	)

	var detected_objects = data.get(
		"detected_objects",
		[]
	)

	show_scan_result(
		detected_objects
	)

	print(
		"===================================="
	)


# =========================================================
# SCAN RESULT
# =========================================================

func show_scan_result(
	detected_objects: Array
):
	if detected_objects.is_empty():
		sensor_message.emit(
			"Scan concluído. Não tenho deteções atuais."
		)

		return

	if detected_objects.size() == 1:
		var obj = detected_objects[0]

		sensor_message.emit(
			"Scan concluído. Detetei %s %s."
			% [
				get_article_and_name(
					obj
				),
				obj.get(
					"proximity",
					""
				)
			]
		)

		return

	var object_names: Array[String] = []

	for obj in detected_objects:
		object_names.append(
			obj.get(
				"name",
				"objeto desconhecido"
			)
		)

	sensor_message.emit(
		"Scan concluído. Detetei: %s."
		% ", ".join(
			object_names
		)
	)


func get_article_and_name(
	obj: Dictionary
) -> String:

	var object_type = obj.get(
		"type",
		"unknown"
	)

	var object_name = obj.get(
		"name",
		"objeto"
	)

	if object_type == "ship":
		return "a " + object_name

	if object_type == "debris":
		return (
			"um "
			+ object_name.to_lower()
		)

	return object_name
