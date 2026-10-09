extends Node


var underground_root: Node2D = null

var current_room_id: String = ""


var rooms := {
	"Entrance": {
		"name": "Entrada",
		"position": Vector2(0, 0),
		"size": Vector2(700, 400),
		"map_info":
			"O Hall de Entrada fica em cima."
	},

	"Hall": {
		"name": "Hall de Entrada",
		"position": Vector2(0, -900),
		"size": Vector2(1000, 600),
		"map_info":
			"A Entrada fica em baixo. "
			+ "O Armazém / Peças fica à esquerda. "
			+ "A Sala Técnica / Energia fica à direita."
	},

	"Storage": {
		"name": "Armazém / Peças",
		"position": Vector2(-1100, -1650),
		"size": Vector2(700, 500),
		"map_info":
			"O Hall de Entrada fica à direita e mais abaixo. "
			+ "A Sala de Suporte fica à esquerda. "
			+ "Os Arquivos / Registos ficam em cima."
	},

	"TechnicalRoom": {
		"name": "Sala Técnica / Energia",
		"position": Vector2(1100, -1650),
		"size": Vector2(800, 550),
		"map_info":
			"O Hall de Entrada fica à esquerda e mais abaixo. "
			+ "Segurança / Contenção fica à direita. "
			+ "O Laboratório / Análise fica em cima."
	},

	"SupportRoom": {
		"name": "Sala de Suporte",
		"position": Vector2(-2200, -1650),
		"size": Vector2(700, 500),
		"map_info":
			"O Armazém / Peças fica à direita. "
			+ "A Oficina / Manutenção fica em cima."
	},

	"Security": {
		"name": "Segurança / Contenção",
		"position": Vector2(2200, -1650),
		"size": Vector2(700, 500),
		"map_info":
			"A Sala Técnica / Energia fica à esquerda."
	},

	"Archives": {
		"name": "Arquivos / Registos",
		"position": Vector2(-1100, -2700),
		"size": Vector2(800, 550),
		"map_info":
			"O Armazém / Peças fica em baixo. "
			+ "O Laboratório / Análise fica à direita. "
			+ "O Santuário fica à esquerda e mais acima."
	},

	"Laboratory": {
		"name": "Laboratório / Análise",
		"position": Vector2(1100, -2700),
		"size": Vector2(800, 550),
		"map_info":
			"A Sala Técnica / Energia fica em baixo. "
			+ "Os Arquivos / Registos ficam à esquerda. "
			+ "O Núcleo Principal fica à direita e mais acima."
	},

	"Maintenance": {
		"name": "Oficina / Manutenção",
		"position": Vector2(-2200, -2700),
		"size": Vector2(700, 500),
		"map_info":
			"A Sala de Suporte fica em baixo."
	},

	"Sanctuary": {
		"name": "Santuário",
		"position": Vector2(-2200, -3800),
		"size": Vector2(1100, 650),
		"map_info":
			"Os Arquivos / Registos ficam à direita e mais abaixo. "
			+ "O Núcleo Principal fica à direita."
	},

	"MainCore": {
		"name": "Núcleo Principal",
		"position": Vector2(2200, -3800),
		"size": Vector2(1100, 650),
		"map_info":
			"O Laboratório / Análise fica à esquerda e mais abaixo. "
			+ "O Santuário fica à esquerda."
	}
}


func _ready():
	underground_root = get_parent() as Node2D

	if underground_root == null:
		push_error(
			"FacilityRoomTracker precisa ser filho de UndergroundRoot."
		)
		return

	call_deferred(
		"create_room_triggers"
	)


func create_room_triggers():
	if underground_root == null:
		return

	var created_count: int = 0

	for room_id in rooms.keys():
		var trigger_name = (
			"RoomTrigger_"
			+ room_id
		)

		if underground_root.has_node(
			trigger_name
		):
			continue

		var data: Dictionary = rooms[
			room_id
		]

		create_room_trigger(
			room_id,
			data
		)

		created_count += 1

	print("")
	print("======================================")
	print("FACILITY ROOM TRACKER READY")
	print("ROOM TRIGGERS CREATED: ", created_count)
	print("ROOMS REGISTERED: ", rooms.size())
	print("======================================")


func create_room_trigger(
	room_id: String,
	data: Dictionary
):
	var area = Area2D.new()

	area.name = (
		"RoomTrigger_"
		+ room_id
	)

	area.position = data[
		"position"
	]

	area.collision_layer = 0
	area.collision_mask = 0xFFFFFFFF

	area.monitoring = true
	area.monitorable = true


	var collision = CollisionShape2D.new()

	collision.name = "CollisionShape2D"


	var shape = RectangleShape2D.new()

	shape.size = (
		data["size"]
		- Vector2(
			50,
			50
		)
	)

	collision.shape = shape

	area.add_child(
		collision
	)


	area.body_entered.connect(
		_on_room_body_entered.bind(
			room_id
		)
	)

	area.body_exited.connect(
		_on_room_body_exited.bind(
			room_id
		)
	)


	underground_root.add_child(
		area
	)


func _on_room_body_entered(
	body: Node,
	room_id: String
):
	if not is_player(
		body
	):
		return

	current_room_id = room_id

	print(
		"FACILITY CURRENT ROOM: ",
		room_id
	)

	refresh_current_location_context()


func _on_room_body_exited(
	body: Node,
	room_id: String
):
	if not is_player(
		body
	):
		return

	if current_room_id != room_id:
		return

	current_room_id = ""

	print(
		"FACILITY CURRENT ROOM: CORRIDOR / NONE"
	)

	refresh_current_location_context()


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


func has_facility_map() -> bool:
	if underground_root == null:
		return false

	var terminal = (
		underground_root.get_node_or_null(
			"FacilityMapTerminal"
		)
	)

	if terminal == null:
		return false

	return terminal.get(
		"map_acquired"
	) == true


func get_current_room_id() -> String:
	return current_room_id


func get_current_room_name() -> String:
	if current_room_id.is_empty():
		return ""

	if not rooms.has(
		current_room_id
	):
		return ""

	return str(
		rooms[
			current_room_id
		]["name"]
	)


func get_current_room_map_info() -> String:
	if current_room_id.is_empty():
		return ""

	if not rooms.has(
		current_room_id
	):
		return ""

	return str(
		rooms[
			current_room_id
		]["map_info"]
	)


func refresh_current_location_context():
	var room_name = get_current_room_name()

	if room_name.is_empty():
		print(
			"FACILITY LOCATION READY FOR CHAT: CORRIDOR / NONE"
		)
		return

	print(
		"FACILITY LOCATION READY FOR CHAT: ",
		room_name
	)
