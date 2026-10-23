extends Area2D

const MainCoreClues := preload("res://scripts/main_core_clues.gd")
const UIStyle := preload("res://scripts/ui_style.gd")

var player_nearby: bool = false
var terminal_open: bool = false
var processing: bool = false

var archive_stage: int = 0
var fragment_recovered: bool = false

var main: Node = null
var underground_root: Node = null

var terminal_visual: Polygon2D = null
var interaction_label: Label = null

var terminal_layer: CanvasLayer = null
var status_label: Label = null
var data_label: Label = null
var action_button: Button = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene
	underground_root = get_parent()

	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	monitoring = true
	monitorable = true

	create_collision()
	create_world_visual()
	create_interaction_label()
	restore_saved_stage()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print("")
	print("ARCHIVES TERMINAL READY")


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

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		220,
		170
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_world_visual():
	terminal_visual = Polygon2D.new()

	terminal_visual.name = "TerminalVisual"

	terminal_visual.polygon = PackedVector2Array([
		Vector2(-95, -55),
		Vector2(95, -55),
		Vector2(95, 55),
		Vector2(-95, 55)
	])

	terminal_visual.color = Color(
		0.18,
		0.22,
		0.34,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "ARQUIVOS"

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
		16
	)

	title.z_index = 7

	add_child(
		title
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.text = (
		"[E] ACESSAR ARQUIVOS"
	)

	interaction_label.position = Vector2(
		-180,
		-110
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


func open_terminal():
	if terminal_open:
		return

	terminal_open = true

	get_tree().paused = true

	create_terminal_ui()

	update_terminal_content()


func close_terminal():
	if processing:
		return

	terminal_open = false

	destroy_terminal_ui()

	get_tree().paused = false


func create_terminal_ui():
	destroy_terminal_ui()

	terminal_layer = CanvasLayer.new()

	terminal_layer.name = "ArchivesTerminalUI"
	terminal_layer.layer = 720
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
		0.01,
		0.015,
		0.025,
		0.95
	)

	terminal_layer.add_child(
		background
	)
	UIStyle.apply(background)


	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(
		center
	)


	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		760,
		550
	)

	container.add_theme_constant_override(
		"separation",
		20
	)

	center.add_child(
		container
	)
	UIStyle.frame(container)


	var title = Label.new()

	title.text = (
		"ARQUIVOS // REGISTOS DA INSTALAÇÃO"
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		28
	)

	UIStyle.title(title)
	container.add_child(
		title
	)


	var separator = HSeparator.new()

	container.add_child(
		separator
	)


	status_label = Label.new()

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	status_label.add_theme_font_size_override(
		"font_size",
		18
	)

	container.add_child(
		status_label
	)


	data_label = Label.new()

	data_label.custom_minimum_size = Vector2(
		700,
		270
	)

	data_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	data_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	data_label.add_theme_font_size_override(
		"font_size",
		19
	)

	container.add_child(
		data_label
	)


	action_button = Button.new()

	action_button.custom_minimum_size = Vector2(
		0,
		62
	)

	action_button.add_theme_font_size_override(
		"font_size",
		18
	)

	action_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	action_button.pressed.connect(
		on_action_pressed
	)

	container.add_child(
		action_button
	)


	var close_button = Button.new()

	close_button.text = "FECHAR"

	close_button.custom_minimum_size = Vector2(
		0,
		55
	)

	close_button.add_theme_font_size_override(
		"font_size",
		17
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


func update_terminal_content():
	if status_label == null:
		return

	if data_label == null:
		return

	if action_button == null:
		return


	match archive_stage:

		0:
			status_label.text = (
				"ÍNDICE DE ARQUIVOS PARCIALMENTE CORROMPIDO"
			)

			data_label.text = (
				"O sistema contém milhares de registos, "
				+ "mas grande parte dos ficheiros encontra-se "
				+ "danificada ou inacessível.\n\n"
				+ "Categorias recuperáveis:\n"
				+ "- Manutenção da instalação\n"
				+ "- Sistemas de contenção\n"
				+ "- Registos biológicos\n"
				+ "- Autorizações de acesso\n\n"
				+ "É possível tentar reconstruir parte do índice."
			)

			action_button.text = (
				"RECUPERAR REGISTOS"
			)

			action_button.visible = true


		1:
			status_label.text = (
				"REGISTOS PARCIAIS RECUPERADOS"
			)

			data_label.text = (
				"Os arquivos confirmam que a instalação "
				+ "mantinha setores dedicados a pesquisa biológica "
				+ "e contenção de organismos.\n\n"
				+ "Vários registos relacionados com sujeitos "
				+ "experimentais foram eliminados.\n\n"
				+ "Existe também um registo cifrado "
				+ "ligado à autenticação do Núcleo Principal."
			)

			action_button.text = (
				"DECIFRAR REGISTO DO NÚCLEO"
			)

			action_button.visible = true


		2:
			status_label.text = (
				"PISTA DO NÚCLEO PRINCIPAL RECUPERADA"
			)

			data_label.text = (
				"REGISTO DECIFRADO:\n\n"
				+ MainCoreClues.get_clue("archives")
				+ "\n\nA autenticação do Núcleo usa uma única palavra. "
				+ "Este registo é uma das três pistas.\n\n"
				+ "PISTAS RECUPERADAS: "
				+ str(MainCoreClues.count_found()) + "/3"
			)

			action_button.visible = false


func on_action_pressed():
	if processing:
		return

	if archive_stage == 0:
		recover_records()

	elif archive_stage == 1:
		recover_access_fragment()


func recover_records():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECONSTRUINDO ÍNDICE..."
	)

	data_label.text = (
		"Recuperando blocos de dados.\n"
		+ "Validando integridade dos registos."
	)

	await get_tree().create_timer(
		1.3,
		true
	).timeout

	archive_stage = 1
	MainCoreClues.save_stage("archives", archive_stage)

	processing = false

	action_button.disabled = false

	update_terminal_content()


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Os arquivos confirmam que este local "
			+ "possuía setores de pesquisa biológica "
			+ "e contenção. Muitos registos foram apagados."
		)


