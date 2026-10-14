extends CharacterBody2D


signal sensor_message(message: String)


@export var speed: float = 180.0
@export var follow_start_distance: float = 180.0
@export var follow_stop_distance: float = 110.0
@export var sensor_range: float = 250.0
@export var scan_cooldown: float = 1.0


const SCAN_URL := "http://127.0.0.1:8000/world/scan"

const DISCOVERY_UNKNOWN_DEBRIS := "unknown_debris"
const DISCOVERY_ANCIENT_SCULPTURE := "ancient_sculpture"


var player: CharacterBody2D
var is_following: bool = false
var scripted_move_active: bool = false
var scripted_move_target: Vector2 = Vector2.ZERO

var scan_request: HTTPRequest

var scan_in_progress: bool = false
var scan_cooldown_active: bool = false

var pending_local_discoveries: Array[String] = []

var unknown_debris_discovered: bool = false
var ancient_sculpture_discovered: bool = false


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	player = get_parent().get_node(
		"Player"
	)

	load_surface_discoveries()

	scan_request = HTTPRequest.new()
	scan_request.name = "ScanRequest"

	add_child(
		scan_request
	)

	scan_request.request_completed.connect(
		_on_scan_request_completed
	)

	print("")
	print("ATLAS SENSOR READY")
	print(
		"Unknown debris discovered: ",
		unknown_debris_discovered
	)
	print(
		"Ancient sculpture discovered: ",
		ancient_sculpture_discovered
	)


func _physics_process(_delta):
	if player == null:
		return

	# Movimento controlado por um evento narrativo.
	if scripted_move_active:
		var target_distance = global_position.distance_to(
			scripted_move_target
		)

		# Quando chega ao destino, fica à espera de novas instruções.
		if target_distance <= 18.0:
			velocity = Vector2.ZERO
			move_and_slide()
			return

		var scripted_direction = global_position.direction_to(
			scripted_move_target
		)

		# Durante o evento, move-se mais depressa do que normalmente.
		velocity = scripted_direction * speed * 1.5
		move_and_slide()
		return

	# Comportamento normal: acompanhar o jogador.
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


func start_scripted_move_to(target: Vector2) -> void:
	scripted_move_target = target
	scripted_move_active = true
	is_following = false


func stop_scripted_move_to() -> void:
	scripted_move_active = false
	velocity = Vector2.ZERO

	move_and_slide()


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
		if not is_instance_valid(
			obj
		):
			continue

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
	print("ATLAS SENSOR SCAN")

	for obj in detectable_objects:
		if not is_instance_valid(
			obj
		):
			continue

		var distance_px = (
			global_position
			.distance_to(
				obj.global_position
			)
		)

		if distance_px > sensor_range:
			continue

		var object_type = get_object_type(
			str(
				obj.name
			)
		)

		var detection = {
			"id": str(
				obj.name
			).to_lower(),
			"name": get_object_display_name(
				str(
					obj.name
				)
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
			round(
				distance_px
			),
			" px"
		)

	if detections.is_empty():
		print(
			"Nenhum objeto detectado."
		)

	pending_local_discoveries = (
		register_local_discoveries(
			detections
		)
	)

	send_scan_to_backend(
		detections
	)


func start_scan_cooldown():
	await get_tree().create_timer(
		scan_cooldown
	).timeout

	scan_cooldown_active = false


func get_object_type(
	object_name: String
) -> String:
	if object_name == "Ship":
		return "ship"

	if object_name.begins_with(
		"UnknownDebris"
	):
		return DISCOVERY_UNKNOWN_DEBRIS

	if object_name.begins_with(
		"AncientSculpture"
	):
		return DISCOVERY_ANCIENT_SCULPTURE

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


func register_local_discoveries(
	detections: Array
) -> Array[String]:
	var new_discoveries: Array[String] = []

	for detection in detections:
		if not (
			detection is Dictionary
		):
			continue

		var object_type = str(
			detection.get(
				"type",
				""
			)
		)

		if (
			object_type
			== DISCOVERY_UNKNOWN_DEBRIS
			and not unknown_debris_discovered
		):
			unknown_debris_discovered = true

			new_discoveries.append(
				DISCOVERY_UNKNOWN_DEBRIS
			)

			SaveManager.set_run_value(
				"story",
				"unknown_debris_discovered",
				true
			)

			print(
				"SURFACE DISCOVERY: UNKNOWN DEBRIS"
			)

		elif (
			object_type
			== DISCOVERY_ANCIENT_SCULPTURE
			and not ancient_sculpture_discovered
		):
			ancient_sculpture_discovered = true

			new_discoveries.append(
				DISCOVERY_ANCIENT_SCULPTURE
			)

			SaveManager.set_run_value(
				"story",
				"ancient_sculpture_discovered",
				true
			)

			print(
				"SURFACE DISCOVERY: ANCIENT SCULPTURE"
			)

	return new_discoveries


func load_surface_discoveries():
	unknown_debris_discovered = bool(
		SaveManager.get_run_value(
			"story",
			"unknown_debris_discovered",
			false
		)
	)

	ancient_sculpture_discovered = bool(
		SaveManager.get_run_value(
			"story",
			"ancient_sculpture_discovered",
			false
		)
	)


func has_unknown_debris_discovery() -> bool:
	return unknown_debris_discovered


func has_ancient_sculpture_discovery() -> bool:
	return ancient_sculpture_discovered


func has_surface_protocol_evidence() -> bool:
	return (
		unknown_debris_discovered
		and ancient_sculpture_discovered
	)


func get_surface_discovery_state() -> Dictionary:
	return {
		"unknown_debris":
			unknown_debris_discovered,
		"ancient_sculpture":
			ancient_sculpture_discovered,
		"protocol_evidence_ready":
			has_surface_protocol_evidence()
	}


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

		show_new_discoveries(
			pending_local_discoveries
		)

		pending_local_discoveries.clear()

		sensor_message.emit(
			"Não consegui processar completamente o scan."
		)


func _on_scan_request_completed(
	result,
	response_code,
	headers,
	body
):
	scan_in_progress = false

	print("")
	print("BACKEND SENSOR")
	print(
		"HTTP: ",
		response_code
	)

	if response_code != 200:
		show_new_discoveries(
			pending_local_discoveries
		)

		pending_local_discoveries.clear()

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
		show_new_discoveries(
			pending_local_discoveries
		)

		pending_local_discoveries.clear()

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

	print(
		"Novas descobertas da run: ",
		pending_local_discoveries
	)

	show_scan_result(
		detected_objects
	)

	show_new_discoveries(
		pending_local_discoveries
	)

	pending_local_discoveries.clear()


func show_new_discoveries(
	new_discoveries: Array
):
	if new_discoveries.is_empty():
		return

	for discovery in new_discoveries:
		var discovery_name = str(
			discovery
		)

		if discovery_name == DISCOVERY_UNKNOWN_DEBRIS:
			sensor_message.emit(
				"Estes destroços não correspondem "
				+ "a nenhuma parte identificada da Nave 47. "
				+ "A origem permanece desconhecida."
			)

		elif discovery_name == DISCOVERY_ANCIENT_SCULPTURE:
			sensor_message.emit(
				"A estrutura parece ser uma escultura antiga. "
				+ "Não tenho dados suficientes para determinar "
				+ "a sua origem ou quem a construiu."
			)


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

	if object_type == DISCOVERY_UNKNOWN_DEBRIS:
		return (
			"os "
			+ object_name.to_lower()
		)

	if object_type == DISCOVERY_ANCIENT_SCULPTURE:
		return (
			"uma "
			+ object_name.to_lower()
		)

	return object_name
