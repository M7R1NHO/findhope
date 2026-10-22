extends Control

signal completed(answers: Dictionary)

const QUESTIONS := [
	{"key": "volunteer_reason", "text": "Qual é a principal razão para se voluntariar?", "options": ["Salvar a Terra", "Proteger alguém", "Explorar o desconhecido", "Cumprir o dever", "Mudar de vida"]},
	{"key": "worked_with_android", "text": "Já trabalhou diretamente com um androide PYSSOA?", "options": ["Sim", "Não"]},
	{"key": "comfortable_with_androids", "text": "Sente-se confortável em trabalhar ao lado de androides?", "options": ["Sim", "Não"]},
	{"key": "android_emergency_decision", "text": "Um androide deveria agir sem autorização humana numa emergência?", "options": ["Sim", "Não"]},
	{"key": "protocol_or_life", "text": "Numa emergência, o que deve prevalecer?", "options": ["Protocolo", "Vida humana"]}
]

var answers: Dictionary = {}
var current_question := 0
var name_input: LineEdit
var age_input: SpinBox
var gender_select: OptionButton
var children_select: OptionButton
var question_label: Label
var options_box: VBoxContainer
var error_label: Label
var next_button: Button
var form_root: Control


func play() -> Dictionary:
	_build_ui()
	show()
	var result: Dictionary = await completed
	return result


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 18
	scroll.offset_right = -24
	scroll.offset_bottom = -18
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	form_root = VBoxContainer.new()
	form_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_root.add_theme_constant_override("separation", 5)
	scroll.add_child(form_root)

	var title := Label.new()
	title.text = "PROJECT FIND HOPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	form_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "FORMULÁRIO DE CANDIDATURA  |  REGISTO DE EMERGÊNCIA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.68, 0.76))
	form_root.add_child(subtitle)

	form_root.add_child(_make_label("Nome"))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Introduza o seu nome"
	name_input.custom_minimum_size.y = 27
	form_root.add_child(name_input)

	form_root.add_child(_make_label("Idade"))
	age_input = SpinBox.new()
	age_input.min_value = 20
	age_input.max_value = 40
	age_input.value = 25
	age_input.custom_minimum_size.y = 27
	form_root.add_child(age_input)

	form_root.add_child(_make_label("Género"))
	gender_select = OptionButton.new()
	gender_select.add_item("Selecionar...")
	gender_select.add_item("Homem")
	gender_select.add_item("Mulher")
	gender_select.custom_minimum_size.y = 27
	form_root.add_child(gender_select)

	form_root.add_child(_make_label("Tem filhos?"))
	children_select = OptionButton.new()
	children_select.add_item("Selecionar...")
	children_select.add_item("Sim")
	children_select.add_item("Não")
	children_select.custom_minimum_size.y = 27
	form_root.add_child(children_select)

	question_label = _make_label("")
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form_root.add_child(question_label)

	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 0)
	form_root.add_child(options_box)

	error_label = _make_label("")
	error_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.32))
	form_root.add_child(error_label)

	next_button = Button.new()
	next_button.text = "CONTINUAR"
	next_button.custom_minimum_size.y = 32
	next_button.pressed.connect(_submit_current)
	form_root.add_child(next_button)

	_render_question()


func _make_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.97))
	return label


func _render_question() -> void:
	for child in options_box.get_children():
		child.queue_free()
	if current_question >= QUESTIONS.size():
		return

	var question: Dictionary = QUESTIONS[current_question]
	question_label.text = "Pergunta %d/%d — %s" % [current_question + 1, QUESTIONS.size(), question["text"]]
	var group := ButtonGroup.new()
	for option in question["options"]:
		var choice := CheckButton.new()
		choice.text = option
		choice.button_group = group
		choice.custom_minimum_size.y = 25
		choice.add_theme_color_override("font_color", Color.WHITE)
		options_box.add_child(choice)
	error_label.text = ""


func _submit_current() -> void:
	error_label.text = ""
	if not answers.has("name"):
		var candidate_name := name_input.text.strip_edges()
		if candidate_name.is_empty():
			error_label.text = "Introduza o seu nome para continuar."
			return
		if gender_select.selected == 0 or children_select.selected == 0:
			error_label.text = "Preencha o género e indique se tem filhos."
			return
		answers["name"] = candidate_name
		answers["age"] = int(age_input.value)
		answers["gender"] = gender_select.get_item_text(gender_select.selected)
		answers["has_children"] = children_select.get_item_text(children_select.selected)

	var selected_answer := ""
	for child in options_box.get_children():
		if child is CheckButton and child.button_pressed:
			selected_answer = child.text
			break
	if selected_answer.is_empty():
		error_label.text = "Selecione uma resposta."
		return

	var question: Dictionary = QUESTIONS[current_question]
	answers[str(question["key"])] = selected_answer
	current_question += 1

	if current_question < QUESTIONS.size():
		_render_question()
	else:
		_save_answers()
		question_label.text = "Candidatura registada."
		options_box.hide()
		next_button.text = "INICIAR"
		next_button.pressed.disconnect(_submit_current)
		next_button.pressed.connect(_finish_form)
		error_label.text = "A carregar os dados para a memória de bordo."


func _save_answers() -> void:
	if not Engine.has_singleton("SaveManager"):
		# SaveManager é normalmente um autoload Godot, acessível diretamente.
		pass
	for key in answers.keys():
		SaveManager.set_run_value("story", "form_" + str(key), answers[key])
	SaveManager.set_run_value("story", "application_form_completed", true)


func _finish_form() -> void:
	completed.emit(answers.duplicate(true))
	queue_free()
