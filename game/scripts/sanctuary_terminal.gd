extends Area2D


var player_nearby: bool = false
var terminal_open: bool = false
var processing: bool = false

var sanctuary_stage: int = 0
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

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print("")
	print("======================================")
	print("SANCTUARY TERMINAL READY")
	print("======================================")


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
		230,
		180
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_world_visual():
	terminal_visual = Polygon2D.new()

	terminal_visual.name = "SanctuaryVisual"

	terminal_visual.polygon = PackedVector2Array([
		Vector2(-100, -60),
		Vector2(100, -60),
		Vector2(100, 60),
		Vector2(-100, 60)
	])

	terminal_visual.color = Color(
		0.30,
		0.24,
		0.14,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "SANTUÁRIO // REFÚGIO"

	title.position = Vector2(
		-145,
		-22
	)

	title.size = Vector2(
		290,
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

	interaction_label.name = "InteractionLabel"

	interaction_label.text = (
		"[E] ACESSAR REGISTOS"
	)

	interaction_label.position = Vector2(
		-180,
		-115
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

	terminal_layer.name = "SanctuaryTerminalUI"
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
		0.015,
		0.012,
		0.008,
		0.96
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
		760,
		560
	)

	container.add_theme_constant_override(
		"separation",
		20
	)

	center.add_child(
		container
	)


	var title = Label.new()

	title.text = (
		"SANTUÁRIO // REGISTOS DE EMERGÊNCIA"
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


	match sanctuary_stage:

		0:
			status_label.text = (
				"REGISTOS DE EMERGÊNCIA DETETADOS"
			)

			data_label.text = (
				"O sistema contém mensagens gravadas "
				+ "durante um evento de emergência.\n\n"
				+ "Grande parte dos ficheiros encontra-se danificada.\n\n"
				+ "Classificação do evento:\n"
				+ "FALHA DE CONTENÇÃO\n\n"
				+ "Vários ocupantes da instalação foram direcionados "
				+ "para este setor de refúgio."
			)

			action_button.text = (
				"RECUPERAR REGISTOS DE EMERGÊNCIA"
			)

			action_button.visible = true


		1:
			status_label.text = (
				"FRAGMENTOS DE EMERGÊNCIA RECUPERADOS"
			)

			data_label.text = (
				"REGISTO PARCIAL:\n\n"
				+ "\"O setor de contenção já não responde.\"\n\n"
				+ "\"Não deixem ninguém entrar no corredor principal.\"\n\n"
				+ "\"O acesso ao Núcleo foi dividido. "
				+ "Nenhuma autorização isolada deve permitir entrada.\"\n\n"
				+ "Existe uma chave parcial armazenada neste terminal.\n\n"
				+ "IDENTIFICAÇÃO: FRAGMENTO B"
			)

			action_button.text = (
				"RECUPERAR FRAGMENTO B"
			)

			action_button.visible = true


		2:
			status_label.text = (
				"FRAGMENTO B RECUPERADO"
			)

			var archive_found = has_archive_fragment()

			if archive_found:
				data_label.text = (
					"Fragmento B armazenado.\n\n"
					+ "FRAGMENTO A: CONFIRMADO\n"
					+ "FRAGMENTO B: CONFIRMADO\n\n"
					+ "AUTORIZAÇÃO DO NÚCLEO PRINCIPAL:\n"
					+ "RECONSTRUÍDA\n\n"
					+ "Os dois fragmentos necessários "
					+ "já estão disponíveis."
				)

			else:
				data_label.text = (
					"Fragmento B armazenado.\n\n"
					+ "FRAGMENTO B: CONFIRMADO\n"
					+ "FRAGMENTO A: AUSENTE\n\n"
					+ "A autorização permanece incompleta."
				)

			action_button.visible = false


func on_action_pressed():
	if processing:
		return

	if sanctuary_stage == 0:
		recover_emergency_logs()

	elif sanctuary_stage == 1:
		recover_access_fragment()


func recover_emergency_logs():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECUPERANDO REGISTOS..."
	)

	data_label.text = (
		"Reconstruindo mensagens de emergência.\n"
		+ "Recuperando dados de segurança."
	)

	await get_tree().create_timer(
		1.4,
		true
	).timeout

	sanctuary_stage = 1

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
			"Estes registos foram gravados durante "
			+ "uma falha de contenção. "
			+ "Este setor serviu como refúgio."
		)


func recover_access_fragment():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECUPERANDO FRAGMENTO..."
	)

	data_label.text = (
		"Validando chave parcial.\n"
		+ "Reconstruindo assinatura de autorização."
	)

	await get_tree().create_timer(
		1.3,
		true
	).timeout

	sanctuary_stage = 2
	fragment_recovered = true

	if underground_root != null:
		underground_root.set_meta(
			"sanctuary_access_fragment",
			true
		)

	update_main_core_access_state()

	processing = false

	terminal_visual.color = Color(
		0.48,
		0.42,
		0.16,
		1.0
	)

	interaction_label.text = (
		"[E] REABRIR REGISTOS"
	)

	update_terminal_content()

	register_fragment()


func update_main_core_access_state():
	if underground_root == null:
		return

	var archive_found = bool(
		underground_root.get_meta(
			"archive_access_fragment",
			false
		)
	)

	var sanctuary_found = bool(
		underground_root.get_meta(
			"sanctuary_access_fragment",
			false
		)
	)

	var ready = (
		archive_found
		and sanctuary_found
	)

	underground_root.set_meta(
		"main_core_access_ready",
		ready
	)


func has_archive_fragment() -> bool:
	if underground_root == null:
		return false

	return bool(
		underground_root.get_meta(
			"archive_access_fragment",
			false
		)
	)


func register_fragment():
	var archive_found = has_archive_fragment()

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):

		if archive_found:
			main.add_chat_message(
				"ANDROID",
				"Temos os dois fragmentos. "
				+ "O Fragmento A dos Arquivos "
				+ "e o Fragmento B deste setor "
				+ "formam uma autorização completa. "
				+ "O acesso ao Núcleo Principal "
				+ "deve agora ser possível."
			)

		else:
			main.add_chat_message(
				"ANDROID",
				"Fragmento B recuperado. "
				+ "Ainda falta a outra parte "
				+ "da autorização."
			)

	send_gameplay_context(
		archive_found
	)


	print("")
	print("======================================")
	print("SANCTUARY COMPLETE")
	print("ACCESS FRAGMENT B: RECOVERED")

	if archive_found:
		print("MAIN CORE ACCESS: READY")
	else:
		print("MAIN CORE ACCESS: INCOMPLETE")

	print("======================================")


func send_gameplay_context(
	archive_found: bool
):
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	var description = (
		"Atlas e o jogador recuperaram registos de emergência "
		+ "no Santuário da instalação subterrânea. "
		+ "Os dados indicam que este setor serviu como refúgio "
		+ "durante uma falha de contenção. "
		+ "Os registos também mostram que a autorização "
		+ "do Núcleo Principal foi deliberadamente dividida "
		+ "em duas partes. "
		+ "O Fragmento de Acesso B foi recuperado."
	)

	if archive_found:
		description += (
			" O Fragmento A já tinha sido recuperado nos Arquivos. "
			+ "Com os Fragmentos A e B, a autorização "
			+ "do Núcleo Principal está agora completa."
		)

	else:
		description += (
			" A segunda parte da autorização ainda não foi encontrada."
		)

	main.send_gameplay_context_event(
		"sanctuary_access_fragment_recovered",
		"sanctuary_access_fragment_recovered",
		description,
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
