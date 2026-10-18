extends Node


@export_file("*.tscn") var main_menu_scene_path: String


var pause_layer: CanvasLayer = null
var pause_open: bool = false

var main_container: VBoxContainer = null
var status_label: Label = null

var submenu_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event):
	if not (
		event is InputEventKey
	):
		return

	if not event.pressed:
		return

	if event.echo:
		return

	if event.keycode != KEY_ESCAPE:
		return

	get_viewport().set_input_as_handled()

	if submenu_layer != null:
		close_submenu()
		return

	if pause_open:
		close_pause()
	else:
		open_pause()


func open_pause():
	if pause_open:
		return

	pause_open = true

	get_tree().paused = true

	create_pause_ui()


func close_pause():
	close_submenu()

	pause_open = false

	if (
		pause_layer != null
		and is_instance_valid(
			pause_layer
		)
	):
		pause_layer.queue_free()

	pause_layer = null
	main_container = null
	status_label = null

	get_tree().paused = false


func create_pause_ui():
	if (
		pause_layer != null
		and is_instance_valid(
			pause_layer
		)
	):
		pause_layer.queue_free()

	pause_layer = CanvasLayer.new()
	pause_layer.layer = 900
	pause_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	add_child(pause_layer)

	var overlay = ColorRect.new()

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.88
	)

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	pause_layer.add_child(
		overlay
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.add_child(
		center
	)

	main_container = VBoxContainer.new()

	main_container.custom_minimum_size = Vector2(
		500,
		0
	)

	main_container.add_theme_constant_override(
		"separation",
		15
	)

	center.add_child(
		main_container
	)

	var title = Label.new()

	title.text = "PAUSA"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		36
	)

	main_container.add_child(
		title
	)

	var spacer = Control.new()

	spacer.custom_minimum_size = Vector2(
		0,
		20
	)

	main_container.add_child(
		spacer
	)

	create_pause_button(
		"CONTINUAR",
		close_pause
	)

	var save_button = create_pause_button(
		"SALVAR JOGO",
		open_save_menu
	)

	if not SaveManager.can_manual_save():
		save_button.disabled = true

		var reason = (
			SaveManager
			.get_manual_save_block_reason()
		)

		save_button.tooltip_text = reason

	create_pause_button(
		"CARREGAR JOGO",
		open_load_menu
	)

	create_pause_button(
		"OPÇÕES",
		open_options
	)

	create_pause_button(
		"MENU PRINCIPAL",
		confirm_main_menu
	)

	create_pause_button(
		"SAIR",
		confirm_exit
	)

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

	main_container.add_child(
		status_label
	)


func create_pause_button(
	text_value: String,
	callback: Callable
) -> Button:
	var button = Button.new()

	button.text = text_value

	button.custom_minimum_size = Vector2(
		0,
		55
	)

	button.add_theme_font_size_override(
		"font_size",
		18
	)

	button.pressed.connect(
		callback
	)

	main_container.add_child(
		button
	)

	return button


func open_save_menu():
	if not SaveManager.can_manual_save():
		set_status(
			SaveManager.get_manual_save_block_reason()
		)
		return

	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = "SALVAR JOGO"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		30
	)

	container.add_child(
		title
	)

	var info = Label.new()

	info.text = (
		"Escolha um dos 5 slots."
	)

	info.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	container.add_child(
		info
	)

	for slot in range(
		1,
		SaveManager.SLOT_COUNT + 1
	):
		create_save_slot_button(
			container,
			slot
		)

	var delete_button = Button.new()
	delete_button.text = "APAGAR TODOS OS SAVES"
	delete_button.custom_minimum_size = Vector2(0, 52)
	delete_button.pressed.connect(
		open_delete_all_saves_confirmation
	)
	container.add_child(delete_button)

	create_back_button(
		container
	)


