extends Node


# =========================================================
# SINAIS
# =========================================================

signal hack_started
signal hack_succeeded(target)
signal hack_cancelled


# =========================================================
# IDs DOS 9 MINIGAMES
# =========================================================

const HACK_CONCATENACAO := 1
const HACK_DIRECOES := 2
const HACK_SOURCE_ACCESS := 3
const HACK_CONTAGEM_TECLAS := 4
const HACK_SOBRECARGA := 5
const HACK_MATRIZ := 6
const HACK_MEMORIA_CORES := 7
const HACK_MULTIPLICACAO_TEXTO := 8
const HACK_CONTAGEM_ZEROS := 9


# =========================================================
# NOMES MOSTRADOS AO JOGADOR
# =========================================================

const HACK_NAMES := {
	HACK_CONCATENACAO:
		"Reconstrução de dados",

	HACK_DIRECOES:
		"Sincronização direcional",

	HACK_SOURCE_ACCESS:
		"Roteamento de acesso",

	HACK_CONTAGEM_TECLAS:
		"Injeção de pulsos",

	HACK_SOBRECARGA:
		"Regulação de carga",

	HACK_MATRIZ:
		"Decodificação matricial",

	HACK_MEMORIA_CORES:
		"Sequência cromática",

	HACK_MULTIPLICACAO_TEXTO:
		"Replicação de dados",

	HACK_CONTAGEM_ZEROS:
		"Verificação binária"
}


# =========================================================
# POR ENQUANTO ESTES 3 JÁ FUNCIONAM
# =========================================================

var implemented_hacks := [
	HACK_CONCATENACAO,
	HACK_MULTIPLICACAO_TEXTO,
	HACK_CONTAGEM_ZEROS
]


# =========================================================
# ESTADO
# =========================================================

var rng := RandomNumberGenerator.new()

var hack_active: bool = false

var current_hack: int = -1

var correct_answer: String = ""

var target_node: Node = null


# =========================================================
# UI
# =========================================================

var ui_layer: CanvasLayer = null

var overlay: ColorRect = null

var main_panel: PanelContainer = null

var content: VBoxContainer = null

var feedback_label: Label = null

var answer_input: LineEdit = null

var confirm_button: Button = null


# =========================================================
# READY
# =========================================================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	rng.randomize()

	print("HACK MANAGER READY")
	print("Pressione H para testar o sistema.")


# =========================================================
# TESTE TEMPORÁRIO
#
# H abre o sistema.
#
# Depois vamos remover isto quando as portas
# chamarem start_hack() diretamente.
# =========================================================

func _unhandled_input(event):
	if hack_active:
		return

	if event is InputEventKey:
		if (
			event.pressed
			and not event.echo
			and event.keycode == KEY_H
		):
			start_hack()


# =========================================================
# COMEÇAR HACK
# =========================================================

func start_hack(
	target: Node = null,
	custom_hacks: Array = []
):
	if hack_active:
		return

	hack_active = true

	target_node = target

	current_hack = -1

	correct_answer = ""

	get_tree().paused = true

	hack_started.emit()

	create_base_ui()

	show_hack_choices(
		custom_hacks
	)


# =========================================================
# CRIAR UI PRINCIPAL
# =========================================================

func create_base_ui():
	destroy_ui()


	# -----------------------------------------------------
	# CANVAS
	# -----------------------------------------------------

	ui_layer = CanvasLayer.new()

	ui_layer.name = "HackInterface"

	ui_layer.layer = 100

	ui_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		ui_layer
	)


	# -----------------------------------------------------
	# FUNDO ESCURO
	# -----------------------------------------------------

	overlay = ColorRect.new()

	overlay.name = "Overlay"

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.01,
		0.02,
		0.03,
		0.94
	)

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	ui_layer.add_child(
		overlay
	)


	# -----------------------------------------------------
	# CENTER
	# -----------------------------------------------------

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.add_child(
		center
	)


	# -----------------------------------------------------
	# PAINEL
	# -----------------------------------------------------

	main_panel = PanelContainer.new()

	main_panel.custom_minimum_size = Vector2(
		720,
		480
	)

	center.add_child(
		main_panel
	)


	# -----------------------------------------------------
	# MARGENS
	# -----------------------------------------------------

	var margin = MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		40
	)

	margin.add_theme_constant_override(
		"margin_right",
		40
	)

	margin.add_theme_constant_override(
		"margin_top",
		35
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		35
	)

	main_panel.add_child(
		margin
	)


	# -----------------------------------------------------
	# CONTEÚDO
	# -----------------------------------------------------

	content = VBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		18
	)

	margin.add_child(
		content
	)


# =========================================================
# MOSTRAR 3 MÉTODOS
# =========================================================

