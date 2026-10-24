extends Node

const TutorialCard := preload("res://scripts/tutorial_card.gd")


# =========================================================
# SINAIS
# =========================================================

signal hack_started
signal hack_succeeded(target)
signal hack_cancelled


# =========================================================
# IDs DOS MINIGAMES
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
# NOMES
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


var implemented_hacks := [
	HACK_CONCATENACAO,
	HACK_DIRECOES,
	HACK_SOURCE_ACCESS,
	HACK_CONTAGEM_TECLAS,
	HACK_SOBRECARGA,
	HACK_MATRIZ,
	HACK_MEMORIA_CORES,
	HACK_MULTIPLICACAO_TEXTO,
	HACK_CONTAGEM_ZEROS
]


# =========================================================
# ESTADO GERAL
# =========================================================

var rng := RandomNumberGenerator.new()

var hack_active := false
var finishing_hack := false

var current_hack := -1

var correct_answer := ""

var target_node: Node = null

var hack_session_id := 0


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
# DIREÇÕES
# =========================================================

var direction_sequence: Array = []

var direction_player_index := 0

var direction_accepting_input := false

var direction_progress_label: Label = null


# =========================================================
# SOURCE -> ACCESS
# =========================================================

var route_blocked: Array = []

var route_visited: Array = []

var route_buttons: Dictionary = {}

var route_status_label: Label = null


# =========================================================
# CONTAGEM DE TECLAS
# =========================================================

var key_target := 0

var key_count := 0

var key_count_label: Label = null


# =========================================================
# SOBRECARGA
# =========================================================

var overload_active := false

var overload_holding := false

var overload_value := 20.0

var overload_safe_min := 45.0

var overload_safe_max := 65.0

var overload_required_time := 3.0

var overload_stable_time := 0.0

var overload_bar: ProgressBar = null

var overload_time_label: Label = null


# =========================================================
# MATRIZ
# =========================================================

var matrix_target_sequence: Array = []

var matrix_player_index := 0

var matrix_progress_label: Label = null


# =========================================================
# MEMÓRIA
# =========================================================

var memory_sequence: Array = []

var memory_input_index := 0

var memory_accepting_input := false

var memory_flash_rect: ColorRect = null

var memory_flash_label: Label = null

var memory_buttons: Array = []


# =========================================================
# READY
# =========================================================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	rng.randomize()

	print("HACK MANAGER READY")
	print("9 MINIGAMES DISPONÍVEIS")
	print("H = teste manual")


# =========================================================
# PROCESS
# =========================================================

func _process(delta):

	if not hack_active:
		return

	# Com um tutorial aberto, os temporizadores param.
	if TutorialCard.is_open(get_tree()):
		return

	if finishing_hack:
		return

	if (
		current_hack
		== HACK_SOBRECARGA
		and overload_active
	):
		update_overload(
			delta
		)


# =========================================================
# INPUT
# =========================================================

func _unhandled_input(event):

	# -----------------------------------------------------
	# TESTE COM H (só em builds de debug; no jogo exportado
	# o hack só começa pelos terminais)
	# -----------------------------------------------------

	if not hack_active:

		if OS.is_debug_build() and event is InputEventKey:

			if (
				event.pressed
				and not event.echo
				and event.keycode == KEY_H
			):
				start_hack()

		return


	if finishing_hack:
		return


	# -----------------------------------------------------
	# INPUT ESPECÍFICO
	# -----------------------------------------------------

	match current_hack:

		HACK_DIRECOES:
			handle_direction_input(
				event
			)

		HACK_CONTAGEM_TECLAS:
			handle_key_count_input(
				event
			)

		HACK_SOBRECARGA:
			handle_overload_input(
				event
			)


# =========================================================
# COMEÇAR HACK
# =========================================================

func start_hack(
	target: Node = null,
	custom_hacks: Array = []
):

	if hack_active:
		return


	hack_session_id += 1


	hack_active = true

	finishing_hack = false

	current_hack = -1

	correct_answer = ""

	target_node = target


	reset_all_minigame_states()


	get_tree().paused = true


	hack_started.emit()


	create_base_ui()

	TutorialCard.show_once(self, "hack")

	# Hacks normais iniciam diretamente um unico minijogo sorteado.
	# A sobrecarga so pode ser iniciada explicitamente durante RUN,
	# passando-a como unico hack permitido.
	var selected_hack := get_random_hack(custom_hacks)
	current_hack = selected_hack

	call_deferred(
		"launch_selected_hack",
		selected_hack
	)


