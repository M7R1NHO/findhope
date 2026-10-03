@tool
extends Node2D


# =========================================================
# GERAR PELO INSPETOR
# =========================================================

var _gerar_layout_agora: bool = false


@export var gerar_layout_agora: bool:
	get:
		return _gerar_layout_agora

	set(value):
		_gerar_layout_agora = value

		if (
			value
			and Engine.is_editor_hint()
			and is_inside_tree()
		):
			_gerar_layout_agora = false

			call_deferred(
				"rebuild_layout"
			)


# =========================================================
# CONFIGURAÇÃO
# =========================================================

@export var corridor_width: float = 160.0
@export var corridor_overlap: float = 12.0

@export var room_border_size: float = 16.0

@export var wall_width: float = 24.0


@export var room_color: Color = Color(
	0.18,
	0.22,
	0.25,
	1.0
)


@export var important_room_color: Color = Color(
	0.22,
	0.27,
	0.31,
	1.0
)


@export var corridor_color: Color = Color(
	0.12,
	0.16,
	0.18,
	1.0
)


@export var border_color: Color = Color(
	0.65,
	0.72,
	0.75,
	1.0
)


@export var wall_color: Color = Color(
	0.75,
	0.82,
	0.85,
	1.0
)


@export var label_color: Color = Color.WHITE


# =========================================================
# SALAS
# =========================================================

var rooms := {
	"Entrance": {
		"name": "ENTRADA",
		"position": Vector2(0, 0),
		"size": Vector2(700, 400),
		"important": false
	},

	"Hall": {
		"name": "HALL DE ENTRADA",
		"position": Vector2(0, -900),
		"size": Vector2(1000, 600),
		"important": true
	},

	"Storage": {
		"name": "ARMAZÉM / PEÇAS",
		"position": Vector2(-1100, -1650),
		"size": Vector2(700, 500),
		"important": false
	},

	"TechnicalRoom": {
		"name": "SALA TÉCNICA / ENERGIA",
		"position": Vector2(1100, -1650),
		"size": Vector2(800, 550),
		"important": true
	},

	"SupportRoom": {
		"name": "SALA DE SUPORTE",
		"position": Vector2(-2200, -1650),
		"size": Vector2(700, 500),
		"important": false
	},

	"Security": {
		"name": "SEGURANÇA / CONTENÇÃO",
		"position": Vector2(2200, -1650),
		"size": Vector2(700, 500),
		"important": false
	},

	"Archives": {
		"name": "ARQUIVOS / REGISTOS",
		"position": Vector2(-1100, -2700),
		"size": Vector2(800, 550),
		"important": true
	},

	"Laboratory": {
		"name": "LABORATÓRIO / ANÁLISE",
		"position": Vector2(1100, -2700),
		"size": Vector2(800, 550),
		"important": true
	},

	"Maintenance": {
		"name": "OFICINA / MANUTENÇÃO",
		"position": Vector2(-2200, -2700),
		"size": Vector2(700, 500),
		"important": false
	},

	"Sanctuary": {
		"name": "SANTUÁRIO / ESCULTURAS",
		"position": Vector2(-2200, -3800),
		"size": Vector2(1100, 650),
		"important": true
	},

	"MainCore": {
		"name": "NÚCLEO PRINCIPAL",
		"position": Vector2(2200, -3800),
		"size": Vector2(1100, 650),
		"important": true
	}
}


# =========================================================
# CORREDORES
# =========================================================

var corridors := {
	"Entrance_Hall": [
		Vector2(0, -200),
		Vector2(0, -600)
	],

	"Hall_Storage": [
		Vector2(-300, -1200),
		Vector2(-300, -1650),
		Vector2(-750, -1650)
	],

	"Hall_Technical": [
		Vector2(300, -1200),
		Vector2(300, -1650),
		Vector2(700, -1650)
	],

	"Storage_Support": [
		Vector2(-1450, -1650),
		Vector2(-1850, -1650)
	],

	"Technical_Security": [
		Vector2(1500, -1650),
		Vector2(1850, -1650)
	],

	"Storage_Archives": [
		Vector2(-1100, -1900),
		Vector2(-1100, -2425)
	],

	"Technical_Laboratory": [
		Vector2(1100, -1925),
		Vector2(1100, -2425)
	],

	"Support_Maintenance": [
		Vector2(-2200, -1900),
		Vector2(-2200, -2450)
	],

	"Archives_Sanctuary": [
		Vector2(-1100, -2975),
		Vector2(-1100, -3300),
		Vector2(-1650, -3300),
		Vector2(-1650, -3475)
	],

	"Laboratory_MainCore": [
		Vector2(1100, -2975),
		Vector2(1100, -3300),
		Vector2(1650, -3300),
		Vector2(1650, -3475)
	],

	"Sanctuary_MainCore": [
		Vector2(-1650, -3800),
		Vector2(1650, -3800)
	],

	"Archives_Laboratory": [
		Vector2(-700, -2700),
		Vector2(700, -2700)
	]
}


