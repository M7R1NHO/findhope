extends Area2D


var player_nearby: bool = false
var terminal_open: bool = false

var analysis_stage: int = 0
var revelation_complete: bool = false

var main: Node = null

var terminal_visual: Polygon2D = null
var interaction_label: Label = null

var terminal_layer: CanvasLayer = null

var status_label: Label = null
var data_label: Label = null
var action_button: Button = null

var processing: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene

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
	print("LABORATORY TERMINAL READY")
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

	collision.name = "InteractionArea"

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
		0.23,
		0.16,
		0.30,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "ANÁLISE BIOLÓGICA"

	title.position = Vector2(
		-130,
		-22
	)

	title.size = Vector2(
		260,
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

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] ACESSAR TERMINAL"
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

	terminal_layer.name = (
		"LaboratoryTerminalUI"
	)

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
		0.01,
		0.015,
		0.94
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
		"LABORATÓRIO // TERMINAL BIOLÓGICO"
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


	match analysis_stage:

		0:
			status_label.text = (
				"AMOSTRA BIOLÓGICA DETETADA"
			)

			data_label.text = (
				"O sistema preservou dados referentes "
				+ "a uma amostra biológica não identificada.\n\n"
				+ "Estado do registo: PARCIALMENTE CORROMPIDO\n"
				+ "Origem: NÃO IDENTIFICADA\n"
				+ "Estrutura celular: ANÓMALA\n\n"
				+ "É possível executar uma análise estrutural "
				+ "sobre os dados restantes."
			)

			action_button.text = (
				"ANALISAR AMOSTRA"
			)

			action_button.visible = true


		1:
			status_label.text = (
				"ANÁLISE ESTRUTURAL CONCLUÍDA"
			)

			data_label.text = (
				"RESULTADO:\n\n"
				+ "A amostra apresenta alterações celulares "
				+ "extensas e crescimento artificialmente induzido.\n\n"
				+ "Diversos segmentos biológicos não correspondem "
				+ "à estrutura final observada.\n\n"
				+ "O sistema possui uma função de comparação "
				+ "genética disponível."
			)

			action_button.text = (
				"COMPARAR MATERIAL GENÉTICO"
			)

			action_button.visible = true


		2:
			status_label.text = (
				"COMPATIBILIDADE GENÉTICA DETETADA"
			)

			data_label.text = (
				"RESULTADO DA COMPARAÇÃO:\n\n"
				+ "Compatibilidade com padrão humano: "
				+ "EXTREMAMENTE ALTA\n\n"
				+ "Os dados indicam que a estrutura biológica "
				+ "original do organismo era humana.\n\n"
				+ "Existe um registo associado identificado como:\n\n"
				+ "\"SUJEITO MODIFICADO\""
			)

			action_button.text = (
				"ABRIR REGISTO DO SUJEITO"
			)

			action_button.visible = true


		3:
			status_label.text = (
				"REGISTO // SUJEITO MODIFICADO"
			)

			data_label.text = (
				"CLASSIFICAÇÃO: SUJEITO MODIFICADO\n\n"
				+ "ESTADO ORIGINAL: HUMANO\n"
				+ "ESTADO FINAL: ALTERAÇÃO BIOLÓGICA EXTREMA\n"
				+ "PROCESSO: INDUZIDO\n\n"
				+ "A maior parte do registo foi eliminada "
				+ "ou encontra-se corrompida.\n\n"
				+ "Não existem dados suficientes neste terminal "
				+ "para identificar quem realizou o procedimento, "
				+ "o objetivo da experiência ou a origem do sujeito."
			)

			action_button.visible = false


func on_action_pressed():
	if processing:
		return

	match analysis_stage:

		0:
			process_stage_one()

		1:
			process_stage_two()

		2:
			process_stage_three()


func process_stage_one():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"ANALISANDO AMOSTRA..."
	)

	data_label.text = (
		"Reconstruindo estrutura celular.\n"
		+ "Comparando alterações morfológicas."
	)

	await get_tree().create_timer(
		1.2,
		true
	).timeout

	analysis_stage = 1

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
			"A estrutura celular foi alterada artificialmente. "
			+ "Isto não parece ser uma mutação natural."
		)


func process_stage_two():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"COMPARANDO MATERIAL GENÉTICO..."
	)

	data_label.text = (
		"Procurando correspondências.\n"
		+ "Reconstruindo padrão biológico original."
	)

	await get_tree().create_timer(
		1.4,
		true
	).timeout

	analysis_stage = 2

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
			"Há uma correspondência que não esperava encontrar. "
			+ "O padrão original é humano."
		)


func process_stage_three():
	processing = true

	action_button.disabled = true

	status_label.text = (
		"RECUPERANDO REGISTO..."
	)

	data_label.text = (
		"Decodificando fragmentos disponíveis.\n"
		+ "Integridade do arquivo comprometida."
	)

	await get_tree().create_timer(
		1.5,
		true
	).timeout

	analysis_stage = 3

	processing = false

	revelation_complete = true

	terminal_visual.color = Color(
		0.55,
		0.16,
		0.20,
		1.0
	)

	interaction_label.text = (
		"[E] REABRIR REGISTO"
	)

	update_terminal_content()

	register_revelation()


func register_revelation():
	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Agora temos confirmação. "
			+ "A criatura que encontrámos não nasceu daquela forma. "
			+ "Ela era humana. "
			+ "Alguém provocou esta transformação."
		)


	send_gameplay_context()


	print("")
	print("======================================")
	print("LABORATORY REVELATION")
	print("CREATURE ORIGINAL STATE: HUMAN")
	print("TRANSFORMATION: INDUCED")
	print("RESPONSIBLE PARTY: UNKNOWN")
	print("======================================")


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"creature_human_origin_confirmed",
		"creature_origin_discovered",
		"Atlas e o jogador analisaram registos biológicos "
		+ "no Laboratório da instalação subterrânea. "
		+ "Os dados confirmam que a criatura encontrada "
		+ "era originalmente humana. "
		+ "A transformação biológica foi induzida artificialmente "
		+ "e não corresponde a uma mutação natural. "
		+ "O terminal identifica o organismo como 'Sujeito Modificado'. "
		+ "Os dados disponíveis não revelam quem realizou "
		+ "a experiência, qual era o objetivo do procedimento "
		+ "nem como o sujeito humano chegou à instalação. "
		+ "Essas informações permanecem desconhecidas.",
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


func is_revelation_complete() -> bool:
	return revelation_complete