# =========================================================
# UI BASE
# =========================================================

func create_base_ui():

	destroy_ui()


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
	# FUNDO
	# -----------------------------------------------------

	overlay = ColorRect.new()

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.01,
		0.02,
		0.03,
		0.95
	)

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	ui_layer.add_child(
		overlay
	)


	# -----------------------------------------------------
	# CENTRO
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
		760,
		520
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
		16
	)

	margin.add_child(
		content
	)


# =========================================================
# SORTEAR UM UNICO MINIGAME
# =========================================================

func get_random_hack(
	custom_hacks: Array = []
) -> int:

	var pool: Array = []

	if not custom_hacks.is_empty():
		for hack_id in custom_hacks:
			if (
				hack_id in implemented_hacks
				and hack_id not in pool
			):
				pool.append(hack_id)

	# A sobrecarga nao aparece em sorteios normais.
	# So e permitida quando pedida explicitamente e isolada.
	if pool.size() != 1 or pool[0] != HACK_SOBRECARGA:
		pool.erase(HACK_SOBRECARGA)

	if pool.is_empty():
		pool = implemented_hacks.duplicate()
		pool.erase(HACK_SOBRECARGA)

	if pool.is_empty():
		push_error("HackManager: nao existem minijogos disponiveis.")
		return HACK_DIRECOES

	return pool[rng.randi_range(0, pool.size() - 1)]


# =========================================================
# ESCOLHA DE 3 MÉTODOS
# =========================================================

func show_hack_choices(
	custom_hacks: Array = []
):

	prepare_minigame_screen()


	add_title(
		"PYSSOA // INTERFACE DE ACESSO",
		"ATLAS:\n"
		+ "Identifiquei três métodos possíveis "
		+ "para interferir com o sistema de acesso."
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


	add_cancel_button(
		"CANCELAR ACESSO"
	)


# =========================================================
# SORTEAR 3
# =========================================================

func get_random_hacks(
	custom_hacks: Array = []
) -> Array:

	var pool: Array = []


	if not custom_hacks.is_empty():

		for hack_id in custom_hacks:

			if (
				hack_id in implemented_hacks
				and hack_id not in pool
			):
				pool.append(
					hack_id
				)


	if pool.is_empty():

		pool = (
			implemented_hacks.duplicate()
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


	call_deferred(
		"launch_selected_hack",
		hack_id
	)


# =========================================================
# LANÇAR
# =========================================================

func launch_selected_hack(
	hack_id: int
):

	if not hack_active:
		return


	match hack_id:

		HACK_CONCATENACAO:
			start_concat_hack()

		HACK_DIRECOES:
			start_direction_hack()

		HACK_SOURCE_ACCESS:
			start_source_access_hack()

		HACK_CONTAGEM_TECLAS:
			start_key_count_hack()

		HACK_SOBRECARGA:
			start_overload_hack()

		HACK_MATRIZ:
			start_matrix_hack()

		HACK_MEMORIA_CORES:
			start_memory_hack()

		HACK_MULTIPLICACAO_TEXTO:
			start_text_multiplication_hack()

		HACK_CONTAGEM_ZEROS:
			start_zero_count_hack()


# =========================================================
# 1 — CONCATENAÇÃO
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


	create_text_minigame(
		"RECONSTRUÇÃO DE DADOS",
		"Una os dois blocos exatamente na ordem apresentada.",
		first
		+ " + "
		+ second
		+ " = ?"
	)


# =========================================================
# 2 — DIREÇÕES
# =========================================================

func start_direction_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_DIRECOES
	)


	direction_sequence.clear()

	direction_player_index = 0


	var options := [
		"UP",
		"DOWN",
		"LEFT",
		"RIGHT"
	]


	var length = rng.randi_range(
		5,
		7
	)


	for _i in range(
		length
	):

		direction_sequence.append(
			options[
				rng.randi_range(
					0,
					options.size() - 1
				)
			]
		)


	add_title(
		"SINCRONIZAÇÃO DIRECIONAL",
		"Reproduza a sequência utilizando "
		+ "as setas do teclado."
	)


	var sequence_label = Label.new()

	sequence_label.text = (
		build_direction_sequence_text()
	)

	sequence_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	sequence_label.custom_minimum_size = Vector2(
		0,
		90
	)

	sequence_label.add_theme_font_size_override(
		"font_size",
		40
	)

	content.add_child(
		sequence_label
	)


	direction_progress_label = Label.new()

	direction_progress_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	direction_progress_label.add_theme_font_size_override(
		"font_size",
		24
	)

	content.add_child(
		direction_progress_label
	)


	create_feedback_label(
		"AGUARDANDO INPUT..."
	)


	update_direction_progress()


	add_cancel_button()


	direction_accepting_input = true


func handle_direction_input(
	event
):

	if not direction_accepting_input:
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


	var pressed_direction = ""


	match event.keycode:

		KEY_UP:
			pressed_direction = "UP"

		KEY_DOWN:
			pressed_direction = "DOWN"

		KEY_LEFT:
			pressed_direction = "LEFT"

		KEY_RIGHT:
			pressed_direction = "RIGHT"

		_:
			return


	get_viewport().set_input_as_handled()


	var expected = (
		direction_sequence[
			direction_player_index
		]
	)


	if pressed_direction == expected:

		direction_player_index += 1


		update_direction_progress()


		if (
			direction_player_index
			>= direction_sequence.size()
		):

			direction_accepting_input = false

			show_success()


	else:

		direction_player_index = 0


		update_direction_progress()


		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Sequência incorreta. Reiniciando."
		)


