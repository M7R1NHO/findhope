extends StaticBody2D


@export var interaction_distance: float = 150.0
@export var interaction_label_offset: Vector2 = Vector2(-60, -90)


var main: Node
var player: CharacterBody2D
var parts_manager: Node
var pause_menu: Node

var interaction_label: Label

var choice_layer: CanvasLayer
var choice_root: Control

var title_label: Label
var info_label: Label

var buttons_container: HBoxContainer
var leave_button: Button
var stay_button: Button
var main_menu_button: Button

var choice_open: bool = false
var ending_started: bool = false

var stay_selected_once: bool = false


func _ready():
	main = get_parent()

	player = main.get_node_or_null(
		"Player"
	)

	parts_manager = main.get_node_or_null(
		"ShipPartsManager"
	)

	pause_menu = main.get_node_or_null(
		"PauseMenu"
	)

	load_run_state()

	create_interaction_label()

	create_departure_ui()


func load_run_state():
	stay_selected_once = bool(
		SaveManager.get_run_value(
			"story",
			"surface_stay_selected",
			false
		)
	)

	ending_started = bool(
		SaveManager.get_run_value(
			"story",
			"early_exit_ending",
			false
		)
	)


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


func create_departure_ui():
	choice_layer = CanvasLayer.new()

	choice_layer.layer = 100

	choice_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

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

	choice_root.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	choice_layer.add_child(
		choice_root
	)

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

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	choice_root.add_child(
		background
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	choice_root.add_child(
		center
	)

	var panel = PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		540,
		260
	)

	center.add_child(
		panel
	)

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

	var vbox = VBoxContainer.new()

	vbox.add_theme_constant_override(
		"separation",
		20
	)

	margin.add_child(
		vbox
	)

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

	leave_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
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

	stay_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	stay_button.pressed.connect(
		_on_stay_pressed
	)

	buttons_container.add_child(
		stay_button
	)

	main_menu_button = Button.new()

	main_menu_button.text = (
		"MENU PRINCIPAL"
	)

	main_menu_button.custom_minimum_size = Vector2(
		220,
		52
	)

	main_menu_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	main_menu_button.visible = false

	main_menu_button.pressed.connect(
		_on_main_menu_pressed
	)

	buttons_container.add_child(
		main_menu_button
	)


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

	if not stay_selected_once:
		register_stay_decision()


func register_stay_decision():
	stay_selected_once = true

	SaveManager.set_run_value(
		"story",
		"surface_stay_selected",
		true
	)

	SaveManager.set_run_value(
		"story",
		"ship_repaired",
		true
	)

	SaveManager.set_run_value(
		"story",
		"early_exit_ending",
		false
	)

	var success = SaveManager.autosave(
		"surface_stay_selected"
	)

	print("")
	print("======================================")
	print("SURFACE DECISION: STAY")
	print(
		"AUTOSAVE #2: ",
		success
	)
	print("======================================")


func _on_leave_planet_pressed():
	if ending_started:
		return

	ending_started = true
	choice_open = false

	register_early_exit_ending()

	block_game_after_ending()

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

	leave_button.visible = false
	stay_button.visible = false

	main_menu_button.visible = true

	if main.has_method(
		"add_chat_message"
	):
		main.add_chat_message(
			"ANDROID",
			"Rota calculada. Estamos a deixar o planeta."
		)

	get_tree().paused = true


func block_game_after_ending():
	SaveManager.set_manual_save_block(
		"ending",
		true
	)

	if player != null:
		player.velocity = Vector2.ZERO

		player.set_physics_process(
			false
		)

		player.set_process_unhandled_input(
			false
		)

	if pause_menu != null:
		pause_menu.set_process_unhandled_input(
			false
		)


func _on_main_menu_pressed():
	var main_menu_scene_path := ""

	if pause_menu != null:
		var value = pause_menu.get(
			"main_menu_scene_path"
		)

		if value != null:
			main_menu_scene_path = str(
				value
			).strip_edges()

	if main_menu_scene_path.is_empty():
		push_warning(
			"Não foi possível encontrar "
			+ "main_menu_scene_path no PauseMenu."
		)

		return

	SaveManager.set_manual_save_block(
		"ending",
		false
	)

	get_tree().paused = false

	get_tree().change_scene_to_file(
		main_menu_scene_path
	)


func register_early_exit_ending():
	SaveManager.set_run_value(
		"story",
		"early_exit_ending",
		true
	)

	SaveManager.set_run_value(
		"story",
		"run_ended",
		true
	)

	SaveManager.set_run_value(
		"story",
		"ending_id",
		"leave_planet_early"
	)

	SaveManager.set_run_value(
		"story",
		"full_completion",
		false
	)

	print("")
	print("======================================")
	print("EARLY ENDING")
	print("ENDING ID: leave_planet_early")
	print("FULL COMPLETION: FALSE")
	print("ACHIEVEMENTS UNLOCKED: FALSE")
	print("ANDROID DIARY UNLOCKED: FALSE")
	print("======================================")
