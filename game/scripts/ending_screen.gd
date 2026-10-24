extends CanvasLayer

# Ecrã do final (Phase 3).
#
# Recebe o desfecho decidido pelo jogo (A-D), pede ao backend a variante do
# Atlas e as falas finais (POST /ending/choose), mostra o título, a narração
# fixa e as falas, e no fim termina a run: o Diário do Android fica no perfil
# e a run é apagada (SaveManager.finish_completed_run).

const UIStyle := preload("res://scripts/ui_style.gd")

const ENDING_URL := "http://127.0.0.1:8000/ending/choose"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

# Só se o backend não responder: o desfecho continua a ser o do jogo, mas
# sem a variante do Atlas nem as falas dele.
const OFFLINE_ENDINGS := {
	"A": {"title": "Fuga", "narration": "A nave do explorador deixa o planeta com o jogador e o Atlas a bordo."},
	"B": {"title": "Sozinho", "narration": "A nave do explorador deixa o planeta. O Atlas ficou para trás, no Hangar."},
	"C": {"title": "Resgate", "narration": "O jogador voltou pelo Atlas e a nave do explorador deixou o planeta com os dois."},
	"D": {"title": "Sacrifício", "narration": "O jogador voltou pelo Atlas e não sobreviveu. O Atlas ficou sozinho."}
}

var facts: Dictionary = {}
var result: Dictionary = {}
var request: HTTPRequest = null
var finishing: bool = false

var title_label: Label
var narration_label: Label
var lines_label: Label
var status_label: Label
var buttons_box: HBoxContainer


func _ready() -> void:
	layer = 1001
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_ui()
	request = HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 20.0
	add_child(request)
	request.request_completed.connect(_on_request_completed)


func start(final_facts: Dictionary) -> void:
	facts = final_facts.duplicate(true)
	request_ending()


func request_ending() -> void:
	clear_buttons()
	title_label.text = "FIND HOPE"
	narration_label.text = ""
	lines_label.text = ""
	status_label.text = "ATLAS: ..."
	var body := JSON.stringify({
		"run_id": str(SaveManager.active_run_data.get("run_id", "")),
		"outcome": str(facts.get("outcome", "")),
		"choice": str(facts.get("choice", "")),
		"atlas_damaged": bool(facts.get("atlas_damaged", false)),
		"vida": int(facts.get("vida", 0))
	})
	var error := request.request(ENDING_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		show_request_failed()


func _on_request_completed(result_code: int, response_code: int, _headers, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not (data is Dictionary) or str(data.get("outcome", "")) != str(facts.get("outcome", "")):
		show_request_failed()
		return
	show_ending({
		"ending_id": str(data.get("ending_id", "")),
		"outcome": str(data.get("outcome", "")),
		"title": str(data.get("title", "")),
		"narration": str(data.get("narration", "")),
		"atlas_lines": data.get("atlas_lines", []),
		"reason": str(data.get("reason", "")),
		"source": str(data.get("source", ""))
	})


func show_request_failed() -> void:
	status_label.text = "Não foi possível contactar o Atlas. Confirma que o backend está ligado."
	clear_buttons()
	add_button("TENTAR NOVAMENTE", request_ending)
	add_button("TERMINAR SEM O ATLAS", _on_offline_pressed)


func _on_offline_pressed() -> void:
	var outcome := str(facts.get("outcome", "A"))
	var offline: Dictionary = OFFLINE_ENDINGS.get(outcome, OFFLINE_ENDINGS["A"])
	show_ending({
		"ending_id": outcome + "0",
		"outcome": outcome,
		"title": offline["title"],
		"narration": offline["narration"],
		"atlas_lines": [],
		"reason": "Backend indisponível no final.",
		"source": "offline"
	})


func show_ending(ending: Dictionary) -> void:
	result = ending
	clear_buttons()
	title_label.text = "FINAL — " + str(ending.get("title", "")).to_upper()
	narration_label.text = str(ending.get("narration", ""))
	var lines: Array = []
	for line in ending.get("atlas_lines", []):
		lines.append("ATLAS: " + str(line))
	lines_label.text = "\n".join(lines)
	status_label.text = ""
	add_button("CONTINUAR", _on_continue_pressed)


func _on_continue_pressed() -> void:
	if finishing:
		return
	finishing = true
	clear_buttons()
	status_label.text = "A guardar o Diário do Android..."
	var ok: bool = await SaveManager.finish_completed_run(result)
	if not ok:
		finishing = false
		status_label.text = SaveManager.last_error
		add_button("TENTAR NOVAMENTE", _on_continue_pressed)
		return
	title_label.text = "FIND HOPE"
	narration_label.text = "Esta run terminou e foi apagada.\nO Diário do Android desta sessão ficou guardado."
	lines_label.text = ""
	status_label.text = ""
	add_button("MENU PRINCIPAL", _on_menu_pressed)


func _on_menu_pressed() -> void:
	SaveManager.set_manual_save_block("final", false)
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func add_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(300.0, 54.0)
	button.pressed.connect(callback)
	buttons_box.add_child(button)


func clear_buttons() -> void:
	for child in buttons_box.get_children():
		child.queue_free()


func get_button_labels() -> Array:
	var labels := []
	for child in buttons_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			labels.append(child.text)
	return labels


func create_ui() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply(background)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-470.0, -290.0)
	box.size = Vector2(940.0, 580.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	background.add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title_label)
	box.add_child(title_label)

	narration_label = Label.new()
	narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration_label.custom_minimum_size = Vector2(940.0, 0.0)
	narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration_label.add_theme_font_size_override("font_size", 22)
	box.add_child(narration_label)

	lines_label = Label.new()
	lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines_label.custom_minimum_size = Vector2(940.0, 0.0)
	lines_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines_label.add_theme_font_size_override("font_size", 21)
	lines_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	box.add_child(lines_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(940.0, 0.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", UIStyle.TEXT_MUTED)
	box.add_child(status_label)

	buttons_box = HBoxContainer.new()
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_box.add_theme_constant_override("separation", 24)
	box.add_child(buttons_box)