func create_save_slot_button(
	container: VBoxContainer,
	slot: int
):
	var button = Button.new()

	button.custom_minimum_size = Vector2(
		0,
		65
	)

	var slot_info = (
		SaveManager.get_manual_slot_info(
			slot
		)
	)

	if slot_info.is_empty():
		button.text = (
			"SLOT "
			+ str(slot)
			+ " — VAZIO"
		)

	else:
		var player_profile: Dictionary = (
			slot_info.get(
				"player_profile",
				{}
			)
		)

		var player_name = str(
			player_profile.get(
				"name",
				"Jogador"
			)
		)

		var saved_at = str(
			slot_info.get(
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
			on_save_slot_pressed(
				slot
			)
	)

	container.add_child(
		button
	)


func on_save_slot_pressed(
	slot: int
):
	if SaveManager.has_manual_slot(
		slot
	):
		open_overwrite_confirmation(
			slot
		)
		return

	save_to_slot(
		slot
	)


func open_overwrite_confirmation(
	slot: int
):
	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = "SOBRESCREVER SAVE?"

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

	var body = Label.new()

	body.text = (
		"O Slot "
		+ str(slot)
		+ " já possui um save.\n\n"
		+ "Deseja substituí-lo pelo progresso atual?"
	)

	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	body.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	container.add_child(
		body
	)

	var buttons = HBoxContainer.new()

	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons.add_theme_constant_override(
		"separation",
		15
	)

	container.add_child(
		buttons
	)

	var cancel = Button.new()

	cancel.text = "CANCELAR"

	cancel.custom_minimum_size = Vector2(
		190,
		55
	)

	cancel.pressed.connect(
		open_save_menu
	)

	buttons.add_child(
		cancel
	)

	var confirm = Button.new()

	confirm.text = "SOBRESCREVER"

	confirm.custom_minimum_size = Vector2(
		190,
		55
	)

	confirm.pressed.connect(
		func():
			save_to_slot(
				slot
			)
	)

	buttons.add_child(
		confirm
	)


var save_in_progress: bool = false


func save_to_slot(
	slot: int
):
	if save_in_progress:
		return

	save_in_progress = true

	var success = (
		await SaveManager.save_manual_slot(
			slot
		)
	)

	save_in_progress = false

	if not success:
		close_submenu()

		set_status(
			"Não foi possível salvar o jogo."
		)

		return

	close_submenu()

	set_status(
		"Jogo salvo no Slot "
		+ str(slot)
		+ "."
	)


func open_load_menu():
	close_submenu()
	# Só espera pela rede na primeira vez; depois usa os metadados em cache.
	if not SaveManager.remote_save_metadata_loaded:
		await SaveManager.sync_remote_saves_to_local()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = "CARREGAR JOGO"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		30
	)

	container.add_child(
		title
	)

	var info = Label.new()

	info.text = (
		"Escolha um dos 5 slots."
	)

	info.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	container.add_child(
		info
	)

	for slot in range(
		1,
		SaveManager.SLOT_COUNT + 1
	):
		create_load_slot_button(
			container,
			slot
		)

	var delete_button = Button.new()
	delete_button.text = "APAGAR TODOS OS SAVES"
	delete_button.custom_minimum_size = Vector2(0, 52)
	delete_button.pressed.connect(
		open_delete_all_saves_confirmation
)
	container.add_child(delete_button)

	create_back_button(
		container
	)


func create_load_slot_button(
	container: VBoxContainer,
	slot: int
):
	var button = Button.new()

	button.custom_minimum_size = Vector2(
		0,
		65
	)

	var slot_info = (
		SaveManager.get_manual_slot_info(
			slot
		)
	)

	if slot_info.is_empty():
		button.text = (
			"SLOT "
			+ str(slot)
			+ " — VAZIO"
		)

		button.disabled = true

	else:
		var player_profile: Dictionary = (
			slot_info.get(
				"player_profile",
				{}
			)
		)

		var player_name = str(
			player_profile.get(
				"name",
				"Jogador"
			)
		)

		var saved_at = str(
			slot_info.get(
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
				confirm_load_slot(
					slot
				)
		)

	container.add_child(
		button
	)


func confirm_load_slot(
	slot: int
):
	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = "CARREGAR SAVE?"

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

	var body = Label.new()

	body.text = (
		"O jogo voltará ao estado salvo "
		+ "no Slot "
		+ str(slot)
		+ "."
	)

	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	body.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	container.add_child(
		body
	)

	var buttons = HBoxContainer.new()

	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons.add_theme_constant_override(
		"separation",
		15
	)

	container.add_child(
		buttons
	)

	var cancel = Button.new()

	cancel.text = "CANCELAR"

	cancel.custom_minimum_size = Vector2(
		190,
		55
	)

	cancel.pressed.connect(
		open_load_menu
	)

	buttons.add_child(
		cancel
	)

	var confirm = Button.new()

	confirm.text = "CARREGAR"

	confirm.custom_minimum_size = Vector2(
		190,
		55
	)

	confirm.pressed.connect(
		func():
			load_slot(
				slot
			)
	)

	buttons.add_child(
		confirm
	)


func load_slot(
	slot: int
):
	var prepared = await SaveManager.prepare_manual_slot_load(slot)

	if not prepared:
		close_submenu()

		set_status(
			"Não foi possível preparar o save."
		)

		return

	close_submenu()

	pause_open = false

	get_tree().paused = false

	# Sem cena de fallback, um snapshot sem scene_path falhava em silêncio.
	var fallback_scene: String = ""
	if get_tree().current_scene != null:
		fallback_scene = get_tree().current_scene.scene_file_path

	SaveManager.call_deferred(
		"load_prepared_scene",
		fallback_scene
	)

func open_options():
	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = "OPÇÕES"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		30
	)

	container.add_child(
		title
	)

	var body = Label.new()

	body.text = (
		"As opções serão implementadas "
		+ "durante o refinamento."
	)

	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	container.add_child(
		body
	)

	create_back_button(
		container
	)


