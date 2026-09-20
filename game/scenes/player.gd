extends CharacterBody2D


@export var speed: float = 200.0

@export var min_x: float = -950.0
@export var max_x: float = 950.0
@export var min_y: float = -650.0
@export var max_y: float = 650.0


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
		and event.keycode == KEY_SPACE
	):
		if atlas != null:
			atlas.scan_environment()


func is_typing_in_chat() -> bool:
	var focused_control = get_viewport().gui_get_focus_owner()

	return focused_control is LineEdit
