extends Control


@export_file("*.tscn") var game_scene_path: String


var new_game_button: Button
var exit_button: Button


func _ready():
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	create_background()
	create_menu()


func create_background():
	var background = ColorRect.new()

	background.name = "Background"
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.025,
		0.035,
		0.045,
		1.0
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		background
	)


func create_menu():
	var center = CenterContainer.new()

	center.name = "Center"
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(
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
		20
	)

	center.add_child(
		menu
	)


	var title = Label.new()

	title.text = "FIND HOPE"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		54
	)

	menu.add_child(
		title
	)


	var subtitle = Label.new()

	subtitle.text = (
		"PROJECT FIND HOPE // NAVE 47"
	)

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		15
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
		30
	)

	menu.add_child(
		spacer
	)


	new_game_button = Button.new()

	new_game_button.text = "NOVO JOGO"

	new_game_button.custom_minimum_size = Vector2(
		420,
		60
	)

	new_game_button.add_theme_font_size_override(
		"font_size",
		20
	)

	new_game_button.pressed.connect(
		on_new_game_pressed
	)

	menu.add_child(
		new_game_button
	)


	exit_button = Button.new()

	exit_button.text = "SAIR"

	exit_button.custom_minimum_size = Vector2(
		420,
		60
	)

	exit_button.add_theme_font_size_override(
		"font_size",
		20
	)

	exit_button.pressed.connect(
		on_exit_pressed
	)

	menu.add_child(
		exit_button
	)


	var version = Label.new()

	version.text = (
		"APAP // BUILD EM DESENVOLVIMENTO"
	)

	version.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	version.add_theme_font_size_override(
		"font_size",
		12
	)

	version.modulate = Color(
		0.45,
		0.5,
		0.53,
		1.0
	)

	menu.add_child(
		version
	)


func on_new_game_pressed():
	if game_scene_path.is_empty():
		push_error(
			"Game Scene Path não foi definido."
		)

		return


	new_game_button.disabled = true
	exit_button.disabled = true


	var error = get_tree().change_scene_to_file(
		game_scene_path
	)


	if error != OK:
		new_game_button.disabled = false
		exit_button.disabled = false

		push_error(
			"Erro ao abrir o jogo: "
			+ str(error)
		)


func on_exit_pressed():
	get_tree().quit()