func recover_access_fragment():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECUPERANDO AUTORIZAÇÃO..."
	)

	data_label.text = (
		"Decifrando registo do Núcleo Principal.\n"
		+ "Verificando assinatura do sistema."
	)

	await get_tree().create_timer(
		1.3,
		true
	).timeout

	archive_stage = 2
	fragment_recovered = true
	MainCoreClues.save_stage("archives", archive_stage)
	register_facility_clue()

	processing = false

	apply_completed_visual()

	update_terminal_content()

	register_fragment()


func register_fragment():
	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Este registo fala da palavra-passe do Núcleo "
			+ "sem a dizer. Sozinho não chega. "
			+ "Devemos compará-lo com as outras pistas."
		)


	send_gameplay_context()


	print("")
	print("======================================")
	print("ARCHIVES COMPLETE")
	print("MAIN CORE CLUE (ARCHIVES): RECOVERED")
	print("CLUES FOUND: ", MainCoreClues.count_found(), "/3")
	print("======================================")


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"archives_main_core_clue_recovered",
		"main_core_clue_recovered",
		"Atlas e o jogador recuperaram dados nos Arquivos "
		+ "da instalação subterrânea. "
		+ "Os registos confirmam a existência de setores "
		+ "de pesquisa biológica e contenção, "
		+ "mas muitos arquivos relacionados com experiências "
		+ "foram eliminados. "
		+ "Também foi decifrado um registo que serve de pista "
		+ "para a palavra-passe do Núcleo Principal: \""
		+ MainCoreClues.get_clue("archives") + "\" "
		+ "A palavra-passe é uma única palavra e deduz-se juntando "
		+ "as pistas do Laboratório, dos Arquivos e do Santuário. "
		+ "Atlas pode ajudar a interpretar a pista, "
		+ "mas não sabe a palavra e não a deve afirmar.",
		true
	)


func destroy_terminal_ui():
	if (
		terminal_layer != null
		and is_instance_valid(
			terminal_layer
		)
	):
		terminal_layer.queue_free()

	terminal_layer = null

	status_label = null
	data_label = null
	action_button = null


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


func has_access_fragment() -> bool:
	return fragment_recovered


func restore_saved_stage() -> void:
	archive_stage = MainCoreClues.load_stage("archives")
	fragment_recovered = archive_stage >= 2
	if fragment_recovered:
		apply_completed_visual()


func apply_completed_visual() -> void:
	if terminal_visual != null:
		terminal_visual.color = Color(
			0.18,
			0.55,
			0.44,
			1.0
		)

	if interaction_label != null:
		interaction_label.text = (
			"[E] REABRIR ARQUIVOS"
		)


func register_facility_clue() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("Arquivos: cena atual não encontrada.")
		return

	var underground := current_scene.get_node_or_null("UndergroundRoot")
	if underground == null:
		push_warning("Arquivos: UndergroundRoot não encontrado.")
		return

	var manager := underground.get_node_or_null("FacilityProgressionManager")
	if manager == null:
		push_warning("Arquivos: FacilityProgressionManager não encontrado.")
		return

	if manager.has_method("register_clue_analyzed"):
		manager.register_clue_analyzed("archives")
	else:
		push_warning("Arquivos: método register_clue_analyzed não encontrado.")
