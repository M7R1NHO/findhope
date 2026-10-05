extends CharacterBody2D


signal sensor_message(message: String)


@export var speed: float = 180.0
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

	if (
		not is_following
		and distance_to_player >= follow_start_distance
	):
		is_following = true

	if (
		is_following
		and distance_to_player <= follow_stop_distance
	):
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

	var detectable_objects = (
		get_tree()
		.get_nodes_in_group(
			"detectable"
		)
	)
	
	print(
	"OBJETOS NO GRUPO DETECTABLE: ",
	detectable_objects.size()
)

	for obj in detectable_objects:
		print(
		"DETECTABLE: ",
		obj.name,
		" | posição: ",
		obj.global_position,
		" | distância: ",
		global_position.distance_to(
			obj.global_position
		)
	)

	var detections: Array = []

	print("")
	print("========== ATLAS SENSOR SCAN ==========")

	for obj in detectable_objects:
		var distance_px = (
			global_position
			.distance_to(
				obj.global_position
			)
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
				" | tipo: ",
				object_type,
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

	# -----------------------------------------------------
	# NAVE 47
	# -----------------------------------------------------

	if object_name == "Ship":
		return "ship"

	# -----------------------------------------------------
	# DESTROÇOS DESCONHECIDOS
	# IMPORTANTE:
	# verificar antes dos destroços normais.
	# -----------------------------------------------------

	if object_name.begins_with(
		"UnknownDebris"
	):
		return "unknown_debris"

	# -----------------------------------------------------
	# ESCULTURA ANTIGA
	# -----------------------------------------------------

	if object_name.begins_with(
		"AncientSculpture"
	):
		return "ancient_sculpture"

	# -----------------------------------------------------
	# DESTROÇOS NORMAIS DA NAVE 47
	# -----------------------------------------------------

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
		"UnknownDebris"
	):
		return "Destroços de origem desconhecida"

	if object_name.begins_with(
		"AncientSculpture"
	):
		return "Escultura antiga"

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

	var response_text = (
		body.get_string_from_utf8()
	)

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

	var new_discoveries = data.get(
		"new_discoveries",
		[]
	)

	print(
		"Novas descobertas: ",
		new_discoveries
	)

	show_scan_result(
		detected_objects
	)

	show_new_discoveries(
		new_discoveries
	)

	print(
		"===================================="
	)


# =========================================================
# NEW DISCOVERIES
# =========================================================

func show_new_discoveries(
	new_discoveries: Array
):
	if new_discoveries.is_empty():
		return

	for discovery in new_discoveries:
		var discovery_name = str(
			discovery
		)

		if discovery_name == "unknown_debris":
			sensor_message.emit(
				"Estes destroços não correspondem "
				+ "a nenhuma parte identificada da Nave 47. "
				+ "A origem permanece desconhecida."
			)

		elif discovery_name == "ancient_sculpture":
			sensor_message.emit(
				"A estrutura parece ser uma escultura antiga. "
				+ "Não tenho dados suficientes para determinar "
				+ "a sua origem ou quem a construiu."
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
		return (
			"a "
			+ object_name
		)

	if object_type == "debris":
		return (
			"um "
			+ object_name.to_lower()
		)

	if object_type == "unknown_debris":
		return (
			"os "
			+ object_name.to_lower()
		)

	if object_type == "ancient_sculpture":
		return (
			"uma "
			+ object_name.to_lower()
		)

	return object_name
