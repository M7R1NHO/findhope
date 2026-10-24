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

var body: CharacterBody2D = null
var facing: String = "front"
var facing_left: bool = false


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


func _process(_delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var velocity := body.velocity
	var moving := velocity.length() > MOVE_THRESHOLD
	if moving:
		if abs(velocity.x) > abs(velocity.y):
			facing = "side"
		else:
			facing = "back" if velocity.y < 0.0 else "front"
		if abs(velocity.x) > MOVE_THRESHOLD:
			facing_left = velocity.x < 0.0
	var wanted := ("walk_" if moving else "idle_") + facing
	if not sprite_frames.has_animation(wanted):
		wanted = ("walk_" if moving else "idle_") + "front"
	if animation != wanted:
		play(wanted)
	# As frames de lado olham para a direita; para a esquerda espelha.
	flip_h = facing_left and facing == "side"
