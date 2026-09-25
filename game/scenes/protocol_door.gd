extends Area2D


@export var interaction_distance: float = 150.0


@onready var interaction_label: Label = $InteractionLabel
@onready var status_label: Label = $StatusLabel
@onready var door_visual: Node2D = $DoorVisual

@onready var terminal_state: Label = \
	$TerminalPanel/TerminalState


var player: CharacterBody2D
var is_open: bool = false


func _ready():
	player = get_parent().get_node("Player")

	interaction_label.visible = false

	set_status_restricted()


func _process(_delta):
	if player == null:
		return

	if is_open:
		interaction_label.visible = false
		return

	var distance = door_visual.global_position.distance_to(
		player.global_position
	)

	interaction_label.visible = (
		distance <= interaction_distance
	)


func examine():
	if is_open:
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


func set_status_granted():
	status_label.text = "ACESSO LIBERADO"
	terminal_state.text = "GRANTED"


func open_door():
	if is_open:
		return

	is_open = true

	set_status_granted()

	interaction_label.visible = false

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

	print("PROTOCOL DOOR OPENED")
