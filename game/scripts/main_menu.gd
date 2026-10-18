extends Control


@export_file("*.tscn") var game_scene_path: String


var root_container: VBoxContainer = null
var status_label: Label = null
var modal_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_menu()
	# A sincronização remota decorre em segundo plano e não bloqueia o menu.
	SaveManager.call_deferred("_sync_remote_saves_in_background")


func create_menu():
	clear_menu()

	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color(
		0.025,
		0.025,
		0.035,
		1.0
	)
	add_child(background)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.add_child(center)

	root_container = VBoxContainer.new()
	root_container.custom_minimum_size = Vector2(
		500,
		0
	)
	root_container.add_theme_constant_override(
		"separation",
		16
	)
	center.add_child(root_container)

	var title = Label.new()
	title.text = "FIND HOPE"
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		44
	)
	root_container.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "PROJECT FIND HOPE"
	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.add_theme_font_size_override(
		"font_size",
		16
	)
	root_container.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(
		0,
		25
	)
	root_container.add_child(spacer)

	var menu_state = SaveManager.get_menu_state()

	if menu_state == "initial":
		create_initial_menu()

	elif menu_state == "standard":
		create_standard_menu(false)

	elif menu_state == "completed":
		create_standard_menu(true)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_font_size_override(
		"font_size",
		14
	)
	root_container.add_child(status_label)


func create_initial_menu():
	create_menu_button(
		"COMEÇAR JOGO",
		start_first_game
	)

	create_menu_button(
		"OPÇÕES",
		open_options
	)

	create_menu_button(
		"CRÉDITOS",
		open_credits
	)

	create_menu_button(
		"SAIR",
		exit_game
	)


func create_standard_menu(
	show_diaries: bool
):
	var continue_button = create_menu_button(
		"CONTINUAR JOGO",
		continue_game
	)

	if not SaveManager.has_current_run_save():
		continue_button.disabled = true
		continue_button.tooltip_text = (
			"Disponível após o primeiro autosave."
		)

	create_menu_button(
		"NOVO JOGO",
		confirm_new_game
	)

	create_menu_button(
		"CARREGAR JOGO",
		open_load_menu
	)

	create_menu_button(
		"CONQUISTAS",
		open_achievements
	)

	if show_diaries:
		create_menu_button(
			"DIÁRIOS",
			open_diaries
		)

	create_menu_button(
		"OPÇÕES",
		open_options
	)

	create_menu_button(
		"CRÉDITOS",
		open_credits
	)

	create_menu_button(
		"SAIR",
		exit_game
	)


func create_menu_button(
	text_value: String,
	callback: Callable
) -> Button:
	var button = Button.new()

	button.text = text_value
	button.custom_minimum_size = Vector2(
		0,
		58
	)
	button.add_theme_font_size_override(
		"font_size",
		19
	)

	button.pressed.connect(
		callback
	)

	root_container.add_child(
		button
	)

	return button


func start_first_game():
	if game_scene_path.strip_edges().is_empty():
		set_status(
			"O caminho da cena do jogo não foi definido."
		)
		return

	await SaveManager.start_new_run()

	get_tree().change_scene_to_file(
		game_scene_path
	)


func continue_game():
	var prepared = await SaveManager.prepare_current_run_load()

	if not prepared:
		set_status(
			"Não foi possível preparar o autosave."
		)
		return

	await load_prepared_save()


func confirm_new_game():
	create_confirmation_modal(
		"NOVO JOGO",
		"O progresso atual da run será reiniciado.\n\n"
		+ "Os 5 saves manuais, conquistas e Diários "
		+ "de Android NÃO serão apagados.",
		"CANCELAR",
		"NOVO JOGO",
		start_new_game
	)


func start_new_game():
	close_modal()

	if game_scene_path.strip_edges().is_empty():
		set_status(
			"O caminho da cena do jogo não foi definido."
		)
		return

	SaveManager.reset_active_run()
	await SaveManager.start_new_run()

	get_tree().change_scene_to_file(
		game_scene_path
	)


func open_load_menu():
	close_modal()
	await SaveManager.sync_remote_saves_to_local()

	modal_layer = CanvasLayer.new()
	modal_layer.layer = 1000
	modal_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	add_child(modal_layer)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.92
	)
	modal_layer.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(center)

	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(
		620,
		0
	)
	container.add_theme_constant_override(
		"separation",
		14
	)
	center.add_child(container)

	var title = Label.new()
	title.text = "CARREGAR JOGO"
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		30
	)
	container.add_child(title)

	var description = Label.new()
	description.text = (
		"Escolha um dos 5 saves manuais."
	)
	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	container.add_child(description)

	for slot in range(
		1,
		SaveManager.SLOT_COUNT + 1
	):
		create_load_slot_button(
			container,
			slot
		)

	var close_button = Button.new()
	close_button.text = "VOLTAR"
	close_button.custom_minimum_size = Vector2(
		0,
		52
	)
	close_button.pressed.connect(
		close_modal
	)
	container.add_child(close_button)


