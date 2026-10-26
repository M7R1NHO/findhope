extends CanvasLayer

# Menu DIÁRIOS: um livro com os Diários do Android, um por run terminada.
#
# Abre com uma animação (o livro aparece fechado e a capa roda pela
# lombada), mostra uma run por página dupla (à esquerda os dados da run, à
# direita o texto escrito pelo Atlas) e vira a página com ANTERIOR/SEGUINTE
# ou com as setas. Sem diários, mostra o livro aberto com uma página em
# branco a explicar como se ganha o primeiro. Fecha com FECHAR ou ESC.
#
# Os diários vêm do perfil (SaveManager.get_android_diaries), que é global:
# o NOVO JOGO não os apaga e cada run aparece uma vez só.

signal closed

const UIStyle := preload("res://scripts/ui_style.gd")

const BOOK_SIZE := Vector2(940, 560)
const PAGE_MARGIN := 18.0
const COVER := Color(0.1, 0.19, 0.2)
const COVER_EDGE := Color(0.31, 0.82, 0.77, 0.8)
const PAPER := Color(0.93, 0.89, 0.8)
const PAPER_SHADE := Color(0.86, 0.81, 0.7)
const INK := Color(0.17, 0.14, 0.11)
const INK_MUTED := Color(0.42, 0.36, 0.29)
const OPEN_TIME := 0.5
const TURN_TIME := 0.18

var diaries: Array = []
var index: int = 0
var busy: bool = false

var book: Control
var left_page: Panel
var right_page: Panel
var cover: Panel
var cover_inside: Panel
var left_box: VBoxContainer
var text_label: RichTextLabel
var counter_label: Label
var previous_button: Button
var next_button: Button
var close_button: Button


static func open(parent: Node) -> CanvasLayer:
	var layer = load("res://scripts/diary_book.gd").new()
	layer.name = "DiaryBook"
	parent.add_child(layer)
	return layer


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	diaries = SaveManager.get_android_diaries()
	index = max(0, diaries.size() - 1)
	build()
	show_page()
	play_open()


