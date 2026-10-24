extends Node2D

# A Sala de Controlo no mundo (Phase 3, sala 2), desenhada a partir da planta
# do confronto (phase3_boss_view.gd), para a sala onde se anda ser a mesma
# que aparece no minijogo:
#
#   - a consola com os três ecrãs, ao centro, encostada à parede de cima;
#   - um termómetro junto a cada porta, com a marca dos 28 °C;
#   - a luz por cima de cada porta (verde aberta, ciano fechada);
#   - o anel do Hangar no chão, que fica cheio depois do confronto;
#   - o brilho vermelho no corredor do lado que aquece.
#
# Só desenha. A colisão da consola é posta pelo phase3_layout.gd, e quem
# muda "awake", "heat" e "hangar_progress" é a animação da sala
# (phase3_layout.play_control_room_intro) e o fim do confronto.

const BossView := preload("res://scripts/phase3_boss_view.gd")
const UIStyle := preload("res://scripts/ui_style.gd")

const DESK_COLOR := Color(0.2, 0.24, 0.29)
const SCREEN_OFF := Color(0.12, 0.14, 0.16)
const OUTLINE := Color(0.07, 0.07, 0.09)

var layout: Node2D = null
var room_size: Vector2 = Vector2(1000.0, 453.0)
var corridor_size: Vector2 = Vector2(220.0, 180.0)
var clock: float = 0.0
# 0 ecrãs apagados, 1 ligados.
var awake: float = 0.0
# 0 a 1, como no confronto (12 °C a 39 °C).
var heat: Dictionary = {"left": 0.0, "right": 0.0}
var hangar_progress: float = 0.0
# Enquanto houver Atlas aqui, desenha o feixe de dados até à consola.
var beam_from: Node2D = null


func _ready() -> void:
	name = "ControlRoomArt"
	z_index = 2


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


# Ponto da planta do confronto -> posição local nesta sala.
func p(view_point: Vector2) -> Vector2:
	return BossView.to_room(view_point, room_size)


func scale_factor() -> float:
	return room_size.x / BossView.ROOM.size.x


func rect(view_rect: Rect2) -> Rect2:
	return Rect2(p(view_rect.position), view_rect.size * scale_factor())


# Posições (locais à sala) onde o Player e o Atlas ficam na consola. São os
# pés dos sprites; o corpo fica 16 px acima (CharacterSprite.attach).
func player_spot() -> Vector2:
	return p(BossView.PLAYER_FEET) - Vector2(0.0, 16.0)


func atlas_spot() -> Vector2:
	return p(BossView.ATLAS_FEET) - Vector2(0.0, 16.0)


func console_rect() -> Rect2:
	return rect(BossView.CONSOLE)


func temperature(side: String) -> float:
	return 12.0 + 27.0 * float(heat[side])


func door_closed(side: String) -> bool:
	if layout == null or not is_instance_valid(layout):
		return false
	if side == "right":
		return not layout.hangar_door.is_empty() and layout.hangar_door["visual"].visible
	for door in layout.phase3_exit_doors:
		if String(door["body"].name) == "Porta_Entrada_Criatura":
			return door["visual"].visible
	return false


func _draw() -> void:
	draw_corridor_heat()
	draw_hangar_ring()
	draw_console()
	for side in ["left", "right"]:
		draw_thermometer(side)
		draw_door_light(side)
	draw_beam()


func draw_corridor_heat() -> void:
	for side in ["left", "right"]:
		var amount: float = heat[side]
		if amount <= 0.05:
			continue
		var pulse := 0.85 + 0.15 * sin(clock * 6.0)
		var edge := room_size.x / 2.0
		var x := -edge - corridor_size.x if side == "left" else edge
		draw_rect(Rect2(x, -corridor_size.y / 2.0, corridor_size.x, corridor_size.y), Color(BossView.HEAT, amount * 0.35 * pulse))
		var door := Vector2(-edge - 50.0 if side == "left" else edge + 50.0, 0.0)
		for ring in 6:
			draw_circle(door, 30.0 + ring * 26.0, Color(BossView.HEAT, amount * 0.09 * pulse))


