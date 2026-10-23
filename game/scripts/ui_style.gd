extends RefCounted

# Estilo visual comum dos menus e terminais.
#
# Os ecrãs do jogo são construídos por código. Em vez de repetir cores e
# caixas em cada script, cada ecrã chama UIStyle.apply() na sua raiz e
# recebe o mesmo tema: botões opacos com contorno, destaque ciano ao passar
# o rato ou com foco do teclado, campos de texto escuros e separadores finos.
#
# Os tamanhos de letra definidos em cada script continuam a valer, porque
# os overrides de um nó têm prioridade sobre o tema.

const ACCENT := Color(0.31, 0.82, 0.77)
const ACCENT_DIM := Color(0.31, 0.82, 0.77, 0.35)
const TEXT := Color(0.9, 0.93, 0.95)
const TEXT_MUTED := Color(0.62, 0.68, 0.74)
const PANEL_BG := Color(0.035, 0.045, 0.06, 0.98)
const PANEL_BORDER := Color(0.16, 0.22, 0.27)
const BUTTON_BG := Color(0.075, 0.09, 0.11)
const BUTTON_BG_HOVER := Color(0.09, 0.14, 0.16)
const BUTTON_BG_PRESSED := Color(0.06, 0.2, 0.2)
const DANGER := Color(0.9, 0.36, 0.36)

static var _theme: Theme = null


static func _box(bg: Color, border: Color, border_width: int = 1, radius: int = 4, margin_h: float = 16.0, margin_v: float = 8.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func get_theme() -> Theme:
	if _theme != null:
		return _theme

	var theme := Theme.new()

	# Botões (as listas de opções do formulário usam o mesmo aspeto)
	for type_name in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, _box(BUTTON_BG, PANEL_BORDER))
		theme.set_stylebox("hover", type_name, _box(BUTTON_BG_HOVER, ACCENT))
		theme.set_stylebox("pressed", type_name, _box(BUTTON_BG_PRESSED, ACCENT, 2))
		theme.set_stylebox("hover_pressed", type_name, _box(BUTTON_BG_PRESSED, ACCENT, 2))
		theme.set_stylebox("focus", type_name, _box(Color(0, 0, 0, 0), ACCENT, 2))
		theme.set_stylebox("disabled", type_name, _box(Color(0.05, 0.055, 0.065), Color(0.12, 0.14, 0.16)))
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, ACCENT)
		theme.set_color("font_focus_color", type_name, ACCENT)
		theme.set_color("font_pressed_color", type_name, Color.WHITE)
		theme.set_color("font_hover_pressed_color", type_name, Color.WHITE)
		theme.set_color("font_disabled_color", type_name, Color(0.4, 0.44, 0.48))

	# Campos de texto
	theme.set_stylebox("normal", "LineEdit", _box(Color(0.02, 0.03, 0.04), PANEL_BORDER, 1, 4, 12.0, 8.0))
	theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), ACCENT, 2, 4, 12.0, 8.0))
	theme.set_stylebox("read_only", "LineEdit", _box(Color(0.03, 0.035, 0.045), PANEL_BORDER, 1, 4, 12.0, 8.0))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", ACCENT_DIM)

	# Texto
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)

	# Separadores: uma linha fina na cor de destaque.
	var line := StyleBoxLine.new()
	line.color = ACCENT_DIM
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 8)

	# Caixa dos terminais (UIStyle.frame)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 1, 8, 36.0, 28.0))

	_theme = theme
	return theme


# Aplica o tema a uma raiz de interface e a todos os seus filhos.
static func apply(root: Control) -> void:
	if root != null:
		root.theme = get_theme()


# Põe o conteúdo de um terminal dentro de uma caixa com contorno, para
# o texto e os botões não se misturarem com o que está por trás.
static func frame(container: Control) -> PanelContainer:
	var parent := container.get_parent()
	var panel := PanelContainer.new()
	panel.name = container.name + "Frame"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if parent != null:
		var index := container.get_index()
		parent.remove_child(container)
		parent.add_child(panel)
		parent.move_child(panel, index)
	panel.add_child(container)
	return panel


static func title(label: Label) -> void:
	if label != null:
		label.add_theme_color_override("font_color", ACCENT)


static func subtitle(label: Label) -> void:
	if label != null:
		label.add_theme_color_override("font_color", TEXT_MUTED)
