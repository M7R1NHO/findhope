extends Area2D


# =========================================================
# CONFIGURAÇÃO
# =========================================================

@export var door_id: String = "underground_door_01"

@export var door_size: Vector2 = Vector2(
	30,
	160
)

@export var interaction_padding: float = 100.0


# =========================================================
# ESTADO
# =========================================================

enum HackAction {
	OPEN,
	CLOSE
}


var is_open: bool = false

var player_nearby: bool = false

var hack_in_progress: bool = false

var pending_action: HackAction = HackAction.OPEN


# =========================================================
# REFERÊNCIAS
# =========================================================

var hack_manager: Node = null

var door_visual: Polygon2D = null

var door_body: StaticBody2D = null

var door_collision: CollisionShape2D = null

var interaction_collision: CollisionShape2D = null

var interaction_label: Label = null


# =========================================================
# READY
# =========================================================

func _ready():
	create_door_nodes()

	find_hack_manager()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	update_door_state()

	print(
		"UNDERGROUND DOOR READY: ",
		door_id
	)


# =========================================================
# CRIAR NÓS DA PORTA AUTOMATICAMENTE
# =========================================================

func create_door_nodes():

	# -----------------------------------------------------
	# VISUAL
	# -----------------------------------------------------

	door_visual = Polygon2D.new()

	door_visual.name = "DoorVisual"

	door_visual.polygon = rectangle_polygon(
		door_size
	)

	door_visual.color = Color(
		0.25,
		0.32,
		0.36,
		1.0
	)

	door_visual.z_index = 2

	add_child(
		door_visual
	)


	# -----------------------------------------------------
	# CORPO FÍSICO
	# -----------------------------------------------------

	door_body = StaticBody2D.new()

	door_body.name = "DoorBody"

	add_child(
		door_body
	)


	# -----------------------------------------------------
	# COLISÃO DA PORTA
	# -----------------------------------------------------

	door_collision = CollisionShape2D.new()

	door_collision.name = "DoorCollision"

	var door_shape = RectangleShape2D.new()

	door_shape.size = door_size

	door_collision.shape = door_shape

	door_body.add_child(
		door_collision
	)


	# -----------------------------------------------------
	# ÁREA DE INTERAÇÃO
	# -----------------------------------------------------

	interaction_collision = CollisionShape2D.new()

	interaction_collision.name = "InteractionArea"

	var interaction_shape = RectangleShape2D.new()

	interaction_shape.size = Vector2(
		door_size.x + interaction_padding * 2.0,
		door_size.y + interaction_padding * 2.0
	)

	interaction_collision.shape = interaction_shape

	add_child(
		interaction_collision
	)


	# -----------------------------------------------------
	# LABEL
	# -----------------------------------------------------

	interaction_label = Label.new()

	interaction_label.name = "InteractionLabel"

	interaction_label.text = "[E] INTERAGIR"

	interaction_label.position = Vector2(
		-120,
		-door_size.y / 2.0 - 65
	)

	interaction_label.size = Vector2(
		240,
		40
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.add_theme_font_size_override(
		"font_size",
		18
	)

	interaction_label.hide()

	interaction_label.z_index = 20

	add_child(
		interaction_label
	)


# =========================================================
# ENCONTRAR HACK MANAGER
# =========================================================

func find_hack_manager():
	var current_scene = (
		get_tree().current_scene
	)

	if current_scene == null:
		return


	hack_manager = (
		current_scene.get_node_or_null(
			"HackManager"
		)
	)


	if hack_manager == null:
		push_error(
			"UndergroundDoor não encontrou HackManager."
		)


# =========================================================
# PLAYER ENTROU NA ÁREA
# =========================================================

func on_body_entered(
	body: Node
):
	if not is_player(
		body
	):
		return


	player_nearby = true


	if not is_open:
		interaction_label.show()


# =========================================================
# PLAYER SAIU
# =========================================================

func on_body_exited(
	body: Node
):
	if not is_player(
		body
	):
		return


	player_nearby = false

	interaction_label.hide()


# =========================================================
# IDENTIFICAR PLAYER
# =========================================================

func is_player(
	body: Node
) -> bool:

	if body.name == "Player":
		return true


	if body.is_in_group(
		"player"
	):
		return true


	return false


# =========================================================
# INPUT
# =========================================================

func _unhandled_input(
	event
):
	if not player_nearby:
		return


	if hack_in_progress:
		return


	if is_open:
		return


	if event is InputEventKey:
		if (
			event.pressed
			and not event.echo
			and event.keycode == KEY_E
		):
			get_viewport().set_input_as_handled()

			request_open_hack()


# =========================================================
# PEDIR HACK PARA ABRIR
# =========================================================

func request_open_hack():
	if is_open:
		return


	if hack_manager == null:
		find_hack_manager()


	if hack_manager == null:
		return


	hack_in_progress = true

	pending_action = HackAction.OPEN


	interaction_label.hide()


	print(
		"DOOR HACK REQUEST: ",
		door_id
	)


	hack_manager.start_hack(
		self
	)


# =========================================================
# FUTURO:
# RUN / HIDE PODEM CHAMAR ISTO
# PARA O JOGADOR FECHAR A PORTA
# =========================================================

func request_close_hack():
	if not is_open:
		return


	if hack_manager == null:
		find_hack_manager()


	if hack_manager == null:
		return


	hack_in_progress = true

	pending_action = HackAction.CLOSE


	hack_manager.start_hack(
		self
	)


# =========================================================
# HACK MANAGER CHAMA ISTO NO SUCESSO
# =========================================================

func on_hack_success():
	hack_in_progress = false


	match pending_action:

		HackAction.OPEN:
			open_door()

		HackAction.CLOSE:
			close_door()


# =========================================================
# ABRIR
# =========================================================

func open_door():
	is_open = true


	if door_visual != null:
		door_visual.hide()


	if door_collision != null:
		door_collision.set_deferred(
			"disabled",
			true
		)


	if interaction_label != null:
		interaction_label.hide()


	print(
		"ACCESS GRANTED: ",
		door_id
	)


# =========================================================
# FECHAR
# =========================================================

func close_door():
	is_open = false


	if door_visual != null:
		door_visual.show()


	if door_collision != null:
		door_collision.set_deferred(
			"disabled",
			false
		)


	print(
		"DOOR CLOSED: ",
		door_id
	)


# =========================================================
# ATUALIZAR ESTADO
# =========================================================

func update_door_state():

	if is_open:

		if door_visual != null:
			door_visual.hide()

		if door_collision != null:
			door_collision.disabled = true

	else:

		if door_visual != null:
			door_visual.show()

		if door_collision != null:
			door_collision.disabled = false


# =========================================================
# RETÂNGULO
# =========================================================

func rectangle_polygon(
	size: Vector2
) -> PackedVector2Array:

	var half = (
		size / 2.0
	)


	return PackedVector2Array([
		Vector2(
			-half.x,
			-half.y
		),

		Vector2(
			half.x,
			-half.y
		),

		Vector2(
			half.x,
			half.y
		),

		Vector2(
			-half.x,
			half.y
		)
	])