# =========================================================
# REBUILD
# =========================================================

func rebuild_layout():
	if not is_inside_tree():
		return

	clear_generated_layout()

	var walkable_polygons: Array = []

	create_all_rooms(
		walkable_polygons
	)

	create_all_corridors(
		walkable_polygons
	)

	create_generated_walls(
		walkable_polygons
	)

	print("")
	print("======================================")
	print("UNDERGROUND LAYOUT + WALLS GENERATED")
	print("======================================")


# =========================================================
# LIMPAR
# =========================================================

func clear_generated_layout():
	var children = get_children()

	for child in children:
		remove_child(
			child
		)

		child.free()


# =========================================================
# OWNER DO EDITOR
# =========================================================

func set_editor_owner(
	node: Node
):
	if not Engine.is_editor_hint():
		return

	var scene_root = (
		get_tree().edited_scene_root
	)

	if scene_root != null:
		node.owner = scene_root


# =========================================================
# SALAS
# =========================================================

func create_all_rooms(
	walkable_polygons: Array
):
	for room_id in rooms.keys():
		var data = rooms[
			room_id
		]

		create_room(
			room_id,
			data,
			walkable_polygons
		)


func create_room(
	room_id: String,
	data: Dictionary,
	walkable_polygons: Array
):
	var room_root = Node2D.new()

	room_root.name = room_id
	room_root.position = data["position"]

	add_child(
		room_root
	)

	set_editor_owner(
		room_root
	)


	# -----------------------------------------------------
	# BORDA VISUAL
	# -----------------------------------------------------

	var border = Polygon2D.new()

	border.name = "Border"

	border.polygon = rectangle_polygon(
		data["size"]
		+ Vector2(
			room_border_size * 2.0,
			room_border_size * 2.0
		)
	)

	border.color = border_color
	border.z_index = -8

	room_root.add_child(
		border
	)

	set_editor_owner(
		border
	)


	# -----------------------------------------------------
	# CHÃO
	# -----------------------------------------------------

	var floor = Polygon2D.new()

	floor.name = "Floor"

	floor.polygon = rectangle_polygon(
		data["size"]
	)

	if data.get(
		"important",
		false
	):
		floor.color = important_room_color

	else:
		floor.color = room_color

	floor.z_index = -7

	room_root.add_child(
		floor
	)

	set_editor_owner(
		floor
	)


	# -----------------------------------------------------
	# NOME
	# -----------------------------------------------------

	var label = Label.new()

	label.name = "RoomName"
	label.text = data["name"]

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	label.add_theme_font_size_override(
		"font_size",
		24
	)

	label.add_theme_color_override(
		"font_color",
		label_color
	)

	label.position = Vector2(
		-data["size"].x / 2.0,
		-30.0
	)

	label.size = Vector2(
		data["size"].x,
		60.0
	)

	room_root.add_child(
		label
	)

	set_editor_owner(
		label
	)


	# -----------------------------------------------------
	# POLÍGONO CAMINHÁVEL
	# -----------------------------------------------------

	walkable_polygons.append(
		rectangle_polygon_at(
			data["position"],
			data["size"]
		)
	)


# =========================================================
# CORREDORES
# =========================================================

func create_all_corridors(
	walkable_polygons: Array
):
	for corridor_name in corridors.keys():
		create_corridor_path(
			corridor_name,
			corridors[corridor_name],
			walkable_polygons
		)


func create_corridor_path(
	corridor_name: String,
	points: Array,
	walkable_polygons: Array
):
	var corridor_root = Node2D.new()

	corridor_root.name = (
		"Corridor_"
		+ corridor_name
	)

	add_child(
		corridor_root
	)

	set_editor_owner(
		corridor_root
	)

	if points.size() < 2:
		return

	for index in range(
		points.size() - 1
	):
		create_corridor_segment(
			corridor_root,
			points[index],
			points[index + 1],
			index,
			walkable_polygons
		)


