extends Node2D

# Objeto de decoração desenhado por código, no estilo dos sprites: contorno
# preto grosso, metal cinzento-frio, amarelo-torrado e ciano.
#
# Cada objeto é um Node2D centrado na origem, com "size" em píxeis do mundo.
# make() cria o objeto e, se for sólido, uma colisão retangular do mesmo
# tamanho (para o Player e o Atlas não passarem por cima).
#
# Só desenha: não tem lógica de jogo nem é interativo.

const OUTLINE := Color(0.07, 0.07, 0.09)
const METAL := Color(0.45, 0.48, 0.53)
const METAL_DARK := Color(0.28, 0.3, 0.34)
const METAL_LIGHT := Color(0.62, 0.66, 0.71)
const ACCENT := Color(0.88, 0.64, 0.17)
const CYAN := Color(0.25, 0.85, 0.85)
const RED := Color(0.85, 0.3, 0.25)
const GREEN := Color(0.35, 0.8, 0.4)
const WHITE := Color(0.9, 0.92, 0.94)
const LINE := 3.0

# Objetos que mexem (luzes a piscar, ventoinhas, bolhas, fumo).
const ANIMATED := ["server", "generator", "tube", "lamp", "radio", "monitors", "crystal", "debris", "hatch"]
# Objetos que ficam no chão (desenhados por baixo dos outros).
const FLOOR_KINDS := ["stripes", "stain", "vent", "carpet", "cables", "papers", "landing", "skid", "pebbles", "hatch"]

var kind: String = "crate"
var size: Vector2 = Vector2(60.0, 60.0)
var variant: int = 0
var clock: float = 0.0


static func make(prop_kind: String, prop_size: Vector2, solid: bool, prop_variant: int = 0) -> Node2D:
	var prop = load("res://scripts/decor_props.gd").new()
	prop.name = "Decor_" + prop_kind
	prop.kind = prop_kind
	prop.size = prop_size
	prop.variant = prop_variant
	if solid:
		var body := StaticBody2D.new()
		body.name = "Solid"
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = prop_size
		collision.shape = shape
		body.add_child(collision)
		prop.add_child(body)
	return prop


static func is_floor_kind(prop_kind: String) -> bool:
	return prop_kind in FLOOR_KINDS


func _ready() -> void:
	set_process(kind in ANIMATED)
	clock = float(variant) * 0.37


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	match kind:
		"crate": draw_crate(r, variant)
		"crates": draw_crates(r)
		"barrel": draw_barrel(r, variant)
		"barrels": draw_barrels(r)
		"shelf": draw_shelf(r)
		"locker": draw_locker(r)
		"cabinet": draw_cabinet(r)
		"desk": draw_desk(r)
		"papers": draw_papers(r)
		"lab_bench": draw_lab_bench(r)
		"tube": draw_tube(r, variant == 1)
		"server": draw_server(r)
		"generator": draw_generator(r)
		"pipes": draw_pipes(r)
		"cables": draw_cables(r)
		"stripes": draw_stripes(r)
		"stain": draw_stain(r)
		"vent": draw_vent(r)
		"bench": draw_bench(r)
		"plant": draw_plant(r)
		"bed": draw_bed(r)
		"tanks": draw_tanks(r)
		"cell": draw_cell(r, variant == 1)
		"monitors": draw_monitors(r)
		"toolbench": draw_toolbench(r)
		"toolbox": draw_toolbox(r)
		"statue": draw_statue(r)
		"carpet": draw_carpet(r)
		"lamp": draw_lamp(r)
		"radio": draw_radio(r)
		"landing": draw_landing(r)
		"fuel": draw_fuel(r)
		"rock": draw_rock(r, false)
		"boulder": draw_rock(r, true)
		"pebbles": draw_pebbles(r)
		"crystal": draw_crystal(r)
		"plate": draw_plate(r)
		"skid": draw_skid(r)
		"sculpture": draw_sculpture(r)
		"debris": draw_alien_debris(r)
		"hatch": draw_hatch(r, variant == 1)


# Muda a variante depois de criado (a escotilha abre: variante 1).
func set_variant(value: int) -> void:
	if variant == value:
		return
	variant = value
	queue_redraw()


# ---------------------------------------------------------------------------
# Ajudas
# ---------------------------------------------------------------------------

# Caixa vista de frente, com uma faixa mais clara em cima (o "tampo").
func box(r: Rect2, fill: Color, top: float = 0.25) -> void:
	draw_rect(r, fill)
	if top > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * top)), fill.lightened(0.18))
	draw_rect(r, OUTLINE, false, LINE)


func ellipse_points(center: Vector2, radius: Vector2, count: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


func ellipse(center: Vector2, radius: Vector2, fill: Color, outline: bool = true, width: float = LINE) -> void:
	var points := ellipse_points(center, radius)
	draw_colored_polygon(points, fill)
	if outline:
		points.append(points[0])
		draw_polyline(points, OUTLINE, width)


func poly(points: PackedVector2Array, fill: Color, outline: bool = true, width: float = LINE) -> void:
	draw_colored_polygon(points, fill)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, OUTLINE, width)


func rng() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = hash(kind) + variant * 7919 + int(size.x) * 31 + int(size.y)
	return random


func blink(period: float, offset: float = 0.0) -> bool:
	return fmod(clock + offset, period) < period * 0.6


# ---------------------------------------------------------------------------
# Armazém, oficina, hangar
# ---------------------------------------------------------------------------

func draw_crate(r: Rect2, tone: int = 0) -> void:
	var fill := Color(0.62, 0.46, 0.2) if tone % 2 == 0 else Color(0.36, 0.42, 0.36)
	box(r, fill)
	var body := Rect2(r.position + Vector2(0.0, r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.75)).grow(-6.0)
	draw_rect(body, fill.darkened(0.25), false, 2.0)
	draw_line(body.position, body.end, fill.darkened(0.35), 3.0)
	draw_line(Vector2(body.position.x, body.end.y), Vector2(body.end.x, body.position.y), fill.darkened(0.35), 3.0)


func draw_crates(r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	draw_crate(Rect2(r.position + Vector2(0.0, h * 0.3), Vector2(w * 0.55, h * 0.7)), 0)
	draw_crate(Rect2(r.position + Vector2(w * 0.58, h * 0.42), Vector2(w * 0.42, h * 0.58)), 1)
	draw_crate(Rect2(r.position + Vector2(w * 0.1, 0.0), Vector2(w * 0.42, h * 0.5)), 0)


func draw_barrel(r: Rect2, tone: int = 0) -> void:
	var colors := [Color(0.22, 0.42, 0.62), ACCENT, Color(0.5, 0.2, 0.18)]
	var fill: Color = colors[tone % colors.size()]
	var rx := r.size.x / 2.0
	var ry: float = min(r.size.x * 0.22, r.size.y * 0.2)
	var top := r.position.y + ry
	var bottom := r.end.y - ry
	var cx := r.get_center().x
	ellipse(Vector2(cx, bottom), Vector2(rx, ry), fill.darkened(0.2))
	draw_rect(Rect2(r.position.x, top, r.size.x, bottom - top), fill)
	for t in [0.33, 0.66]:
		var y: float = lerp(top, bottom, t)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), fill.darkened(0.3), 3.0)
	draw_line(Vector2(r.position.x, top), Vector2(r.position.x, bottom), OUTLINE, LINE)
	draw_line(Vector2(r.end.x, top), Vector2(r.end.x, bottom), OUTLINE, LINE)
	ellipse(Vector2(cx, top), Vector2(rx, ry), fill.lightened(0.2))
	ellipse(Vector2(cx + rx * 0.35, top), Vector2(rx * 0.18, ry * 0.35), fill.darkened(0.4), false)


