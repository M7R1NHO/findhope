extends Node


@export_file("*.tscn") var main_menu_scene_path: String


var overlay: ColorRect
var continue_button: Button
var main_menu_button: Button
var exit_button: Button

var is_open: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	create_pause_menu()

	overlay.visible = false


func _input(event):
	if event is InputEventKey:
		if (
			event.keycode == KEY_ESCAPE
			and event.pressed
			and not event.echo
		):
			toggle_pause_menu()

			get_viewport().set_input_as_handled()


func create_pause_menu():
	var layer = CanvasLayer.new()

	layer.name = "PauseLayer"

	layer.layer = 500

	layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		layer
	)


	overlay = ColorRect.new()

	overlay.name = "Overlay"

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.78
	)

	overlay.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	layer.add_child(
		overlay
	)


	var center = CenterContainer.new()

	center.name = "Center"

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	center.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	overlay.add_child(
		center
	)


	var menu = VBoxContainer.new()

	menu.name = "Menu"

	menu.custom_minimum_size = Vector2(
		420,
		0
	)

	menu.add_theme_constant_override(
		"separation",
		18
	)

	menu.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	center.add_child(
		menu
	)


	var title = Label.new()

	title.name = "Title"

	title.text = "PAUSA"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		44
	)

	menu.add_child(
		title
	)


	var subtitle = Label.new()

	subtitle.text = "FIND HOPE // NAVE 47"

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		14
	)

	subtitle.modulate = Color(
		0.65,
		0.72,
		0.76,
		1.0
	)

	menu.add_child(
		subtitle
	)


	var spacer = Control.new()

	spacer.custom_minimum_size = Vector2(
		0,
		25
	)

	menu.add_child(
		spacer
	)


	continue_button = Button.new()

	continue_button.name = "ContinueButton"

	continue_button.text = "CONTINUAR"

	continue_button.custom_minimum_size = Vector2(
		420,
		60
	)

	continue_button.add_theme_font_size_override(
		"font_size",
		20
	)

	continue_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	continue_button.pressed.connect(
		on_continue_pressed
	)

	menu.add_child(
		continue_button
	)


	main_menu_button = Button.new()

	main_menu_button.name = "MainMenuButton"

	main_menu_button.text = "MENU PRINCIPAL"

	main_menu_button.custom_minimum_size = Vector2(
		420,
		60
	)

	main_menu_button.add_theme_font_size_override(
		"font_size",
		20
	)

	main_menu_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	main_menu_button.pressed.connect(
		on_main_menu_pressed
	)

	menu.add_child(
		main_menu_button
	)


	exit_button = Button.new()

	exit_button.name = "ExitButton"

	exit_button.text = "SAIR"

	exit_button.custom_minimum_size = Vector2(
		420,
		60
	)

	exit_button.add_theme_font_size_override(
		"font_size",
		20
	)

	exit_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	exit_button.pressed.connect(
		on_exit_pressed
	)

	menu.add_child(
		exit_button
	)


func toggle_pause_menu():
	if is_open:
		close_pause_menu()

	else:
		open_pause_menu()


func open_pause_menu():
	is_open = true

	overlay.visible = true

	get_tree().paused = true


func close_pause_menu():
	is_open = false

	overlay.visible = false

	get_tree().paused = false


func on_continue_pressed():
	close_pause_menu()


func on_main_menu_pressed():
	if main_menu_scene_path.is_empty():
		push_error(
			"Main Menu Scene Path não foi definido."
		)

		return

	get_tree().paused = false

	is_open = false

	var error = get_tree().change_scene_to_file(
		main_menu_scene_path
	)

	if error != OK:
		push_error(
			"Não foi possível abrir o menu principal. Erro: "
			+ str(error)
		)


func on_exit_pressed():
	get_tree().paused = false

	get_tree().quit()
