
extends Area2D


const DEBUG_DOORS := false


@export var door_id: String = "underground_door_01"
@export var door_size: Vector2 = Vector2(30, 160)
@export var interaction_padding: float = 100.0


enum HackAction {
	OPEN,
	CLOSE
}


var is_open: bool = false
var player_nearby: bool = false
var hack_in_progress: bool = false
var pending_action: HackAction = HackAction.OPEN

var power_locked: bool = false
var security_locked: bool = false
var main_core_locked: bool = false

var hack_manager: Node = null
var door_visual: Polygon2D = null
var door_body: StaticBody2D = null
var door_collision: CollisionShape2D = null
var interaction_collision: CollisionShape2D = null
var interaction_label: Label = null


func _ready():
	create_door_nodes()
	find_hack_manager()

	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Inicializada: ", door_id)


func create_door_nodes():
	door_visual = Polygon2D.new()
	door_visual.name = "DoorVisual"
	door_visual.polygon = rectangle_polygon(door_size)
	door_visual.color = Color(0.25, 0.32, 0.36, 1.0)
	door_visual.z_index = 2
	add_child(door_visual)

	door_body = StaticBody2D.new()
	door_body.name = "DoorBody"
	add_child(door_body)

	door_collision = CollisionShape2D.new()
	door_collision.name = "DoorCollision"

	var door_shape = RectangleShape2D.new()
	door_shape.size = door_size
	door_collision.shape = door_shape
	door_body.add_child(door_collision)

	interaction_collision = CollisionShape2D.new()
	interaction_collision.name = "InteractionArea"

	var interaction_shape = RectangleShape2D.new()
	interaction_shape.size = Vector2(
		door_size.x + interaction_padding * 2.0,
		door_size.y + interaction_padding * 2.0
	)
	interaction_collision.shape = interaction_shape
	add_child(interaction_collision)

	interaction_label = Label.new()
	interaction_label.name = "InteractionLabel"
	interaction_label.position = Vector2(
		-140,
		-door_size.y / 2.0 - 65
	)
	interaction_label.size = Vector2(280, 40)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 18)
	interaction_label.hide()
	interaction_label.z_index = 20
	add_child(interaction_label)


func find_hack_manager():
	var current_scene = get_tree().current_scene

	if current_scene == null:
		return

	hack_manager = current_scene.get_node_or_null("HackManager")

	if hack_manager == null:
		push_error(
			"[PORTA] Não foi possível encontrar o HackManager."
		)


func on_body_entered(body: Node):
	if not is_player(body):
		return

	player_nearby = true
	refresh_interaction_label()


func on_body_exited(body: Node):
	if not is_player(body):
		return

	player_nearby = false

	if interaction_label != null:
		interaction_label.hide()


func is_player(body: Node) -> bool:
	return body.name == "Player" or body.is_in_group("player")


func _unhandled_input(event):
	if not player_nearby:
		return

	if hack_in_progress or is_open or is_progression_locked():
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode != KEY_E:
		return

	get_viewport().set_input_as_handled()
	request_open_hack()


func request_open_hack():
	if is_open or is_progression_locked():
		return

	if hack_manager == null:
		find_hack_manager()

	if hack_manager == null:
		return

	hack_in_progress = true
	pending_action = HackAction.OPEN

	if interaction_label != null:
		interaction_label.hide()

	if DEBUG_DOORS:
		print("[PORTA] Pedido de abertura: ", door_id)

	hack_manager.start_hack(self)


func request_close_hack():
	if not is_open or is_progression_locked():
		return

	if hack_manager == null:
		find_hack_manager()

	if hack_manager == null:
		return

	hack_in_progress = true
	pending_action = HackAction.CLOSE

	hack_manager.start_hack(self)


func on_hack_success():
	hack_in_progress = false

	if is_progression_locked():
		update_door_state()
		return

	match pending_action:
		HackAction.OPEN:
			open_door()
		HackAction.CLOSE:
			close_door()


func on_hack_cancelled():
	hack_in_progress = false
	refresh_interaction_label()


func open_door():
	if is_progression_locked():
		return

	is_open = true
	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Acesso concedido: ", door_id)


func close_door():
	is_open = false
	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Fechada: ", door_id)


func set_power_locked(locked: bool):
	if power_locked == locked:
		return

	power_locked = locked

	if locked:
		hack_in_progress = false
		is_open = false

	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Bloqueio de energia alterado: ", door_id, " = ", locked)


func set_security_locked(locked: bool):
	if security_locked == locked:
		return

	security_locked = locked

	if locked:
		hack_in_progress = false
		is_open = false

	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Bloqueio de segurança alterado: ", door_id, " = ", locked)


func set_main_core_locked(locked: bool):
	if main_core_locked == locked:
		return

	main_core_locked = locked

	if locked:
		hack_in_progress = false
		is_open = false

	update_door_state()

	if DEBUG_DOORS:
		print("[PORTA] Bloqueio do núcleo alterado: ", door_id, " = ", locked)


func is_power_locked() -> bool:
	return power_locked


func is_security_locked() -> bool:
	return security_locked


func is_main_core_locked() -> bool:
	return main_core_locked


func is_progression_locked() -> bool:
	return power_locked or security_locked or main_core_locked


func refresh_interaction_label():
	if interaction_label == null:
		return

	if not player_nearby or is_open:
		interaction_label.hide()
		return

	if power_locked:
		interaction_label.text = "SETOR SEM ENERGIA"
	elif security_locked:
		interaction_label.text = "BLOQUEIO DE SEGURANÇA"
	elif main_core_locked:
		interaction_label.text = "AUTORIZAÇÃO NECESSÁRIA"
	else:
		interaction_label.text = "[E] INTERAGIR"

	interaction_label.show()


func update_door_state():
	if is_progression_locked():
		is_open = false

	if is_open:
		if door_visual != null:
			door_visual.hide()

		if door_collision != null:
			door_collision.set_deferred("disabled", true)
	else:
		if door_visual != null:
			door_visual.show()

			if power_locked:
				door_visual.color = Color(0.80, 0.10, 0.10, 1.0)
			elif security_locked:
				door_visual.color = Color(0.65, 0.12, 0.12, 1.0)
			elif main_core_locked:
				door_visual.color = Color(0.45, 0.20, 0.55, 1.0)
			else:
				door_visual.color = Color(0.25, 0.32, 0.36, 1.0)

		if door_collision != null:
			door_collision.set_deferred("disabled", false)

	refresh_interaction_label()


func rectangle_polygon(size: Vector2) -> PackedVector2Array:
	var half = size / 2.0

	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