func draw_barrels(r: Rect2) -> void:
	var count: int = max(2, int(r.size.x / (r.size.y * 0.8)))
	var w := r.size.x / count
	for i in count:
		var lift := 6.0 if i % 2 == 1 else 0.0
		draw_barrel(Rect2(r.position.x + i * w + 2.0, r.position.y + lift, w - 4.0, r.size.y - lift), i + variant)


func draw_shelf(r: Rect2) -> void:
	box(r, METAL_DARK, 0.0)
	var random := rng()
	var rows := 2
	var row_h := r.size.y / rows
	for row in rows:
		var y := r.position.y + row * row_h
		draw_line(Vector2(r.position.x, y + row_h), Vector2(r.end.x, y + row_h), OUTLINE, 2.0)
		var x := r.position.x + 5.0
		while x < r.end.x - 14.0:
			var item_w := random.randf_range(10.0, 22.0)
			var item_h := random.randf_range(row_h * 0.45, row_h * 0.8)
			var colors := [ACCENT, CYAN.darkened(0.3), RED, METAL_LIGHT, Color(0.4, 0.55, 0.35)]
			var item := Rect2(x, y + row_h - item_h - 2.0, min(item_w, r.end.x - 5.0 - x), item_h)
			draw_rect(item, colors[random.randi() % colors.size()])
			draw_rect(item, OUTLINE, false, 1.5)
			x += item_w + random.randf_range(2.0, 6.0)
	draw_rect(r, OUTLINE, false, LINE)


func draw_locker(r: Rect2) -> void:
	var count: int = max(1, int(r.size.x / 34.0))
	var w := r.size.x / count
	for i in count:
		var door := Rect2(r.position.x + i * w, r.position.y, w, r.size.y)
		draw_rect(door, Color(0.36, 0.44, 0.52) if i % 2 == 0 else Color(0.33, 0.4, 0.48))
		for k in 3:
			var y := door.position.y + 6.0 + k * 4.0
			draw_line(Vector2(door.position.x + 7.0, y), Vector2(door.end.x - 7.0, y), OUTLINE, 1.5)
		draw_rect(Rect2(door.end.x - 9.0, door.get_center().y, 4.0, 9.0), METAL_LIGHT)
		draw_rect(door, OUTLINE, false, 2.0)
	draw_rect(r, OUTLINE, false, LINE)


func draw_cabinet(r: Rect2) -> void:
	box(r, Color(0.4, 0.43, 0.38), 0.15)
	var drawers := 3
	var top := r.position.y + r.size.y * 0.15
	var h := (r.end.y - top) / drawers
	for i in drawers:
		var d := Rect2(r.position.x + 5.0, top + i * h + 3.0, r.size.x - 10.0, h - 6.0)
		draw_rect(d, OUTLINE, false, 2.0)
		draw_rect(Rect2(d.get_center() - Vector2(9.0, 2.0), Vector2(18.0, 4.0)), METAL_LIGHT)
		draw_rect(Rect2(d.position + Vector2(4.0, 3.0), Vector2(14.0, 7.0)), WHITE.darkened(0.15))
	# Folha a sair da gaveta de cima.
	poly(PackedVector2Array([Vector2(r.end.x - 26.0, top + 2.0), Vector2(r.end.x - 10.0, top - 9.0), Vector2(r.end.x - 4.0, top + 2.0)]), WHITE)


func draw_desk(r: Rect2) -> void:
	box(r, METAL_DARK, 0.55)
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55))
	# Monitor
	var screen := Rect2(top.position + Vector2(top.size.x * 0.12, 4.0), Vector2(top.size.x * 0.3, top.size.y * 0.62))
	draw_rect(screen, Color(0.04, 0.12, 0.14))
	draw_rect(screen.grow(-4.0), CYAN.darkened(0.55))
	draw_rect(screen, OUTLINE, false, 2.0)
	# Papéis e caneca
	draw_set_transform(top.get_center() + Vector2(top.size.x * 0.18, 0.0), 0.2, Vector2.ONE)
	draw_rect(Rect2(-12.0, -9.0, 24.0, 18.0), WHITE)
	draw_rect(Rect2(-12.0, -9.0, 24.0, 18.0), OUTLINE, false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ellipse(top.position + Vector2(top.size.x * 0.85, top.size.y * 0.45), Vector2(6.0, 6.0), RED)
	# Pernas
	for x in [r.position.x + 8.0, r.end.x - 12.0]:
		draw_rect(Rect2(x, top.end.y, 4.0, r.end.y - top.end.y), OUTLINE)


func draw_papers(r: Rect2) -> void:
	var random := rng()
	for i in 6:
		var center := Vector2(random.randf_range(r.position.x + 10.0, r.end.x - 10.0), random.randf_range(r.position.y + 8.0, r.end.y - 8.0))
		draw_set_transform(center, random.randf_range(-0.8, 0.8), Vector2.ONE)
		var sheet := Rect2(-11.0, -8.0, 22.0, 16.0)
		draw_rect(sheet, WHITE.darkened(random.randf_range(0.0, 0.2)))
		for k in 3:
			draw_line(Vector2(-8.0, -4.0 + k * 4.0), Vector2(6.0, -4.0 + k * 4.0), METAL, 1.0)
		draw_rect(sheet, OUTLINE, false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# Laboratório
# ---------------------------------------------------------------------------

func draw_lab_bench(r: Rect2) -> void:
	box(r, Color(0.78, 0.8, 0.83), 0.55)
	var top_h := r.size.y * 0.55
	var colors := [GREEN, CYAN, Color(0.9, 0.45, 0.7), ACCENT]
	var count: int = max(3, int(r.size.x / 34.0))
	for i in count:
		var x := r.position.x + (i + 0.5) * r.size.x / count
		var c: Color = colors[i % colors.size()]
		if i % 3 == 2:
			# Suporte de tubos de ensaio
			draw_rect(Rect2(x - 12.0, r.position.y + top_h * 0.35, 24.0, 6.0), METAL_DARK)
			for k in 3:
				draw_rect(Rect2(x - 10.0 + k * 8.0, r.position.y + 4.0, 4.0, top_h * 0.5), c.lerp(WHITE, 0.3))
		else:
			ellipse(Vector2(x, r.position.y + top_h * 0.5), Vector2(9.0, 9.0), WHITE.lerp(c, 0.6))
			draw_rect(Rect2(x - 3.0, r.position.y + top_h * 0.5 - 15.0, 6.0, 8.0), WHITE)
	for x in [r.position.x + 10.0, r.end.x - 14.0]:
		draw_rect(Rect2(x, r.position.y + top_h, 4.0, r.size.y - top_h), OUTLINE)


func draw_tube(r: Rect2, broken: bool) -> void:
	var cx := r.get_center().x
	var base_h := r.size.y * 0.18
	var glass := Rect2(r.position.x + 6.0, r.position.y + 6.0, r.size.x - 12.0, r.size.y - base_h - 6.0)
	if broken:
		ellipse(Vector2(cx, r.end.y - base_h * 0.4), Vector2(r.size.x * 0.7, base_h * 0.7), Color(0.3, 0.75, 0.4, 0.45), false)
	# Tampa e base
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 10.0), METAL_DARK)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 10.0), OUTLINE, false, 2.0)
	draw_rect(Rect2(r.position.x, r.end.y - base_h, r.size.x, base_h), METAL_DARK)
	draw_rect(Rect2(r.position.x, r.end.y - base_h, r.size.x, base_h), OUTLINE, false, LINE)
	draw_circle(Vector2(cx, r.end.y - base_h / 2.0), 3.0, GREEN if not broken else (RED if blink(1.0) else RED.darkened(0.6)))
	if broken:
		# Vidro partido: só cacos agarrados à base e à tampa.
		poly(PackedVector2Array([glass.position + Vector2(0.0, glass.size.y), glass.position + Vector2(0.0, glass.size.y * 0.55), glass.position + Vector2(glass.size.x * 0.3, glass.size.y * 0.8), glass.position + Vector2(glass.size.x * 0.5, glass.size.y)]), Color(0.6, 0.9, 0.95, 0.5))
		poly(PackedVector2Array([glass.end, glass.end - Vector2(0.0, glass.size.y * 0.4), glass.end - Vector2(glass.size.x * 0.35, glass.size.y * 0.1)]), Color(0.6, 0.9, 0.95, 0.5))
		poly(PackedVector2Array([glass.position, glass.position + Vector2(glass.size.x, 0.0), glass.position + Vector2(glass.size.x * 0.7, glass.size.y * 0.25), glass.position + Vector2(glass.size.x * 0.2, glass.size.y * 0.15)]), Color(0.6, 0.9, 0.95, 0.5))
		return
	draw_rect(glass, Color(0.25, 0.8, 0.75, 0.45))
	# Silhueta lá dentro
	ellipse(glass.get_center() + Vector2(0.0, 6.0), Vector2(glass.size.x * 0.22, glass.size.y * 0.28), Color(0.05, 0.12, 0.12, 0.6), false)
	ellipse(glass.get_center() + Vector2(0.0, -glass.size.y * 0.22), Vector2(glass.size.x * 0.16, glass.size.x * 0.16), Color(0.05, 0.12, 0.12, 0.6), false)
	# Bolhas a subir
	for i in 4:
		var t := fmod(clock * 0.5 + i * 0.27, 1.0)
		var bubble := Vector2(glass.position.x + glass.size.x * (0.25 + 0.17 * i), glass.end.y - t * glass.size.y)
		draw_circle(bubble, 2.0 + i % 2, Color(0.8, 1.0, 1.0, 0.6 * (1.0 - t)))
	draw_line(glass.position + Vector2(5.0, 6.0), Vector2(glass.position.x + 5.0, glass.end.y - 6.0), Color(1, 1, 1, 0.5), 2.0)
	draw_rect(glass, OUTLINE, false, LINE)


