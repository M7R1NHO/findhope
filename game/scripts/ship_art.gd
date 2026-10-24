extends Node2D

# Naves desenhadas por código, no estilo dos sprites.
#   "nave47":     a Nave 47 despenhada na superfície (casco amolgado, cockpit
#                 rachado, motores apagados a deitar fumo, faíscas).
#   "explorador": a nave do viajante no Hangar (inteira, branca e ciano,
#                 motores a brilhar, luzes de presença a piscar).
#   "nave47_voo": a Nave 47 inteira, a voar (intro e menu principal): os
#                 mesmos cinzentos, faixa amarela e cockpit, motores acesos.
#                 Com "drift" anda sozinha; "interference" (0 a 1) faz os
#                 motores falhar e a nave tremer.
# "size" é a caixa onde a nave cabe, centrada na origem. Só desenha: a
# colisão é da cena (Nave 47) ou de quem cria o nó (explorador).

const OUTLINE := Color(0.07, 0.07, 0.09)
const ACCENT := Color(0.88, 0.64, 0.17)
const CYAN := Color(0.25, 0.85, 0.85)
const RED := Color(0.85, 0.3, 0.25)
const LINE := 4.0

var style: String = "nave47"
var size: Vector2 = Vector2(660.0, 260.0)
var clock: float = 0.0
var drift: Vector2 = Vector2.ZERO
var interference: float = 0.0


static func make(ship_style: String, ship_size: Vector2) -> Node2D:
	var art = load("res://scripts/ship_art.gd").new()
	art.name = "ShipArt"
	art.style = ship_style
	art.size = ship_size
	return art


func _process(delta: float) -> void:
	clock += delta
	position += drift * delta
	queue_redraw()


func _draw() -> void:
	if style == "explorador":
		draw_explorer()
	elif style == "nave47_voo":
		draw_nave47_flying()
	else:
		draw_nave47()


# Pontos dados numa caixa de -1..1 passam para o tamanho da nave.
func fit(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * size.x / 2.0, p.y * size.y / 2.0))
	return out


func at(x: float, y: float) -> Vector2:
	return Vector2(x * size.x / 2.0, y * size.y / 2.0)


func shape(points: PackedVector2Array, fill: Color, width: float = LINE) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE, width)


func oval(center: Vector2, radius: Vector2, fill: Color, outline: bool = true) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	if outline:
		shape(points, fill, 3.0)
	else:
		draw_colored_polygon(points, fill)


# ---------------------------------------------------------------------------
# Nave 47 (despenhada)
# ---------------------------------------------------------------------------

