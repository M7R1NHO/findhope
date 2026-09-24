extends Area2D


@export var interaction_distance: float = 90.0

var is_open: bool = false


func examine():
	if is_open:
		return

	var main = get_parent()

	if main.has_method(
		"on_protocol_door_interacted"
	):
		main.on_protocol_door_interacted()


func open_door():
	if is_open:
		return

	is_open = true

	var collision = get_node_or_null(
		"CollisionShape2D"
	)

	if collision != null:
		collision.set_deferred(
			"disabled",
			true
		)

	var visual = get_node_or_null(
		"DoorVisual"
	)

	if visual != null:
		visual.visible = false

	print("PROTOCOL DOOR OPENED")
