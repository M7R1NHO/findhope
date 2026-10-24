extends Control

# Planta da Sala de Controlo durante o confronto (vista de cima).
#
# Só desenha: lê o estado do confronto (phase3_boss.gd) em cada frame e
# nunca o altera. Tudo é feito com _draw() (retângulos, círculos, arcos),
# sem imagens.
#
#   - portas que deslizam a fechar/abrir;
#   - brilho vermelho no corredor, que cresce com a temperatura do sensor
#     (a criatura em si não se vê: não há câmaras);
#   - termómetros junto a cada porta;
#   - anel de progresso do Hangar, Player na consola e Atlas a trabalhar;
#   - tremor quando a criatura bate numa porta, clarão vermelho e a
#     silhueta da criatura quando entra, luzes de emergência sem energia.

const UIStyle := preload("res://scripts/ui_style.gd")
const CharacterFrames := preload("res://scripts/character_frames.gd")

const VIEW_SIZE := Vector2(1000.0, 300.0)
const ROOM := Rect2(200.0, 14.0, 600.0, 272.0)
const WALL := 12.0
const DOOR_HEIGHT := 92.0
const DOOR_SPEED := 6.0            # fração da porta por segundo (~0,17 s)
const INTRUDER_TIME := 1.4         # quanto tempo a criatura fica à vista ao entrar
const INTRUDER_WALK := 0.5         # dos quais a passar a porta

const FLOOR_COLOR := Color(0.11, 0.13, 0.16)
const GRID_COLOR := Color(0.16, 0.19, 0.23)
const WALL_COLOR := Color(0.55, 0.62, 0.68)
const CORRIDOR_COLOR := Color(0.07, 0.08, 0.1)
const DOOR_COLOR := Color(0.36, 0.4, 0.45)
const HAZARD := Color(0.85, 0.68, 0.16)
const HEAT := Color(1.0, 0.32, 0.12)
const ATLAS_BODY := Color(0.95, 0.85, 0.3)
const PLAYER_BODY := Color(0.88, 0.92, 0.95)

var boss: Node = null
var clock: float = 0.0
var door_amount: Dictionary = {"left": 0.0, "right": 0.0}   # 0 aberta, 1 fechada
var shake: float = 0.0
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var knock_side: String = ""
var knock_time: float = 0.0
var intruder_side: String = ""
var intruder_time: float = 0.0
var base_offset: Vector2 = Vector2.ZERO
var spark_rng := RandomNumberGenerator.new()   # só para efeitos; não mexe no confronto


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(target: Node) -> void:
	boss = target
	boss.door_knocked.connect(_on_door_knocked)
	boss.creature_entered.connect(_on_creature_entered)


func _on_door_knocked(side: String) -> void:
	knock_side = side
	knock_time = 0.6
	shake = 8.0
	flash = 0.25
	flash_color = Color(1.0, 1.0, 1.0)


func _on_creature_entered(side: String) -> void:
	intruder_side = side
	intruder_time = INTRUDER_TIME
	shake = 14.0
	flash = 0.6
	flash_color = Color(0.9, 0.05, 0.05)


func _process(delta: float) -> void:
	clock += delta
	if boss != null:
		for side in ["left", "right"]:
			var target: float = 1.0 if boss.doors_closed[side] else 0.0
			door_amount[side] = move_toward(door_amount[side], target, DOOR_SPEED * delta)
	shake = max(0.0, shake - 30.0 * delta)
	flash = max(0.0, flash - 1.2 * delta)
	knock_time = max(0.0, knock_time - delta)
	intruder_time = max(0.0, intruder_time - delta)
	queue_redraw()


# 0 a 1: quão quente está o lado (12 °C → 0, 39 °C → 1).
func heat_of(side: String) -> float:
	if boss == null:
		return 0.0
	return clamp((float(boss.sensor_readings[side]) - 12.0) / 27.0, 0.0, 1.0)


func door_rect(side: String) -> Rect2:
	var y := ROOM.get_center().y - DOOR_HEIGHT / 2.0
	var x := ROOM.position.x - WALL / 2.0 if side == "left" else ROOM.end.x - WALL / 2.0
	return Rect2(x, y, WALL, DOOR_HEIGHT)