func draw_nave47() -> void:
	var hull := Color(0.58, 0.61, 0.65)
	var hull_dark := Color(0.4, 0.43, 0.48)
	# Sombra e areia empurrada à volta do casco.
	oval(at(0.02, 0.62), Vector2(size.x * 0.5, size.y * 0.2), Color(0, 0, 0, 0.22), false)
	oval(at(0.9, 0.1), Vector2(size.x * 0.1, size.y * 0.35), Color(0.6, 0.42, 0.2, 0.5), false)

	# Asa de cima (inteira) e asa de baixo (partida).
	shape(fit([Vector2(-0.45, -0.62), Vector2(0.12, -0.62), Vector2(-0.12, -1.0), Vector2(-0.55, -1.0)]), hull_dark)
	draw_line(at(-0.5, -0.9), at(-0.1, -0.9), ACCENT, 6.0)
	shape(fit([Vector2(-0.45, 0.62), Vector2(0.05, 0.62), Vector2(-0.08, 0.8), Vector2(-0.2, 0.74), Vector2(-0.28, 0.95), Vector2(-0.52, 0.95)]), hull_dark)

	# Motores (atrás, à esquerda), apagados.
	for y in [-0.32, 0.32]:
		var nozzle := Rect2(at(-1.0, y - 0.2), Vector2(size.x * 0.1, size.y * 0.2))
		draw_rect(nozzle, Color(0.18, 0.19, 0.22))
		draw_rect(nozzle, OUTLINE, false, LINE)
		draw_circle(nozzle.position + Vector2(8.0, nozzle.size.y / 2.0), nozzle.size.y * 0.32, Color(0.35, 0.15, 0.08, 0.6 + 0.2 * sin(clock * 2.0 + y)))

	# Casco
	var body := fit([Vector2(-0.9, -0.55), Vector2(0.45, -0.68), Vector2(0.82, -0.42), Vector2(1.0, 0.0), Vector2(0.82, 0.42), Vector2(0.45, 0.68), Vector2(-0.9, 0.55)])
	shape(body, hull)
	# Placas do casco
	for x in [-0.6, -0.3, 0.0, 0.3]:
		draw_line(at(x, -0.6), at(x, 0.6), hull_dark, 2.0)
	draw_line(at(-0.9, 0.0), at(0.55, 0.0), hull_dark, 2.0)
	for x in [-0.75, -0.45, -0.15, 0.15]:
		for y in [-0.45, 0.45]:
			draw_circle(at(x, y), 2.5, Color(0.75, 0.78, 0.82))
	# Faixa amarela e número
	draw_rect(Rect2(at(-0.55, -0.6), Vector2(size.x * 0.08, size.y * 0.6)), ACCENT)
	draw_rect(Rect2(at(-0.55, -0.6), Vector2(size.x * 0.08, size.y * 0.6)), OUTLINE, false, 2.0)
	draw_string(ThemeDB.fallback_font, at(-0.3, 0.42), "47", HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.32), Color(0.2, 0.22, 0.26))
	draw_string(ThemeDB.fallback_font, at(-0.3, -0.18), "RIGHTSIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.1), Color(0.3, 0.32, 0.36))

	# Cockpit rachado
	var glass := fit([Vector2(0.5, -0.38), Vector2(0.78, -0.25), Vector2(0.9, 0.0), Vector2(0.78, 0.25), Vector2(0.5, 0.38), Vector2(0.44, 0.0)])
	shape(glass, Color(0.1, 0.3, 0.36))
	draw_line(at(0.52, -0.25), at(0.7, -0.18), Color(1, 1, 1, 0.5), 3.0)
	draw_polyline(fit([Vector2(0.62, 0.05), Vector2(0.7, -0.08), Vector2(0.76, 0.02), Vector2(0.84, -0.06)]), Color(0.85, 1.0, 1.0, 0.8), 2.0)
	draw_polyline(fit([Vector2(0.7, -0.08), Vector2(0.66, -0.22)]), Color(0.85, 1.0, 1.0, 0.8), 2.0)

	# Danos: queimaduras e um rombo com cabos à mostra.
	oval(at(-0.78, 0.3), Vector2(size.x * 0.06, size.y * 0.12), Color(0.1, 0.08, 0.06, 0.55), false)
	oval(at(0.32, -0.38), Vector2(size.x * 0.05, size.y * 0.09), Color(0.1, 0.08, 0.06, 0.5), false)
	var hole := fit([Vector2(0.06, 0.12), Vector2(0.16, 0.06), Vector2(0.22, 0.2), Vector2(0.14, 0.34), Vector2(0.04, 0.28)])
	shape(hole, Color(0.08, 0.08, 0.1), 3.0)
	draw_line(at(0.1, 0.2), at(0.2, 0.42), RED, 3.0)
	draw_line(at(0.13, 0.18), at(0.25, 0.32), Color(0.3, 0.5, 0.8), 3.0)
	if fmod(clock, 1.7) < 0.25:
		var spark := at(0.2, 0.42)
		for i in 5:
			var a := TAU * i / 5.0 + clock * 7.0
			draw_line(spark, spark + Vector2(cos(a), sin(a)) * 9.0, Color(1.0, 0.9, 0.4), 2.0)

	# Fumo a sair dos motores.
	for i in 7:
		var t := fmod(clock * 0.25 + i / 7.0, 1.0)
		var origin := at(-0.95, -0.32 if i % 2 == 0 else 0.32)
		var p := origin + Vector2(-t * size.x * 0.25, -t * size.y * 0.9 + sin(t * 6.0 + i) * 12.0)
		draw_circle(p, 10.0 + t * 26.0, Color(0.25, 0.24, 0.24, 0.35 * (1.0 - t)))


# ---------------------------------------------------------------------------
# Nave do viajante (Hangar)
# ---------------------------------------------------------------------------

func draw_explorer() -> void:
	var hull := Color(0.86, 0.88, 0.9)
	var trim := Color(0.2, 0.55, 0.58)
	oval(at(0.0, 0.75), Vector2(size.x * 0.45, size.y * 0.16), Color(0, 0, 0, 0.25), false)
	# Asas recuadas
	shape(fit([Vector2(-0.35, -0.4), Vector2(0.15, -0.4), Vector2(-0.3, -1.0), Vector2(-0.62, -1.0)]), hull.darkened(0.12))
	shape(fit([Vector2(-0.35, 0.4), Vector2(0.15, 0.4), Vector2(-0.3, 1.0), Vector2(-0.62, 1.0)]), hull.darkened(0.12))
	draw_line(at(-0.55, -0.92), at(-0.32, -0.92), trim, 5.0)
	draw_line(at(-0.55, 0.92), at(-0.32, 0.92), trim, 5.0)
	# Luzes de presença nas pontas das asas
	draw_circle(at(-0.6, -0.97), 5.0, RED if fmod(clock, 1.2) < 0.4 else RED.darkened(0.6))
	draw_circle(at(-0.6, 0.97), 5.0, Color(0.3, 0.9, 0.4) if fmod(clock + 0.6, 1.2) < 0.4 else Color(0.15, 0.4, 0.2))
	# Motores a brilhar
	var pulse := 0.75 + 0.25 * sin(clock * 5.0)
	for y in [-0.22, 0.22]:
		var flame := at(-1.0, y)
		draw_circle(flame + Vector2(-8.0, 0.0), size.y * 0.16 * pulse, Color(CYAN, 0.25))
		draw_circle(flame, size.y * 0.1 * pulse, Color(0.7, 1.0, 1.0, 0.7))
		var nozzle := Rect2(at(-0.95, y - 0.13), Vector2(size.x * 0.1, size.y * 0.26))
		draw_rect(nozzle, Color(0.3, 0.33, 0.37))
		draw_rect(nozzle, OUTLINE, false, 3.0)
	# Casco elegante
	var body := fit([Vector2(-0.85, -0.42), Vector2(0.3, -0.5), Vector2(0.75, -0.3), Vector2(1.0, 0.0), Vector2(0.75, 0.3), Vector2(0.3, 0.5), Vector2(-0.85, 0.42)])
	shape(body, hull)
	draw_line(at(-0.85, 0.0), at(0.4, 0.0), hull.darkened(0.15), 2.0)
	for x in [-0.55, -0.25, 0.05]:
		draw_line(at(x, -0.45), at(x, 0.45), hull.darkened(0.15), 2.0)
	draw_rect(Rect2(at(-0.7, -0.08), Vector2(size.x * 0.55, size.y * 0.16)), trim)
	draw_rect(Rect2(at(-0.7, -0.08), Vector2(size.x * 0.55, size.y * 0.16)), OUTLINE, false, 2.0)
	# Cockpit com reflexo
	var glass := fit([Vector2(0.42, -0.28), Vector2(0.75, -0.18), Vector2(0.88, 0.0), Vector2(0.75, 0.18), Vector2(0.42, 0.28), Vector2(0.36, 0.0)])
	shape(glass, Color(0.08, 0.2, 0.28), 3.0)
	draw_line(at(0.45, -0.18), at(0.68, -0.12), Color(1, 1, 1, 0.6), 3.0)
	# Luzes de navegação a correr ao longo da faixa
	for i in 5:
		var on := int(clock * 6.0) % 5 == i
		draw_circle(at(-0.62 + i * 0.12, 0.0), 3.0, CYAN if on else CYAN.darkened(0.6))


# ---------------------------------------------------------------------------
# Nave 47 a voar (intro, menu)
# ---------------------------------------------------------------------------

func draw_nave47_flying() -> void:
	var hull := Color(0.58, 0.61, 0.65)
	var hull_dark := Color(0.4, 0.43, 0.48)
	# Com interferência, a nave treme e os motores falham.
	var shake := Vector2.ZERO
	var engines := 1.0
	if interference > 0.0:
		shake = Vector2(sin(clock * 37.0), cos(clock * 29.0)) * 3.0 * interference
		if fmod(clock * 5.3, 1.0) < 0.35 * interference:
			engines = 0.25
	draw_set_transform(shake, sin(clock * 1.3) * 0.02 + shake.y * 0.004, Vector2.ONE)

	# Rasto dos motores
	var pulse := (0.8 + 0.2 * sin(clock * 9.0)) * engines
	for y in [-0.32, 0.32]:
		var nozzle := at(-1.0, y)
		for i in 16:
			var t := float(i) / 16.0
			draw_circle(nozzle + Vector2(-t * size.x * 0.5, 0.0), size.y * (0.12 - t * 0.08) * pulse, Color(ACCENT.lerp(Color(1.0, 0.4, 0.15), t), 0.28 * (1.0 - t) * pulse))
		draw_circle(nozzle + Vector2(-6.0, 0.0), size.y * 0.1 * pulse, Color(1.0, 0.95, 0.75, 0.9 * pulse))

	# Asas
	shape(fit([Vector2(-0.45, -0.62), Vector2(0.12, -0.62), Vector2(-0.12, -1.0), Vector2(-0.55, -1.0)]), hull_dark)
	shape(fit([Vector2(-0.45, 0.62), Vector2(0.12, 0.62), Vector2(-0.12, 1.0), Vector2(-0.55, 1.0)]), hull_dark)
	draw_line(at(-0.5, -0.9), at(-0.1, -0.9), ACCENT, 5.0)
	draw_line(at(-0.5, 0.9), at(-0.1, 0.9), ACCENT, 5.0)
	draw_circle(at(-0.52, -0.97), 4.0, RED if fmod(clock, 1.2) < 0.4 else RED.darkened(0.6))
	draw_circle(at(-0.52, 0.97), 4.0, Color(0.3, 0.9, 0.4) if fmod(clock + 0.6, 1.2) < 0.4 else Color(0.15, 0.4, 0.2))

	# Motores
	for y in [-0.32, 0.32]:
		var box := Rect2(at(-1.0, y - 0.2), Vector2(size.x * 0.1, size.y * 0.2))
		draw_rect(box, Color(0.18, 0.19, 0.22))
		draw_rect(box, OUTLINE, false, LINE)

	# Casco, placas, faixa e número
	var body := fit([Vector2(-0.9, -0.55), Vector2(0.45, -0.68), Vector2(0.82, -0.42), Vector2(1.0, 0.0), Vector2(0.82, 0.42), Vector2(0.45, 0.68), Vector2(-0.9, 0.55)])
	shape(body, hull)
	for x in [-0.6, -0.3, 0.0, 0.3]:
		draw_line(at(x, -0.6), at(x, 0.6), hull_dark, 2.0)
	draw_line(at(-0.9, 0.0), at(0.55, 0.0), hull_dark, 2.0)
	draw_rect(Rect2(at(-0.55, -0.6), Vector2(size.x * 0.08, size.y * 0.6)), ACCENT)
	draw_rect(Rect2(at(-0.55, -0.6), Vector2(size.x * 0.08, size.y * 0.6)), OUTLINE, false, 2.0)
	draw_string(ThemeDB.fallback_font, at(-0.3, 0.42), "47", HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.32), Color(0.2, 0.22, 0.26))
	draw_string(ThemeDB.fallback_font, at(-0.3, -0.18), "RIGHTSIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.1), Color(0.3, 0.32, 0.36))

	# Cockpit inteiro, com reflexo
	var glass := fit([Vector2(0.5, -0.38), Vector2(0.78, -0.25), Vector2(0.9, 0.0), Vector2(0.78, 0.25), Vector2(0.5, 0.38), Vector2(0.44, 0.0)])
	shape(glass, Color(0.1, 0.3, 0.36))
	draw_line(at(0.52, -0.25), at(0.7, -0.18), Color(1, 1, 1, 0.5), 3.0)
	# Com interferência, uma luz de aviso pisca no cockpit.
	if interference > 0.0 and fmod(clock, 0.6) < 0.3:
		draw_circle(at(0.62, 0.1), size.y * 0.05, RED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
