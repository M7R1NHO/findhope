
@tool
extends Node2D

# Dimensoes das salas e dos corredores.
@export var room_size: Vector2 = Vector2(1000.0, 600.0)
@export var corridor_width: float = 180.0
@export var corridor_length: float = 220.0
@export var wall_width: float = 24.0

# Dimensoes das estruturas da sala central.
@export var structure_size: Vector2 = Vector2(150.0, 200.0)
@export var structure_offset_x: float = 250.0
@export var structure_offset_y: float = 150.0

# Cores do layout.
@export var room_color: Color = Color(0.12, 0.15, 0.18, 1.0)
@export var corridor_color: Color = Color(0.08, 0.10, 0.12, 1.0)
@export var wall_color: Color = Color(0.65, 0.72, 0.75, 1.0)
@export var structure_color: Color = Color(0.35, 0.40, 0.44, 1.0)

# Botao para reconstruir o layout no Inspetor.
@export var gerar_layout_agora: bool = false:
	set(value):
		gerar_layout_agora = false

		if value and is_inside_tree():
			rebuild_layout()


func _ready() -> void:
	if not Engine.is_editor_hint():
		rebuild_layout()


func rebuild_layout() -> void:
	if not is_inside_tree():
		return

	# Limpar apenas os elementos deste layout.
	for child in get_children():
		if child.is_in_group("phase3_generated"):
			remove_child(child)
			child.free()

	# Distancia entre os centros das salas.
	var step_x: float = room_size.x + corridor_length

	var room_1_x: float = 0.0
	var room_2_x: float = step_x
	var room_3_x: float = step_x * 2.0

	# Sala 1: Android. Abertura na parede direita.
	create_room(
		"Sala_1_Android",
		Vector2(room_1_x, 0.0),
		false,
		true,
		"SALA 1 - ANDROID"
	)

	# Sala 2: Criatura. Aberturas nos dois lados.
	create_room(
		"Sala_2_Criatura",
		Vector2(room_2_x, 0.0),
		true,
		true,
		"SALA 2 - CRIATURA"
	)

	# Sala 3: Nave. Abertura na parede esquerda.
	create_room(
		"Sala_3_Nave",
		Vector2(room_3_x, 0.0),
		true,
		false,
		"SALA 3 - NAVE"
	)

	# Corredor entre as salas 1 e 2.
	create_corridor(
		"Corredor_Android_Criatura",
		Vector2(room_1_x + room_size.x / 2.0 + corridor_length / 2.0, 0.0)
	)

	# Corredor entre as salas 2 e 3.
	create_corridor(
		"Corredor_Criatura_Nave",
		Vector2(room_2_x + room_size.x / 2.0 + corridor_length / 2.0, 0.0)
	)

	# Quatro estruturas em torno da sala central.
	create_structure(
		"Estrutura_Superior_Esquerda",
		Vector2(room_2_x - structure_offset_x, -structure_offset_y)
	)

	create_structure(
		"Estrutura_Superior_Direita",
		Vector2(room_2_x + structure_offset_x, -structure_offset_y)
	)

	create_structure(
		"Estrutura_Inferior_Esquerda",
		Vector2(room_2_x - structure_offset_x, structure_offset_y)
	)

	create_structure(
		"Estrutura_Inferior_Direita",
		Vector2(room_2_x + structure_offset_x, structure_offset_y)
	)

	print("PHASE 3: 3 salas, 2 corredores e 4 estruturas criados.")


func create_room(
	room_name: String,
	center: Vector2,
	opening_left: bool,
	opening_right: bool,
	label_text: String
) -> void:
	var room := Node2D.new()
	room.name = room_name
	room.position = center
	room.add_to_group("phase3_generated")
	add_child(room)

	# Chao da sala.
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = rectangle(room_size)
	floor.color = room_color
	floor.z_index = -2
	room.add_child(floor)

	# Nome da sala.
	var label := Label.new()
	label.name = "RoomLabel"
	label.text = label_text
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

	# Corpo das colisoes das paredes.
	var wall_body := StaticBody2D.new()
	wall_body.name = "WallCollision"
	room.add_child(wall_body)

	var half_x: float = room_size.x / 2.0
	var half_y: float = room_size.y / 2.0
	var opening_half: float = corridor_width / 2.0
	var side_length: float = half_y - opening_half

	# Parede superior.
	create_wall(
		wall_body,
		Vector2(0.0, -half_y),
		Vector2(room_size.x, wall_width)
	)

	# Parede inferior.
	create_wall(
		wall_body,
		Vector2(0.0, half_y),
		Vector2(room_size.x, wall_width)
	)

	# Parede esquerda.
	if opening_left:
		create_wall(
			wall_body,
			Vector2(-half_x, -(opening_half + side_length / 2.0)),
			Vector2(wall_width, side_length)
		)

		create_wall(
			wall_body,
			Vector2(-half_x, opening_half + side_length / 2.0),
			Vector2(wall_width, side_length)
		)
	else:
		create_wall(
			wall_body,
			Vector2(-half_x, 0.0),
			Vector2(wall_width, room_size.y)
		)

	# Parede direita.
	if opening_right:
		create_wall(
			wall_body,
			Vector2(half_x, -(opening_half + side_length / 2.0)),
			Vector2(wall_width, side_length)
		)

		create_wall(
			wall_body,
			Vector2(half_x, opening_half + side_length / 2.0),
			Vector2(wall_width, side_length)
		)
	else:
		create_wall(
			wall_body,
			Vector2(half_x, 0.0),
			Vector2(wall_width, room_size.y)
		)


func create_corridor(
	corridor_name: String,
	center: Vector2
) -> void:
	var corridor := Node2D.new()
	corridor.name = corridor_name
	corridor.position = center
	corridor.add_to_group("phase3_generated")
	add_child(corridor)

	# Aspeto visual do corredor.
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = rectangle(
		Vector2(corridor_length, corridor_width)
	)
	floor.color = corridor_color
	floor.z_index = -1
	corridor.add_child(floor)


func create_structure(
	structure_name: String,
	center: Vector2
) -> void:
	var structure := StaticBody2D.new()
	structure.name = structure_name
	structure.position = center
	structure.add_to_group("phase3_generated")
	add_child(structure)

	# Aspeto visual da estrutura.
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = rectangle(structure_size)
	visual.color = structure_color
	visual.z_index = 1
	structure.add_child(visual)

	# Colisao da estrutura.
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = structure_size
	collision.shape = shape
	structure.add_child(collision)


func create_wall(
	parent: Node2D,
	center: Vector2,
	size: Vector2
) -> void:
	# Colisao da parede.
	var collision := CollisionShape2D.new()
	collision.name = "Collision"

	var shape := RectangleShape2D.new()
	shape.size = size

	collision.shape = shape
	collision.position = center
	parent.add_child(collision)

	# Representacao visual da parede.
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = rectangle(size)
	visual.position = center
	visual.color = wall_color
	visual.z_index = 1
	parent.add_child(visual)


func rectangle(size: Vector2) -> PackedVector2Array:
	var half: Vector2 = size / 2.0

	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