# ---------------------------------------------------------------------------
# Energia, núcleo, comunicações
# ---------------------------------------------------------------------------

func draw_server(r: Rect2) -> void:
	box(r, Color(0.15, 0.16, 0.19), 0.12)
	var units := int((r.size.y * 0.88) / 14.0)
	var top := r.position.y + r.size.y * 0.12
	for i in units:
		var y := top + i * 14.0 + 3.0
		draw_rect(Rect2(r.position.x + 5.0, y, r.size.x - 10.0, 10.0), Color(0.22, 0.24, 0.28))
		for k in 3:
			var on := blink(0.4 + 0.13 * ((i + k) % 5), float(i * 3 + k) * 0.21)
			var c: Color = [GREEN, CYAN, ACCENT][(i + k) % 3]
			draw_rect(Rect2(r.position.x + 9.0 + k * 7.0, y + 3.0, 4.0, 4.0), c if on else c.darkened(0.7))
		draw_line(Vector2(r.end.x - 26.0, y + 5.0), Vector2(r.end.x - 9.0, y + 5.0), OUTLINE, 2.0)


func draw_generator(r: Rect2) -> void:
	box(r, Color(0.38, 0.41, 0.37), 0.2)
	var stripe := Rect2(r.position.x, r.end.y - 12.0, r.size.x, 12.0)
	draw_hazard(stripe)
	draw_rect(stripe, OUTLINE, false, 2.0)
	var fan_r: float = min(r.size.y * 0.28, r.size.x * 0.22)
	var fan_c := Vector2(r.position.x + fan_r + 12.0, r.get_center().y + 2.0)
	draw_circle(fan_c, fan_r + 3.0, OUTLINE)
	draw_circle(fan_c, fan_r, Color(0.12, 0.13, 0.15))
	for i in 4:
		var a := clock * 9.0 + i * TAU / 4.0
		draw_line(fan_c, fan_c + Vector2(cos(a), sin(a)) * (fan_r - 3.0), METAL_LIGHT, 5.0)
	draw_circle(fan_c, 4.0, METAL)
	# Painel com mostradores e luz de aviso
	var panel_x := fan_c.x + fan_r + 14.0
	for i in 2:
		var dial := Vector2(panel_x + 12.0 + i * 26.0, r.get_center().y - 2.0)
		draw_circle(dial, 9.0, OUTLINE)
		draw_circle(dial, 7.0, WHITE)
		var a := -PI * 0.75 + sin(clock * 1.3 + i) * 0.6
		draw_line(dial, dial + Vector2(cos(a), sin(a)) * 6.0, RED, 2.0)
	draw_circle(Vector2(r.end.x - 12.0, r.position.y + 10.0), 5.0, OUTLINE)
	draw_circle(Vector2(r.end.x - 12.0, r.position.y + 10.0), 3.5, RED if blink(1.2) else RED.darkened(0.6))


func draw_hazard(r: Rect2) -> void:
	draw_rect(r, ACCENT)
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var stripe := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + 9.0, r.position.y), Vector2(x + 9.0, r.end.y)])
		for piece in Geometry2D.intersect_polygons(stripe, rect_poly):
			draw_colored_polygon(piece, OUTLINE)
		x += 18.0


func draw_pipes(r: Rect2) -> void:
	var count: int = max(1, int(r.size.y / 12.0))
	var h := r.size.y / count
	for i in count:
		var y := r.position.y + (i + 0.5) * h
		var c: Color = [METAL, Color(0.5, 0.36, 0.25), Color(0.3, 0.45, 0.55)][i % 3]
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), OUTLINE, h - 1.0)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, h - 5.0)
		draw_line(Vector2(r.position.x, y - h * 0.18), Vector2(r.end.x, y - h * 0.18), c.lightened(0.25), 2.0)
		var x := r.position.x + 40.0 + i * 25.0
		while x < r.end.x - 10.0:
			draw_rect(Rect2(x - 3.0, y - h / 2.0, 6.0, h), c.darkened(0.3))
			x += 90.0
	var valve := Vector2(r.get_center().x, r.position.y + h / 2.0)
	draw_circle(valve, h * 0.75, OUTLINE)
	draw_circle(valve, h * 0.6, RED)
	draw_circle(valve, h * 0.2, OUTLINE)


func draw_cables(r: Rect2) -> void:
	var random := rng()
	for i in 3:
		var start := Vector2(r.position.x, r.position.y + r.size.y * (0.2 + 0.3 * i))
		var finish := Vector2(r.end.x, r.position.y + r.size.y * random.randf_range(0.1, 0.9))
		var points := PackedVector2Array()
		var bend := random.randf_range(-r.size.y * 0.4, r.size.y * 0.4)
		for k in 17:
			var t := k / 16.0
			var p := start.lerp(finish, t)
			p.y += sin(t * PI) * bend
			points.append(p)
		draw_polyline(points, OUTLINE, 8.0)
		draw_polyline(points, [Color(0.15, 0.15, 0.18), Color(0.55, 0.2, 0.18), Color(0.2, 0.3, 0.5)][i], 4.0)


func draw_stripes(r: Rect2) -> void:
	draw_hazard(r)
	draw_rect(r, OUTLINE, false, 2.0)