func _draw() -> void:
	if boss == null:
		return
	var offset := Vector2.ZERO
	if shake > 0.0:
		offset = Vector2(spark_rng.randf_range(-shake, shake), spark_rng.randf_range(-shake, shake)) * 0.5
	base_offset = offset + (size - VIEW_SIZE) / 2.0
	draw_set_transform(base_offset, 0.0, Vector2.ONE)

	draw_corridors()
	draw_room()
	for side in ["left", "right"]:
		draw_door(side)
		draw_thermometer(side)
	draw_hangar_ring()
	draw_console()
	draw_player(Vector2(470.0, 96.0))
	draw_atlas(Vector2(532.0, 96.0))
	if intruder_time > 0.0:
		draw_intruder(intruder_side)
	if boss.power_out:
		draw_power_out()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(flash_color, flash * 0.5))


func draw_corridors() -> void:
	var center_y := ROOM.get_center().y
	for side in ["left", "right"]:
		var x := 0.0 if side == "left" else ROOM.end.x
		var corridor := Rect2(x, center_y - DOOR_HEIGHT / 2.0 - 8.0, ROOM.position.x, DOOR_HEIGHT + 16.0)
		draw_rect(corridor, CORRIDOR_COLOR)
		# Riscas no chão do corredor, para dar profundidade.
		for i in 6:
			var line_x := corridor.position.x + 18.0 + i * 30.0
			draw_line(Vector2(line_x, corridor.position.y + 6.0), Vector2(line_x, corridor.end.y - 6.0), Color(0.12, 0.13, 0.16), 2.0)
		# Calor: brilho que cresce com a leitura do sensor.
		var heat := heat_of(side)
		if heat > 0.05:
			var pulse := 0.85 + 0.15 * sin(clock * 6.0)
			draw_rect(corridor, Color(HEAT, heat * 0.35 * pulse))
			var door_x := ROOM.position.x - 30.0 if side == "left" else ROOM.end.x + 30.0
			for ring in 6:
				draw_circle(Vector2(door_x, center_y), 18.0 + ring * 16.0, Color(HEAT, heat * 0.09 * pulse))


func draw_room() -> void:
	draw_rect(ROOM, FLOOR_COLOR)
	var step := 34.0
	var x := ROOM.position.x + step
	while x < ROOM.end.x:
		draw_line(Vector2(x, ROOM.position.y), Vector2(x, ROOM.end.y), GRID_COLOR, 1.0)
		x += step
	var y := ROOM.position.y + step
	while y < ROOM.end.y:
		draw_line(Vector2(ROOM.position.x, y), Vector2(ROOM.end.x, y), GRID_COLOR, 1.0)
		y += step
	# Paredes, com as aberturas das portas.
	var door_top := ROOM.get_center().y - DOOR_HEIGHT / 2.0
	var door_bottom := door_top + DOOR_HEIGHT
	draw_rect(Rect2(ROOM.position.x - WALL / 2.0, ROOM.position.y - WALL / 2.0, ROOM.size.x + WALL, WALL), WALL_COLOR)
	draw_rect(Rect2(ROOM.position.x - WALL / 2.0, ROOM.end.y - WALL / 2.0, ROOM.size.x + WALL, WALL), WALL_COLOR)
	for wall_x in [ROOM.position.x - WALL / 2.0, ROOM.end.x - WALL / 2.0]:
		draw_rect(Rect2(wall_x, ROOM.position.y, WALL, door_top - ROOM.position.y), WALL_COLOR)
		draw_rect(Rect2(wall_x, door_bottom, WALL, ROOM.end.y - door_bottom), WALL_COLOR)