func draw_hangar_ring() -> void:
	var center := p(BossView.RING_CENTER)
	var radius := BossView.RING_RADIUS * scale_factor()
	var width := 8.0 * scale_factor()
	draw_circle(center, radius + width, Color(0.08, 0.09, 0.11, 0.8))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.18, 0.22, 0.26), width)
	if hangar_progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * clamp(hangar_progress, 0.0, 1.0), 64, UIStyle.ACCENT, width)
	draw_arc(center, radius + width / 2.0 + 2.0, 0.0, TAU, 64, OUTLINE, 3.0)


func draw_console() -> void:
	var desk := console_rect()
	var k := scale_factor()
	draw_rect(desk, DESK_COLOR)
	draw_rect(desk, OUTLINE, false, 4.0)
	for i in 3:
		var screen := Rect2(desk.position + Vector2((10.0 + i * 50.0) * k, 7.0 * k), Vector2(40.0, 24.0) * k)
		var glow := 0.6 + 0.4 * sin(clock * 3.0 + i)
		var lit := Color(0.15, 0.55, 0.55).lerp(UIStyle.ACCENT, glow)
		# Ao ligar, os ecrãs piscam antes de ficarem acesos.
		var on: float = awake
		if awake > 0.0 and awake < 1.0 and fmod(clock * 13.0 + i * 1.7, 1.0) < 0.35:
			on = 0.0
		draw_rect(screen, SCREEN_OFF.lerp(lit, on))
		draw_rect(screen, OUTLINE, false, 2.0)


func draw_thermometer(side: String) -> void:
	var amount: float = heat[side]
	var tube := rect(BossView.thermo_rect(side))
	var k := scale_factor()
	draw_rect(tube, Color(0.05, 0.06, 0.08))
	var fill_height: float = tube.size.y * max(0.08, amount)
	var fill_color := Color(0.25, 0.55, 0.9).lerp(BossView.HEAT, amount)
	draw_rect(Rect2(tube.position.x, tube.end.y - fill_height, tube.size.x, fill_height), fill_color)
	draw_rect(tube, OUTLINE, false, 3.0)
	draw_circle(Vector2(tube.get_center().x, tube.end.y + 8.0 * k), 10.0 * k, fill_color)
	var mark_y := tube.end.y - tube.size.y * ((28.0 - 12.0) / 27.0)
	draw_line(Vector2(tube.position.x - 6.0, mark_y), Vector2(tube.end.x + 6.0, mark_y), UIStyle.DANGER, 3.0)
	var text := str(snapped(temperature(side), 0.1)) + "°"
	draw_string(ThemeDB.fallback_font, Vector2(tube.position.x - 18.0, tube.end.y + 52.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.DANGER if temperature(side) >= 28.0 else UIStyle.TEXT)


func draw_door_light(side: String) -> void:
	var view := BossView.ROOM
	var x := view.position.x if side == "left" else view.end.x
	var light := p(Vector2(x, view.get_center().y - BossView.DOOR_HEIGHT / 2.0 - 14.0))
	var color := UIStyle.ACCENT if door_closed(side) else Color(0.3, 0.8, 0.35)
	draw_circle(light, 9.0, OUTLINE)
	draw_circle(light, 7.0, color)


func draw_beam() -> void:
	if beam_from == null or not is_instance_valid(beam_from):
		return
	var start := to_local(beam_from.global_position) + Vector2(0.0, -40.0)
	var desk := console_rect()
	var finish := Vector2(desk.get_center().x + 30.0, desk.end.y)
	var segments := 8
	for i in segments:
		if (i + int(clock * 8.0)) % 2 == 0:
			draw_line(start.lerp(finish, float(i) / segments), start.lerp(finish, float(i + 1) / segments), Color(UIStyle.ACCENT, 0.7), 3.0)


# Riscas amarelas nas portas da sala, como no confronto.
class DoorStripes extends Node2D:
	var size: Vector2 = Vector2(32.0, 240.0)

	func _draw() -> void:
		var y := -size.y / 2.0 + 8.0
		while y < size.y / 2.0 - 10.0:
			draw_rect(Rect2(-size.x / 2.0, y, size.x, 8.0), BossView.HAZARD)
			y += 24.0


static func make_door_stripes(door_size: Vector2) -> Node2D:
	var stripes := DoorStripes.new()
	stripes.name = "HazardStripes"
	stripes.size = door_size
	stripes.set_meta("world_style", true)
	return stripes