func draw_stain(r: Rect2) -> void:
	var random := rng()
	var colors := [Color(0.06, 0.06, 0.08, 0.5), Color(0.3, 0.7, 0.35, 0.33), Color(0.45, 0.08, 0.08, 0.4)]
	var color: Color = colors[variant % colors.size()]
	for blob in 3:
		var center := r.get_center() + Vector2(random.randf_range(-0.25, 0.25) * r.size.x, random.randf_range(-0.2, 0.2) * r.size.y)
		var points := PackedVector2Array()
		var blob_scale := 0.5 if blob == 0 else 0.28
		for i in 14:
			var a := TAU * i / 14.0
			var k := random.randf_range(0.7, 1.1)
			points.append(center + Vector2(cos(a) * r.size.x * blob_scale * k, sin(a) * r.size.y * blob_scale * k))
		draw_colored_polygon(points, color)


func draw_vent(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.11, 0.13))
	var x := r.position.x + 6.0
	while x < r.end.x - 4.0:
		draw_line(Vector2(x, r.position.y + 4.0), Vector2(x, r.end.y - 4.0), METAL_DARK, 3.0)
		x += 8.0
	draw_rect(r, OUTLINE, false, LINE)
	for c in [r.position + Vector2(4, 4), Vector2(r.end.x - 4.0, r.position.y + 4.0), Vector2(r.position.x + 4.0, r.end.y - 4.0), r.end - Vector2(4, 4)]:
		draw_circle(c, 1.8, METAL_LIGHT)


func draw_bench(r: Rect2) -> void:
	var seat := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.7))
	for x in [r.position.x + 10.0, r.end.x - 14.0]:
		draw_rect(Rect2(x, seat.end.y - 2.0, 4.0, r.end.y - seat.end.y + 2.0), OUTLINE)
	box(seat, Color(0.3, 0.38, 0.46), 0.4)
	var x := seat.position.x + seat.size.x / 3.0
	while x < seat.end.x - 4.0:
		draw_line(Vector2(x, seat.position.y + 3.0), Vector2(x, seat.end.y - 3.0), OUTLINE, 2.0)
		x += seat.size.x / 3.0


func draw_plant(r: Rect2) -> void:
	var pot := PackedVector2Array([Vector2(r.position.x + r.size.x * 0.18, r.position.y + r.size.y * 0.55), Vector2(r.end.x - r.size.x * 0.18, r.position.y + r.size.y * 0.55), Vector2(r.end.x - r.size.x * 0.28, r.end.y), Vector2(r.position.x + r.size.x * 0.28, r.end.y)])
	var cx := r.get_center().x
	var base_y := r.position.y + r.size.y * 0.58
	# Planta "alienígena": folhas compridas de cor estranha.
	var leaf_color := Color(0.3, 0.6, 0.55) if variant % 2 == 0 else Color(0.5, 0.35, 0.6)
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.45
		var tip := Vector2(cx, base_y) + Vector2(cos(a), sin(a)) * r.size.y * 0.55
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * 5.0
		poly(PackedVector2Array([Vector2(cx, base_y) + side, tip, Vector2(cx, base_y) - side]), leaf_color.lightened(0.1 * (i % 2)))
	poly(pot, Color(0.42, 0.44, 0.48))
	draw_line(pot[0] + Vector2(0, 5), pot[1] + Vector2(0, 5), OUTLINE, 2.0)


# ---------------------------------------------------------------------------
# Suporte e segurança
# ---------------------------------------------------------------------------

func draw_bed(r: Rect2) -> void:
	var frame := Rect2(r.position + Vector2(0.0, r.size.y * 0.15), Vector2(r.size.x * 0.82, r.size.y * 0.85))
	box(frame, METAL, 0.0)
	var mattress := frame.grow(-6.0)
	draw_rect(mattress, WHITE)
	draw_rect(Rect2(mattress.position + Vector2(mattress.size.x * 0.35, 0.0), Vector2(mattress.size.x * 0.65, mattress.size.y)), Color(0.3, 0.6, 0.62))
	ellipse(Vector2(mattress.position.x + mattress.size.x * 0.16, mattress.get_center().y), Vector2(mattress.size.x * 0.12, mattress.size.y * 0.35), WHITE.darkened(0.08))
	draw_rect(mattress, OUTLINE, false, 2.0)
	# Suporte do soro
	var pole_x := r.end.x - r.size.x * 0.07
	draw_line(Vector2(pole_x, r.end.y), Vector2(pole_x, r.position.y + 6.0), OUTLINE, 4.0)
	ellipse(Vector2(pole_x + 6.0, r.position.y + 12.0), Vector2(6.0, 9.0), Color(0.7, 0.9, 1.0, 0.8))


func draw_tanks(r: Rect2) -> void:
	var count: int = max(2, int(r.size.x / 34.0))
	var w := r.size.x / count
	for i in count:
		var t := Rect2(r.position.x + i * w + 2.0, r.position.y + (i % 2) * 6.0, w - 4.0, r.size.y - (i % 2) * 6.0)
		var fill := Color(0.3, 0.6, 0.4) if i % 2 == 0 else WHITE.darkened(0.15)
		draw_rect(Rect2(t.position + Vector2(0.0, t.size.x * 0.3), t.size - Vector2(0.0, t.size.x * 0.3)), fill)
		ellipse(Vector2(t.get_center().x, t.position.y + t.size.x * 0.3), Vector2(t.size.x / 2.0, t.size.x * 0.3), fill.lightened(0.2))
		draw_rect(Rect2(t.get_center().x - 4.0, t.position.y - 2.0, 8.0, 8.0), METAL_DARK)
		draw_rect(Rect2(t.position + Vector2(0.0, t.size.x * 0.3), t.size - Vector2(0.0, t.size.x * 0.3)), OUTLINE, false, LINE)
		draw_rect(Rect2(t.position.x, t.get_center().y, t.size.x, 6.0), ACCENT)
	draw_line(Vector2(r.position.x, r.get_center().y + 14.0), Vector2(r.end.x, r.get_center().y + 14.0), OUTLINE, 3.0)


func draw_cell(r: Rect2, broken: bool) -> void:
	var c := r.get_center()
	var radius: float = min(r.size.x, r.size.y) / 2.0
	draw_circle(c, radius, OUTLINE)
	draw_circle(c, radius - 3.0, METAL_DARK)
	draw_circle(c, radius - 12.0, Color(0.1, 0.11, 0.13))
	var glass := Color(0.4, 0.85, 0.9, 0.35)
	if broken:
		# Vidro rebentado de dentro para fora, com cacos à volta.
		var random := rng()
		for i in 9:
			var a := random.randf_range(0.0, TAU)
			var d := random.randf_range(radius * 0.5, radius * 0.95)
			var p := c + Vector2(cos(a), sin(a)) * d
			poly(PackedVector2Array([p, p + Vector2(7, 2).rotated(a), p + Vector2(2, 8).rotated(a)]), Color(0.6, 0.9, 0.95, 0.6), false)
		for i in 7:
			var a := TAU * i / 7.0 + 0.3
			draw_line(c + Vector2(cos(a), sin(a)) * radius * 0.3, c + Vector2(cos(a), sin(a)) * (radius - 12.0), Color(0.8, 1, 1, 0.5), 2.0)
		draw_circle(c, radius * 0.3, Color(0.3, 0.7, 0.35, 0.35))
	else:
		draw_circle(c, radius - 12.0, glass)
		draw_arc(c, radius - 18.0, -2.4, -1.4, 10, Color(1, 1, 1, 0.6), 3.0)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		draw_circle(c + Vector2(cos(a), sin(a)) * (radius - 6.0), 3.0, ACCENT)
	var light := c + Vector2(0.0, -radius + 6.0)
	draw_circle(light, 4.0, RED if (broken and blink(0.8)) else RED.darkened(0.5))