func build_direction_sequence_text() -> String:

	var result = ""


	for index in range(
		direction_sequence.size()
	):

		result += direction_to_symbol(
			direction_sequence[index]
		)


		if (
			index
			< direction_sequence.size() - 1
		):
			result += "    "


	return result


func build_direction_progress_text() -> String:

	var result = ""


	for index in range(
		direction_sequence.size()
	):

		if index < direction_player_index:
			result += "✓"

		else:
			result += "○"


		if (
			index
			< direction_sequence.size() - 1
		):
			result += "    "


	return result


func update_direction_progress():

	if direction_progress_label == null:
		return


	direction_progress_label.text = (
		build_direction_progress_text()
	)


func direction_to_symbol(
	direction: String
) -> String:

	match direction:

		"UP":
			return "↑"

		"DOWN":
			return "↓"

		"LEFT":
			return "←"

		"RIGHT":
			return "→"


	return "?"


# =========================================================
# 3 — SOURCE -> ACCESS
# =========================================================

func start_source_access_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_SOURCE_ACCESS
	)


	route_buttons.clear()

	route_visited = [
		0
	]


	var patterns := [
		[2, 4],
		[3, 4],
		[1, 7],
		[3, 5]
	]


	route_blocked = (
		patterns[
			rng.randi_range(
				0,
				patterns.size() - 1
			)
		].duplicate()
	)


	add_title(
		"ROTEAMENTO DE ACESSO",
		"Crie uma rota entre SOURCE e ACCESS. "
		+ "Só pode avançar horizontal ou verticalmente."
	)


	var grid = GridContainer.new()

	grid.columns = 3

	grid.add_theme_constant_override(
		"h_separation",
		12
	)

	grid.add_theme_constant_override(
		"v_separation",
		12
	)

	content.add_child(
		grid
	)


	for index in range(
		9
	):

		var button = Button.new()

		button.custom_minimum_size = Vector2(
			170,
			80
		)

		button.add_theme_font_size_override(
			"font_size",
			18
		)


		if index == 0:

			button.text = "SOURCE"

			button.disabled = true


		elif index == 8:

			button.text = "ACCESS"


		elif index in route_blocked:

			button.text = "×"

			button.disabled = true


		else:

			button.text = "○"


		button.pressed.connect(
			on_route_node_pressed.bind(
				index
			)
		)


		route_buttons[index] = button


		grid.add_child(
			button
		)


	route_status_label = Label.new()

	route_status_label.text = (
		"SOURCE conectado."
	)

	route_status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	route_status_label.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(
		route_status_label
	)


	create_feedback_label()


	add_cancel_button()


	update_route_visuals()


