extends Node2D

# A criatura no mundo: sai de uma conduta no chão, procura, aproxima-se do
# Player e volta para a conduta. Usada no HIDEINICIAL, nos encontros dos
# corredores, nos esconderijos das salas e antes do Game Over do RUN.
#
# É só visual: não tem colisão e não decide nada. Quem a usa
# (alien_encounter_manager.gd) diz o que fazer e espera pelos sinais:
#
#   var creature := CreatureActor.spawn(parent, vent_global_position)
#   creature.emerge_then_search(waypoints)     # sai e procura
#   creature.approach(player)                  # vai até ao Player -> reached
#   creature.go_back()                         # volta à conduta  -> gone
#
# Sprites: sprites/characters/mutant/ (emerge_0..4, search_0..4,
# retreat_0..4), recortados da folha "MONSTRO - MUTANTE (NOVAS ANIMAÇÕES)".
# Todas as imagens têm o mesmo tamanho, com o centro da conduta no mesmo
# píxel (VENT_CENTER), por isso a conduta não salta entre frames. Para
# andar até ao Player usa os sprites de sempre da criatura (monster).

signal emerged
signal reached
signal gone

const CharacterFrames := preload("res://scripts/character_frames.gd")
const CharacterSprite := preload("res://scripts/character_sprite.gd")

const MUTANT_ROOT := "res://sprites/characters/mutant/"
# Centro da conduta dentro das imagens (píxeis).
const VENT_CENTER := Vector2(106.0, 162.5)
const SPRITE_SCALE := 0.75
# Tamanho da grelha (só a moldura de metal) dentro das imagens, em píxeis.
const VENT_FOOTPRINT := Vector2(169.0, 101.0)
# As condutas dos corredores são mais pequenas, para o Player passar ao lado
# (corredores com 160 px de largura). A criatura sai e desce por elas com
# este tamanho e cresce para o tamanho normal quando começa a procurar.
const CORRIDOR_VENT_SCALE := 0.45
const GROW_TIME := 0.25
# Os pés, nas frames de procura, ficam um pouco abaixo do centro da conduta.
const FEET_Y := 10.0
const WALK_HEIGHT := 118.0

const SEARCH_SPEED := 70.0
const APPROACH_SPEED := 170.0
const RETURN_SPEED := 150.0
const WAYPOINT_PAUSE := 0.6
const APPROACH_TIMEOUT := 3.0
const RETURN_TIMEOUT := 4.0

# Ordem de desenho: por cima da conduta e das personagens.
const CREATURE_Z := 30
# A conduta é um buraco no chão: fica sempre por baixo do Player e do Atlas
# (z 3/5). 0 = depth_sort.gd FLOOR_Z. Antes era 2, por cima deles (z 0).
const VENT_Z := 0

enum State { IDLE, EMERGE, SEARCH, APPROACH, ATTACK, RETURN, RETREAT, GONE }

static var _mutant_frames: SpriteFrames = null

var state: int = State.IDLE
var vent_position := Vector2.ZERO
var vent_scale: float = SPRITE_SCALE
var waypoints: Array = []
var waypoint_index: int = 0
var waypoint_wait: float = 0.0
var target: Node2D = null
var stop_distance: float = 80.0
var state_time: float = 0.0

var body: AnimatedSprite2D = null
var walker: AnimatedSprite2D = null


# ---------------------------------------------------------------------------
# Criar
# ---------------------------------------------------------------------------

static func mutant_frames() -> SpriteFrames:
	if _mutant_frames != null:
		return _mutant_frames
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var animations := {
		"emerge": [8.0, false],
		"search": [6.0, true],
		"retreat": [8.0, false],
	}
	for animation in animations:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, animations[animation][0])
		frames.set_animation_loop(animation, animations[animation][1])
		for i in 5:
			var path: String = MUTANT_ROOT + animation + "_" + str(i) + ".png"
			if not ResourceLoader.exists(path):
				push_warning("Sprite em falta: " + path)
				return null
			frames.add_frame(animation, load(path))
	_mutant_frames = frames
	return frames


# A criatura aparece (ainda escondida) na conduta em vent_global.
static func spawn(parent: Node, vent_global: Vector2, scale_of_vent: float = SPRITE_SCALE) -> Node2D:
	var creature = load("res://scripts/creature_actor.gd").new()
	creature.name = "CreatureActor"
	parent.add_child(creature)
	creature.global_position = vent_global
	creature.vent_position = vent_global
	creature.vent_scale = scale_of_vent
	return creature


# Conduta no chão (a imagem vazia da última frame de "recuar"). O nó fica no
# centro da conduta. É sólida: o Player e o Atlas andam à volta dela.
static func make_vent(vent_scale_value: float = SPRITE_SCALE) -> Node2D:
	var vent := Node2D.new()
	vent.name = "Vent"
	vent.z_as_relative = false
	vent.z_index = VENT_Z
	vent.set_meta("vent_scale", vent_scale_value)
	var solid := StaticBody2D.new()
	solid.name = "Solid"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = vent_size(vent_scale_value)
	collision.shape = shape
	solid.add_child(collision)
	vent.add_child(solid)
	var path := MUTANT_ROOT + "retreat_4.png"
	if not ResourceLoader.exists(path):
		return vent
	var sprite := Sprite2D.new()
	sprite.name = "VentSprite"
	sprite.texture = load(path)
	sprite.scale = Vector2(vent_scale_value, vent_scale_value)
	sprite.position = (sprite.texture.get_size() / 2.0 - VENT_CENTER) * vent_scale_value
	vent.add_child(sprite)
	return vent


