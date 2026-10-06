extends Area2D


var player_nearby: bool = false

var tools_collected: bool = false
var equipment_connected: bool = false

var main: Node = null
var fight_manager: Node = null

var equipment_visual: Polygon2D = null
var energy_visual: Polygon2D = null
var interaction_label: Label = null


func _ready():
	main = get_tree().current_scene

	if main != null:
		fight_manager = (
			main.get_node_or_null(
				"FightManager"
			)
		)

	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	monitoring = true
	monitorable = true

	create_collision()
	create_visuals()
	create_interaction_label()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print(
		"SONIC EQUIPMENT READY"
	)


func _unhandled_input(event):
	if equipment_connected:
		return

	if not player_nearby:
		return

	if not (
		event is InputEventKey
	):
		return

	if (
		not event.pressed
		or event.echo
	):
		return

	if event.keycode != KEY_E:
		return

	get_viewport().set_input_as_handled()

	if not tools_collected:
		collect_tools()

	else:
		connect_equipment()


func create_collision():
	var collision = CollisionShape2D.new()

	collision.name = "InteractionArea"

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		190,
		150
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_visuals():
	equipment_visual = Polygon2D.new()

	equipment_visual.name = "SonicDevice"

	equipment_visual.polygon = PackedVector2Array([
		Vector2(-65, -35),
		Vector2(65, -35),
		Vector2(65, 35),
		Vector2(-65, 35)
	])

	equipment_visual.color = Color(
		0.25,
		0.28,
		0.30,
		1.0
	)

	equipment_visual.z_index = 5

	add_child(
		equipment_visual
	)


	energy_visual = Polygon2D.new()

	energy_visual.name = "AlienEnergy"

	energy_visual.polygon = PackedVector2Array([
		Vector2(-22, -22),
		Vector2(22, -22),
		Vector2(22, 22),
		Vector2(-22, 22)
	])

	energy_visual.position = Vector2(
		90,
		0
	)

	energy_visual.color = Color(
		0.18,
		0.75,
		0.72,
		1.0
	)

	energy_visual.z_index = 6

	add_child(
		energy_visual
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] RECOLHER FERRAMENTAS"
	)

	interaction_label.position = Vector2(
		-180,
		-100
	)

	interaction_label.size = Vector2(
		360,
		45
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.add_theme_font_size_override(
		"font_size",
		17
	)

	interaction_label.visible = false

	interaction_label.z_index = 10

	add_child(
		interaction_label
	)


func on_body_entered(
	body: Node
):
	if not is_player(
		body
	):
		return

	player_nearby = true

	interaction_label.visible = true


func on_body_exited(
	body: Node
):
	if not is_player(
		body
	):
		return

	player_nearby = false

	interaction_label.visible = false


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


func collect_tools():
	if tools_collected:
		return

	tools_collected = true

	equipment_visual.color = Color(
		0.35,
		0.43,
		0.46,
		1.0
	)

	interaction_label.text = (
		"[E] CONECTAR ATLAS À ENERGIA"
	)

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Estas ferramentas fazem parte de um sistema acústico. "
			+ "A estrutura parece compatível comigo, "
			+ "mas precisa de uma fonte de energia."
		)

	print("")
	print(
		"SONIC TOOLS COLLECTED"
	)


func connect_equipment():
	if equipment_connected:
		return

	if not tools_collected:
		return

	if fight_manager == null:
		push_error(
			"FightManager não encontrado."
		)

		return

	if not fight_manager.has_method(
		"unlock_combat"
	):
		push_error(
			"FightManager não possui unlock_combat()."
		)

		return

	equipment_connected = true

	fight_manager.unlock_combat()

	equipment_visual.color = Color(
		0.15,
		0.82,
		0.68,
		1.0
	)

	energy_visual.color = Color(
		0.30,
		1.0,
		0.82,
		1.0
	)

	interaction_label.text = (
		"SISTEMA SONORO OPERACIONAL"
	)

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Conexão concluída. "
			+ "O equipamento utiliza energia desta instalação "
			+ "para gerar ondas sonoras de alta intensidade. "
			+ "Se encontrarmos novamente aquela criatura, "
			+ "agora tenho uma forma de a afastar."
		)

	send_gameplay_context()

	print("")
	print(
		"======================================"
	)

	print(
		"SONIC COMBAT EQUIPMENT CONNECTED"
	)

	print(
		"FIGHT UNLOCKED"
	)

	print(
		"======================================"
	)


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"sonic_equipment_connected",
		"combat_equipment_acquired",
		"Atlas recolheu ferramentas no Armazém / Peças "
		+ "e integrou um equipamento acústico da instalação "
		+ "a uma fonte de energia alienígena. "
		+ "O equipamento produz ondas sonoras de alta intensidade "
		+ "que podem afastar a criatura. "
		+ "Atlas não utiliza uma arma de projéteis: "
		+ "o seu método de combate atual depende de emissão sonora. "
		+ "Durante a descarga, o jogador também precisa manter "
		+ "uma distância segura da zona de emissão.",
		true
	)
