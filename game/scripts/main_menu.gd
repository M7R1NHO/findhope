extends Control

const UIStyle := preload("res://scripts/ui_style.gd")
const MenuBackdrop := preload("res://scripts/menu_backdrop.gd")
const DiaryBook := preload("res://scripts/diary_book.gd")
const AchievementsScreen := preload("res://scripts/achievements_screen.gd")
const OptionsPanel := preload("res://scripts/options_panel.gd")


@export_file("*.tscn") var game_scene_path: String


var root_container: VBoxContainer = null
var status_label: Label = null
var modal_layer: CanvasLayer = null
var continue_button: Button = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_failed.connect(_on_save_failed)
	SaveManager.remote_saves_updated.connect(_refresh_continue_button)
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
	UIStyle.apply(background)
	# Estrelas, planeta e a Nave 47 por trás dos botões.
	background.add_child(MenuBackdrop.new())

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
		8
	)
	center.add_child(root_container)
	# Caixa semitransparente para os botões se lerem por cima das estrelas.
	var frame := UIStyle.frame(root_container)
	frame.add_theme_stylebox_override("panel", UIStyle._box(Color(UIStyle.PANEL_BG, 0.82), UIStyle.PANEL_BORDER, 1, 8, 30.0, 20.0))

	var title = Label.new()
	title.text = "FIND HOPE"
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		52
	)
	UIStyle.title(title)
	title.add_theme_color_override("font_shadow_color", Color(UIStyle.ACCENT, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
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
	UIStyle.subtitle(subtitle)
	root_container.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(
		0,
		10
	)
	root_container.add_child(spacer)

	var menu_state = SaveManager.get_menu_state()

	if menu_state == "initial":
		create_initial_menu()

	elif menu_state == "standard":
		create_standard_menu(false)

	elif menu_state == "completed":
		create_standard_menu(true)

	# APAGAR PROGRESSO: pequeno, no canto inferior esquerdo, com dupla
	# confirmação (confirm_erase_progress).
	var erase_button := Button.new()
	erase_button.name = "EraseProgressButton"
	erase_button.text = "APAGAR PROGRESSO"
	erase_button.add_theme_font_size_override("font_size", 12)
	erase_button.add_theme_color_override("font_color", UIStyle.DANGER)
	erase_button.add_theme_color_override("font_hover_color", UIStyle.DANGER.lightened(0.2))
	erase_button.anchor_left = 0.0
	erase_button.anchor_right = 0.0
	erase_button.anchor_top = 1.0
	erase_button.anchor_bottom = 1.0
	erase_button.offset_left = 16.0
	erase_button.offset_top = -48.0
	erase_button.offset_right = 186.0
	erase_button.offset_bottom = -16.0
	erase_button.pressed.connect(confirm_erase_progress)
	background.add_child(erase_button)

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
	continue_button = create_menu_button(
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

	# DIÁRIOS aparece sempre depois do primeiro jogo: sem diários mostra o
	# livro com a página em branco (show_diaries fica só por compatibilidade).
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
		44
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

	if not await SaveManager.start_new_run():
		return

	get_tree().change_scene_to_file(
		game_scene_path
	)


func continue_game():
	var prepared = await SaveManager.prepare_current_run_load()

	if not prepared:
		set_status(
			SaveManager.last_error
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

	if not await SaveManager.start_new_run():
		return

	get_tree().change_scene_to_file(
		game_scene_path
	)


func open_load_menu():
	close_modal()
	if not SaveManager.remote_save_metadata_loaded:
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
	UIStyle.apply(overlay)

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
	UIStyle.title(title)
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

	set_status("A carregar…")
	await SaveManager.load_prepared_scene(scene_path)


func _on_save_failed(message: String):
	close_modal()
	set_status(message)


func _refresh_continue_button():
	if is_instance_valid(continue_button):
		continue_button.disabled = not SaveManager.has_current_run_save()

func open_achievements():
	close_modal()
	# As 16 conquistas, bloqueadas e desbloqueadas (achievements_screen.gd).
	modal_layer = AchievementsScreen.open(self)


func open_diaries():
	close_modal()
	# Livro com um Diário do Android por run (diary_book.gd).
	modal_layer = DiaryBook.open(self)


func open_options():
	# Volume geral e da música (options_panel.gd); grava no perfil.
	create_information_modal(
		"OPÇÕES",
		"A banda sonora toca no menu e no jogo."
	)
	var container: VBoxContainer = modal_layer.find_child("ModalContent", true, false)
	OptionsPanel.add_controls(container)
	# O VOLTAR fica no fim, depois dos controlos.
	var back := container.get_child(2)
	container.move_child(back, container.get_child_count() - 1)


# 1.ª confirmação: diz o que vai ser apagado e o que fica.
func confirm_erase_progress():
	create_confirmation_modal(
		"APAGAR PROGRESSO",
		"Vai ser apagado TODO o teu progresso:\n"
		+ "a run atual, os 5 saves manuais, os Diários do Android, "
		+ "as conquistas e todo o histórico de conversas com o Atlas "
		+ "(no computador e no servidor).\n\n"
		+ "As opções de som ficam como estão.",
		"CANCELAR",
		"CONTINUAR",
		confirm_erase_progress_final
	)


# 2.ª confirmação.
func confirm_erase_progress_final():
	create_confirmation_modal(
		"TENS A CERTEZA?",
		"Esta ação não pode ser desfeita.\n"
		+ "O jogo volta ao estado inicial, como na primeira vez.",
		"CANCELAR",
		"APAGAR TUDO",
		erase_progress
	)


func erase_progress():
	close_modal()
	set_status("A apagar o progresso…")
	var report: Dictionary = await SaveManager.erase_all_progress()
	if not report.get("ok", false) and report.has("error"):
		set_status(str(report["error"]))
		return
	var lines := ["O progresso foi apagado. O jogo voltou ao estado inicial."]
	if not report.get("local_files_left", []).is_empty():
		lines.append("Alguns ficheiros locais não foram apagados: " + ", ".join(report["local_files_left"]))
	match str(report.get("backend", "")):
		"ok":
			lines.append("O servidor confirmou que apagou as conversas e os saves remotos.")
		"partial":
			lines.append("O servidor apagou as conversas com o Atlas, mas a base de dados dos saves não respondeu. O pedido fica guardado e é repetido sozinho; os saves antigos já não voltam a aparecer.")
		_:
			lines.append("O servidor não respondeu. O pedido fica guardado e é repetido quando o jogo voltar a abrir com o backend ligado; os saves antigos já não voltam a aparecer.")
	create_menu()
	create_information_modal("PROGRESSO APAGADO", "\n\n".join(lines))


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
	UIStyle.apply(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(center)

	var container = VBoxContainer.new()
	container.name = "ModalContent"
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
	UIStyle.title(title)
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
	UIStyle.apply(overlay)

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
	UIStyle.title(title)
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
