extends StaticBody2D


@export var interaction_distance: float = 150.0
@export var interaction_label_offset: Vector2 = Vector2(-60, -90)


var main: Node
var player: CharacterBody2D
var parts_manager: Node

var interaction_label: Label

var choice_layer: CanvasLayer
var choice_root: Control

var title_label: Label
var info_label: Label

var buttons_container: HBoxContainer
var leave_button: Button
var stay_button: Button

var choice_open: bool = false
var ending_started: bool = false


func _ready():
	main = get_parent()

	player = main.get_node_or_null(
		"Player"
	)

	parts_manager = main.get_node_or_null(
		"ShipPartsManager"
	)

	create_interaction_label()

	create_departure_ui()


# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if player == null:
		return

	if ending_started:
		interaction_label.visible = false
		return

	if choice_open:
		interaction_label.visible = false
		return

	if parts_manager == null:
		interaction_label.visible = false
		return

	var distance = global_position.distance_to(
		player.global_position
	)

	var all_parts = false

	if parts_manager.has_method(
		"has_all_parts"
	):
		all_parts = parts_manager.has_all_parts()

	interaction_label.visible = (
		distance <= interaction_distance
		and all_parts
	)


# =========================================================
# INTERACTION
# =========================================================

func examine():
	if ending_started:
		return

	if parts_manager == null:
		push_warning(
			"ShipPartsManager não encontrado."
		)

		return

	var collected = 0
	var required = 6

	if parts_manager.has_method(
		"get_collected_count"
	):
		collected = (
			parts_manager.get_collected_count()
		)

	if parts_manager.has_method(
		"get_required_count"
	):
		required = (
			parts_manager.get_required_count()
		)

	if not parts_manager.has_all_parts():
		if main.has_method(
			"add_chat_message"
		):
			main.add_chat_message(
				"ANDROID",
				"A Nave 47 ainda não possui "
				+ "todos os componentes necessários. "
				+ "Recuperámos %d de %d peças."
				% [
					collected,
					required
				]
			)

		return

	show_departure_choice()


# =========================================================
# INTERACTION LABEL
# =========================================================

func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.text = (
		"[E] INTERAGIR"
	)

	interaction_label.position = (
		interaction_label_offset
	)

	interaction_label.visible = false

	interaction_label.add_theme_font_size_override(
		"font_size",
		18
	)

	add_child(
		interaction_label
	)


# =========================================================
# DEPARTURE UI
# =========================================================

func create_departure_ui():
	choice_layer = CanvasLayer.new()

	choice_layer.layer = 100

	add_child(
		choice_layer
	)

	choice_root = Control.new()

	choice_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	choice_root.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	choice_root.visible = false

	choice_layer.add_child(
		choice_root
	)


	# -----------------------------------------------------
	# FUNDO ESCURO
	# -----------------------------------------------------

	var background = ColorRect.new()

	background.color = Color(
		0.0,
		0.0,
		0.0,
		0.72
	)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	choice_root.add_child(
		background
	)


	# -----------------------------------------------------
	# CENTRO
	# -----------------------------------------------------

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	choice_root.add_child(
		center
	)


	# -----------------------------------------------------
	# PAINEL
	# -----------------------------------------------------

	var panel = PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		540,
		260
	)

	center.add_child(
		panel
	)


	# -----------------------------------------------------
	# MARGENS
	# -----------------------------------------------------

	var margin = MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		30
	)

	margin.add_theme_constant_override(
		"margin_right",
		30
	)

	margin.add_theme_constant_override(
		"margin_top",
		25
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		25
	)

	panel.add_child(
		margin
	)


	# -----------------------------------------------------
	# CONTEÚDO
	# -----------------------------------------------------

	var vbox = VBoxContainer.new()

	vbox.add_theme_constant_override(
		"separation",
		20
	)

	margin.add_child(
		vbox
	)


	# -----------------------------------------------------
	# TÍTULO
	# -----------------------------------------------------

	title_label = Label.new()

	title_label.text = "NAVE 47"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		28
	)

	vbox.add_child(
		title_label
	)


	# -----------------------------------------------------
	# TEXTO
	# -----------------------------------------------------

	info_label = Label.new()

	info_label.text = (
		"Todas as peças necessárias foram recuperadas.\n"
		+ "A Nave 47 pode deixar o planeta.\n\n"
		+ "O que deseja fazer?"
	)

	info_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	info_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	info_label.custom_minimum_size = Vector2(
		460,
		90
	)

	vbox.add_child(
		info_label
	)


	# -----------------------------------------------------
	# BOTÕES
	# -----------------------------------------------------

	buttons_container = HBoxContainer.new()

	buttons_container.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons_container.add_theme_constant_override(
		"separation",
		20
	)

	vbox.add_child(
		buttons_container
	)


	leave_button = Button.new()

	leave_button.text = (
		"SAIR DO PLANETA"
	)

	leave_button.custom_minimum_size = Vector2(
		190,
		50
	)

	leave_button.pressed.connect(
		_on_leave_planet_pressed
	)

	buttons_container.add_child(
		leave_button
	)


	stay_button = Button.new()

	stay_button.text = (
		"PERMANECER"
	)

	stay_button.custom_minimum_size = Vector2(
		190,
		50
	)

	stay_button.pressed.connect(
		_on_stay_pressed
	)

	buttons_container.add_child(
		stay_button
	)


# =========================================================
# SHOW CHOICE
# =========================================================

func show_departure_choice():
	if choice_open:
		return

	choice_open = true

	interaction_label.visible = false

	choice_root.visible = true

	if player != null:
		player.velocity = Vector2.ZERO

		player.set_physics_process(
			false
		)

		player.set_process_unhandled_input(
			false
		)


# =========================================================
# PERMANECER
# =========================================================

func _on_stay_pressed():
	choice_open = false

	choice_root.visible = false

	if player != null:
		player.set_physics_process(
			true
		)

		player.set_process_unhandled_input(
			true
		)

	if main.has_method(
		"add_chat_message"
	):
		main.add_chat_message(
			"ANDROID",
			"Entendido. Permaneceremos no planeta "
			+ "por enquanto."
		)


# =========================================================
# SAIR DO PLANETA
# =========================================================

func _on_leave_planet_pressed():
	if ending_started:
		return

	ending_started = true
	choice_open = false

	title_label.text = (
		"FIND HOPE"
	)

	info_label.text = (
		"FINAL — SAIR DO PLANETA\n\n"
		+ "Com a Nave 47 reparada, "
		+ "você decidiu abandonar o planeta.\n\n"
		+ "Os mistérios encontrados na superfície "
		+ "ficaram para trás."
	)

	buttons_container.visible = false

	if main.has_method(
		"add_chat_message"
	):
		main.add_chat_message(
			"ANDROID",
			"Rota calculada. Estamos a deixar o planeta."
		)

	get_tree().paused = true
