extends AnimatedSprite2D

# Sprite animado de uma personagem no mundo.
#
# Ligado a um CharacterBody2D (Player ou Atlas), escolhe a animação pela
# velocidade do corpo: para cima usa as costas, para baixo a frente e para os
# lados a vista de lado (espelhada para a esquerda). Parado, fica no IDLE da
# última direção.
# O quadrado de cor antigo (filho "Polygon2D") fica escondido; se os PNG não
# existirem, nada muda e o quadrado continua visível.
#
# Também serve para a criatura, sem corpo: monster() cria um sprite que só
# toca uma animação fixa.

const CharacterFrames := preload("res://scripts/character_frames.gd")

const MOVE_THRESHOLD := 5.0
# Uma direção nova só é aceite depois de durar este tempo (a seguir na
# diagonal, a velocidade oscila e a vista trocava a cada frame).
const FACING_HOLD := 0.12
# Inclinação (radianos) de quem anda de lado com as frames de frente.
const SIDE_LEAN := 0.12
# Mais do que isto numa frame é um teletransporte, não uma caminhada.
const TELEPORT_DISTANCE := 60.0

var body: CharacterBody2D = null
var character: String = ""
var facing: String = "front"
var facing_left: bool = false
var facing_time: float = 0.0
var pending_facing: String = ""
var base_position: Vector2 = Vector2.ZERO
var world_height: float = 84.0
var last_body_position: Vector2 = Vector2.INF


# Põe o sprite no corpo. height = altura no mundo, em píxeis. Os pés ficam
# na base da colisão (raio feet_y abaixo do centro).
static func attach(target: CharacterBody2D, character: String, height: float = 84.0, feet_y: float = 16.0) -> AnimatedSprite2D:
	var frames := CharacterFrames.frames_for(character)
	if target == null or frames == null:
		return null
	var sprite = load("res://scripts/character_sprite.gd").new()
	sprite.name = "CharacterSprite"
	sprite.sprite_frames = frames
	sprite.body = target
	sprite.character = character
	sprite.fit(height, feet_y)
	target.add_child(sprite)
	var old := target.get_node_or_null("Polygon2D")
	if old is CanvasItem:
		old.visible = false
	sprite.play("idle_front")
	return sprite


# Criatura (ou personagem) sem corpo, a tocar uma animação.
static func monster(parent: Node, animation: String = "idle_front", height: float = 110.0) -> AnimatedSprite2D:
	var frames := CharacterFrames.frames_for("monster")
	if parent == null or frames == null:
		return null
	var sprite = load("res://scripts/character_sprite.gd").new()
	sprite.name = "MonsterSprite"
	sprite.sprite_frames = frames
	sprite.fit(height, height / 2.0)
	parent.add_child(sprite)
	sprite.play(animation)
	return sprite


func fit(height: float, feet_y: float) -> void:
	var texture := sprite_frames.get_frame_texture("idle_front", 0)
	var factor := height / float(texture.get_height())
	scale = Vector2(factor, factor)
	position = Vector2(0.0, feet_y - height / 2.0)
	base_position = position
	world_height = height
	add_child(make_shadow(texture.get_height() * 0.2, texture.get_height() / 2.0 - 6.0))


# Sombra oval debaixo dos pés, como nas folhas de sprites.
func make_shadow(radius_x: float, offset_y: float) -> Node2D:
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(Vector2(cos(angle) * radius_x, offset_y + sin(angle) * radius_x * 0.28))
	shadow.polygon = points
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.show_behind_parent = true
	return shadow


func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var velocity := movement_velocity(delta)
	var moving := velocity.length() > MOVE_THRESHOLD
	if moving:
		var wanted_facing := "side"
		if abs(velocity.x) <= abs(velocity.y):
			wanted_facing = "back" if velocity.y < 0.0 else "front"
		update_facing(wanted_facing, delta, animation.begins_with("idle_"))
		if abs(velocity.x) > MOVE_THRESHOLD:
			facing_left = velocity.x < 0.0
	else:
		pending_facing = ""
	var wanted := ("walk_" if moving else "idle_") + facing
	if not sprite_frames.has_animation(wanted):
		wanted = ("walk_" if moving else "idle_") + "front"
	if animation != wanted:
		play(wanted)
	# As frames de lado olham para a direita; para a esquerda espelha.
	flip_h = facing_left and facing == "side"
	apply_side_lean(moving)


# Velocidade do corpo; se o corpo for movido por um tween (cutscenes, como o
# Hangar) a velocidade fica a zero e usa-se o deslocamento desde a frame
# anterior, para a animação também andar.
func movement_velocity(delta: float) -> Vector2:
	var velocity := body.velocity
	var position_now := body.global_position
	if velocity.length() <= MOVE_THRESHOLD and last_body_position != Vector2.INF and delta > 0.0:
		var moved := position_now - last_body_position
		if moved.length() < TELEPORT_DISTANCE:
			velocity = moved / delta
	last_body_position = position_now
	return velocity


# Muda de vista: logo, se estava parado; senão só depois de a nova direção
# durar FACING_HOLD (sem trocas de vista a cada frame).
func update_facing(wanted_facing: String, delta: float, from_idle: bool) -> void:
	if wanted_facing == facing:
		pending_facing = ""
		facing_time += delta
		return
	if from_idle:
		facing = wanted_facing
		facing_time = 0.0
		pending_facing = ""
		return
	if pending_facing != wanted_facing:
		pending_facing = wanted_facing
		facing_time = 0.0
	facing_time += delta
	if facing_time >= FACING_HOLD:
		facing = wanted_facing
		pending_facing = ""
		facing_time = 0.0


# Quem usa as frames de frente para andar de lado (o Atlas) inclina-se para
# o lado do movimento, com os pés no mesmo sítio. O skew do Godot desloca
# um ponto à altura y em -sin(skew) * y; os pés (y = metade da altura) voltam
# ao sítio somando sin(lean) * metade da altura.
func apply_side_lean(moving: bool) -> void:
	var lean := 0.0
	if moving and facing == "side" and character in CharacterFrames.SIDE_FROM_FRONT:
		lean = -SIDE_LEAN if facing_left else SIDE_LEAN
	skew = lean
	position = base_position + Vector2(sin(lean) * world_height / 2.0, 0.0)