func draw_monitors(r: Rect2) -> void:
	box(r, METAL_DARK, 0.0)
	var count: int = max(2, int(r.size.x / 60.0))
	var w := (r.size.x - 8.0) / count
	var random := RandomNumberGenerator.new()
	random.seed = int(clock * 8.0) + variant
	for i in count:
		var screen := Rect2(r.position.x + 4.0 + i * w + 3.0, r.position.y + 5.0, w - 6.0, r.size.y * 0.6)
		draw_rect(screen, Color(0.05, 0.08, 0.09))
		# Imagem das câmaras com ruído
		for k in 6:
			var y := screen.position.y + random.randf() * screen.size.y
			draw_line(Vector2(screen.position.x + 2.0, y), Vector2(screen.end.x - 2.0, y), Color(0.5, 0.7, 0.7, 0.25), 1.0)
		draw_rect(screen, OUTLINE, false, 2.0)
	draw_circle(Vector2(r.end.x - 10.0, r.end.y - 9.0), 4.0, RED if blink(1.0) else RED.darkened(0.6))
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 8.0, r.end.y - 5.0), "CAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WHITE.darkened(0.3))


# ---------------------------------------------------------------------------
# Oficina
# ---------------------------------------------------------------------------

func draw_toolbench(r: Rect2) -> void:
	box(r, Color(0.48, 0.38, 0.28), 0.55)
	var top_h := r.size.y * 0.55
	var y := r.position.y + top_h * 0.5
	# Chave inglesa
	var wx := r.position.x + r.size.x * 0.2
	draw_line(Vector2(wx - 18.0, y + 4.0), Vector2(wx + 14.0, y - 4.0), OUTLINE, 6.0)
	draw_line(Vector2(wx - 18.0, y + 4.0), Vector2(wx + 14.0, y - 4.0), METAL_LIGHT, 3.0)
	draw_circle(Vector2(wx + 16.0, y - 5.0), 6.0, OUTLINE)
	draw_circle(Vector2(wx + 16.0, y - 5.0), 4.0, METAL_LIGHT)
	# Martelo
	var hx := r.position.x + r.size.x * 0.48
	draw_line(Vector2(hx, y + 8.0), Vector2(hx + 4.0, y - 8.0), OUTLINE, 5.0)
	draw_line(Vector2(hx, y + 8.0), Vector2(hx + 4.0, y - 8.0), ACCENT.darkened(0.3), 3.0)
	draw_rect(Rect2(hx - 6.0, y - 13.0, 18.0, 7.0), METAL)
	draw_rect(Rect2(hx - 6.0, y - 13.0, 18.0, 7.0), OUTLINE, false, 2.0)
	# Torno
	var vise := Rect2(r.end.x - r.size.x * 0.22, r.position.y + 3.0, r.size.x * 0.16, top_h - 6.0)
	draw_rect(vise, Color(0.3, 0.45, 0.6))
	draw_rect(vise, OUTLINE, false, 2.0)
	for x in [r.position.x + 8.0, r.end.x - 12.0]:
		draw_rect(Rect2(x, r.position.y + top_h, 4.0, r.size.y - top_h), OUTLINE)


func draw_toolbox(r: Rect2) -> void:
	var body := Rect2(r.position + Vector2(0.0, r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.75))
	draw_arc(Vector2(r.get_center().x, body.position.y), r.size.x * 0.22, PI, TAU, 10, OUTLINE, 4.0)
	box(body, RED.darkened(0.15), 0.35)
	draw_rect(Rect2(body.get_center() - Vector2(5.0, 0.0), Vector2(10.0, 5.0)), METAL_LIGHT)


# ---------------------------------------------------------------------------
# Santuário
# ---------------------------------------------------------------------------

func draw_statue(r: Rect2) -> void:
	var stone := Color(0.55, 0.52, 0.48)
	var pedestal := Rect2(r.position.x + r.size.x * 0.08, r.end.y - r.size.y * 0.28, r.size.x * 0.84, r.size.y * 0.28)
	box(pedestal, Color(0.36, 0.35, 0.34), 0.3)
	var cx := r.get_center().x
	var top := r.position.y + 4.0
	var bottom := pedestal.position.y
	match variant % 3:
		0:
			# Figura alta e estranha, com a cabeça alongada.
			poly(PackedVector2Array([Vector2(cx - r.size.x * 0.22, bottom), Vector2(cx - r.size.x * 0.12, top + r.size.y * 0.3), Vector2(cx, top + r.size.y * 0.24), Vector2(cx + r.size.x * 0.12, top + r.size.y * 0.3), Vector2(cx + r.size.x * 0.22, bottom)]), stone)
			ellipse(Vector2(cx, top + r.size.y * 0.14), Vector2(r.size.x * 0.13, r.size.y * 0.14), stone.lightened(0.08))
			draw_circle(Vector2(cx - 5.0, top + r.size.y * 0.13), 2.5, CYAN.darkened(0.2))
			draw_circle(Vector2(cx + 5.0, top + r.size.y * 0.13), 2.5, CYAN.darkened(0.2))
		1:
			# Esfera sobre um pilar
			draw_rect(Rect2(cx - 6.0, top + r.size.y * 0.35, 12.0, bottom - top - r.size.y * 0.35), stone.darkened(0.15))
			draw_rect(Rect2(cx - 6.0, top + r.size.y * 0.35, 12.0, bottom - top - r.size.y * 0.35), OUTLINE, false, 2.0)
			ellipse(Vector2(cx, top + r.size.y * 0.24), Vector2(r.size.x * 0.28, r.size.x * 0.28), stone)
			draw_arc(Vector2(cx, top + r.size.y * 0.24), r.size.x * 0.16, 0.0, TAU, 16, CYAN.darkened(0.3), 2.0)
		_:
			# Pilar torcido, com uma lua por cima
			poly(PackedVector2Array([Vector2(cx - r.size.x * 0.25, bottom), Vector2(cx - r.size.x * 0.08, top + r.size.y * 0.3), Vector2(cx - r.size.x * 0.14, top + r.size.y * 0.12), Vector2(cx + r.size.x * 0.1, top + r.size.y * 0.22), Vector2(cx + r.size.x * 0.06, top + r.size.y * 0.4), Vector2(cx + r.size.x * 0.25, bottom)]), stone)
			draw_arc(Vector2(cx, top + r.size.y * 0.08), r.size.x * 0.14, PI * 0.2, PI * 1.6, 12, OUTLINE, 6.0)
			draw_arc(Vector2(cx, top + r.size.y * 0.08), r.size.x * 0.14, PI * 0.2, PI * 1.6, 12, CYAN.darkened(0.2), 3.0)
	# Gravações
	for i in 3:
		var y := pedestal.position.y + pedestal.size.y * 0.45 + i * 5.0
		draw_line(Vector2(pedestal.position.x + 8.0, y), Vector2(pedestal.position.x + 8.0 + (i + 2) * 6.0, y), OUTLINE, 1.5)


func draw_carpet(r: Rect2) -> void:
	draw_rect(r, Color(0.32, 0.1, 0.12, 0.9))
	draw_rect(r.grow(-6.0), Color(0.65, 0.5, 0.2, 0.8), false, 2.0)
	var long := r.size.x >= r.size.y
	var step := 46.0
	var count := int((r.size.x if long else r.size.y) / step)
	for i in count:
		var c := r.get_center() + (Vector2((i - (count - 1) / 2.0) * step, 0.0) if long else Vector2(0.0, (i - (count - 1) / 2.0) * step))
		var d: float = min(r.size.x, r.size.y) * 0.25
		poly(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(0.5, 0.18, 0.2), false)
		draw_circle(c, 3.0, Color(0.75, 0.6, 0.25))


