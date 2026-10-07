extends Area2D


var player_nearby: bool = false
var terminal_open: bool = false
var processing: bool = false

var core_unlocked: bool = false
var deep_access_discovered: bool = false

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
	print("MAIN CORE TERMINAL READY")
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
		250,
		190
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_world_visual():
	terminal_visual = Polygon2D.new()

	terminal_visual.name = "MainCoreVisual"

	terminal_visual.polygon = PackedVector2Array([
		Vector2(-110, -65),
		Vector2(110, -65),
		Vector2(110, 65),
		Vector2(-110, 65)
	])

	terminal_visual.color = Color(
		0.18,
		0.12,
		0.24,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "NÚCLEO PRINCIPAL"

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
		16
	)

	title.z_index = 7

	add_child(
		title
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.name = "InteractionLabel"

	interaction_label.text = (
		"[E] ACESSAR NÚCLEO"
	)

	interaction_label.position = Vector2(
		-190,
		-120
	)

	interaction_label.size = Vector2(
		380,
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

	terminal_layer.name = "MainCoreTerminalUI"
	terminal_layer.layer = 730

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
		0.008,
		0.008,
		0.015,
		0.97
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
		780,
		570
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
		"NÚCLEO PRINCIPAL // CONTROLO CENTRAL"
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		29
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
		19
	)

	container.add_child(
		status_label
	)


	data_label = Label.new()

	data_label.custom_minimum_size = Vector2(
		720,
		285
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


	var archive_fragment = has_archive_fragment()
	var sanctuary_fragment = has_sanctuary_fragment()


	if core_unlocked:
		status_label.text = (
			"ACESSO PROFUNDO LIBERADO"
		)

		data_label.text = (
			"AUTORIZAÇÃO DO NÚCLEO: VÁLIDA\n\n"
			+ "Uma rota de acesso foi identificada "
			+ "abaixo da instalação principal.\n\n"
			+ "A estrutura encontrada não corresponde "
			+ "integralmente aos padrões arquitetónicos "
			+ "observados neste complexo.\n\n"
			+ "ORIGEM: NÃO DETERMINADA\n"
			+ "ESTADO: ACESSÍVEL\n\n"
			+ "Atlas não possui dados suficientes "
			+ "para identificar o que existe além deste ponto."
		)

		action_button.visible = false

		return


	status_label.text = (
		"AUTORIZAÇÃO NECESSÁRIA"
	)


	var archive_text = (
		"CONFIRMADO"
		if archive_fragment
		else "AUSENTE"
	)

	var sanctuary_text = (
		"CONFIRMADO"
		if sanctuary_fragment
		else "AUSENTE"
	)


	data_label.text = (
		"FRAGMENTO A // ARQUIVOS: "
		+ archive_text
		+ "\n"
		+ "FRAGMENTO B // SANTUÁRIO: "
		+ sanctuary_text
		+ "\n\n"
	)


	if (
		archive_fragment
		and sanctuary_fragment
	):
		data_label.text += (
			"As duas partes da autorização "
			+ "foram localizadas.\n\n"
			+ "O sistema pode reconstruir "
			+ "a credencial de acesso."
		)

		action_button.text = (
			"RECONSTRUIR AUTORIZAÇÃO"
		)

		action_button.visible = true

	else:
		data_label.text += (
			"A autorização permanece incompleta.\n\n"
			+ "É necessário recuperar os dois "
			+ "fragmentos de acesso."
		)

		action_button.visible = false


func on_action_pressed():
	if processing:
		return

	if core_unlocked:
		return

	if not (
		has_archive_fragment()
		and has_sanctuary_fragment()
	):
		return

	reconstruct_authorization()


func reconstruct_authorization():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECONSTRUINDO AUTORIZAÇÃO..."
	)

	data_label.text = (
		"Combinando Fragmento A e Fragmento B.\n\n"
		+ "Validando assinatura de segurança.\n"
		+ "Acessando controlo central."
	)

	await get_tree().create_timer(
		1.6,
		true
	).timeout


	status_label.text = (
		"AUTORIZAÇÃO ACEITE"
	)

	data_label.text = (
		"Credencial reconstruída com sucesso.\n\n"
		+ "Pesquisando rotas restritas..."
	)

	await get_tree().create_timer(
		1.2,
		true
	).timeout


	discover_deep_access()


func discover_deep_access():
	core_unlocked = true
	deep_access_discovered = true
	processing = false

	if underground_root != null:

		underground_root.set_meta(
			"main_core_unlocked",
			true
		)

		underground_root.set_meta(
			"phase3_unlocked",
			true
		)


	terminal_visual.color = Color(
		0.15,
		0.62,
		0.52,
		1.0
	)

	interaction_label.text = (
		"[E] REABRIR NÚCLEO"
	)

	update_terminal_content()

	register_discovery()


func register_discovery():
	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Autorização aceite. "
			+ "Existe um acesso abaixo desta instalação. "
			+ "A estrutura além dele não corresponde "
			+ "completamente ao restante complexo. "
			+ "Não consigo determinar a sua origem daqui."
		)


	send_gameplay_context()


	print("")
	print("======================================")
	print("MAIN CORE UNLOCKED")
	print("ACCESS FRAGMENT A: CONFIRMED")
	print("ACCESS FRAGMENT B: CONFIRMED")
	print("DEEP ACCESS: DISCOVERED")
	print("PHASE 3: UNLOCKED")
	print("======================================")


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"main_core_deep_access_discovered",
		"deep_access_discovered",
		"Atlas e o jogador combinaram o Fragmento A "
		+ "recuperado nos Arquivos com o Fragmento B "
		+ "recuperado no Santuário. "
		+ "A autorização do Núcleo Principal foi reconstruída "
		+ "e aceite pelo sistema. "
		+ "O Núcleo revelou a existência de uma rota restrita "
		+ "que conduz para uma estrutura abaixo da instalação. "
		+ "Essa estrutura não corresponde completamente "
		+ "aos padrões arquitetónicos observados no complexo. "
		+ "A origem e função dessa estrutura permanecem desconhecidas. "
		+ "Atlas não deve afirmar ainda que sabe o que existe lá.",
		true
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


func has_sanctuary_fragment() -> bool:
	if underground_root == null:
		return false

	return bool(
		underground_root.get_meta(
			"sanctuary_access_fragment",
			false
		)
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


func is_core_unlocked() -> bool:
	return core_unlocked


func is_phase3_unlocked() -> bool:
	return core_unlocked