func show_hack_choices(
	custom_hacks: Array = []
):
	clear_content()


	var title = Label.new()

	title.text = "PYSSOA // INTERFACE DE ACESSO"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		28
	)

	content.add_child(
		title
	)


	var separator = HSeparator.new()

	content.add_child(
		separator
	)


	var atlas_text = Label.new()

	atlas_text.text = (
		"ATLAS:\n"
		+ "Identifiquei três métodos possíveis "
		+ "para interferir com o sistema de acesso."
	)

	atlas_text.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	atlas_text.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(
		atlas_text
	)


	var instruction = Label.new()

	instruction.text = (
		"Escolha uma abordagem:"
	)

	instruction.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(
		instruction
	)


	var choices = get_random_hacks(
		custom_hacks
	)


	for hack_id in choices:
		var button = Button.new()

		button.text = (
			HACK_NAMES[hack_id]
		)

		button.custom_minimum_size = Vector2(
			0,
			58
		)

		button.add_theme_font_size_override(
			"font_size",
			18
		)

		button.pressed.connect(
			on_hack_choice_pressed.bind(
				hack_id
			)
		)

		content.add_child(
			button
		)


	var cancel_button = Button.new()

	cancel_button.text = "CANCELAR ACESSO"

	cancel_button.custom_minimum_size = Vector2(
		0,
		45
	)

	cancel_button.pressed.connect(
		cancel_hack
	)

	content.add_child(
		cancel_button
	)


# =========================================================
# ESCOLHER 3 HACKS
# =========================================================

func get_random_hacks(
	custom_hacks: Array = []
) -> Array:

	var pool: Array = []


	# Se a porta mandar uma lista própria
	if not custom_hacks.is_empty():
		for hack_id in custom_hacks:
			if (
				hack_id in implemented_hacks
				and hack_id not in pool
			):
				pool.append(
					hack_id
				)


	# Caso contrário usa todos os implementados
	if pool.is_empty():
		pool = implemented_hacks.duplicate()


	# Completa até termos pelo menos 3
	for hack_id in implemented_hacks:
		if pool.size() >= 3:
			break

		if hack_id not in pool:
			pool.append(
				hack_id
			)


	pool.shuffle()


	var result: Array = []

	var amount = min(
		3,
		pool.size()
	)


	for index in range(
		amount
	):
		result.append(
			pool[index]
		)


	return result


# =========================================================
# ESCOLHA
# =========================================================

func on_hack_choice_pressed(
	hack_id: int
):
	current_hack = hack_id


	match current_hack:

		HACK_CONCATENACAO:
			start_concat_hack()

		HACK_MULTIPLICACAO_TEXTO:
			start_text_multiplication_hack()

		HACK_CONTAGEM_ZEROS:
			start_zero_count_hack()

		_:
			print(
				"Minigame ainda não implementado: ",
				current_hack
			)


# =========================================================
# MINIGAME 1
# CONCATENAÇÃO
#
# gH65s + 777 = gH65s777
# =========================================================

func start_concat_hack():
	var first = random_token(
		rng.randi_range(
			2,
			5
		)
	)

	var second = random_token(
		rng.randi_range(
			2,
			4
		)
	)


	correct_answer = (
		first + second
	)


	var question = (
		first
		+ " + "
		+ second
		+ " = ?"
	)


	create_text_minigame(
		"RECONSTRUÇÃO DE DADOS",
		"Una os dois blocos exatamente na ordem apresentada.",
		question
	)


# =========================================================
# MINIGAME 8
# MULTIPLICAÇÃO TEXTUAL
#
# y × 3 = yyy
# =========================================================

func start_text_multiplication_hack():
	var letters = (
		"abcdefghjkmnpqrstuvwxyz"
	)

	var random_index = rng.randi_range(
		0,
		letters.length() - 1
	)

	var letter = letters.substr(
		random_index,
		1
	)


	var amount = rng.randi_range(
		2,
		7
	)


	correct_answer = ""


	for _index in range(
		amount
	):
		correct_answer += letter


	var question = (
		letter
		+ " × "
		+ str(amount)
		+ " = ?"
	)


	create_text_minigame(
		"REPLICAÇÃO DE DADOS",
		"Repita o carácter pela quantidade indicada.",
		question
	)


# =========================================================
# MINIGAME 9
# CONTAR ZEROS
#
# 0000000 = 7
# =========================================================

func start_zero_count_hack():
	var amount = rng.randi_range(
		5,
		15
	)


	var zero_string = ""


	for _index in range(
		amount
	):
		zero_string += "0"


	correct_answer = str(
		amount
	)


	var question = (
		zero_string
		+ " = ?"
	)


	create_text_minigame(
		"VERIFICAÇÃO BINÁRIA",
		"Conte a quantidade de zeros apresentada.",
		question
	)


# =========================================================
# UI PADRÃO PARA HACKS DE TEXTO
# =========================================================