func on_route_node_pressed(
	index: int
):

	if finishing_hack:
		return


	if index in route_blocked:
		return


	var current_node = (
		route_visited[
			route_visited.size() - 1
		]
	)


	if (
		index in route_visited
		or not route_nodes_adjacent(
			current_node,
			index
		)
	):

		reset_route_attempt()

		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Ligação inválida. "
			+ "Rota reiniciada."
		)

		return


	route_visited.append(
		index
	)


	update_route_visuals()


	if index == 8:

		show_success()


func route_nodes_adjacent(
	a: int,
	b: int
) -> bool:

	var ax = a % 3
	var ay = a / 3

	var bx = b % 3
	var by = b / 3


	return (
		abs(ax - bx)
		+ abs(ay - by)
		== 1
	)


func reset_route_attempt():

	route_visited = [
		0
	]


	update_route_visuals()


func update_route_visuals():

	for index in route_buttons.keys():

		var button: Button = (
			route_buttons[index]
		)


		if index == 0:

			button.text = "SOURCE ✓"


		elif index == 8:

			if index in route_visited:
				button.text = "ACCESS ✓"

			else:
				button.text = "ACCESS"


		elif index in route_blocked:

			button.text = "×"


		elif index in route_visited:

			button.text = "●"


		else:

			button.text = "○"


	if route_status_label != null:

		route_status_label.text = (
			"Conexões estabelecidas: "
			+ str(
				route_visited.size() - 1
			)
		)


# =========================================================
# 4 — CONTAGEM DE TECLAS
# =========================================================

func start_key_count_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_CONTAGEM_TECLAS
	)


	key_target = rng.randi_range(
		18,
		30
	)

	key_count = 0


	add_title(
		"INJEÇÃO DE PULSOS",
		"Pressione ESPAÇO exatamente "
		+ str(key_target)
		+ " vezes.\n"
		+ "Se ultrapassar o limite, "
		+ "a tentativa reinicia."
	)


	key_count_label = Label.new()

	key_count_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	key_count_label.custom_minimum_size = Vector2(
		0,
		100
	)

	key_count_label.add_theme_font_size_override(
		"font_size",
		38
	)

	content.add_child(
		key_count_label
	)


	create_feedback_label(
		"INJETE OS PULSOS."
	)


	var validate_button = Button.new()

	validate_button.text = (
		"VALIDAR CONTAGEM"
	)

	validate_button.custom_minimum_size = Vector2(
		0,
		55
	)

	validate_button.pressed.connect(
		validate_key_count
	)

	content.add_child(
		validate_button
	)


	add_cancel_button()


	update_key_count_label()


func handle_key_count_input(
	event
):

	if not (
		event is InputEventKey
	):
		return


	if (
		not event.pressed
		or event.echo
	):
		return


	if event.keycode != KEY_SPACE:
		return


	get_viewport().set_input_as_handled()


	key_count += 1


	update_key_count_label()


	if key_count > key_target:

		key_count = 0

		update_key_count_label()


		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Limite ultrapassado. "
			+ "Contagem reiniciada."
		)


	elif key_count == key_target:

		set_feedback_success(
			"LIMITE EXATO ATINGIDO.\n"
			+ "Valide a contagem."
		)


func validate_key_count():

	if key_count == key_target:

		show_success()

	else:

		set_feedback_error(
			"CONTAGEM INCORRETA.\n"
			+ "Continue até "
			+ str(key_target)
			+ "."
		)


func update_key_count_label():

	if key_count_label == null:
		return


	key_count_label.text = (
		str(key_count)
		+ " / "
		+ str(key_target)
	)


# =========================================================
# 5 — SOBRECARGA
# =========================================================

