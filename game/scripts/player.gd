
extends CharacterBody2D

@export var speed: float = 200.0
@export var min_x: float = -3400.0
@export var max_x: float = 1940.0
@export var min_y: float = -1480.0
@export var max_y: float = 1400.0
@export var interaction_range: float = 150.0

var atlas: CharacterBody2D
var tutorial_locked: bool = false
var tutorial_target: Node2D = null


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	atlas = get_parent().get_node_or_null("Atlas")


func _physics_process(_delta):
	if tutorial_locked or is_typing_in_chat():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()

	#global_position.x = clampf(
	#	global_position.x,
	#	min_x,
	#	max_x
	#)

	# global_position.y = clampf(
	#	global_position.y,
	#	min_y,
	#	max_y
	#)


func _unhandled_input(event):
	if tutorial_locked or is_typing_in_chat():
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_SPACE:
		if atlas != null:
			atlas.scan_environment()

	if event.keycode == KEY_E:
		try_interaction()


func try_interaction():
	if tutorial_target != null:
		if not is_instance_valid(tutorial_target):
			tutorial_target = null
		elif global_position.distance_to(
			tutorial_target.global_position
		) <= interaction_range:
			if tutorial_target.has_method("examine"):
				tutorial_target.examine()
			return

	var interactables = get_tree().get_nodes_in_group(
		"interactable"
	)

	var closest_object: Node2D = null
	var closest_distance = interaction_range

	for object in interactables:
		if not is_instance_valid(object):
			continue

		if not object is Node2D:
			continue

		var interaction_position = object.global_position
		var door_visual = object.get_node_or_null("DoorVisual")

		if door_visual != null:
			interaction_position = door_visual.global_position

		var distance = global_position.distance_to(
			interaction_position
		)

		if distance <= closest_distance:
			closest_distance = distance
			closest_object = object

	if closest_object == null:
		print("NENHUM OBJETO PERTO")
		return

	if closest_object.has_method("examine"):
		closest_object.examine()
	else:
		print("Objeto sem método examine(): ", closest_object.name)


func set_tutorial_locked(locked: bool):
	tutorial_locked = locked

	if locked:
		velocity = Vector2.ZERO


func set_tutorial_interaction_target(target: Node2D):
	tutorial_target = target


func clear_tutorial_interaction_target():
	tutorial_target = null


func set_movement_bounds(
	new_min_x: float,
	new_max_x: float,
	new_min_y: float,
	new_max_y: float
):
	min_x = new_min_x
	max_x = new_max_x
	min_y = new_min_y
	max_y = new_max_y


func teleport_to(target_position: Vector2):
	velocity = Vector2.ZERO
	global_position = target_position


func is_typing_in_chat() -> bool:
	var focus = get_viewport().gui_get_focus_owner()
	return focus is LineEdit
