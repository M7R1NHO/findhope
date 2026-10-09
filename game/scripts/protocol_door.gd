extends Area2D


@export var interaction_distance: float = 200.0

@export var underground_half_width: float = 3200.0
@export var underground_half_height: float = 4500.0

@export var interaction_label_width: float = 200.0
@export var interaction_label_height: float = 35.0
@export var interaction_label_y_offset: float = -60.0


const SAVE_ID := "protocol_door"


@onready var interaction_label: Label = $InteractionLabel
@onready var status_label: Label = $StatusLabel
@onready var door_visual: Node2D = $DoorVisual

@onready var terminal_state: Label = \
	$TerminalPanel/TerminalState


var player: CharacterBody2D
var atlas: CharacterBody2D

var underground_spawn: Node2D

var hack_manager: Node = null


var is_open: bool = false
var entered_underground: bool = false
var hack_authorized: bool = false
var hack_in_progress: bool = false


func _ready():
	add_to_group(
		"saveable"
	)

	var main = get_parent()

	player = main.get_node(
		"Player"
	)

	atlas = main.get_node(
		"Atlas"
	)

	underground_spawn = main.get_node_or_null(
		"UndergroundRoot/UndergroundSpawn"
	)

	hack_manager = main.get_node_or_null(
		"HackManager"
	)

	if hack_manager == null:
		push_warning(
			"ProtocolDoor não encontrou HackManager."
		)

	setup_interaction_label()

	restore_story_state()