func draw_lamp(r: Rect2) -> void:
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.35)
	var flicker := 0.85 + 0.15 * sin(clock * 9.0 + variant) * sin(clock * 3.3)
	for i in 4:
		draw_circle(c, r.size.x * (0.9 - i * 0.18) * flicker, Color(1.0, 0.6, 0.2, 0.06 + i * 0.03))
	draw_rect(Rect2(r.get_center().x - 5.0, c.y, 10.0, r.end.y - c.y - 8.0), METAL_DARK)
	draw_rect(Rect2(r.get_center().x - 5.0, c.y, 10.0, r.end.y - c.y - 8.0), OUTLINE, false, 2.0)
	draw_rect(Rect2(r.position.x + 6.0, r.end.y - 10.0, r.size.x - 12.0, 10.0), METAL)
	draw_rect(Rect2(r.position.x + 6.0, r.end.y - 10.0, r.size.x - 12.0, 10.0), OUTLINE, false, 2.0)
	poly(PackedVector2Array([c + Vector2(-r.size.x * 0.32, -4.0), c + Vector2(r.size.x * 0.32, -4.0), c + Vector2(r.size.x * 0.2, 8.0), c + Vector2(-r.size.x * 0.2, 8.0)]), METAL)
	ellipse(c + Vector2(0.0, -7.0), Vector2(r.size.x * 0.18, 7.0 * flicker), Color(1.0, 0.75, 0.3), false)
	ellipse(c + Vector2(0.0, -9.0), Vector2(r.size.x * 0.09, 4.0 * flicker), Color(1.0, 0.95, 0.7), false)


# ---------------------------------------------------------------------------
# Comunicações e hangar
# ---------------------------------------------------------------------------

func draw_radio(r: Rect2) -> void:
	box(r, Color(0.24, 0.27, 0.3), 0.15)
	var top := r.position.y + r.size.y * 0.15
	# Antena
	draw_line(Vector2(r.end.x - 14.0, r.position.y), Vector2(r.end.x - 4.0, r.position.y - 26.0), OUTLINE, 3.0)
	draw_circle(Vector2(r.end.x - 4.0, r.position.y - 26.0), 3.5, RED if blink(0.9) else RED.darkened(0.6))
	# Mostradores
	for i in 3:
		var dial := Vector2(r.position.x + 16.0 + i * 24.0, top + 14.0)
		draw_circle(dial, 9.0, OUTLINE)
		draw_circle(dial, 7.0, Color(0.85, 0.8, 0.6))
		var a := -PI * 0.7 + fmod(clock * (0.6 + i * 0.3), 1.4)
		draw_line(dial, dial + Vector2(cos(a), sin(a)) * 6.0, OUTLINE, 2.0)
	# Onda no ecrã
	var screen := Rect2(r.position.x + 8.0, top + 28.0, r.size.x - 16.0, r.end.y - top - 34.0)
	if screen.size.y > 8.0:
		draw_rect(screen, Color(0.04, 0.12, 0.1))
		var points := PackedVector2Array()
		for k in 20:
			var x := screen.position.x + k * screen.size.x / 19.0
			points.append(Vector2(x, screen.get_center().y + sin(k * 0.9 + clock * 6.0) * screen.size.y * 0.3))
		draw_polyline(points, GREEN, 2.0)
		draw_rect(screen, OUTLINE, false, 2.0)


func draw_landing(r: Rect2) -> void:
	var c := r.get_center()
	var radius: float = min(r.size.x, r.size.y) / 2.0
	draw_arc(c, radius, 0.0, TAU, 48, Color(ACCENT, 0.7), 6.0)
	draw_arc(c, radius * 0.8, 0.0, TAU, 48, Color(ACCENT, 0.35), 2.0)
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector2(cos(a), sin(a)) * radius * 0.9
		draw_circle(p, 4.0, Color(ACCENT, 0.8))
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * radius * 0.35
		draw_line(Vector2(x, c.y - radius * 0.4), Vector2(x, c.y + radius * 0.4), Color(1, 1, 1, 0.25), 8.0)
	draw_line(Vector2(c.x - radius * 0.35, c.y), Vector2(c.x + radius * 0.35, c.y), Color(1, 1, 1, 0.25), 8.0)


func draw_fuel(r: Rect2) -> void:
	var end_r := r.size.y / 2.0
	var body := Rect2(r.position.x + end_r, r.position.y, r.size.x - end_r * 2.0, r.size.y)
	var fill := Color(0.55, 0.22, 0.18)
	draw_circle(Vector2(body.position.x, r.get_center().y), end_r, OUTLINE)
	draw_circle(Vector2(body.end.x, r.get_center().y), end_r, OUTLINE)
	draw_circle(Vector2(body.position.x, r.get_center().y), end_r - 3.0, fill.darkened(0.1))
	draw_circle(Vector2(body.end.x, r.get_center().y), end_r - 3.0, fill.darkened(0.1))
	draw_rect(body.grow_individual(0, -3, 0, -3), fill)
	draw_line(body.position, Vector2(body.end.x, body.position.y), OUTLINE, LINE)
	draw_line(Vector2(body.position.x, body.end.y), body.end, OUTLINE, LINE)
	draw_rect(Rect2(body.position.x, body.position.y + 6.0, body.size.x, 6.0), fill.lightened(0.25))
	draw_hazard(Rect2(body.get_center().x - 30.0, body.position.y + r.size.y * 0.4, 60.0, r.size.y * 0.25))
	draw_string(ThemeDB.fallback_font, Vector2(body.position.x + 6.0, body.end.y - 6.0), "H2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WHITE)


# ---------------------------------------------------------------------------
# Superfície
# ---------------------------------------------------------------------------

func draw_rock(r: Rect2, big: bool) -> void:
	var random := rng()
	var points := PackedVector2Array()
	var c := r.get_center() + Vector2(0.0, r.size.y * 0.1)
	for i in 9:
		var a := TAU * i / 9.0 + random.randf_range(-0.2, 0.2)
		var k := random.randf_range(0.75, 1.0)
		points.append(c + Vector2(cos(a) * r.size.x * 0.5 * k, sin(a) * r.size.y * 0.42 * k))
	var base := Color(0.55, 0.38, 0.25) if variant % 2 == 0 else Color(0.45, 0.4, 0.38)
	ellipse(c + Vector2(4.0, r.size.y * 0.3), Vector2(r.size.x * 0.5, r.size.y * 0.16), Color(0, 0, 0, 0.18), false)
	poly(points, base)
	# Face iluminada em cima e fissuras
	var light := PackedVector2Array()
	for i in 5:
		light.append(c + (points[i + 4 if i + 4 < points.size() else 0] - c) * 0.55 + Vector2(0.0, -r.size.y * 0.08))
	draw_colored_polygon(light, base.lightened(0.18))
	if big:
		draw_line(c + Vector2(-r.size.x * 0.1, -r.size.y * 0.1), c + Vector2(r.size.x * 0.05, r.size.y * 0.15), OUTLINE, 2.0)


func draw_pebbles(r: Rect2) -> void:
	var random := rng()
	for i in 7:
		var p := Vector2(random.randf_range(r.position.x, r.end.x), random.randf_range(r.position.y, r.end.y))
		var s := random.randf_range(3.0, 7.0)
		ellipse(p, Vector2(s, s * 0.7), Color(0.5, 0.36, 0.24), i % 2 == 0)


func draw_crystal(r: Rect2) -> void:
	var c := Vector2(r.get_center().x, r.end.y - 6.0)
	var glow := 0.5 + 0.5 * sin(clock * 2.0 + variant)
	var color := Color(0.55, 0.35, 0.85) if variant % 2 == 0 else Color(0.25, 0.8, 0.8)
	draw_circle(c + Vector2(0.0, -r.size.y * 0.35), r.size.x * 0.55, Color(color, 0.08 + 0.08 * glow))
	var shards := [[-0.3, 0.55, -0.35], [0.0, 1.0, 0.0], [0.28, 0.7, 0.3], [-0.1, 0.4, -0.6]]
	for s in shards:
		var base := c + Vector2(s[0] * r.size.x, 0.0)
		var tip := base + Vector2(0.0, -s[1] * r.size.y * 0.95).rotated(s[2] * 0.5)
		var w := r.size.x * 0.12
		poly(PackedVector2Array([base + Vector2(-w, 0), tip + Vector2(-w * 0.2, w), tip, tip + Vector2(w * 0.2, w), base + Vector2(w, 0)]), color.lerp(WHITE, 0.15 * glow))
		draw_line(base, tip + Vector2(0, w), color.lightened(0.4), 2.0)


func draw_plate(r: Rect2) -> void:
	var random := rng()
	var points := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + random.randf_range(-0.3, 0.3)
		points.append(r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.45) * random.randf_range(0.7, 1.0))
	ellipse(r.get_center() + Vector2(3.0, r.size.y * 0.25), Vector2(r.size.x * 0.45, r.size.y * 0.15), Color(0, 0, 0, 0.18), false)
	poly(points, METAL.darkened(random.randf_range(0.0, 0.25)))
	for i in 3:
		draw_circle(r.get_center() + Vector2(random.randf_range(-0.3, 0.3) * r.size.x, random.randf_range(-0.2, 0.2) * r.size.y), 2.0, METAL_LIGHT)
	draw_line(points[0].lerp(points[3], 0.2), points[0].lerp(points[3], 0.8), ACCENT.darkened(0.2), 4.0)