func create_text_minigame(
	title_text: String,
	instruction_text: String,
	question_text: String
):
	clear_content()


	var title = Label.new()

	title.text = title_text

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		30
	)

	content.add_child(
		title
	)


	var separator = HSeparator.new()

	content.add_child(
		separator
	)


	var instruction = Label.new()

	instruction.text = instruction_text

	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	instruction.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	instruction.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(
		instruction
	)


	var question = Label.new()

	question.text = question_text

	question.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	question.add_theme_font_size_override(
		"font_size",
		34
	)

	question.custom_minimum_size = Vector2(
		0,
		90
	)

	content.add_child(
		question
	)


	answer_input = LineEdit.new()

	answer_input.placeholder_text = (
		"Introduza a resposta..."
	)

	answer_input.custom_minimum_size = Vector2(
		0,
		55
	)

	answer_input.add_theme_font_size_override(
		"font_size",
		22
	)

	answer_input.text_submitted.connect(
		on_answer_submitted
	)

	content.add_child(
		answer_input
	)


	confirm_button = Button.new()

	confirm_button.text = (
		"ENVIAR"
	)

	confirm_button.custom_minimum_size = Vector2(
		0,
		55
	)

	confirm_button.add_theme_font_size_override(
		"font_size",
		18
	)

	confirm_button.pressed.connect(
		check_answer
	)

	content.add_child(
		confirm_button
	)


	feedback_label = Label.new()

	feedback_label.text = ""

	feedback_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	feedback_label.add_theme_font_size_override(
		"font_size",
		20
	)

	content.add_child(
		feedback_label
	)


	var cancel_button = Button.new()

	cancel_button.text = (
		"CANCELAR"
	)

	cancel_button.pressed.connect(
		cancel_hack
	)

	content.add_child(
		cancel_button
	)


	answer_input.grab_focus()


# =========================================================
# ENTER NO LINEEDIT
# =========================================================

func on_answer_submitted(
	_text: String
):
	check_answer()


# =========================================================
# VALIDAR RESPOSTA
# =========================================================

func check_answer():
	if answer_input == null:
		return


	var player_answer = (
		answer_input.text.strip_edges()
	)


	if player_answer == correct_answer:

		show_success()

	else:

		show_failure()


# =========================================================
# ERRO
# =========================================================

func show_failure():
	if feedback_label == null:
		return


	feedback_label.text = (
		"ACCESS DENIED\n"
		+ "Resposta incorreta. Tente novamente."
	)

	feedback_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.25
		)
	)


	answer_input.select_all()

	answer_input.grab_focus()


# =========================================================
# SUCESSO
# =========================================================

func show_success():
	if feedback_label != null:

		feedback_label.text = (
			"ACCESS GRANTED"
		)

		feedback_label.add_theme_color_override(
			"font_color",
			Color(
				0.25,
				1.0,
				0.45
			)
		)


	if answer_input != null:
		answer_input.editable = false


	if confirm_button != null:
		confirm_button.disabled = true


	await get_tree().create_timer(
		0.8,
		true
	).timeout


	finish_success()


# =========================================================
# FINALIZAR COM SUCESSO
# =========================================================

func finish_success():
	var saved_target = (
		target_node
	)


	destroy_ui()


	hack_active = false

	current_hack = -1

	correct_answer = ""

	target_node = null


	get_tree().paused = false


	hack_succeeded.emit(
		saved_target
	)


	# Quando ligarmos uma porta ao sistema,
	# basta ela possuir esta função.
	if (
		saved_target != null
		and is_instance_valid(
			saved_target
		)
		and saved_target.has_method(
			"on_hack_success"
		)
	):
		saved_target.call(
			"on_hack_success"
		)


	print("HACK SUCCESS")


# =========================================================
# CANCELAR
# =========================================================

func cancel_hack():
	destroy_ui()


	hack_active = false

	current_hack = -1

	correct_answer = ""

	target_node = null


	get_tree().paused = false


	hack_cancelled.emit()


	print("HACK CANCELLED")


# =========================================================
# TOKEN ALEATÓRIO
# =========================================================

func random_token(
	length: int
) -> String:

	var characters = (
		"ABCDEFGHJKLMNPQRSTUVWXYZ"
		+ "abcdefghijkmnpqrstuvwxyz"
		+ "23456789"
	)


	var result = ""


	for _index in range(
		length
	):
		var random_index = rng.randi_range(
			0,
			characters.length() - 1
		)

		result += characters.substr(
			random_index,
			1
		)


	return result


# =========================================================
# LIMPAR CONTEÚDO
# =========================================================

func clear_content():
	if content == null:
		return

	for child in content.get_children():
		child.hide()
		child.set_process(false)
		child.queue_free()


# =========================================================
# DESTRUIR UI
# =========================================================

func destroy_ui():
	if (
		ui_layer != null
		and is_instance_valid(
			ui_layer
		)
	):
		ui_layer.queue_free()


	ui_layer = null

	overlay = null

	main_panel = null

	content = null

	feedback_label = null

	answer_input = null

	confirm_button = null
