extends Area2D


@export var interaction_distance: float = 200.0

@export var underground_half_width: float = 3200.0
@export var underground_half_height: float = 4500.0

@export var interaction_label_width: float = 200.0
@export var interaction_label_height: float = 35.0
@export var interaction_label_y_offset: float = -60.0


@onready var interaction_label: Label = $InteractionLabel
@onready var status_label: Label = $StatusLabel
@onready var door_visual: Node2D = $DoorVisual

@onready var terminal_state: Label = \
	$TerminalPanel/TerminalState


var player: CharacterBody2D
var atlas: CharacterBody2D

var underground_spawn: Node2D

var is_open: bool = false
var entered_underground: bool = false


func _ready():
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

	setup_interaction_label()

	set_status_restricted()


# =========================================================
# INTERACTION LABEL
# =========================================================

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


# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if player == null:
		return

	if entered_underground:
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

	else:
		interaction_label.text = "[E] INTERAGIR"


# =========================================================
# INTERACTION
# =========================================================

func examine():
	if entered_underground:
		return

	if is_open:
		enter_underground()
		return

	var main = get_parent()

	if main.has_method(
		"on_protocol_door_interacted"
	):
		main.on_protocol_door_interacted()


# =========================================================
# DOOR STATUS
# =========================================================

func set_status_restricted():
	status_label.text = "ACESSO RESTRITO"
	terminal_state.text = "LOCKED"


func set_status_analyzing():
	status_label.text = "ANALISANDO PROTOCOLO"
	terminal_state.text = "ANALYZING"


func set_status_denied():
	status_label.text = "ACESSO NEGADO"
	terminal_state.text = "DENIED"


func set_status_granted():
	status_label.text = "ACESSO LIBERADO"
	terminal_state.text = "GRANTED"


# =========================================================
# OPEN DOOR
# =========================================================

func open_door():
	if is_open:
		return

	is_open = true

	set_status_granted()

	interaction_label.text = "[E] ENTRAR"

	update_interaction_label_position()

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

	print(
		"PROTOCOL DOOR OPENED"
	)


# =========================================================
# ENTER UNDERGROUND
# =========================================================

func enter_underground():
	if entered_underground:
		return

	if underground_spawn == null:
		push_warning(
			"UndergroundSpawn não encontrado."
		)

		return

	entered_underground = true

	interaction_label.visible = false

	var spawn_position = (
		underground_spawn.global_position
	)

	player.set_movement_bounds(
		spawn_position.x - underground_half_width,
		spawn_position.x + underground_half_width,
		spawn_position.y - underground_half_height,
		spawn_position.y + underground_half_height
	)

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

	var main = get_parent()

	if main.has_method(
		"add_chat_message"
	):
		main.add_chat_message(
			"ANDROID",
			"Entrámos na instalação subterrânea."
		)

	if main.has_method(
		"send_gameplay_context_event"
	):
		main.send_gameplay_context_event(
			"underground_01_entered",
			"underground_entered",
			"O jogador e Atlas entraram "
			+ "na instalação subterrânea.",
			true
		)

	print(
		"ENTERED UNDERGROUND"
	)
