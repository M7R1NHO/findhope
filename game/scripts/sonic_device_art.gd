extends Node2D

# Dispositivo sónico do Atlas, desenhado em código no estilo dos sprites
# (contorno escuro, cinzento e ciano). Fica preso ao ombro do Atlas depois de
# o equipamento ser ligado (sonic_equipment.gd) e aparece também na luta.
#
#   SonicDeviceArt.mount_on(atlas)   # prende ao ombro e segue a vista
#   device.pulse()                   # brilho curto (ao disparar)

const OUTLINE := Color(0.07, 0.07, 0.09)
const BODY := Color(0.36, 0.4, 0.44)
const BODY_DARK := Color(0.22, 0.25, 0.28)
const CYAN := Color(0.3, 0.95, 0.95)
const NODE_NAME := "SonicDevice"

# Ombro direito do Atlas no mundo (sprite de 84 px, pés 16 px abaixo do centro).
const SHOULDER_FRONT := Vector2(13.0, -24.0)
const SHOULDER_SIDE := Vector2(-11.0, -26.0)

var clock: float = 0.0
var glow: float = 0.0
var follow_sprite: AnimatedSprite2D = null


static func make(device_scale: float = 1.0) -> Node2D:
	var art = load("res://scripts/sonic_device_art.gd").new()
	art.name = NODE_NAME
	art.scale = Vector2(device_scale, device_scale)
	return art


# Prende o dispositivo ao Atlas (uma vez só). Devolve o nó.
static func mount_on(atlas: Node2D) -> Node2D:
	if atlas == null:
		return null
	var existing := atlas.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing
	var art := make()
	art.follow_sprite = atlas.get_node_or_null("CharacterSprite")
	art.position = SHOULDER_FRONT
	art.z_index = 1
	atlas.add_child(art)
	return art


func pulse() -> void:
	glow = 1.0


func _process(delta: float) -> void:
	clock += delta
	glow = maxf(0.0, glow - delta * 2.5)
	if follow_sprite != null and is_instance_valid(follow_sprite):
		follow_view()
	queue_redraw()


# De frente e de costas fica no ombro direito; de lado fica nas costas.
func follow_view() -> void:
	match follow_sprite.facing:
		"side":
			position = Vector2(-SHOULDER_SIDE.x if follow_sprite.facing_left else SHOULDER_SIDE.x, SHOULDER_SIDE.y)
		"back":
			position = Vector2(-SHOULDER_FRONT.x, SHOULDER_FRONT.y)
		_:
			position = SHOULDER_FRONT


func _draw() -> void:
	# Suporte preso ao ombro
	draw_rect(Rect2(-3.0, 2.0, 6.0, 6.0), BODY_DARK)
	draw_rect(Rect2(-3.0, 2.0, 6.0, 6.0), OUTLINE, false, 1.5)
	# Corpo
	var body := Rect2(-8.0, -6.0, 16.0, 10.0)
	draw_rect(body, BODY)
	draw_rect(Rect2(-8.0, 0.0, 16.0, 4.0), BODY_DARK)
	draw_rect(body, OUTLINE, false, 2.0)
	# Altifalante com anéis
	var center := Vector2(0.0, -9.0)
	var light := CYAN.lerp(Color.WHITE, glow * 0.6)
	draw_circle(center, 6.5, OUTLINE)
	draw_circle(center, 5.0, Color(0.08, 0.2, 0.24))
	var beat := 0.5 + 0.5 * sin(clock * 4.0)
	draw_arc(center, 3.6, 0.0, TAU, 16, Color(light, 0.55 + 0.45 * maxf(beat, glow)), 1.5, true)
	draw_circle(center, 1.6, light)
	# Luz de estado
	draw_circle(Vector2(5.0, -1.5), 1.2, light)
	if glow > 0.0:
		draw_circle(center, 9.0 + 8.0 * (1.0 - glow), Color(CYAN, 0.45 * glow))