func start_overload_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_SOBRECARGA
	)


	overload_active = true

	overload_holding = false

	overload_value = 20.0

	overload_stable_time = 0.0


	add_title(
		"REGULAÇÃO DE CARGA",
		"Mantenha ESPAÇO pressionado para "
		+ "aumentar a carga.\n"
		+ "Mantenha o sinal entre "
		+ str(int(overload_safe_min))
		+ "% e "
		+ str(int(overload_safe_max))
		+ "% durante "
		+ str(int(overload_required_time))
		+ " segundos."
	)


	overload_bar = ProgressBar.new()

	overload_bar.min_value = 0

	overload_bar.max_value = 100

	overload_bar.value = (
		overload_value
	)

	overload_bar.show_percentage = true

	overload_bar.custom_minimum_size = Vector2(
		0,
		60
	)

	content.add_child(
		overload_bar
	)


	var zone_label = Label.new()

	zone_label.text = (
		"ZONA SEGURA: "
		+ str(int(overload_safe_min))
		+ "% — "
		+ str(int(overload_safe_max))
		+ "%"
	)

	zone_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	zone_label.add_theme_font_size_override(
		"font_size",
		20
	)

	content.add_child(
		zone_label
	)


	overload_time_label = Label.new()

	overload_time_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	overload_time_label.add_theme_font_size_override(
		"font_size",
		22
	)

	content.add_child(
		overload_time_label
	)


	create_feedback_label(
		"SEGURE ESPAÇO PARA AUMENTAR A CARGA."
	)


	add_cancel_button()


	update_overload_labels()


func handle_overload_input(
	event
):

	if not (
		event is InputEventKey
	):
		return


	if event.keycode != KEY_SPACE:
		return


	get_viewport().set_input_as_handled()


	if event.echo:
		return


	overload_holding = (
		event.pressed
	)


func update_overload(
	delta: float
):

	if overload_holding:

		overload_value += (
			30.0 * delta
		)

	else:

		overload_value -= (
			18.0 * delta
		)


	overload_value = clamp(
		overload_value,
		0.0,
		100.0
	)


	# -----------------------------------------------------
	# PASSOU DO LIMITE
	# -----------------------------------------------------

	if overload_value > overload_safe_max:

		overload_value = 20.0

		overload_stable_time = 0.0

		overload_holding = false


		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Sobrecarga detectada. "
			+ "Carga reiniciada."
		)


	# -----------------------------------------------------
	# ZONA SEGURA
	# -----------------------------------------------------

	elif (
		overload_value
		>= overload_safe_min
		and overload_value
		<= overload_safe_max
	):

		overload_stable_time += delta


		set_feedback_success(
			"SINAL ESTÁVEL..."
		)


		if (
			overload_stable_time
			>= overload_required_time
		):

			overload_active = false

			show_success()

			return


	# -----------------------------------------------------
	# ABAIXO
	# -----------------------------------------------------

	else:

		overload_stable_time = 0.0


	update_overload_labels()


func update_overload_labels():

	if overload_bar != null:

		overload_bar.value = (
			overload_value
		)


	if overload_time_label != null:

		overload_time_label.text = (
			"Estabilidade: "
			+ "%.1f" % overload_stable_time
			+ " / "
			+ "%.1f" % overload_required_time
			+ " s"
		)


# =========================================================
# 6 — MATRIZ
# =========================================================

func start_matrix_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_MATRIZ
	)


	matrix_player_index = 0


	matrix_target_sequence = [
		"A",
		"B",
		"C"
	]


	matrix_target_sequence.shuffle()


	add_title(
		"DECODIFICAÇÃO MATRICIAL",
		"Selecione os símbolos na ordem solicitada."
	)


	var objective = Label.new()

	objective.text = (
		"OBJETIVO: "
		+ matrix_target_sequence[0]
		+ " → "
		+ matrix_target_sequence[1]
		+ " → "
		+ matrix_target_sequence[2]
	)

	objective.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	objective.add_theme_font_size_override(
		"font_size",
		24
	)

	content.add_child(
		objective
	)


	var grid = GridContainer.new()

	grid.columns = 3

	grid.add_theme_constant_override(
		"h_separation",
		12
	)

	grid.add_theme_constant_override(
		"v_separation",
		12
	)

	content.add_child(
		grid
	)


	var symbols := [
		"A",
		"C",
		"B",
		"B",
		"A",
		"C",
		"C",
		"B",
		"A"
	]


	symbols.shuffle()


	for symbol in symbols:

		var button = Button.new()

		button.text = symbol

		button.custom_minimum_size = Vector2(
			180,
			70
		)

		button.add_theme_font_size_override(
			"font_size",
			28
		)

		button.pressed.connect(
			on_matrix_button_pressed.bind(
				symbol
			)
		)

		grid.add_child(
			button
		)


	matrix_progress_label = Label.new()

	matrix_progress_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	matrix_progress_label.add_theme_font_size_override(
		"font_size",
		22
	)

	content.add_child(
		matrix_progress_label
	)


	create_feedback_label()


	add_cancel_button()


	update_matrix_progress()


