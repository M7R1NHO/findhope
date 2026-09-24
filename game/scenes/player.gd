extends CharacterBody2D


@export var speed: float = 200.0

@export var min_x: float = -950.0
@export var max_x: float = 950.0
@export var min_y: float = -650.0
@export var max_y: float = 650.0

@export var interaction_range: float = 150.0


var atlas: CharacterBody2D


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	atlas = get_parent().get_node("Atlas")


func _physics_process(_delta):
	if is_typing_in_chat():
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

	global_position.x = clamp(
		global_position.x,
		min_x,
		max_x
	)

	global_position.y = clamp(
		global_position.y,
		min_y,
		max_y
	)


func _unhandled_input(event):
	if is_typing_in_chat():
		return

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		if event.keycode == KEY_SPACE:
			if atlas != null:
				atlas.scan_environment()

		if event.keycode == KEY_E:
			print("E PRESSIONADO")
			try_interaction()


func try_interaction():
	var interactables = get_tree().get_nodes_in_group(
		"interactable"
	)

	print(
		"INTERACTABLES ENCONTRADOS: ",
		interactables.size()
	)

	var closest_object = null
	var closest_distance = interaction_range

	for object in interactables:
		if not object is Node2D:
			continue

		var distance = global_position.distance_to(
			object.global_position
		)

		print(
			"OBJETO: ",
			object.name,
			" | DISTANCIA: ",
			distance
		)

		if distance <= closest_distance:
			closest_distance = distance
			closest_object = object

	if closest_object == null:
		print("NENHUM OBJETO PERTO")
		return

	print(
		"INTERAGINDO COM: ",
		closest_object.name
	)

	if closest_object.has_method("examine"):
		closest_object.examine()
	else:
		print(
			"ERRO: objeto nao possui examine()"
		)


func is_typing_in_chat() -> bool:
	var focused_control = (
		get_viewport().gui_get_focus_owner()
	)

	return focused_control is LineEdit