func setup_interaction_label():
	interaction_label.visible = false

	interaction_label.size = Vector2(
		interaction_label_width,
		interaction_label_height
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	update_interaction_label_position()


func update_interaction_label_position():
	if door_visual == null:
		return

	interaction_label.global_position = Vector2(
		door_visual.global_position.x
		- interaction_label_width / 2.0,
		door_visual.global_position.y
		+ interaction_label_y_offset
	)


func _process(_delta):
	if player == null:
		return

	if entered_underground:
		interaction_label.visible = false
		return

	if hack_in_progress:
		interaction_label.visible = false
		return

	var interaction_position = global_position

	if door_visual != null:
		interaction_position = (
			door_visual.global_position
		)

	var distance = (
		interaction_position.distance_to(
			player.global_position
		)
	)

	if distance > interaction_distance:
		interaction_label.visible = false
		return

	interaction_label.visible = true

	if is_open:
		interaction_label.text = "[E] ENTRAR"

	elif hack_authorized:
		interaction_label.text = "[E] ACESSAR"

	else:
		interaction_label.text = "[E] INTERAGIR"


func examine():
	if entered_underground:
		return

	if is_open:
		enter_underground()
		return

	if hack_authorized:
		start_protocol_hack()
		return

	var main = get_parent()

	if main.has_method(
		"on_protocol_door_interacted"
	):
		main.on_protocol_door_interacted()


func set_status_restricted():
	status_label.text = "ACESSO RESTRITO"
	terminal_state.text = "LOCKED"


func set_status_analyzing():
	status_label.text = "ANALISANDO PROTOCOLO"
	terminal_state.text = "ANALYZING"


func set_status_denied():
	status_label.text = "ACESSO NEGADO"
	terminal_state.text = "DENIED"


func set_status_hack_ready():
	status_label.text = "INTERFERÊNCIA DISPONÍVEL"
	terminal_state.text = "READY"


func set_status_hacking():
	status_label.text = "INTERFERINDO NO SISTEMA"
	terminal_state.text = "HACKING"


func set_status_granted():
	status_label.text = "ACESSO LIBERADO"
	terminal_state.text = "GRANTED"


func set_status_sealed():
	status_label.text = "ACESSO BLOQUEADO"
	terminal_state.text = "SEALED"


func authorize_hack():
	if is_open:
		return

	if entered_underground:
		return

	hack_authorized = true

	SaveManager.set_run_value(
		"story",
		"protocol_hack_authorized",
		true
	)

	set_status_hack_ready()

	interaction_label.text = "[E] ACESSAR"

	print(
		"PROTOCOL DOOR HACK AUTHORIZED"
	)


func start_protocol_hack():
	if is_open:
		return

	if not hack_authorized:
		return

	if hack_in_progress:
		return

	if hack_manager == null:
		var main = get_parent()

		hack_manager = main.get_node_or_null(
			"HackManager"
		)

	if hack_manager == null:
		push_warning(
			"Não foi possível iniciar o hack: "
			+ "HackManager não encontrado."
		)

		set_status_hack_ready()

		return

	hack_in_progress = true

	set_status_hacking()

	interaction_label.visible = false

	print(
		"PROTOCOL DOOR HACK STARTED"
	)

	hack_manager.start_hack(
		self
	)


func on_hack_success():
	hack_in_progress = false

	var main = get_parent()

	if main.has_method(
		"on_protocol_door_hack_success"
	):
		main.on_protocol_door_hack_success()

	else:
		open_door()


func on_hack_cancelled():
	hack_in_progress = false

	if is_open:
		return

	if entered_underground:
		set_status_sealed()
		return

	if hack_authorized:
		set_status_hack_ready()

	else:
		set_status_restricted()

	print(
		"PROTOCOL DOOR HACK CANCELLED"
	)


func open_door():
	if is_open:
		return

	if entered_underground:
		return

	is_open = true

	hack_in_progress = false

	SaveManager.set_run_value(
		"story",
		"protocol_door_opened",
		true
	)

	set_status_granted()

	interaction_label.text = "[E] ENTRAR"

	apply_open_visual_state()

	print(
		"PROTOCOL DOOR OPENED"
	)


func apply_open_visual_state():
	var collision = get_node_or_null(
		"CollisionShape2D"
	)

	if collision != null:
		collision.set_deferred(
			"disabled",
			true
		)

	if door_visual != null:
		door_visual.visible = false

	update_interaction_label_position()


func apply_closed_visual_state():
	var collision = get_node_or_null(
		"CollisionShape2D"
	)

	if collision != null:
		collision.set_deferred(
			"disabled",
			false
		)

	if door_visual != null:
		door_visual.visible = true

	update_interaction_label_position()


func enter_underground():
	if entered_underground:
		return

	if underground_spawn == null:
		push_warning(
			"UndergroundSpawn não encontrado."
		)

		return

	entered_underground = true
	is_open = false
	hack_authorized = false
	hack_in_progress = false

	interaction_label.visible = false

	var spawn_position = (
		underground_spawn.global_position
	)

	apply_underground_bounds()

	player.teleport_to(
		spawn_position
	)

	if atlas != null:
		atlas.global_position = (
			spawn_position
			+ Vector2(
				80.0,
				0.0
			)
		)

		atlas.velocity = Vector2.ZERO

	seal_entrance()

	SaveManager.set_run_value(
		"story",
		"protocol_door_crossed",
		true
	)

	SaveManager.set_run_value(
		"story",
		"underground_entered",
		true
	)

	SaveManager.set_run_value(
		"story",
		"protocol_door_sealed",
		true
	)

	var main = get_parent()

	if main.has_method(
		"add_chat_message"
	):
		main.add_chat_message(
			"ANDROID",
			"A porta fechou atrás de nós."
		)

		main.add_chat_message(
			"ANDROID",
			"O mecanismo interno deixou de responder. "
			+ "Não consigo reabrir o acesso deste lado."
		)

		main.add_chat_message(
			"ANDROID",
			"Teremos de avançar pela instalação."
		)

	if main.has_method(
		"send_gameplay_context_event"
	):
		main.send_gameplay_context_event(
			"underground_01_entered",
			"underground_entered",
			"O jogador e Atlas entraram "
			+ "na instalação subterrânea. "
			+ "A entrada fechou atrás deles "
			+ "e não pode ser reaberta pelo interior.",
			true
		)

	var autosave_success = SaveManager.autosave(
		"protocol_door_crossed"
	)

	print("")
	print("ENTERED UNDERGROUND")
	print(
		"AUTOSAVE #3: ",
		autosave_success
	)


func seal_entrance():
	is_open = false
	hack_authorized = false
	hack_in_progress = false

	set_status_sealed()

	apply_closed_visual_state()


func apply_underground_bounds():
	if (
		player == null
		or underground_spawn == null
	):
		return

	var spawn_position = (
		underground_spawn.global_position
	)

	player.set_movement_bounds(
		spawn_position.x - underground_half_width,
		spawn_position.x + underground_half_width,
		spawn_position.y - underground_half_height,
		spawn_position.y + underground_half_height
	)


func restore_story_state():
	entered_underground = bool(
		SaveManager.get_run_value(
			"story",
			"protocol_door_crossed",
			false
		)
	)

	var was_opened = bool(
		SaveManager.get_run_value(
			"story",
			"protocol_door_opened",
			false
		)
	)

	hack_authorized = bool(
		SaveManager.get_run_value(
			"story",
			"protocol_hack_authorized",
			false
		)
	)

	if entered_underground:
		is_open = false
		hack_authorized = false

		set_status_sealed()

		apply_closed_visual_state()

		apply_underground_bounds()

		return

	if was_opened:
		is_open = true

		set_status_granted()

		apply_open_visual_state()

		return

	if hack_authorized:
		is_open = false

		set_status_hack_ready()

		apply_closed_visual_state()

		return

	is_open = false

	set_status_restricted()

	apply_closed_visual_state()


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	return {
		"is_open": is_open,
		"entered_underground": entered_underground,
		"hack_authorized": hack_authorized
	}


func load_save_data(
	data: Dictionary
):
	is_open = bool(
		data.get(
			"is_open",
			false
		)
	)

	entered_underground = bool(
		data.get(
			"entered_underground",
			false
		)
	)

	hack_authorized = bool(
		data.get(
			"hack_authorized",
			false
		)
	)

	hack_in_progress = false

	if entered_underground:
		is_open = false
		hack_authorized = false

		set_status_sealed()

		apply_closed_visual_state()

		apply_underground_bounds()

		return

	if is_open:
		set_status_granted()

		apply_open_visual_state()

		return

	if hack_authorized:
		set_status_hack_ready()

		apply_closed_visual_state()

		return

	set_status_restricted()

	apply_closed_visual_state()