func on_matrix_button_pressed(
	symbol: String
):

	var expected = (
		matrix_target_sequence[
			matrix_player_index
		]
	)


	if symbol == expected:

		matrix_player_index += 1


		update_matrix_progress()


		if (
			matrix_player_index
			>= matrix_target_sequence.size()
		):

			show_success()


	else:

		matrix_player_index = 0


		update_matrix_progress()


		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Símbolo incorreto. "
			+ "Sequência reiniciada."
		)


func update_matrix_progress():

	if matrix_progress_label == null:
		return


	var text = ""


	for index in range(
		matrix_target_sequence.size()
	):

		if index < matrix_player_index:
			text += "✓"

		else:
			text += "○"


		if (
			index
			< matrix_target_sequence.size() - 1
		):
			text += "     "


	matrix_progress_label.text = text


# =========================================================
# 7 — MEMÓRIA DE CORES
# =========================================================

func start_memory_hack():

	prepare_minigame_screen()


	current_hack = (
		HACK_MEMORIA_CORES
	)


	memory_sequence.clear()

	memory_input_index = 0

	memory_accepting_input = false

	memory_buttons.clear()


	var colors := [
		"RED",
		"GREEN",
		"BLUE"
	]


	for _i in range(
		3
	):

		memory_sequence.append(
			colors[
				rng.randi_range(
					0,
					colors.size() - 1
				)
			]
		)


	add_title(
		"SEQUÊNCIA CROMÁTICA",
		"Memorize as três cores e reproduza "
		+ "a sequência na ordem correta."
	)


	memory_flash_rect = ColorRect.new()

	memory_flash_rect.custom_minimum_size = Vector2(
		0,
		120
	)

	memory_flash_rect.color = Color(
		0.08,
		0.08,
		0.08,
		1.0
	)

	content.add_child(
		memory_flash_rect
	)


	memory_flash_label = Label.new()

	memory_flash_label.text = (
		"PREPARE-SE"
	)

	memory_flash_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	memory_flash_label.add_theme_font_size_override(
		"font_size",
		22
	)

	content.add_child(
		memory_flash_label
	)


	var buttons_container = HBoxContainer.new()

	buttons_container.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons_container.add_theme_constant_override(
		"separation",
		15
	)

	content.add_child(
		buttons_container
	)


	for color_name in colors:

		var button = Button.new()

		button.text = (
			memory_color_display_name(
				color_name
			)
		)

		button.custom_minimum_size = Vector2(
			180,
			60
		)

		button.disabled = true

		button.pressed.connect(
			on_memory_color_pressed.bind(
				color_name
			)
		)


		memory_buttons.append(
			button
		)


		buttons_container.add_child(
			button
		)


	create_feedback_label(
		"OBSERVE A SEQUÊNCIA..."
	)


	add_cancel_button()


	call_deferred(
		"play_memory_sequence",
		hack_session_id
	)


func play_memory_sequence(
	session_id: int
):

	memory_accepting_input = false


	set_memory_buttons_enabled(
		false
	)


	# A sequência só passa depois de fechado o tutorial.
	while TutorialCard.is_open(get_tree()):
		await get_tree().process_frame

	await get_tree().create_timer(
		0.6,
		true
	).timeout


	if not memory_session_valid(
		session_id
	):
		return


	for color_name in memory_sequence:

		if not memory_session_valid(
			session_id
		):
			return


		memory_flash_rect.color = (
			memory_color_value(
				color_name
			)
		)


		memory_flash_label.text = (
			memory_color_display_name(
				color_name
			)
		)


		await get_tree().create_timer(
			0.33,
			true
		).timeout


		if not memory_session_valid(
			session_id
		):
			return


		memory_flash_rect.color = Color(
			0.08,
			0.08,
			0.08,
			1.0
		)


		memory_flash_label.text = ""


		await get_tree().create_timer(
			0.10,
			true
		).timeout


	if not memory_session_valid(
		session_id
	):
		return


	memory_flash_label.text = (
		"REPRODUZA A SEQUÊNCIA"
	)


	memory_accepting_input = true


	set_memory_buttons_enabled(
		true
	)


	set_feedback_normal(
		"ESCOLHA AS 3 CORES."
	)