func create_corridor_segment(
	parent: Node2D,
	start: Vector2,
	end: Vector2,
	index: int,
	walkable_polygons: Array
):
	var direction = (
		end - start
	)

	var length = (
		direction.length()
	)

	if length <= 0.0:
		return

	var center = (
		start + end
	) / 2.0

	var segment_size: Vector2


	# -----------------------------------------------------
	# HORIZONTAL
	# -----------------------------------------------------

	if abs(direction.x) >= abs(
		direction.y
	):
		segment_size = Vector2(
			length
			+ corridor_overlap * 2.0,
			corridor_width
		)


	# -----------------------------------------------------
	# VERTICAL
	# -----------------------------------------------------

	else:
		segment_size = Vector2(
			corridor_width,
			length
			+ corridor_overlap * 2.0
		)


	var segment = Polygon2D.new()

	segment.name = (
		"Segment_"
		+ str(index)
	)

	segment.position = center

	segment.polygon = rectangle_polygon(
		segment_size
	)

	segment.color = corridor_color
	segment.z_index = -6

	parent.add_child(
		segment
	)

	set_editor_owner(
		segment
	)


	# -----------------------------------------------------
	# ÁREA CAMINHÁVEL DO CORREDOR
	# -----------------------------------------------------

	walkable_polygons.append(
		rectangle_polygon_at(
			center,
			segment_size
		)
	)


# =========================================================
# PAREDES AUTOMÁTICAS
# =========================================================

func create_generated_walls(
	walkable_polygons: Array
):
	if walkable_polygons.is_empty():
		return

	var merged_polygons = (
		merge_walkable_polygons(
			walkable_polygons
		)
	)


	var walls_root = Node2D.new()

	walls_root.name = "GeneratedWalls"

	add_child(
		walls_root
	)

	set_editor_owner(
		walls_root
	)


	# -----------------------------------------------------
	# COLISÃO
	# -----------------------------------------------------

	var wall_body = StaticBody2D.new()

	wall_body.name = "WallCollision"

	walls_root.add_child(
		wall_body
	)

	set_editor_owner(
		wall_body
	)


	# -----------------------------------------------------
	# VISUAIS
	# -----------------------------------------------------

	var visuals = Node2D.new()

	visuals.name = "WallVisuals"

	walls_root.add_child(
		visuals
	)

	set_editor_owner(
		visuals
	)


	for index in range(
		merged_polygons.size()
	):
		var polygon: PackedVector2Array = (
			merged_polygons[index]
		)


		# =================================================
		# COLLISION POLYGON
		# =================================================

		var collision = (
			CollisionPolygon2D.new()
		)

		collision.name = (
			"WallCollision_"
			+ str(index)
		)

		collision.build_mode = (
			CollisionPolygon2D.BUILD_SEGMENTS
		)

		collision.polygon = polygon

		wall_body.add_child(
			collision
		)

		set_editor_owner(
			collision
		)


		# =================================================
		# LINHA VISUAL
		# =================================================

		var line = Line2D.new()

		line.name = (
			"WallLine_"
			+ str(index)
		)

		line.points = polygon

		line.closed = true

		line.width = wall_width

		line.default_color = (
			wall_color
		)

		line.antialiased = true

		line.z_index = -4

		visuals.add_child(
			line
		)

		set_editor_owner(
			line
		)


# =========================================================
# UNIR TODA A ÁREA CAMINHÁVEL
# =========================================================

func merge_walkable_polygons(
	source_polygons: Array
) -> Array:

	var merged: Array = []

	for polygon in source_polygons:
		merged.append(
			polygon
		)


	var changed = true

	while changed:
		changed = false

		var i = 0

		while i < merged.size():

			var j = i + 1

			while j < merged.size():

				var result = (
					Geometry2D.merge_polygons(
						merged[i],
						merged[j]
					)
				)

				# Se virou apenas um polígono,
				# então havia contacto/intersecção.
				if result.size() == 1:

					merged[i] = result[0]

					merged.remove_at(
						j
					)

					changed = true

					break

				j += 1

			if changed:
				break

			i += 1


	return merged


# =========================================================
# RETÂNGULO LOCAL
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


# =========================================================
# RETÂNGULO EM POSIÇÃO DO MAPA
# =========================================================

func rectangle_polygon_at(
	center: Vector2,
	size: Vector2
) -> PackedVector2Array:

	var local_polygon = (
		rectangle_polygon(
			size
		)
	)

	var result = (
		PackedVector2Array()
	)

	for point in local_polygon:
		result.append(
			point + center
		)

	return result