# Rasto do despiste na areia: sulco largo junto à nave, a estreitar para
# trás, com bordas suaves e areia revolvida.
func draw_skid(r: Rect2) -> void:
	var cy := r.get_center().y
	for layer in 4:
		var k := 1.0 - layer * 0.22
		var points := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			var half: float = lerp(r.size.y * 0.08, r.size.y * 0.5, t * t) * k
			points.append(Vector2(lerp(r.position.x, r.end.x, t), cy - half + sin(t * 9.0) * 4.0))
		for i in range(12, -1, -1):
			var t := i / 12.0
			var half: float = lerp(r.size.y * 0.08, r.size.y * 0.5, t * t) * k
			points.append(Vector2(lerp(r.position.x, r.end.x, t), cy + half + cos(t * 7.0) * 4.0))
		draw_colored_polygon(points, Color(0.42, 0.26, 0.1, 0.1))
	var random := rng()
	for i in 14:
		var t := random.randf_range(0.1, 1.0)
		var x: float = lerp(r.position.x, r.end.x, t)
		var half: float = lerp(r.size.y * 0.08, r.size.y * 0.45, t * t)
		var y := cy + random.randf_range(-half, half)
		draw_line(Vector2(x, y), Vector2(x + random.randf_range(30.0, 80.0), y + random.randf_range(-4.0, 4.0)), Color(0.3, 0.18, 0.08, 0.25), 3.0)
	# Montes de areia empurrada dos lados
	for side in [-1.0, 1.0]:
		for i in 4:
			var t := 0.55 + i * 0.13
			var x: float = lerp(r.position.x, r.end.x, t)
			var half: float = lerp(r.size.y * 0.08, r.size.y * 0.5, t * t)
			draw_circle(Vector2(x, cy + side * (half + 6.0)), 10.0 + i * 3.0, Color(0.95, 0.75, 0.4, 0.25))


# ---------------------------------------------------------------------------
# Descobertas da superfície e PROTOCOL DOOR
# ---------------------------------------------------------------------------

# Escultura antiga (AncientSculpture): estatueta de pedra gasta, meio
# enterrada na areia. Uma figura de pé com um capacete redondo nas mãos,
# com uma marca ciano no peito: pista discreta de que quem a fez era humano.
func draw_sculpture(r: Rect2) -> void:
	var stone := Color(0.7, 0.58, 0.42)
	var stone_dark := stone.darkened(0.28)
	var cx := r.get_center().x
	var w := r.size.x
	var h := r.size.y
	var foot := r.end.y - h * 0.08
	# Sombra e areia acumulada à volta da base.
	ellipse(Vector2(cx + 4.0, foot), Vector2(w * 0.52, h * 0.08), Color(0, 0, 0, 0.2), false)
	ellipse(Vector2(cx, foot - 1.0), Vector2(w * 0.48, h * 0.06), Color(0.8, 0.58, 0.28), false)
	# Base de pedra rachada, com um canto partido.
	var base := PackedVector2Array([Vector2(cx - w * 0.36, foot - 2.0), Vector2(cx - w * 0.36, foot - h * 0.17), Vector2(cx + w * 0.2, foot - h * 0.17),
		Vector2(cx + w * 0.36, foot - h * 0.11), Vector2(cx + w * 0.36, foot - 2.0)])
	poly(base, stone_dark, true, 2.0)
	draw_line(Vector2(cx - w * 0.36, foot - h * 0.13), Vector2(cx + w * 0.3, foot - h * 0.13), stone_dark.lightened(0.2), 1.5)
	draw_line(Vector2(cx + w * 0.05, foot - h * 0.17), Vector2(cx, foot - h * 0.07), OUTLINE, 1.5)
	var hip := foot - h * 0.17
	var waist := r.position.y + h * 0.55
	var shoulder := r.position.y + h * 0.3
	# Pernas.
	for side in [-1.0, 1.0]:
		poly(PackedVector2Array([Vector2(cx + side * w * 0.04, hip), Vector2(cx + side * w * 0.04, waist), Vector2(cx + side * w * 0.17, waist), Vector2(cx + side * w * 0.15, hip)]), stone.darkened(0.08), true, 2.0)
	# Tronco (fato, com cinto) e ombros largos.
	poly(PackedVector2Array([Vector2(cx - w * 0.17, waist + 2.0), Vector2(cx - w * 0.22, shoulder + h * 0.04), Vector2(cx - w * 0.12, shoulder),
		Vector2(cx + w * 0.12, shoulder), Vector2(cx + w * 0.22, shoulder + h * 0.04), Vector2(cx + w * 0.17, waist + 2.0)]), stone, true, 2.0)
	draw_line(Vector2(cx - w * 0.17, waist - 2.0), Vector2(cx + w * 0.17, waist - 2.0), stone_dark, 2.0)
	# Capacete redondo seguro à frente do peito.
	ellipse(Vector2(cx, shoulder + h * 0.13), Vector2(w * 0.15, h * 0.075), stone.lightened(0.12), true, 2.0)
	draw_arc(Vector2(cx, shoulder + h * 0.13), w * 0.08, PI * 1.1, PI * 1.9, 8, OUTLINE, 1.5)
	# Cabeça humana, com os olhos gastos.
	ellipse(Vector2(cx, r.position.y + h * 0.17), Vector2(w * 0.13, h * 0.1), stone.lightened(0.06), true, 2.0)
	draw_line(Vector2(cx - w * 0.07, r.position.y + h * 0.17), Vector2(cx - w * 0.02, r.position.y + h * 0.17), OUTLINE, 1.5)
	draw_line(Vector2(cx + w * 0.02, r.position.y + h * 0.17), Vector2(cx + w * 0.07, r.position.y + h * 0.17), OUTLINE, 1.5)
	# Marca ciano no ombro (como o emblema dos fatos) e rachadela.
	draw_circle(Vector2(cx - w * 0.14, shoulder + h * 0.035), 2.2, CYAN.darkened(0.1))
	draw_line(Vector2(cx + w * 0.1, shoulder + 2.0), Vector2(cx + w * 0.05, shoulder + h * 0.08), OUTLINE, 1.2)