func on_memory_color_pressed(
	color_name: String
):

	if not memory_accepting_input:
		return


	var expected = (
		memory_sequence[
			memory_input_index
		]
	)


	if color_name == expected:

		memory_input_index += 1


		if (
			memory_input_index
			>= memory_sequence.size()
		):

			memory_accepting_input = false

			set_memory_buttons_enabled(
				false
			)

			show_success()


	else:

		memory_input_index = 0

		memory_accepting_input = false


		set_memory_buttons_enabled(
			false
		)


		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Sequência incorreta. "
			+ "Repetindo sinal..."
		)


		call_deferred(
			"replay_memory_sequence",
			hack_session_id
		)


func replay_memory_sequence(
	session_id: int
):

	await get_tree().create_timer(
		0.7,
		true
	).timeout


	if not memory_session_valid(
		session_id
	):
		return


	await play_memory_sequence(
		session_id
	)


func memory_session_valid(
	session_id: int
) -> bool:

	return (
		hack_active
		and current_hack
		== HACK_MEMORIA_CORES
		and session_id
		== hack_session_id
	)


func set_memory_buttons_enabled(
	enabled: bool
):

	for button in memory_buttons:

		if (
			button != null
			and is_instance_valid(
				button
			)
		):

			button.disabled = (
				not enabled
			)


func memory_color_value(
	color_name: String
) -> Color:

	match color_name:

		"RED":
			return Color(
				0.9,
				0.12,
				0.12,
				1.0
			)

		"GREEN":
			return Color(
				0.12,
				0.85,
				0.25,
				1.0
			)

		"BLUE":
			return Color(
				0.12,
				0.35,
				1.0,
				1.0
			)


	return Color.WHITE


func memory_color_display_name(
	color_name: String
) -> String:

	match color_name:

		"RED":
			return "VERMELHO"

		"GREEN":
			return "VERDE"

		"BLUE":
			return "AZUL"


	return color_name


# =========================================================
# 8 — MULTIPLICAÇÃO TEXTUAL
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


	for _i in range(
		amount
	):

		correct_answer += letter


	create_text_minigame(
		"REPLICAÇÃO DE DADOS",
		"Repita o carácter pela quantidade indicada.",
		letter
		+ " × "
		+ str(amount)
		+ " = ?"
	)


# =========================================================
# 9 — CONTAGEM DE ZEROS
# =========================================================

func start_zero_count_hack():

	var amount = rng.randi_range(
		5,
		15
	)


	var zero_string = ""


	for _i in range(
		amount
	):

		zero_string += "0"


	correct_answer = str(
		amount
	)


	create_text_minigame(
		"VERIFICAÇÃO BINÁRIA",
		"Conte a quantidade de zeros apresentada.",
		zero_string
		+ " = ?"
	)


# =========================================================
# MINIGAMES DE TEXTO
# =========================================================

