extends Control

# Fundo do espaço, comum ao menu principal e à cena 1 da introdução:
# estrelas em três camadas que andam devagar, planetas ao longe, o horizonte
# de um planeta em baixo e a Nave 47 a voar à direita (ShipArt "nave47_voo").
#
# "warp" (0 a 1) estica as estrelas em riscos, como a nave a sair da
# velocidade de salto; a introdução usa-o quando a Nave 47 entra.
# Com show_ship = false (pôr antes de entrar na árvore) não há nave parada:
# a introdução põe a sua.
# Só desenha; não recebe o rato.

const ShipArt := preload("res://scripts/ship_art.gd")
const UIStyle := preload("res://scripts/ui_style.gd")

const STAR_COUNT := 150
const SKY_TOP := Color(0.02, 0.035, 0.08)
const SKY_BOTTOM := Color(0.006, 0.008, 0.02)
const STAR_COLOR := Color(0.65, 0.82, 1.0)
const PLANET := Color(0.035, 0.045, 0.06)
const SHIP_SIZE := Vector2(300.0, 115.0)
# Onde fica a nave, em fração do ecrã (fora da coluna de botões).
const SHIP_ANCHOR := Vector2(0.86, 0.3)
const WARP_SPEED := 1400.0
const WARP_STREAK := 260.0

# Planetas ao longe: [centro (fração do ecrã), raio (fração da altura),
# cor, cor da sombra, anel]. Andam muito devagar para a esquerda.
const PLANETS := [
	[Vector2(0.13, 0.2), 0.085, Color(0.78, 0.48, 0.3), Color(0.32, 0.15, 0.12), true],
	[Vector2(0.07, 0.56), 0.03, Color(0.55, 0.62, 0.7), Color(0.18, 0.2, 0.26), false],
	[Vector2(0.94, 0.6), 0.022, Color(0.35, 0.75, 0.7), Color(0.08, 0.25, 0.3), false],
]
# Os planetas só se mexem durante o "warp" (no menu ficam fora da coluna
# dos botões).
const PLANET_WARP_SPEED := 60.0

var stars: Array = []   # [posição 0..1, camada 0..2, fase]
var clock: float = 0.0
var ship: Node2D = null
var show_ship: bool = true
var warp: float = 0.0
var planet_travel: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 47
	for i in STAR_COUNT:
		stars.append([Vector2(rng.randf(), rng.randf()), rng.randi_range(0, 2), rng.randf() * TAU])
	if show_ship:
		ship = ShipArt.make("nave47_voo", SHIP_SIZE)
		ship.name = "MenuShip"
		add_child(ship)


func _process(delta: float) -> void:
	clock += delta
	planet_travel += PLANET_WARP_SPEED * warp * delta
	if ship != null:
		# A nave flutua um pouco no sítio.
		ship.position = size * SHIP_ANCHOR + Vector2(sin(clock * 0.5) * 10.0, sin(clock * 0.9) * 6.0)
	queue_redraw()


func _draw() -> void:
	# Céu em degradê, de cima para baixo.
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))

	# Estrelas: as mais próximas andam mais depressa e brilham mais. Em
	# "warp" passam a riscos compridos que correm para a esquerda.
	for star in stars:
		var layer: int = star[1]
		var speed := 4.0 + layer * 7.0
		var x := fposmod(star[0].x * size.x - clock * (speed + WARP_SPEED * warp * (1.0 + layer)), size.x)
		var y: float = star[0].y * size.y
		var twinkle := 0.55 + 0.45 * sin(clock * (1.0 + layer) + star[2])
		var radius := 0.8 + layer * 0.6
		var color := Color(STAR_COLOR, (0.35 + layer * 0.2) * twinkle)
		if warp > 0.02:
			var streak := WARP_STREAK * warp * (0.4 + layer * 0.3)
			draw_line(Vector2(x, y), Vector2(x + streak, y), Color(color, color.a * (0.5 + warp * 0.5)), radius * 1.4)
		draw_circle(Vector2(x, y), radius, color)

	for planet in PLANETS:
		draw_far_planet(planet)

	# Horizonte de um planeta, com a atmosfera em ciano.
	var center := Vector2(size.x * 0.5, size.y * 2.05)
	var radius := size.y * 1.35
	for i in 4:
		draw_circle(center, radius + 26.0 - i * 6.0, Color(UIStyle.ACCENT, 0.04 + i * 0.03))
	draw_circle(center, radius, PLANET)
	draw_arc(center, radius, PI * 1.15, PI * 1.85, 96, Color(UIStyle.ACCENT, 0.5), 2.0)


# Planeta pequeno: disco com o lado escuro à direita, faixas e, se tiver,
# um anel inclinado (a metade de trás por baixo do disco).
func draw_far_planet(planet: Array) -> void:
	var r: float = size.y * float(planet[1])
	var c: Vector2 = Vector2(planet[0].x * size.x, planet[0].y * size.y)
	c.x = fposmod(c.x - planet_travel + r * 3.0, size.x + r * 6.0) - r * 3.0
	var lit: Color = planet[2]
	var dark: Color = planet[3]
	var ringed: bool = planet[4]
	var ring_color := Color(lit.lightened(0.25), 0.8)
	if ringed:
		draw_set_transform(c, -0.35, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, r * 1.75, PI, TAU, 48, ring_color, r * 0.16)
		draw_set_transform(Vector2.ZERO)
	draw_circle(c, r + 2.0, Color(0.07, 0.07, 0.09))
	draw_circle(c, r, lit)
	# Faixas.
	for i in 3:
		var y := (i - 1) * r * 0.45
		var half := sqrt(maxf(r * r - y * y, 0.0))
		draw_line(c + Vector2(-half, y), c + Vector2(half, y), lit.darkened(0.15), maxf(r * 0.12, 1.0))
	# Sombra do lado direito: entre a borda do disco e o terminador (meia
	# elipse), para nunca sair do planeta.
	var shadow := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var a := -PI / 2.0 + PI * i / steps
		shadow.append(c + Vector2(cos(a), sin(a)) * r)
	for i in steps + 1:
		var a := PI / 2.0 - PI * i / steps
		shadow.append(c + Vector2(cos(a) * r * 0.25, sin(a) * r))
	draw_colored_polygon(shadow, Color(dark, 0.88))
	if ringed:
		draw_set_transform(c, -0.35, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, r * 1.75, 0.0, PI, 48, ring_color, r * 0.16)
		draw_set_transform(Vector2.ZERO)