func build() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	UIStyle.apply(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "DIÁRIOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	UIStyle.title(title)
	column.add_child(title)

	book = Control.new()
	book.name = "Book"
	book.custom_minimum_size = BOOK_SIZE
	book.pivot_offset = BOOK_SIZE / 2.0
	column.add_child(book)

	# Capa de trás, a fazer de moldura à volta das páginas.
	var back := Panel.new()
	back.position = Vector2(-10, -10)
	back.size = BOOK_SIZE + Vector2(20, 20)
	back.add_theme_stylebox_override("panel", box(COVER, COVER_EDGE, 2, 10))
	book.add_child(back)

	var half := Vector2(BOOK_SIZE.x / 2.0, BOOK_SIZE.y)
	left_page = make_page("LeftPage", Vector2.ZERO, half, PAPER_SHADE)
	right_page = make_page("RightPage", Vector2(half.x, 0), half, PAPER)
	right_page.pivot_offset = Vector2(0, half.y / 2.0)

	left_box = VBoxContainer.new()
	left_box.position = Vector2(PAGE_MARGIN + 6, PAGE_MARGIN)
	left_box.size = half - Vector2(PAGE_MARGIN * 2 + 6, PAGE_MARGIN * 2)
	left_box.add_theme_constant_override("separation", 8)
	left_page.add_child(left_box)

	text_label = RichTextLabel.new()
	text_label.name = "Text"
	text_label.position = Vector2(PAGE_MARGIN, PAGE_MARGIN)
	text_label.size = half - Vector2(PAGE_MARGIN * 2 + 6, PAGE_MARGIN * 2)
	text_label.bbcode_enabled = true
	text_label.scroll_active = true
	text_label.add_theme_color_override("default_color", INK)
	text_label.add_theme_font_size_override("normal_font_size", 15)
	text_label.add_theme_font_size_override("italics_font_size", 15)
	text_label.add_theme_constant_override("line_separation", 3)
	right_page.add_child(text_label)

	# Lombada.
	var spine := ColorRect.new()
	spine.color = Color(0, 0, 0, 0.28)
	spine.position = Vector2(half.x - 3, 0)
	spine.size = Vector2(6, half.y)
	book.add_child(spine)

	# Capa da frente (fechada por cima da página da direita) e o seu verso,
	# que aparece à esquerda quando a capa roda pela lombada.
	cover = make_cover("Cover", Vector2(half.x, 0), half)
	cover.pivot_offset = Vector2(0, half.y / 2.0)
	var cover_title := Label.new()
	cover_title.text = "DIÁRIO DO ANDROID\n\nUNIDADE ATLAS · PYSSOA"
	cover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_title.add_theme_font_size_override("font_size", 22)
	cover_title.add_theme_color_override("font_color", UIStyle.ACCENT)
	cover.add_child(cover_title)
	cover_inside = make_cover("CoverInside", Vector2.ZERO, half)
	cover_inside.pivot_offset = Vector2(half.x, half.y / 2.0)
	cover_inside.visible = false

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	column.add_child(bar)
	previous_button = make_button(bar, "◀ ANTERIOR", previous_page)
	counter_label = Label.new()
	counter_label.custom_minimum_size = Vector2(140, 0)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(counter_label)
	next_button = make_button(bar, "SEGUINTE ▶", next_page)
	close_button = make_button(bar, "FECHAR", close)


func box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func make_page(page_name: String, at: Vector2, page_size: Vector2, fill: Color) -> Panel:
	var page := Panel.new()
	page.name = page_name
	page.position = at
	page.size = page_size
	page.clip_contents = true
	page.add_theme_stylebox_override("panel", box(fill, Color(INK, 0.35), 1, 3))
	book.add_child(page)
	return page


func make_cover(cover_name: String, at: Vector2, cover_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.name = cover_name
	panel.position = at
	panel.size = cover_size
	panel.add_theme_stylebox_override("panel", box(COVER.lightened(0.05), COVER_EDGE, 2, 6))
	book.add_child(panel)
	return panel


func make_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 46)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func ink_label(text: String, size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	left_box.add_child(label)
	return label


# ---------------------------------------------------------------------------
# Conteúdo
# ---------------------------------------------------------------------------

func show_page() -> void:
	for child in left_box.get_children():
		child.queue_free()
	if diaries.is_empty():
		ink_label("DIÁRIO DO ANDROID", 22)
		ink_label("Ainda sem registos", 16, INK_MUTED)
		text_label.text = "[i]Esta página está em branco.[/i]\n\nCada vez que terminares o jogo, o Atlas dessa run escreve aqui o seu diário: o que viveram juntos, o que descobriram e como acabou.\n\nOs diários ficam guardados para sempre. Começar um NOVO JOGO não os apaga."
		counter_label.text = "0 / 0"
	else:
		var diary: Dictionary = diaries[index]
		var final: Dictionary = diary.get("final", {})
		var ending: Dictionary = diary.get("ending", {})
		ink_label("RUN %d" % (index + 1), 14, INK_MUTED)
		ink_label(str(diary.get("title", "Registo")).to_upper(), 24)
		var name := str(diary.get("player_profile", {}).get("name", "")).strip_edges()
		if name != "":
			ink_label("Tripulante: " + name, 16)
		var finished := str(diary.get("created_at", "")).replace("T", " ")
		if finished != "":
			ink_label("Terminada: " + finished, 14, INK_MUTED)
		var outcome := str(ending.get("outcome", final.get("outcome", "")))
		if outcome != "":
			ink_label("Final " + str(ending.get("ending_id", outcome)) + " · " + ("Atlas danificado" if bool(final.get("atlas_damaged", false)) else "Atlas inteiro"), 14, INK_MUTED)
		var stats: Dictionary = diary.get("stats", {})
		var lines: Array = []
		if int(stats.get("fights_won", 0)) > 0:
			lines.append("Combates vencidos: %d" % int(stats.get("fights_won", 0)))
		if int(stats.get("hacks_success", 0)) > 0:
			lines.append("Sistemas abertos: %d" % int(stats.get("hacks_success", 0)))
		if int(stats.get("hides_success", 0)) > 0:
			lines.append("Esconderijos: %d" % int(stats.get("hides_success", 0)))
		if not lines.is_empty():
			ink_label("\n".join(lines), 14)
		var paragraphs: Array = diary.get("paragraphs", [])
		text_label.text = "\n\n".join(paragraphs.map(func(p): return str(p).replace("[", "[lb]")))
		counter_label.text = "%d / %d" % [index + 1, diaries.size()]
	text_label.scroll_to_line(0)
	previous_button.disabled = index <= 0 or diaries.is_empty()
	next_button.disabled = index >= diaries.size() - 1 or diaries.is_empty()


func previous_page() -> void:
	turn(-1)


func next_page() -> void:
	turn(1)


# Vira a página: a página da direita fecha pela lombada, o conteúdo muda e
# volta a abrir.
func turn(step: int) -> void:
	var target := index + step
	if busy or target < 0 or target >= diaries.size():
		return
	busy = true
	var tween := create_tween()
	tween.tween_property(right_page, "scale:x", 0.0, TURN_TIME).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(left_box, "modulate:a", 0.0, TURN_TIME)
	await tween.finished
	index = target
	show_page()
	tween = create_tween()
	tween.tween_property(right_page, "scale:x", 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(left_box, "modulate:a", 1.0, TURN_TIME)
	await tween.finished
	busy = false


# ---------------------------------------------------------------------------
# Abrir e fechar
# ---------------------------------------------------------------------------

func play_open() -> void:
	busy = true
	left_page.modulate.a = 0.0
	book.modulate.a = 0.0
	book.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(book, "modulate:a", 1.0, OPEN_TIME * 0.4)
	tween.parallel().tween_property(book, "scale", Vector2.ONE, OPEN_TIME * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A capa roda pela lombada: fecha-se para a lombada à direita...
	tween.tween_property(cover, "scale:x", 0.0, OPEN_TIME * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		cover.visible = false
		cover_inside.visible = true
		cover_inside.scale.x = 0.0)
	# ...e o verso abre-se à esquerda, revelando as páginas.
	tween.tween_property(cover_inside, "scale:x", 1.0, OPEN_TIME * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		cover_inside.visible = false)
	tween.tween_property(left_page, "modulate:a", 1.0, OPEN_TIME * 0.2)
	await tween.finished
	busy = false
	(next_button if not next_button.disabled else close_button).grab_focus()


func is_open_finished() -> bool:
	return not busy and not cover.visible


func close() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(book, "scale", Vector2(0.9, 0.9), 0.15)
	tween.parallel().tween_property(book, "modulate:a", 0.0, 0.15)
	await tween.finished
	closed.emit()
	queue_free()


# _input (e não _unhandled_input): as setas mudariam o foco dos botões.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		previous_page()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		next_page()