func create_text_minigame(
	title_text: String,
	instruction_text: String,
	question_text: String
):

	prepare_minigame_screen()


	add_title(
		title_text,
		instruction_text
	)


	var question = Label.new()

	question.text = (
		question_text
	)

	question.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	question.custom_minimum_size = Vector2(
		0,
		90
	)

	question.add_theme_font_size_override(
		"font_size",
		34
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

	confirm_button.pressed.connect(
		check_answer
	)

	content.add_child(
		confirm_button
	)


	create_feedback_label()


	add_cancel_button()


	answer_input.grab_focus()


func on_answer_submitted(
	_text: String
):

	check_answer()


func check_answer():

	if answer_input == null:
		return


	var player_answer = (
		answer_input.text.strip_edges()
	)


	if player_answer == correct_answer:

		show_success()


	else:

		set_feedback_error(
			"ACCESS DENIED\n"
			+ "Resposta incorreta. "
			+ "Tente novamente."
		)


		answer_input.select_all()

		answer_input.grab_focus()


# =========================================================
# SUCESSO
# =========================================================

func show_success():

	if finishing_hack:
		return


	finishing_hack = true


	direction_accepting_input = false

	overload_active = false

	overload_holding = false

	memory_accepting_input = false


	set_memory_buttons_enabled(
		false
	)


	set_feedback_success(
		"ACCESS GRANTED"
	)


	if answer_input != null:

		answer_input.editable = false


	if confirm_button != null:

		confirm_button.disabled = true


	await get_tree().create_timer(
		0.8,
		true
	).timeout


	if not hack_active:
		return


	finish_success()


# =========================================================
# FINALIZAR
# =========================================================

func finish_success():

	var saved_target = (
		target_node
	)

	_register_behavior("hack_success")


	hack_session_id += 1


	destroy_ui()


	hack_active = false

	finishing_hack = false

	current_hack = -1

	correct_answer = ""

	target_node = null


	reset_all_minigame_states()


	get_tree().paused = false


	hack_succeeded.emit(
		saved_target
	)


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

	if finishing_hack:
		return


	var saved_target = (
		target_node
	)


	hack_session_id += 1


	destroy_ui()


	hack_active = false

	finishing_hack = false

	current_hack = -1

	correct_answer = ""

	target_node = null


	reset_all_minigame_states()


	get_tree().paused = false


	hack_cancelled.emit()


	if (
		saved_target != null
		and is_instance_valid(
			saved_target
		)
		and saved_target.has_method(
			"on_hack_cancelled"
		)
	):

		saved_target.call(
			"on_hack_cancelled"
		)


	print("HACK CANCELLED")


# =========================================================
# UI HELPERS
# =========================================================

func prepare_minigame_screen():

	clear_content()


	feedback_label = null

	answer_input = null

	confirm_button = null


func add_title(
	title_text: String,
	instruction_text: String = ""
):

	var title = Label.new()

	title.text = (
		title_text
	)

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


	if instruction_text != "":

		var instruction = Label.new()

		instruction.text = (
			instruction_text
		)

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


func create_feedback_label(
	initial_text: String = ""
):

	feedback_label = Label.new()

	feedback_label.text = (
		initial_text
	)

	feedback_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	feedback_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	feedback_label.add_theme_font_size_override(
		"font_size",
		19
	)

	content.add_child(
		feedback_label
		)


func set_feedback_normal(
	text: String
):

	if feedback_label == null:
		return


	feedback_label.text = text


	feedback_label.remove_theme_color_override(
		"font_color"
	)


func set_feedback_error(
	text: String
):

	if feedback_label == null:
		return

	# Todas as chamadas são tentativas erradas num minigame.
	_register_behavior("hack_failed")


	feedback_label.text = text


	feedback_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.25
		)
	)


func set_feedback_success(
	text: String
):

	if feedback_label == null:
		return


	feedback_label.text = text


	feedback_label.add_theme_color_override(
		"font_color",
		Color(
			0.25,
			1.0,
			0.45
		)
	)


func add_cancel_button(
	text: String = "CANCELAR"
):

	var button = Button.new()

	button.text = text

	button.custom_minimum_size = Vector2(
		0,
		45
	)

	button.pressed.connect(
		cancel_hack
	)

	content.add_child(
		button
	)


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


	for _i in range(
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
# RESET
# =========================================================

func reset_all_minigame_states():

	direction_sequence.clear()

	direction_player_index = 0

	direction_accepting_input = false

	direction_progress_label = null


	route_blocked.clear()

	route_visited.clear()

	route_buttons.clear()

	route_status_label = null


	key_target = 0

	key_count = 0

	key_count_label = null


	overload_active = false

	overload_holding = false

	overload_value = 20.0

	overload_stable_time = 0.0

	overload_bar = null

	overload_time_label = null


	matrix_target_sequence.clear()

	matrix_player_index = 0

	matrix_progress_label = null


	memory_sequence.clear()

	memory_input_index = 0

	memory_accepting_input = false

	memory_flash_rect = null

	memory_flash_label = null

	memory_buttons.clear()


# =========================================================
# LIMPAR CONTEÚDO
# =========================================================

func clear_content():

	if content == null:
		return


	for child in content.get_children():

		child.hide()

		child.set_process(
			false
		)

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


# Atlas 2.0: comportamento observado (contadores no save + contexto do Atlas).
func _register_behavior(event: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("register_behavior"):
		main.register_behavior(event)
