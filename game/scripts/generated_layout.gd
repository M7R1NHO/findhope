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


const FORCED_OPENING_MARGIN: float = 18.0
const AXIS_TOLERANCE: float = 1.0


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
# ABERTURAS FORÇADAS
#
# Estes são exatamente os quatro pontos que estavam
# a receber uma "tampa" de colisão.
# =========================================================

func get_forced_openings() -> Array:
	var opening_size: float = (
		corridor_width
		+ FORCED_OPENING_MARGIN * 2.0
	)


	return [
		{
			"position": Vector2(
				-700,
				-2700
			),
			"orientation": "vertical",
			"size": opening_size
		},

		{
			"position": Vector2(
				700,
				-2700
			),
			"orientation": "vertical",
			"size": opening_size
		},

		{
			"position": Vector2(
				-1650,
				-3800
			),
			"orientation": "vertical",
			"size": opening_size
		},

		{
			"position": Vector2(
				1650,
				-3800
			),
			"orientation": "vertical",
			"size": opening_size
		}
	]


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
	print(
		"======================================"
	)
	print(
		"UNDERGROUND LAYOUT + WALLS GENERATED"
	)
	print(
		"======================================"
	)


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

	room_root.position = data[
		"position"
	]


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
		data[
			"size"
		]
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


	# Sem título visível no chão: o nome da sala fica só nos dados.


	# -----------------------------------------------------
	# CAMINHÁVEL
	# -----------------------------------------------------

	walkable_polygons.append(
		rectangle_polygon_at(
			data[
				"position"
			],
			data[
				"size"
			]
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
			corridors[
				corridor_name
			],
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
	# ÁREA CAMINHÁVEL
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
	# COLLISION
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


	var wall_index: int = 0


	for polygon in merged_polygons:

		if polygon.size() < 2:
			continue


		for point_index in range(
			polygon.size()
		):

			var start: Vector2 = (
				polygon[
					point_index
				]
			)


			var next_index = (
				(point_index + 1)
				% polygon.size()
			)


			var end: Vector2 = (
				polygon[
					next_index
				]
			)


			var pieces = (
				cut_wall_segment_for_openings(
					start,
					end
				)
			)


			for piece in pieces:

				if piece.size() < 2:
					continue


				var piece_start: Vector2 = (
					piece[0]
				)


				var piece_end: Vector2 = (
					piece[1]
				)


				if (
					piece_start.distance_to(
						piece_end
					)
					< 0.5
				):
					continue


				create_wall_collision_segment(
					wall_body,
					piece_start,
					piece_end,
					wall_index
				)


				create_wall_visual_segment(
					visuals,
					piece_start,
					piece_end,
					wall_index
				)


				wall_index += 1


	print(
		"GENERATED WALL SEGMENTS: ",
		wall_index
	)


	print(
		"FORCED OPENINGS CREATED: 4"
	)


# =========================================================
# CORTAR ABERTURAS NAS PAREDES
# =========================================================

func cut_wall_segment_for_openings(
	start: Vector2,
	end: Vector2
) -> Array:

	# -----------------------------------------------------
	# PAREDE VERTICAL
	# -----------------------------------------------------

	if abs(
		start.x - end.x
	) <= AXIS_TOLERANCE:

		var x: float = (
			(start.x + end.x)
			/ 2.0
		)


		var low: float = min(
			start.y,
			end.y
		)


		var high: float = max(
			start.y,
			end.y
		)


		var intervals: Array = [
			Vector2(
				low,
				high
			)
		]


		for opening in get_forced_openings():

			if str(
				opening[
					"orientation"
				]
			) != "vertical":
				continue


			var center: Vector2 = (
				opening[
					"position"
				]
			)


			if abs(
				x - center.x
			) > AXIS_TOLERANCE:
				continue


			var opening_size: float = float(
				opening[
					"size"
				]
			)


			var cut_low: float = (
				center.y
				- opening_size / 2.0
			)


			var cut_high: float = (
				center.y
				+ opening_size / 2.0
			)


			intervals = subtract_interval(
				intervals,
				cut_low,
				cut_high
			)


		var result: Array = []


		for interval in intervals:

			result.append([
				Vector2(
					x,
					interval.x
				),

				Vector2(
					x,
					interval.y
				)
			])


		return result


	# -----------------------------------------------------
	# PAREDE HORIZONTAL
	# -----------------------------------------------------

	if abs(
		start.y - end.y
	) <= AXIS_TOLERANCE:

		var y: float = (
			(start.y + end.y)
			/ 2.0
		)


		var low: float = min(
			start.x,
			end.x
		)


		var high: float = max(
			start.x,
			end.x
		)


		var intervals: Array = [
			Vector2(
				low,
				high
			)
		]


		for opening in get_forced_openings():

			if str(
				opening[
					"orientation"
				]
			) != "horizontal":
				continue


			var center: Vector2 = (
				opening[
					"position"
				]
			)


			if abs(
				y - center.y
			) > AXIS_TOLERANCE:
				continue


			var opening_size: float = float(
				opening[
					"size"
				]
			)


			var cut_low: float = (
				center.x
				- opening_size / 2.0
			)


			var cut_high: float = (
				center.x
				+ opening_size / 2.0
			)


			intervals = subtract_interval(
				intervals,
				cut_low,
				cut_high
			)


		var result: Array = []


		for interval in intervals:

			result.append([
				Vector2(
					interval.x,
					y
				),

				Vector2(
					interval.y,
					y
				)
			])


		return result


	# -----------------------------------------------------
	# FALLBACK
	# -----------------------------------------------------

	return [
		[
			start,
			end
		]
	]


# =========================================================
# SUBTRAIR INTERVALO
# =========================================================

func subtract_interval(
	intervals: Array,
	cut_low: float,
	cut_high: float
) -> Array:

	var result: Array = []


	for interval in intervals:

		var interval_low: float = (
			interval.x
		)


		var interval_high: float = (
			interval.y
		)


		# Sem intersecção.
		if (
			cut_high <= interval_low
			or cut_low >= interval_high
		):
			result.append(
				interval
			)

			continue


		# Parte antes da abertura.
		if cut_low > interval_low:

			result.append(
				Vector2(
					interval_low,
					min(
						cut_low,
						interval_high
					)
				)
			)


		# Parte depois da abertura.
		if cut_high < interval_high:

			result.append(
				Vector2(
					max(
						cut_high,
						interval_low
					),
					interval_high
				)
			)


	return result


# =========================================================
# SEGMENTO DE COLLISION
# =========================================================

func create_wall_collision_segment(
	wall_body: StaticBody2D,
	start: Vector2,
	end: Vector2,
	index: int
):

	var collision = CollisionShape2D.new()


	collision.name = (
		"WallCollision_"
		+ str(index)
	)


	var shape = SegmentShape2D.new()


	shape.a = start

	shape.b = end


	collision.shape = shape


	wall_body.add_child(
		collision
	)


	set_editor_owner(
		collision
	)


# =========================================================
# SEGMENTO VISUAL
# =========================================================

func create_wall_visual_segment(
	visuals: Node2D,
	start: Vector2,
	end: Vector2,
	index: int
):

	var line = Line2D.new()


	line.name = (
		"WallLine_"
		+ str(index)
	)


	line.points = PackedVector2Array([
		start,
		end
	])


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
# UNIR ÁREA CAMINHÁVEL
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


				if result.size() == 1:

					merged[i] = (
						result[0]
					)


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
# RETÂNGULO NO MAPA
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
