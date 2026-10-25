extends Node

# Interface do chat do Atlas (renovação do chat, 24/10/2026).
#
# O main.gd continua a tratar da comunicação com o backend e guarda o
# registo das mensagens (visible_messages). Este nó só trata de mostrar:
# - um botão circular com o ícone do androide, que abre e fecha o chat;
# - a caixa do chat com o tema comum (UIStyle);
# - as falas do Atlas a aparecerem letra a letra, da esquerda para a direita;
# - um contador de mensagens novas no botão quando o chat está fechado.

const UIStyle = preload("res://scripts/ui_style.gd")

const BUTTON_SIZE := 64.0
const MARGIN := 20.0
const PANEL_SIZE := Vector2(430, 300)

# Letras por segundo da animação das falas do Atlas.
const TYPE_SPEED := 45.0
const MAX_MESSAGES := 30

# Quem fala é o Atlas: estas falas são animadas letra a letra.
const ANIMATED_SPEAKERS := ["ATLAS", "ANDROID"]

signal opened_changed(is_open: bool)

var panel: Panel
var history: RichTextLabel
var input: LineEdit
var toggle_button: Button
var title_label: Label

var is_open: bool = true
var unread: int = 0

# Mensagens já mostradas: [speaker, text]
var shown: Array = []
# Mensagens à espera de serem escritas, pela ordem de chegada.
var queue: Array = []
var typing: bool = false
var typed_chars: float = 0.0
var typing_base: int = 0
var typing_total: int = 0


# Desenha o ícone do androide (cabeça com antena e dois olhos) dentro de um
# círculo. Não há imagem do Atlas no projeto, por isso é desenhado por código.
class AndroidButton extends Button:
	var unread: int = 0
	var pulse: float = 0.0

	func _process(delta: float) -> void:
		if unread > 0:
			pulse = fmod(pulse + delta * 2.5, TAU)
			queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius: float = min(size.x, size.y) / 2.0 - 2.0
		var hovered := is_hovered()
		var accent: Color = UIStyle.ACCENT

		var ring_width := 2.0
		if unread > 0:
			ring_width = 2.0 + 1.5 * (0.5 + 0.5 * sin(pulse))
		draw_circle(center, radius, UIStyle.BUTTON_BG_HOVER if hovered else UIStyle.BUTTON_BG)
		draw_arc(center, radius, 0.0, TAU, 48, accent if (hovered or unread > 0) else UIStyle.PANEL_BORDER.lightened(0.4), ring_width, true)

		# Cabeça
		var head := Rect2(center + Vector2(-13, -9), Vector2(26, 20))
		draw_rect(head, accent)
		draw_rect(Rect2(head.position + Vector2(-3, 6), Vector2(3, 8)), accent)
		draw_rect(Rect2(head.position + Vector2(26, 6), Vector2(3, 8)), accent)
		# Antena
		draw_line(center + Vector2(0, -9), center + Vector2(0, -16), accent, 2.0)
		draw_circle(center + Vector2(0, -18), 2.5, accent)
		# Olhos e boca
		var dark: Color = UIStyle.PANEL_BG
		draw_circle(center + Vector2(-6, -1), 3.0, dark)
		draw_circle(center + Vector2(6, -1), 3.0, dark)
		draw_rect(Rect2(center + Vector2(-6, 6), Vector2(12, 2)), dark)
		# Pescoço/ombros
		draw_rect(Rect2(center + Vector2(-9, 13), Vector2(18, 4)), accent.darkened(0.25))

		if unread > 0:
			var badge := center + Vector2(radius * 0.7, -radius * 0.7)
			draw_circle(badge, 10.0, UIStyle.DANGER)
			var font := get_theme_default_font()
			var text := str(unread) if unread < 10 else "9+"
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			draw_string(font, badge + Vector2(-text_size.x / 2.0, 4.5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)


func setup(ui_layer: CanvasLayer, chat_panel: Panel, chat_history: RichTextLabel, chat_input: LineEdit) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = chat_panel
	history = chat_history
	input = chat_input

	_style_panel()
	_build_header()
	_build_toggle_button(ui_layer)
	set_open(true)


func _style_panel() -> void:
	UIStyle.apply(panel)

	# Canto inferior direito, ao lado do botão.
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_right = -(MARGIN + BUTTON_SIZE + 12.0)
	panel.offset_bottom = -MARGIN
	panel.offset_left = panel.offset_right - PANEL_SIZE.x
	panel.offset_top = panel.offset_bottom - PANEL_SIZE.y
	panel.add_theme_stylebox_override("panel", UIStyle._box(UIStyle.PANEL_BG, UIStyle.PANEL_BORDER, 1, 8, 12.0, 10.0))

	# O VBox ocupa o painel com uma margem interior.
	var box := history.get_parent() as Control
	box.offset_left = 12
	box.offset_top = 10
	box.offset_right = -12
	box.offset_bottom = -12

	history.bbcode_enabled = true
	history.scroll_following = true
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history.selection_enabled = false
	history.add_theme_font_size_override("normal_font_size", 15)
	history.add_theme_font_size_override("bold_font_size", 15)
	history.add_theme_constant_override("paragraph_separation", 6)
	history.gui_input.connect(_on_history_gui_input)

	input.add_theme_font_size_override("font_size", 15)


func _build_header() -> void:
	var box := history.get_parent()
	var header := HBoxContainer.new()
	header.name = "ChatHeader"
	box.add_child(header)
	box.move_child(header, 0)

	title_label = Label.new()
	title_label.text = "ATLAS · CANAL DE COMUNICAÇÃO"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 13)
	UIStyle.title(title_label)
	header.add_child(title_label)

	var close := Button.new()
	close.name = "ChatClose"
	close.text = "×"
	close.tooltip_text = "Fechar o chat"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(28, 24)
	close.add_theme_stylebox_override("normal", UIStyle._box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 4.0, 0.0))
	close.pressed.connect(func(): set_open(false))
	header.add_child(close)

	var line := HSeparator.new()
	box.add_child(line)
	box.move_child(line, 1)