func confirm_main_menu():
	open_confirmation(
		"VOLTAR AO MENU?",
		"O progresso desde o último autosave "
		+ "ou save manual poderá ser perdido.",
		"MENU PRINCIPAL",
		go_to_main_menu
	)


func go_to_main_menu():
	close_submenu()

	pause_open = false

	get_tree().paused = false

	if main_menu_scene_path.strip_edges().is_empty():
		push_warning(
			"main_menu_scene_path não definido."
		)
		return

	get_tree().change_scene_to_file(
		main_menu_scene_path
	)


func confirm_exit():
	open_confirmation(
		"SAIR DO JOGO?",
		"O progresso desde o último autosave "
		+ "ou save manual poderá ser perdido.",
		"SAIR",
		exit_game
	)


func exit_game():
	get_tree().paused = false

	get_tree().quit()


func open_confirmation(
	title_text: String,
	body_text: String,
	confirm_text: String,
	callback: Callable
):
	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()

	title.text = title_text

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

	var body = Label.new()

	body.text = body_text

	body.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	body.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	container.add_child(
		body
	)

	var buttons = HBoxContainer.new()

	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons.add_theme_constant_override(
		"separation",
		15
	)

	container.add_child(
		buttons
	)

	var cancel = Button.new()

	cancel.text = "CANCELAR"

	cancel.custom_minimum_size = Vector2(
		190,
		55
	)

	cancel.pressed.connect(
		close_submenu
	)

	buttons.add_child(
		cancel
	)

	var confirm = Button.new()

	confirm.text = confirm_text

	confirm.custom_minimum_size = Vector2(
		190,
		55
	)

	confirm.pressed.connect(
		callback
	)

	buttons.add_child(
		confirm
	)


func create_submenu_base() -> CanvasLayer:
	var layer = CanvasLayer.new()

	layer.layer = 950

	layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		layer
	)

	var overlay = ColorRect.new()

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.96
	)

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	layer.add_child(
		overlay
	)

	return layer


func create_submenu_container(
	layer: CanvasLayer
) -> VBoxContainer:
	var overlay = layer.get_child(
		0
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.add_child(
		center
	)

	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		620,
		0
	)

	container.add_theme_constant_override(
		"separation",
		14
	)

	center.add_child(
		container
	)

	return container


func create_back_button(
	container: VBoxContainer
):
	var button = Button.new()

	button.text = "VOLTAR"

	button.custom_minimum_size = Vector2(
		0,
		52
	)

	button.pressed.connect(
		close_submenu
	)

	container.add_child(
		button
	)


func close_submenu():
	if (
		submenu_layer != null
		and is_instance_valid(
			submenu_layer
		)
	):
		submenu_layer.queue_free()

	submenu_layer = null


func set_status(
	message: String
):
	if status_label == null:
		return

	status_label.text = message
	
func open_delete_all_saves_confirmation():
	close_submenu()

	submenu_layer = create_submenu_base()

	var container = create_submenu_container(
		submenu_layer
	)

	var title = Label.new()
	title.text = "APAGAR TODOS OS SAVES?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	container.add_child(title)

	var body = Label.new()
	body.text = (
		"Esta ação vai apagar os saves manuais "
		+ "dos Slots 1 a 5.\n\n"
		+ "O autosave, as conquistas e os diários "
		+ "serão preservados.\n\n"
		+ "Tens a certeza?"
	)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(body)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 15)
	container.add_child(buttons)

	var cancel = Button.new()
	cancel.text = "CANCELAR"
	cancel.custom_minimum_size = Vector2(190, 55)
	cancel.pressed.connect(open_save_menu)
	buttons.add_child(cancel)

	var confirm = Button.new()
	confirm.text = "APAGAR TUDO"
	confirm.custom_minimum_size = Vector2(190, 55)
	confirm.pressed.connect(
		confirm_delete_all_manual_saves
	)
	buttons.add_child(confirm)

func confirm_delete_all_manual_saves():
	var success = SaveManager.delete_all_manual_slots()

	close_submenu()

	if success:
		set_status("Todos os saves manuais foram apagados.")
	else:
		set_status(
			"Não foi possível apagar todos os saves. "
			+ "Verifica os avisos na consola."
		)

	open_save_menu()