# Destroços de origem desconhecida (UnknownDebris): placa curva de um metal
# escuro e arroxeado, que não é da Nave 47, espetada na areia, com costuras
# roxas a brilhar devagar e lascas à volta.
func draw_alien_debris(r: Rect2) -> void:
	var hull := Color(0.24, 0.2, 0.3)
	var glow_color := Color(0.62, 0.38, 0.92)
	var glow := 0.5 + 0.5 * sin(clock * 1.6)
	var c := r.get_center()
	var w := r.size.x
	var h := r.size.y
	var foot := r.end.y - h * 0.12
	ellipse(Vector2(c.x + 5.0, foot), Vector2(w * 0.48, h * 0.12), Color(0, 0, 0, 0.2), false)
	draw_circle(Vector2(c.x, foot - h * 0.35), w * 0.45, Color(glow_color, 0.05 + 0.06 * glow))
	# Placa principal, inclinada e curva.
	var plate := PackedVector2Array([Vector2(c.x - w * 0.42, foot), Vector2(c.x - w * 0.3, r.position.y + h * 0.3), Vector2(c.x - w * 0.05, r.position.y + h * 0.08),
		Vector2(c.x + w * 0.22, r.position.y + h * 0.16), Vector2(c.x + w * 0.12, foot - h * 0.2), Vector2(c.x + w * 0.2, foot)])
	poly(plate, hull)
	# Nervuras curvas.
	for i in 3:
		var t := 0.25 + i * 0.22
		var a := plate[1].lerp(plate[2], t)
		var b := plate[0].lerp(plate[5], t)
		draw_line(a, b.lerp(a, 0.25), hull.lightened(0.18), 3.0)
	# Costuras roxas que brilham.
	var seam := PackedVector2Array([plate[1].lerp(plate[2], 0.15) + Vector2(4, 6), c + Vector2(-w * 0.08, -h * 0.05), c + Vector2(w * 0.02, h * 0.12)])
	draw_polyline(seam, OUTLINE, 5.0)
	draw_polyline(seam, glow_color.lerp(WHITE, 0.3 * glow), 2.5)
	# Símbolos que não pertencem a nenhum alfabeto conhecido.
	var glyph := c + Vector2(-w * 0.17, -h * 0.12)
	draw_arc(glyph, 4.0, 0.0, PI * 1.5, 8, glow_color.lerp(WHITE, 0.2 * glow), 1.5)
	draw_line(glyph + Vector2(6, -4), glyph + Vector2(6, 5), glow_color.lerp(WHITE, 0.2 * glow), 1.5)
	# Segunda lasca mais pequena, à direita.
	poly(PackedVector2Array([Vector2(c.x + w * 0.22, foot), Vector2(c.x + w * 0.3, foot - h * 0.32), Vector2(c.x + w * 0.44, foot - h * 0.18), Vector2(c.x + w * 0.46, foot)]), hull.darkened(0.15))
	draw_line(Vector2(c.x + w * 0.31, foot - h * 0.22), Vector2(c.x + w * 0.4, foot - h * 0.12), glow_color.darkened(0.2), 1.5)
	# Areia a tapar a base.
	poly(PackedVector2Array([Vector2(c.x - w * 0.5, foot + 3.0), Vector2(c.x - w * 0.3, foot - h * 0.06), Vector2(c.x, foot - h * 0.02),
		Vector2(c.x + w * 0.32, foot - h * 0.07), Vector2(c.x + w * 0.5, foot + 3.0)]), Color(0.82, 0.6, 0.3))


# PROTOCOL DOOR: escotilha no chão, com moldura de faixas de perigo. Fechada:
# tampa com fecho e luz vermelha. Aberta: a tampa fica deitada para trás e
# vê-se o poço escuro com a escada; a luz fica verde.
func draw_hatch(r: Rect2, open: bool) -> void:
	var c := r.get_center()
	var frame_rect := r.grow(-2.0)
	var hole := r.grow(-r.size.y * 0.2)
	ellipse(c + Vector2(4.0, 4.0), r.size * 0.5, Color(0, 0, 0, 0.2), false)
	box(frame_rect, METAL_DARK, 0.0)
	# Faixas de perigo na moldura.
	var stripe := 14.0
	var x := frame_rect.position.x
	var i := 0
	while x < frame_rect.end.x:
		if i % 2 == 0:
			var stripe_w: float = min(stripe, frame_rect.end.x - x)
			draw_rect(Rect2(x, frame_rect.position.y + 2.0, stripe_w, hole.position.y - frame_rect.position.y - 4.0), ACCENT.darkened(0.1))
			draw_rect(Rect2(x, hole.end.y + 2.0, stripe_w, frame_rect.end.y - hole.end.y - 4.0), ACCENT.darkened(0.1))
		x += stripe
		i += 1
	draw_rect(frame_rect, OUTLINE, false, LINE)
	var light_pos := Vector2(frame_rect.end.x - 8.0, frame_rect.position.y + 8.0)
	if open:
		# Tampa deitada para trás (por cima, no chão).
		var lid := Rect2(hole.position.x + 4.0, r.position.y - hole.size.y * 0.55, hole.size.x - 8.0, hole.size.y * 0.55)
		box(lid, METAL.darkened(0.15), 0.0)
		draw_line(lid.position + Vector2(lid.size.x / 2.0, 3.0), lid.position + Vector2(lid.size.x / 2.0, lid.size.y - 3.0), OUTLINE, 2.0)
		# Poço com escada.
		draw_rect(hole, Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(hole.position, Vector2(hole.size.x, hole.size.y * 0.22)), Color(0.12, 0.12, 0.15))
		var rail_l := hole.position.x + hole.size.x * 0.35
		var rail_r := hole.end.x - hole.size.x * 0.35
		draw_line(Vector2(rail_l, hole.position.y + 4.0), Vector2(rail_l, hole.end.y), METAL, 2.5)
		draw_line(Vector2(rail_r, hole.position.y + 4.0), Vector2(rail_r, hole.end.y), METAL, 2.5)
		for k in 3:
			var y := hole.position.y + 8.0 + k * hole.size.y * 0.28
			draw_line(Vector2(rail_l, y), Vector2(rail_r, y), METAL_LIGHT.darkened(0.2 + k * 0.2), 2.0)
		draw_rect(hole, OUTLINE, false, 2.0)
		draw_circle(light_pos, 4.0, GREEN)
	else:
		# Tampa fechada, em duas metades, com o fecho a meio.
		box(hole, METAL, 0.0)
		draw_line(Vector2(c.x, hole.position.y + 2.0), Vector2(c.x, hole.end.y - 2.0), OUTLINE, 2.0)
		for side in [-1.0, 1.0]:
			for k in 2:
				draw_circle(Vector2(c.x + side * hole.size.x * 0.38, hole.position.y + 6.0 + k * (hole.size.y - 12.0)), 2.0, METAL_LIGHT)
		var lock := Rect2(c.x - 9.0, c.y - 6.0, 18.0, 12.0)
		box(lock, METAL_DARK, 0.0)
		draw_rect(Rect2(c.x - 4.0, c.y - 2.0, 8.0, 4.0), RED.darkened(0.2) if blink(1.4) else RED.darkened(0.6))
		draw_circle(light_pos, 4.0, RED if blink(1.0) else RED.darkened(0.5))
	draw_arc(light_pos, 4.0, 0.0, TAU, 12, OUTLINE, 1.5)
