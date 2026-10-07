extends Area2D


var player_nearby: bool = false
var terminal_read: bool = false
var terminal_open: bool = false

var main: Node = null

var terminal_visual: Polygon2D = null
var interaction_label: Label = null

var terminal_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene

	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	monitoring = true
	monitorable = true

	create_collision()
	create_visual()
	create_interaction_label()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print(
		"SUPPORT TERMINAL READY"
	)


func _unhandled_input(event):
	if terminal_open:
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

	open_terminal()


func create_collision():
	var collision = CollisionShape2D.new()

	collision.name = "InteractionArea"

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		220,
		170
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_visual():
	terminal_visual = Polygon2D.new()

	terminal_visual.name = "TerminalVisual"

	terminal_visual.polygon = PackedVector2Array([
		Vector2(-90, -55),
		Vector2(90, -55),
		Vector2(90, 55),
		Vector2(-90, 55)
	])

	terminal_visual.color = Color(
		0.12,
		0.32,
		0.42,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "SUPORTE TÉRMICO"

	title.position = Vector2(
		-120,
		-22
	)

	title.size = Vector2(
		240,
		45
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		15
	)

	title.z_index = 7

	add_child(
		title
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] ACESSAR TERMINAL"
	)

	interaction_label.position = Vector2(
		-170,
		-110
	)

	interaction_label.size = Vector2(
		340,
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


func open_terminal():
	if terminal_open:
		return

	terminal_open = true

	get_tree().paused = true

	create_terminal_ui()

	if not terminal_read:
		terminal_read = true

		register_discovery()


func create_terminal_ui():
	destroy_terminal_ui()

	terminal_layer = CanvasLayer.new()

	terminal_layer.name = (
		"SupportTerminalUI"
	)

	terminal_layer.layer = 700

	terminal_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		terminal_layer
	)


	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.0,
		0.0,
		0.0,
		0.88
	)

	terminal_layer.add_child(
		background
	)


	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(
		center
	)


	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		720,
		500
	)

	container.add_theme_constant_override(
		"separation",
		22
	)

	center.add_child(
		container
	)


	var title = Label.new()

	title.text = (
		"SISTEMA DE SUPORTE // CONTROLO TÉRMICO"
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		28
	)

	container.add_child(
		title
	)


	var separator = HSeparator.new()

	container.add_child(
		separator
	)


	var report = Label.new()

	report.text = (
		"RELATÓRIO DE ESTADO\n\n"
		+ "Rede térmica: PARCIALMENTE OPERACIONAL\n\n"
		+ "Setores habitáveis: ESTÁVEIS\n"
		+ "Setores inferiores: VARIAÇÃO TÉRMICA DETETADA\n"
		+ "Sistema de contenção: DADOS INCOMPLETOS\n\n"
		+ "AVISO:\n"
		+ "Exposição prolongada a setores fora dos limites "
		+ "térmicos recomendados pode comprometer organismos "
		+ "biológicos e sistemas eletrónicos."
	)

	report.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	report.add_theme_font_size_override(
		"font_size",
		19
	)

	container.add_child(
		report
	)


	var spacer = Control.new()

	spacer.custom_minimum_size = Vector2(
		0,
		20
	)

	container.add_child(
		spacer
	)


	var close_button = Button.new()

	close_button.text = "FECHAR"

	close_button.custom_minimum_size = Vector2(
		0,
		60
	)

	close_button.add_theme_font_size_override(
		"font_size",
		19
	)

	close_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	close_button.pressed.connect(
		close_terminal
	)

	container.add_child(
		close_button
	)


func close_terminal():
	terminal_open = false

	destroy_terminal_ui()

	get_tree().paused = false


func destroy_terminal_ui():
	if (
		terminal_layer != null
		and is_instance_valid(
			terminal_layer
		)
	):
		terminal_layer.queue_free()

	terminal_layer = null


func register_discovery():
	terminal_visual.color = Color(
		0.12,
		0.58,
		0.62,
		1.0
	)

	interaction_label.text = (
		"[E] REABRIR TERMINAL"
	)


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Este setor controlava parte da temperatura "
			+ "da instalação. Há registos de variações "
			+ "térmicas anormais nos níveis inferiores."
		)


	send_gameplay_context()


	print("")
	print(
		"======================================"
	)

	print(
		"SUPPORT THERMAL DATA DISCOVERED"
	)

	print(
		"LOWER SECTORS: THERMAL VARIATION"
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
		"support_thermal_system_discovered",
		"thermal_system_discovered",
		"Atlas e o jogador acessaram um terminal "
		+ "na Sala de Suporte da instalação subterrânea. "
		+ "O terminal mostra que existe uma rede de controlo térmico. "
		+ "Os setores habitáveis aparecem como estáveis, "
		+ "mas existem variações térmicas anormais "
		+ "registadas nos níveis inferiores. "
		+ "Exposição prolongada fora dos limites recomendados "
		+ "pode afetar organismos biológicos e sistemas eletrónicos. "
		+ "A causa dessas variações ainda é desconhecida.",
		true
	)


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


func was_terminal_read() -> bool:
	return terminal_read
