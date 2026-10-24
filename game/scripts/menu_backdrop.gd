extends Control

# Fundo do menu principal: espaço com estrelas em três camadas que andam
# devagar, o horizonte de um planeta em baixo e a Nave 47 a voar à direita
# (ShipArt "nave47_voo", a mesma da intro). Só desenha; não recebe o rato.

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

var stars: Array = []   # [posição 0..1, camada 0..2, fase]
var clock: float = 0.0
var ship: Node2D = null
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 47
	for i in STAR_COUNT:
		stars.append([Vector2(rng.randf(), rng.randf()), rng.randi_range(0, 2), rng.randf() * TAU])
	ship = ShipArt.make("nave47_voo", SHIP_SIZE)
	ship.name = "MenuShip"
	add_child(ship)


func _process(delta: float) -> void:
	clock += delta
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

	# Estrelas: as mais próximas andam mais depressa e brilham mais.
	for star in stars:
		var layer: int = star[1]
		var speed := 4.0 + layer * 7.0
		var x := fposmod(star[0].x * size.x - clock * speed, size.x)
		var y: float = star[0].y * size.y
		var twinkle := 0.55 + 0.45 * sin(clock * (1.0 + layer) + star[2])
		var radius := 0.8 + layer * 0.6
		draw_circle(Vector2(x, y), radius, Color(STAR_COLOR, (0.35 + layer * 0.2) * twinkle))

	# Horizonte de um planeta, com a atmosfera em ciano.
	var center := Vector2(size.x * 0.5, size.y * 2.05)
	var radius := size.y * 1.35
	for i in 4:
		draw_circle(center, radius + 26.0 - i * 6.0, Color(UIStyle.ACCENT, 0.04 + i * 0.03))
	draw_circle(center, radius, PLANET)
	draw_arc(center, radius, PI * 1.15, PI * 1.85, 96, Color(UIStyle.ACCENT, 0.5), 2.0)