func create_load_slot_button(
	container: VBoxContainer,
	slot: int
):
	var button = Button.new()

	button.custom_minimum_size = Vector2(
		0,
		68
	)

	var info = SaveManager.get_manual_slot_info(
		slot
	)

	if info.is_empty():
		button.text = (
			"SLOT "
			+ str(slot)
			+ " — VAZIO"
		)
		button.disabled = true

	else:
		var player_profile: Dictionary = (
			info.get(
				"player_profile",
				{}
			)
		)

		var player_name = str(
			player_profile.get(
				"name",
				"Sem nome"
			)
		)

		var saved_at = str(
			info.get(
				"saved_at",
				""
			)
		)

		button.text = (
			"SLOT "
			+ str(slot)
			+ " — "
			+ player_name
			+ "\n"
			+ saved_at
		)

		button.pressed.connect(
			func():
				load_manual_slot(slot)
		)

	container.add_child(button)


func load_manual_slot(
	slot: int
):
	var prepared = await SaveManager.prepare_manual_slot_load(slot)

	if not prepared:
		set_status(
			"Não foi possível carregar o Slot "
			+ str(slot)
			+ "."
		)
		return

	close_modal()

	await load_prepared_save()


func load_prepared_save():
	var scene_path = SaveManager.get_pending_scene_path()

	if scene_path.strip_edges().is_empty():
		scene_path = game_scene_path

	if scene_path.strip_edges().is_empty():
		set_status(
			"O save nao possui uma cena valida."
		)
		return

	SaveManager.call_deferred(
		"load_prepared_scene",
		scene_path
	)

func open_achievements():
	close_modal()

	var achievements: Dictionary = (
		SaveManager.profile.get(
			"achievements",
			{}
		)
	)

	var body = ""

	if achievements.is_empty():
		body = (
			"Nenhuma conquista desbloqueada."
		)

	else:
		body = (
			"Conquistas desbloqueadas: "
			+ str(achievements.size())
		)

	create_information_modal(
		"CONQUISTAS",
		body
	)


func open_diaries():
	close_modal()

	var diaries: Array = (
		SaveManager.profile.get(
			"android_diaries",
			[]
		)
	)

	var body = ""

	if diaries.is_empty():
		body = (
			"Nenhum Diário de Android "
			+ "foi registrado."
		)

	else:
		body = (
			"Diários registrados: "
			+ str(diaries.size())
		)

	create_information_modal(
		"DIÁRIOS",
		body
	)


func open_options():
	create_information_modal(
		"OPÇÕES",
		"As opções serão implementadas "
		+ "durante o refinamento do jogo."
	)


func open_credits():
	create_information_modal(
		"CRÉDITOS",
		"FIND HOPE\n\n"
		+ "Desenvolvido por Guilherme\n\n"
		+ "Project Find Hope"
	)


func create_information_modal(
	title_text: String,
	body_text: String
):
	close_modal()

	modal_layer = CanvasLayer.new()
	modal_layer.layer = 1000
	modal_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	add_child(modal_layer)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.92
	)
	modal_layer.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(center)

	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(
		600,
		0
	)
	container.add_theme_constant_override(
		"separation",
		18
	)
	center.add_child(container)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		30
	)
	container.add_child(title)

	var body = Label.new()
	body.text = body_text
	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	body.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	body.add_theme_font_size_override(
		"font_size",
		18
	)
	container.add_child(body)

	var close_button = Button.new()
	close_button.text = "VOLTAR"
	close_button.custom_minimum_size = Vector2(
		0,
		52
	)
	close_button.pressed.connect(
		close_modal
	)
	container.add_child(close_button)


func create_confirmation_modal(
	title_text: String,
	body_text: String,
	cancel_text: String,
	confirm_text: String,
	confirm_callback: Callable
):
	close_modal()

	modal_layer = CanvasLayer.new()
	modal_layer.layer = 1000
	modal_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	add_child(modal_layer)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.94
	)
	modal_layer.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(center)

	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(
		620,
		0
	)
	container.add_theme_constant_override(
		"separation",
		18
	)
	center.add_child(container)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		30
	)
	container.add_child(title)

	var body = Label.new()
	body.text = body_text
	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	body.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	body.add_theme_font_size_override(
		"font_size",
		18
	)
	container.add_child(body)

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override(
		"separation",
		15
	)
	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	container.add_child(buttons)

	var cancel_button = Button.new()
	cancel_button.text = cancel_text
	cancel_button.custom_minimum_size = Vector2(
		200,
		55
	)
	cancel_button.pressed.connect(
		close_modal
	)
	buttons.add_child(cancel_button)

	var confirm_button = Button.new()
	confirm_button.text = confirm_text
	confirm_button.custom_minimum_size = Vector2(
		200,
		55
	)
	confirm_button.pressed.connect(
		confirm_callback
	)
	buttons.add_child(confirm_button)


func close_modal():
	if (
		modal_layer != null
		and is_instance_valid(modal_layer)
	):
		modal_layer.queue_free()

	modal_layer = null


func set_status(
	message: String
):
	if status_label == null:
		return

	status_label.text = message


func clear_menu():
	for child in get_children():
		child.queue_free()

	root_container = null
	status_label = null


func exit_game():
	get_tree().quit()