func draw_door(side: String) -> void:
	var opening := door_rect(side)
	var amount: float = door_amount[side]
	# A porta desce do topo da abertura.
	if amount > 0.01:
		var slab := Rect2(opening.position.x - 3.0, opening.position.y, opening.size.x + 6.0, opening.size.y * amount)
		var color := DOOR_COLOR
		if knock_side == side and knock_time > 0.0:
			color = color.lerp(Color.WHITE, knock_time)
		draw_rect(slab, color)
		var stripe_y := slab.position.y + 4.0
		while stripe_y < slab.end.y - 6.0:
			draw_rect(Rect2(slab.position.x, stripe_y, slab.size.x, 5.0), HAZARD)
			stripe_y += 14.0
	# Luz de estado por cima da porta: verde aberta, ciano fechada.
	var light := Vector2(opening.get_center().x, opening.position.y - 14.0)
	var light_color := UIStyle.ACCENT if boss.doors_closed[side] else Color(0.3, 0.8, 0.35)
	if boss.power_out:
		light_color = Color(0.3, 0.3, 0.3)
	draw_circle(light, 5.0, light_color)
	var key := "A" if side == "left" else "D"
	var font := get_theme_default_font()
	var label_x := opening.position.x - 40.0 if side == "left" else opening.end.x + 24.0
	draw_string(font, Vector2(label_x, opening.end.y + 28.0), "[" + key + "]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyle.TEXT_MUTED)


func draw_thermometer(side: String) -> void:
	var heat := heat_of(side)
	var x := ROOM.position.x + 34.0 if side == "left" else ROOM.end.x - 46.0
	var tube := Rect2(x, ROOM.position.y + 40.0, 12.0, 150.0)
	draw_rect(tube, Color(0.05, 0.06, 0.08))
	var fill_height: float = tube.size.y * max(0.08, heat)
	var cold := Color(0.25, 0.55, 0.9)
	var fill_color := cold.lerp(HEAT, heat)
	draw_rect(Rect2(tube.position.x, tube.end.y - fill_height, tube.size.x, fill_height), fill_color)
	draw_rect(tube, Color(0.4, 0.45, 0.5), false, 1.0)
	draw_circle(Vector2(tube.get_center().x, tube.end.y + 8.0), 10.0, fill_color)
	# Marca dos 28 °C (zona de perigo).
	var mark_y := tube.end.y - tube.size.y * ((28.0 - 12.0) / 27.0)
	draw_line(Vector2(tube.position.x - 4.0, mark_y), Vector2(tube.end.x + 4.0, mark_y), UIStyle.DANGER, 2.0)
	var font := get_theme_default_font()
	var text := str(snapped(float(boss.sensor_readings[side]), 0.1)) + "°"
	draw_string(font, Vector2(tube.position.x - 14.0, tube.end.y + 40.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		UIStyle.DANGER if float(boss.sensor_readings[side]) >= 28.0 else UIStyle.TEXT)


func draw_hangar_ring() -> void:
	var center := Vector2(500.0, 205.0)
	var progress: float = 1.0 - float(boss.time_left) / float(boss.DURATION)
	draw_arc(center, 46.0, 0.0, TAU, 48, Color(0.18, 0.22, 0.26), 8.0)
	draw_arc(center, 46.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, UIStyle.ACCENT, 8.0)
	var font := get_theme_default_font()
	var seconds := str(int(ceil(float(boss.time_left)))) + " s"
	draw_string(font, center + Vector2(-46.0, 6.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, 92.0, 20, UIStyle.TEXT)
	draw_string(font, center + Vector2(-46.0, 74.0), "HANGAR", HORIZONTAL_ALIGNMENT_CENTER, 92.0, 13, UIStyle.TEXT_MUTED)


func draw_console() -> void:
	var desk := Rect2(420.0, 26.0, 160.0, 40.0)
	draw_rect(desk, Color(0.2, 0.24, 0.29))
	for i in 3:
		var screen := Rect2(desk.position.x + 10.0 + i * 50.0, desk.position.y + 7.0, 40.0, 24.0)
		var glow := 0.6 + 0.4 * sin(clock * 3.0 + i)
		var color := Color(0.15, 0.55, 0.55).lerp(UIStyle.ACCENT, glow)
		if boss.power_out:
			color = Color(0.12, 0.14, 0.16)
		draw_rect(screen, color)


# Desenha um sprite com os pés em "feet". Devolve false se não houver PNG.
func draw_sprite(texture: Texture2D, feet: Vector2, height: float, tint: Color = Color.WHITE, flip: bool = false) -> bool:
	if texture == null:
		return false
	var width := height * texture.get_width() / texture.get_height()
	var rect := Rect2(feet.x - width / 2.0, feet.y - height, width, height)
	draw_ellipse_shadow(feet, min(width, height * 0.6) * 0.35)
	if flip:
		# Espelho horizontal à volta dos pés.
		draw_set_transform(base_offset + Vector2(feet.x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(texture, rect, false, tint)
	if flip:
		draw_set_transform(base_offset, 0.0, Vector2.ONE)
	return true


func draw_ellipse_shadow(feet: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(feet + Vector2(cos(angle) * radius, sin(angle) * radius * 0.3))
	draw_colored_polygon(points, Color(0, 0, 0, 0.3))


func draw_player(at: Vector2) -> void:
	var bob := sin(clock * 2.0) * 1.5
	var body := at + Vector2(0.0, bob)
	# De costas, virado para a consola.
	if draw_sprite(CharacterFrames.first_texture("player", "idle_back"), at + Vector2(0.0, 26.0), 56.0):
		return
	draw_circle(body + Vector2(0.0, 14.0), 13.0, Color(0.7, 0.75, 0.8))     # mochila / corpo
	draw_circle(body, 13.0, PLAYER_BODY)                                       # capacete
	draw_arc(body + Vector2(0.0, -2.0), 8.0, PI * 1.1, PI * 1.9, 12, UIStyle.ACCENT, 4.0)   # visor


func draw_atlas(at: Vector2) -> void:
	var damaged: bool = boss.atlas_damaged
	var bob := sin(clock * 2.6 + 1.0) * 1.5
	var body := at + Vector2(0.0, bob)
	var color := ATLAS_BODY.lerp(Color(0.8, 0.3, 0.25), 0.5) if damaged else ATLAS_BODY
	var tint := Color(1.0, 0.55, 0.5) if damaged else Color.WHITE
	if not draw_sprite(CharacterFrames.first_texture("atlas", "idle_front"), at + Vector2(0.0, 26.0 + bob), 56.0, tint):
		draw_rect(Rect2(body.x - 11.0, body.y + 2.0, 22.0, 24.0), color)
		draw_circle(body, 11.0, color)
		var eye_color := UIStyle.DANGER if damaged else UIStyle.ACCENT
		draw_circle(body + Vector2(0.0, -1.0), 4.0, eye_color)
		draw_line(body + Vector2(0.0, -11.0), body + Vector2(0.0, -20.0), color, 2.0)
		if fmod(clock, 1.0) < 0.5:
			draw_circle(body + Vector2(0.0, -21.0), 2.5, eye_color)
	# Feixe de dados para a consola enquanto abre o Hangar.
	if boss.running and not boss.power_out:
		var start := body + Vector2(0.0, -12.0)
		var finish := Vector2(540.0, 66.0)
		var segments := 6
		for i in segments:
			if (i + int(clock * 8.0)) % 2 == 0:
				draw_line(start.lerp(finish, float(i) / segments), start.lerp(finish, float(i + 1) / segments), Color(UIStyle.ACCENT, 0.7), 2.0)
	if damaged:
		for i in 3:
			var spark := body + Vector2(spark_rng.randf_range(-16.0, 16.0), spark_rng.randf_range(-14.0, 24.0))
			if spark_rng.randf() < 0.4:
				draw_line(spark, spark + Vector2(spark_rng.randf_range(-6.0, 6.0), spark_rng.randf_range(-6.0, 6.0)), HAZARD, 2.0)


# Frame da animação da criatura ao fim de "time" segundos (null sem PNG).
func monster_frame(animation: String, time: float) -> Texture2D:
	var frames := CharacterFrames.frames_for("monster")
	if frames == null or not frames.has_animation(animation):
		return null
	var count := frames.get_frame_count(animation)
	return frames.get_frame_texture(animation, int(time * frames.get_animation_speed(animation)) % count)


# A criatura só aparece no instante em que entra.
func draw_intruder(side: String) -> void:
	var opening := door_rect(side)
	var center := Vector2(opening.get_center().x + (50.0 if side == "left" else -50.0), opening.get_center().y)
	var alpha: float = clamp(intruder_time, 0.0, 1.0)
	# Entra a andar pela porta (primeiro meio segundo) e depois ataca.
	# As frames da criatura olham para a direita: pela porta direita, espelha.
	var elapsed: float = INTRUDER_TIME - intruder_time
	var walking: bool = elapsed < INTRUDER_WALK
	var walk_from := Vector2(opening.get_center().x + (-40.0 if side == "left" else 40.0), opening.get_center().y)
	var feet := walk_from.lerp(center, clamp(elapsed / INTRUDER_WALK, 0.0, 1.0)) + Vector2(0.0, 40.0)
	var texture := monster_frame("walk_side" if walking else "attack", elapsed)
	if draw_sprite(texture, feet, 96.0, Color(1, 1, 1, alpha), side == "right"):
		return
	draw_circle(center, 34.0, Color(0.03, 0.02, 0.02, alpha))
	draw_circle(center + Vector2(0.0, -24.0), 22.0, Color(0.03, 0.02, 0.02, alpha))
	draw_circle(center + Vector2(-8.0, -26.0), 4.0, Color(1.0, 0.15, 0.1, alpha))
	draw_circle(center + Vector2(8.0, -26.0), 4.0, Color(1.0, 0.15, 0.1, alpha))


func draw_power_out() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.0, 0.0, 0.0, 0.55))
	if fmod(clock, 0.8) < 0.4:
		for corner in [ROOM.position + Vector2(16, 16), Vector2(ROOM.end.x - 16, ROOM.position.y + 16),
				Vector2(ROOM.position.x + 16, ROOM.end.y - 16), ROOM.end - Vector2(16, 16)]:
			draw_circle(corner, 14.0, Color(0.9, 0.1, 0.1, 0.5))
	var font := get_theme_default_font()
	draw_string(font, Vector2(0.0, ROOM.position.y + 40.0), "SEM ENERGIA", HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, 22, UIStyle.DANGER)