# Tamanho da grelha no mundo, para uma escala.
static func vent_size(vent_scale_value: float = SPRITE_SCALE) -> Vector2:
	return VENT_FOOTPRINT * vent_scale_value


func _ready() -> void:
	z_as_relative = false
	z_index = CREATURE_Z

	body = AnimatedSprite2D.new()
	body.name = "MutantSprite"
	body.sprite_frames = mutant_frames()
	body.centered = false
	body.offset = -VENT_CENTER
	body.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	body.visible = false
	add_child(body)
	body.animation_finished.connect(_on_body_animation_finished)

	walker = CharacterSprite.monster(self, "walk_front", WALK_HEIGHT)
	if walker != null:
		walker.position.y = FEET_Y - WALK_HEIGHT / 2.0
		walker.visible = false


# ---------------------------------------------------------------------------
# Ordens
# ---------------------------------------------------------------------------

# Sai da conduta e depois procura pelos pontos dados (globais). Sem pontos,
# procura parada no sítio.
func emerge_then_search(search_points: Array = []) -> void:
	waypoints = search_points.duplicate()
	waypoint_index = 0
	global_position = vent_position
	set_state(State.EMERGE)
	if body.sprite_frames == null:
		set_state(State.SEARCH)
		emerged.emit()
		return
	show_body("emerge")


func search(search_points: Array = []) -> void:
	waypoints = search_points.duplicate()
	waypoint_index = 0
	waypoint_wait = WAYPOINT_PAUSE
	set_state(State.SEARCH)
	show_body("search")


# Vai até ao alvo; quando fica a stop_distance, ataca (fica a rugir) e emite
# "reached". Desiste ao fim de APPROACH_TIMEOUT e emite na mesma.
func approach(node: Node2D, distance: float = 80.0) -> void:
	target = node
	stop_distance = distance
	set_state(State.APPROACH)
	show_walker("walk_front")


# Volta a andar até à conduta e desce por ela; no fim emite "gone" e
# desaparece.
func go_back() -> void:
	if state == State.RETURN or state == State.RETREAT or state == State.GONE:
		return
	set_state(State.RETURN)
	show_body("search")


func set_state(new_state: int) -> void:
	state = new_state
	state_time = 0.0


func is_busy() -> bool:
	return state != State.GONE


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------

func show_body(animation: String) -> void:
	if walker != null:
		walker.visible = false
	if body.sprite_frames == null:
		if walker != null:
			walker.visible = true
			walker.play("walk_front")
		return
	# A sair ou a descer pela conduta, a imagem (que traz a grelha) fica do
	# tamanho da conduta; a procurar, do tamanho normal.
	var wanted := Vector2.ONE * (SPRITE_SCALE if animation == "search" else vent_scale)
	if body.visible and not body.scale.is_equal_approx(wanted):
		create_tween().tween_property(body, "scale", wanted, GROW_TIME)
	else:
		body.scale = wanted
	body.visible = true
	body.play(animation)


func show_walker(animation: String) -> void:
	if walker == null:
		show_body("search")
		return
	body.visible = false
	walker.visible = true
	walker.play(animation)


func _on_body_animation_finished() -> void:
	match state:
		State.EMERGE:
			emerged.emit()
			search(waypoints)
		State.RETREAT:
			finish()


func finish() -> void:
	set_state(State.GONE)
	visible = false
	gone.emit()
	queue_free()


func _process(delta: float) -> void:
	state_time += delta
	match state:
		State.SEARCH:
			update_search(delta)
		State.APPROACH:
			update_approach(delta)
		State.RETURN:
			update_return(delta)


func update_search(delta: float) -> void:
	if waypoints.is_empty():
		return
	if waypoint_wait > 0.0:
		waypoint_wait -= delta
		return
	var point: Vector2 = waypoints[waypoint_index % waypoints.size()]
	if move_towards(point, SEARCH_SPEED, delta):
		waypoint_index += 1
		waypoint_wait = WAYPOINT_PAUSE


func update_approach(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		attack()
		return
	var goal: Vector2 = target.global_position
	if global_position.distance_to(goal) <= stop_distance or state_time >= APPROACH_TIMEOUT:
		attack()
		return
	var step := (goal - global_position).normalized()
	move_towards(goal, APPROACH_SPEED, delta)
	if walker != null:
		if absf(step.x) > absf(step.y):
			walker.play("walk_side")
			walker.flip_h = step.x < 0.0
		elif step.y < 0.0:
			walker.play("walk_back")
		else:
			walker.play("walk_front")


func attack() -> void:
	set_state(State.ATTACK)
	if walker != null:
		walker.play("attack")
		if target != null and is_instance_valid(target):
			walker.flip_h = target.global_position.x < global_position.x
	reached.emit()


func update_return(delta: float) -> void:
	if move_towards(vent_position, RETURN_SPEED, delta) or state_time >= RETURN_TIMEOUT:
		global_position = vent_position
		set_state(State.RETREAT)
		body.flip_h = false
		show_body("retreat")
		if body.sprite_frames == null:
			finish()


# Anda até ao ponto; devolve true quando lá chega. Vira-se para onde anda
# (as frames de procura olham para a direita).
func move_towards(point: Vector2, speed: float, delta: float) -> bool:
	var to_point := point - global_position
	var distance := to_point.length()
	if distance <= speed * delta or distance < 1.0:
		global_position = point
		return true
	global_position += to_point / distance * speed * delta
	if absf(to_point.x) > 2.0:
		body.flip_h = to_point.x < 0.0
	return false
