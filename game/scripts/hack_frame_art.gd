extends Control

# Moldura comum dos minijogos (hack_manager.create_base_ui), para parecerem
# o ecrã de um terminal da instalação e não uma janela solta:
#   "backdrop": por trás do painel, linhas de varrimento e cantos escuros,
#               com a sala ainda a ver-se ao fundo;
#   "panel":    dentro do painel, por trás do conteúdo: cantos em L, rebites,
#               luzes de estado e um brilho que desce devagar, como nos
#               ecrãs dos terminais do mundo (world_style.gd).
# Só desenha; não recebe o rato.

const UIStyle := preload("res://scripts/ui_style.gd")

const OUTLINE := Color(0.07, 0.07, 0.09)
const METAL := Color(0.28, 0.3, 0.34)
const RIVET := Color(0.4, 0.43, 0.48)
const AMBER := Color(0.88, 0.64, 0.17)

var mode: String = "panel"
var clock: float = 0.0


static func make(art_mode: String) -> Control:
	var art = load("res://scripts/hack_frame_art.gd").new()
	art.name = "HackFrame_" + art_mode
	art.mode = art_mode
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art


# Caixa do painel: fundo de ecrã escuro e moldura de metal com contorno.
static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.05, 0.06, 0.97)
	box.border_color = METAL
	box.set_border_width_all(6)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	box.shadow_size = 14
	return box


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	if mode == "backdrop":
		draw_backdrop()
	else:
		draw_panel()


func draw_backdrop() -> void:
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.0, 0.0, 0.0, 0.18), 1.0)
		y += 3.0
	# Cantos mais escuros.
	var steps := 10
	for i in steps:
		var inset := float(i) * 14.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(0.0, 0.0, 0.0, 0.04), false, 14.0)


func draw_panel() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Contorno preto grosso por fora da moldura, como nos sprites.
	draw_rect(rect.grow(2.0), OUTLINE, false, 4.0)

	# Brilho que desce devagar pelo ecrã e linhas de varrimento leves.
	var sweep := fmod(clock * 60.0, size.y + 120.0) - 60.0
	draw_rect(Rect2(6.0, sweep, size.x - 12.0, 60.0), Color(UIStyle.ACCENT, 0.035))
	var y := 8.0
	while y < size.y - 8.0:
		draw_line(Vector2(8.0, y), Vector2(size.x - 8.0, y), Color(1.0, 1.0, 1.0, 0.018), 1.0)
		y += 4.0

	# Cantos em L, em ciano.
	var arm := 26.0
	var inset := 14.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(inset + corner.x * (size.x - inset * 2.0), inset + corner.y * (size.y - inset * 2.0))
		var dx := -arm if corner.x == 1 else arm
		var dy := -arm if corner.y == 1 else arm
		draw_line(p, p + Vector2(dx, 0.0), Color(UIStyle.ACCENT, 0.7), 3.0)
		draw_line(p, p + Vector2(0.0, dy), Color(UIStyle.ACCENT, 0.7), 3.0)

	# Rebites na moldura.
	for corner in [Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(3, size.y - 3), Vector2(size.x - 3, size.y - 3)]:
		draw_circle(corner, 3.0, RIVET)
		draw_arc(corner, 3.0, 0.0, TAU, 12, OUTLINE, 1.5)

	# Luzes de estado em cima, à direita.
	var colors := [Color(0.3, 0.8, 0.35), AMBER, UIStyle.ACCENT]
	for i in 3:
		var on := fmod(clock * (0.7 + i * 0.4) + i * 0.33, 1.0) < 0.6
		var color: Color = colors[i] if on else colors[i].darkened(0.6)
		var led := Vector2(size.x - 60.0 + i * 16.0, 3.0)
		draw_circle(led, 4.0, OUTLINE)
		draw_circle(led, 3.0, color)
