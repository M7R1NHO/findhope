
@tool
extends Node2D

@export var room_size: Vector2 = Vector2(1000, 600)
@export var corridor_width: float = 180.0
@export var corridor_length: float = 220.0
@export var wall_width: float = 24.0

@export var room_color: Color = Color(0.12, 0.15, 0.18, 1.0)
@export var corridor_color: Color = Color(0.08, 0.10, 0.12, 1.0)
@export var wall_color: Color = Color(0.65, 0.72, 0.75, 1.0)

@export var structure_size: Vector2 = Vector2(150, 400)
@export var structure_offset_x: float = 250.0

var _gerar_layout_agora := false

@export var gerar_layout_agora: bool:
	get:
		return _gerar_layout_agora
	set(value):
		_gerar_layout_agora = false
		if value and is_inside_tree():
			rebuild_layout()


func _ready() -> void:
	if not Engine.is_editor_hint():
		rebuild_layout()


func rebuild_layout() -> void:
	if not is_inside_tree():
		return

	# Remover os elementos gerados anteriormente.
	for child in get_children():
		if child.is_in_group("phase3_generated"):
			remove_child(child)
			child.free()

	var step_x: float = room_size.x + corridor_length

	# SALA 1 — ANDROID
	create_room(
		"SALA 1 - ANDROID",
		Vector2(0, 0),
		false,
		true
	)

	# SALA 2 — CRIATURA
	create_room(
		"SALA 2 - CRIATURA",
		Vector2(step_x, 0),
		true,
		true
	)

	# SALA 3 — NAVE
	create_room(
		"SALA 3 - NAVE",
		Vector2(step_x * 2.0, 0),
		true,
		false
	)

	# Corredor entre a sala 1 e a sala 2.
	create_corridor(
		Vector2(room_size.x / 2.0 + corridor_length / 2.0, 0)
	)

	# Corredor entre a sala 2 e a sala 3.
	create_corridor(
		Vector2(step_x + room_size.x / 2.0 + corridor_length / 2.0, 0)
	)

	# Duas estruturas na parte superior da sala central.
	create_structure(
		Vector2(step_x - structure_offset_x, -room_size.y / 2.0),
		structure_size,
		"Estrutura_Superior_Esquerda"
	)

	create_structure(
		Vector2(step_x + structure_offset_x, -room_size.y / 2.0),
		structure_size,
		"Estrutura_Superior_Direita"
	)

	# Duas estruturas na parte inferior da sala central.
	create_structure(
		Vector2(step_x - structure_offset_x, room_size.y / 2.0),
		structure_size,
		"Estrutura_Inferior_Esquerda"
	)

	create_structure(
		Vector2(step_x + structure_offset_x, room_size.y / 2.0),
		structure_size,
		"Estrutura_Inferior_Direita"
	)

	print("PHASE 3: 3 salas, 2 corredores e 4 estruturas gerados.")


func create_room(
	room_name: String,
	center: Vector2,
	opening_left: bool,
	opening_right: bool
) -> void:
	var room := Node2D.new()
	room.name = room_name.replace(" ", "_")
	room.position = center
	room.add_to_group("phase3_generated")
	add_child(room)

	# Chão da sala.
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = rectangle(room_size)
	floor.color = room_color
	floor.z_index = -2
	room.add_child(floor)

	# Identificação da sala.
	var label := Label.new()
	label.name = "RoomLabel"
	label.text = room_name
	label.position = Vector2(
		-room_size.x / 2.0,
		-room_size.y / 2.0 + 20.0
	)
	label.size = Vector2(room_size.x, 60.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	room.add_child(label)

	# Colisões das paredes.
	var wall_body := StaticBody2D.new()
	wall_body.name = "WallCollision"
	room.add_child(wall_body)

	var half := room_size / 2.0
	var opening_half := corridor_width / 2.0
	var side_length := half.y - opening_half

	# Paredes superior e inferior.
	create_wall(
		wall_body,
		Vector2(0, -half.y),
		Vector2(room_size.x, wall_width)
	)

	create_wall(
		wall_body,
		Vector2(0, half.y),
		Vector2(room_size.x, wall_width)
	)

	# Parede esquerda.
	if opening_left:
		create_wall(
			wall_body,
			Vector2(-half.x, -(opening_half + side_length / 2.0)),
			Vector2(wall_width, side_length)
		)

		create_wall(
			wall_body,
			Vector2(-half.x, opening_half + side_length / 2.0),
			Vector2(wall_width, side_length)
		)
	else:
		create_wall(
			wall_body,
			Vector2(-half.x, 0),
			Vector2(wall_width, room_size.y)
		)

	# Parede direita.
	if opening_right:
		create_wall(
			wall_body,
			Vector2(half.x, -(opening_half + side_length / 2.0)),
			Vector2(wall_width, side_length)
		)

		create_wall(
			wall_body,
			Vector2(half.x, opening_half + side_length / 2.0),
			Vector2(wall_width, side_length)
		)
	else:
		create_wall(
			wall_body,
			Vector2(half.x, 0),
			Vector2(wall_width, room_size.y)
		)


func create_corridor(center: Vector2) -> void:
	var corridor := Polygon2D.new()
	corridor.name = "Corridor"
	corridor.position = center
	corridor.polygon = rectangle(
		Vector2(corridor_length, corridor_width)
	)
	corridor.color = corridor_color
	corridor.z_index = -1
	corridor.add_to_group("phase3_generated")
	add_child(corridor)


func create_structure(
	center: Vector2,
	size: Vector2,
	structure_name: String
) -> void:
	var structure := Polygon2D.new()
	structure.name = structure_name
	structure.position = center
	structure.polygon = rectangle(size)
	structure.color = wall_color
	structure.z_index = 1
	structure.add_to_group("phase3_generated")
	add_child(structure)


func create_wall(
	parent: Node2D,
	center: Vector2,
	size: Vector2
) -> void:
	# Colisão.
	var collision := CollisionShape2D.new()
	collision.name = "WallCollisionShape"

	var shape := RectangleShape2D.new()
	shape.size = size

	collision.shape = shape
	collision.position = center
	parent.add_child(collision)

	# Representação visual.
	var visual := Polygon2D.new()
	visual.name = "WallVisual"
	visual.polygon = rectangle(size)
	visual.position = center
	visual.color = wall_color
	visual.z_index = 1
	parent.add_child(visual)


func rectangle(size: Vector2) -> PackedVector2Array:
	var half := size / 2.0

	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