func _build_toggle_button(ui_layer: CanvasLayer) -> void:
	toggle_button = AndroidButton.new()
	toggle_button.name = "ChatToggle"
	toggle_button.tooltip_text = "Chat do Atlas (Enter)"
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.flat = true
	toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_button.offset_right = -MARGIN
	toggle_button.offset_bottom = -MARGIN
	toggle_button.offset_left = -MARGIN - BUTTON_SIZE
	toggle_button.offset_top = -MARGIN - BUTTON_SIZE
	toggle_button.pressed.connect(toggle)
	ui_layer.add_child(toggle_button)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value
	panel.visible = value
	if value:
		unread = 0
	else:
		input.release_focus()
	_refresh_button()
	opened_changed.emit(value)


func _refresh_button() -> void:
	if toggle_button is AndroidButton:
		toggle_button.unread = unread
		toggle_button.queue_redraw()


# Enter abre o chat e põe o cursor na caixa de texto.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return
	if get_tree().paused or get_viewport().gui_get_focus_owner() != null:
		return
	if not is_open:
		set_open(true)
	if input.editable:
		input.grab_focus()
	get_viewport().set_input_as_handled()


# Clicar no histórico mostra logo o resto da fala.
func _on_history_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip_typing()


# =========================================================
# MENSAGENS
# =========================================================

func push(speaker: String, text: String) -> void:
	# Uma fala do jogador aparece logo; antes disso terminam as do Atlas.
	if not speaker in ANIMATED_SPEAKERS:
		skip_typing()
		_show(speaker, text, false)
	else:
		queue.append([speaker, text])
		if not typing:
			_start_next()

	if not is_open and speaker != "VOCÊ":
		unread += 1
		_refresh_button()


func is_typing() -> bool:
	return typing or not queue.is_empty()


# Termina já a fala atual e as que estão na fila.
func skip_typing() -> void:
	while typing or not queue.is_empty():
		if typing:
			typing = false
			history.visible_characters = -1
		if not queue.is_empty():
			var next: Array = queue.pop_front()
			_show(next[0], next[1], false)


func _start_next() -> void:
	if queue.is_empty():
		return
	var next: Array = queue.pop_front()
	_show(next[0], next[1], true)


func _show(speaker: String, text: String, animate: bool) -> void:
	shown.append([speaker, text])
	while shown.size() > MAX_MESSAGES:
		shown.pop_front()

	_render()
	var total := history.get_total_character_count()
	if animate:
		typing = true
		typing_total = total
		typing_base = total - _visible_length(speaker, text)
		typed_chars = 0.0
		history.visible_characters = typing_base
	else:
		history.visible_characters = -1


func _process(delta: float) -> void:
	if not typing:
		return
	typed_chars += delta * TYPE_SPEED
	var visible := typing_base + int(typed_chars)
	if visible >= typing_total:
		typing = false
		history.visible_characters = -1
		_start_next()
	else:
		history.visible_characters = visible


func _render() -> void:
	history.clear()
	var parts: Array[String] = []
	for item in shown:
		parts.append(_format(item[0], item[1]))
	history.append_text("\n".join(parts))


func _speaker_color(speaker: String) -> Color:
	match speaker:
		"ATLAS", "ANDROID":
			return UIStyle.ACCENT
		"SISTEMA":
			return UIStyle.DANGER
		_:
			return UIStyle.TEXT_MUTED


func _format(speaker: String, text: String) -> String:
	var color := _speaker_color(speaker).to_html(false)
	return "[color=#%s][b]%s:[/b][/color] %s" % [color, speaker, _escape(text)]


# Número de letras visíveis de uma mensagem (sem as etiquetas BBCode).
func _visible_length(speaker: String, text: String) -> int:
	return (speaker + ": " + text).length()


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
