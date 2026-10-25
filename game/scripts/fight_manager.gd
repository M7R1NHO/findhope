extends Node

const TutorialCard := preload("res://scripts/tutorial_card.gd")
const UISprite := preload("res://scripts/ui_sprite.gd")
const SonicDeviceArt := preload("res://scripts/sonic_device_art.gd")


signal fight_won(atlas_hp)
signal atlas_destroyed


@export var atlas_max_hp: int = 100

@export var actor_move_speed: float = 280.0

@export var claw_speed: float = 380.0
@export var bite_speed: float = 270.0

@export var hit_invulnerability: float = 0.9

# FIGHT 3.0: a criatura persegue o Player. Foge-se com o Player [1]; com o
# Atlas [2] aponta-se com o rato e o E dispara o dispositivo sónico.
# Ao fim de hits_to_win golpes a criatura recua.
@export var creature_speed: float = 105.0
@export var sonic_cooldown: float = 2.0
@export var sonic_range: float = 560.0
@export var sonic_half_angle: float = 24.0
@export var hits_to_win: int = 10
@export var attack_interval: float = 5.0
@export var hazard_damage: int = 2
@export var contact_damage: int = 3


var atlas_hp: int = 100

var fight_active: bool = false

var combat_unlocked: bool = false

var rng := RandomNumberGenerator.new()


enum FightPhase {
	NONE,
	COMBAT,
	RETREAT,
	ENDING
}


var fight_phase: int = FightPhase.NONE


var fight_layer: CanvasLayer = null

var fight_root: Control = null

var life_label: Label = null
var hits_label: Label = null
var cooldown_label: Label = null

var phase_label: Label = null
var control_label: Label = null
var combat_log: Label = null


var arena: Control = null

var arena_size := Vector2(
	720,
	420
)


var player_token: ColorRect = null
var atlas_token: ColorRect = null
var player_sprite: TextureRect = null
var atlas_sprite: TextureRect = null

var actor_size := Vector2(
	24,
	24
)


var player_position := Vector2.ZERO
var atlas_position := Vector2.ZERO

var selected_actor: int = 1


var player_hit_cooldown: float = 0.0
var atlas_hit_cooldown: float = 0.0


var hazards: Array = []

var attack_timer: float = 0.0
var attack_count: int = 0


# Criatura na arena. O quadrado é a área de colisão; o sprite é o aspeto.
const CREATURE_SIZE := Vector2(46, 46)
const CREATURE_SPRITE_HEIGHT := 104.0
const CREATURE_KNOCKBACK := 150.0
const CREATURE_STUN := 1.6
const CREATURE_START_ROAR := 1.2
const RETREAT_SPEED := 300.0
const DEFEAT_LUNGE_TIME := 0.8

var creature_token: Control = null
var creature_sprite: TextureRect = null
var creature_position := Vector2.ZERO
var creature_stun: float = 0.0
var creature_stun_animation: String = "roar"
var creature_retreat_direction := Vector2.ZERO


# Dispositivo sónico. Cada disparo conta no máximo um golpe.
const WAVE_TIME := 0.4

var sonic_hits: int = 0
var sonic_cooldown_left: float = 0.0
var shots_fired: int = 0
var sonic_waves: Array = []
var aim_overlay: Control = null
var atlas_device: Node2D = null


var defeat_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	rng.randomize()

	atlas_hp = atlas_max_hp

	print(
		"FIGHT MANAGER READY | VIDA: ",
		atlas_hp
	)


func _process(delta: float):
	if not fight_active:
		return

	# Com um tutorial aberto, os temporizadores param.
	if TutorialCard.is_open(get_tree()):
		return

	player_hit_cooldown = max(
		0.0,
		player_hit_cooldown - delta
	)

	atlas_hit_cooldown = max(
		0.0,
		atlas_hit_cooldown - delta
	)

	update_sonic_waves(delta)

	if fight_phase == FightPhase.COMBAT:
		sonic_cooldown_left = max(0.0, sonic_cooldown_left - delta)

		update_actor_movement(delta)
		update_creature(delta)
		update_attacks(delta)
		update_hazards(delta)
		update_ui()

	elif fight_phase == FightPhase.RETREAT:
		update_creature_retreat(delta)


# _input (e não _unhandled_input) para a luta ler as teclas antes dos
# terminais, que também ouvem o E com o jogo pausado.
func _input(event):
	if not fight_active:
		return

	if not (
		event is InputEventKey
	):
		return

	if (
		not event.pressed
		or event.echo
	):
		return

	# Com um tutorial aberto, as teclas são do cartão.
	if TutorialCard.is_open(get_tree()):
		return

	if event.keycode == KEY_1:
		selected_actor = 1

		update_actor_selection()

		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_2:
		selected_actor = 2

		update_actor_selection()

		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_E:
		get_viewport().set_input_as_handled()

		fire_sonic(get_aim_point())


func start_fight():
	if fight_active:
		return

	fight_active = true

	fight_phase = FightPhase.COMBAT

	sonic_hits = 0
	sonic_cooldown_left = 0.0
	shots_fired = 0
	sonic_waves.clear()

	attack_timer = attack_interval
	attack_count = 0

	player_hit_cooldown = 0.0
	atlas_hit_cooldown = 0.0

	get_tree().paused = true

	create_fight_ui()

	reset_actor_positions()

	place_creature()

	if phase_label != null:
		phase_label.text = "A CRIATURA PERSEGUE O PLAYER"

	if combat_log != null:
		combat_log.text = (
			"Foge com o Player [1]. Muda para o Atlas [2], aponta com o rato e carrega E."
		)

	update_ui()

	TutorialCard.show_once(self, "fight")

	print("")
	print("======================================")
	print("SONIC FIGHT STARTED")
	print("SHARED LIFE: ", atlas_hp)
	print("HITS TO WIN: ", hits_to_win)
	print("======================================")


# ---------------------------------------------------------------------------
# Criatura
# ---------------------------------------------------------------------------

# Começa no canto mais longe do Player, a rugir, para dar tempo de reagir.
func place_creature() -> void:
	var half := CREATURE_SIZE / 2.0
	var corners := [
		half,
		Vector2(arena_size.x - half.x, half.y),
		Vector2(half.x, arena_size.y - half.y),
		arena_size - half
	]

	creature_position = corners[0]

	for corner in corners:
		if corner.distance_to(player_position) > creature_position.distance_to(player_position):
			creature_position = corner

	stun_creature(CREATURE_START_ROAR, "roar")
	update_creature_visual(Vector2.ZERO)


func update_creature(delta: float) -> void:
	if creature_stun > 0.0:
		creature_stun = max(0.0, creature_stun - delta)
		update_creature_visual(Vector2.ZERO)
		return

	var to_player := player_position - creature_position
	var step := Vector2.ZERO

	if to_player.length() > 1.0:
		step = to_player.normalized() * minf(creature_speed * delta, to_player.length())

	creature_position = clamp_creature_position(creature_position + step)
	update_creature_visual(step)

	var creature_rect := get_creature_rect()

	if creature_rect.intersects(get_actor_rect(player_position)):
		creature_bite("player", player_position)

	elif creature_rect.intersects(get_actor_rect(atlas_position)):
		creature_bite("atlas", atlas_position)


# Ao tocar numa personagem a criatura morde e recua um pouco, para não tirar
# vida em todas as frames.
func creature_bite(actor_name: String, actor_position: Vector2) -> void:
	hit_actor(actor_name, contact_damage)

	if not fight_active:
		return

	var away := creature_position - actor_position

	if away.length() < 1.0:
		away = Vector2.UP

	creature_position = clamp_creature_position(
		creature_position + away.normalized() * 70.0
	)

	stun_creature(0.5, "attack")


func stun_creature(duration: float, animation_name: String) -> void:
	creature_stun = duration
	creature_stun_animation = animation_name


func update_creature_visual(step: Vector2) -> void:
	if creature_token == null or not is_instance_valid(creature_token):
		return

	creature_token.position = creature_position - CREATURE_SIZE / 2.0

	if creature_sprite == null:
		return

	if creature_stun > 0.0:
		creature_sprite.play(creature_stun_animation)

	elif step.length() < 0.01:
		creature_sprite.play("idle_front")

	elif absf(step.x) > absf(step.y):
		creature_sprite.play("walk_side")
		creature_sprite.flip_h = step.x < 0.0

	elif step.y < 0.0:
		creature_sprite.play("walk_back")

	else:
		creature_sprite.play("walk_front")


func clamp_creature_position(point: Vector2) -> Vector2:
	var half := CREATURE_SIZE / 2.0

	return Vector2(
		clampf(point.x, half.x, arena_size.x - half.x),
		clampf(point.y, half.y, arena_size.y - half.y)
	)


func get_creature_rect() -> Rect2:
	return Rect2(
		creature_position - CREATURE_SIZE / 2.0,
		CREATURE_SIZE
	)


# Garras e mordidas, alternadas, a cada attack_interval segundos.
func update_attacks(delta: float) -> void:
	attack_timer -= delta

	if attack_timer > 0.0:
		return

	attack_timer = attack_interval
	attack_count += 1

	if attack_count % 2 == 1:
		spawn_claw_attack()

	else:
		spawn_bite_attack()


func start_creature_retreat(direction: Vector2) -> void:
	fight_phase = FightPhase.RETREAT

	clear_hazards()

	creature_retreat_direction = direction

	if creature_retreat_direction.length() < 0.01:
		creature_retreat_direction = (creature_position - player_position).normalized()

	if creature_retreat_direction.length() < 0.01:
		creature_retreat_direction = Vector2.UP

	creature_stun = 0.0

	if phase_label != null:
		phase_label.text = "A CRIATURA RECUA"

	if combat_log != null:
		combat_log.text = (
			str(hits_to_win)
			+ " golpes sónicos. A criatura afasta-se da frequência sonora."
		)

	update_ui()


func update_creature_retreat(delta: float) -> void:
	creature_position += creature_retreat_direction * RETREAT_SPEED * delta

	update_creature_visual(creature_retreat_direction)

	var faded := false

	if creature_token != null and is_instance_valid(creature_token):
		creature_token.modulate.a = maxf(0.0, creature_token.modulate.a - delta * 0.8)
		faded = creature_token.modulate.a <= 0.05

	var outside := not Rect2(Vector2.ZERO, arena_size).grow(CREATURE_SIZE.x).has_point(creature_position)

	if outside or faded:
		finish_fight_victory()


# ---------------------------------------------------------------------------
# Dispositivo sónico
# ---------------------------------------------------------------------------

func get_aim_point() -> Vector2:
	if arena != null and is_instance_valid(arena):
		return arena.get_local_mouse_position()

	return creature_position


# Dispara na direção de aim_point (coordenadas da arena). Devolve true se a
# onda acertou na criatura. Cada disparo conta no máximo um golpe.
func fire_sonic(aim_point: Vector2) -> bool:
	if not fight_active or fight_phase != FightPhase.COMBAT:
		return false

	if selected_actor != 2:
		if combat_log != null:
			combat_log.text = "Só o Atlas dispara: carrega [2] para o controlar."

		return false

	if sonic_cooldown_left > 0.0:
		if combat_log != null:
			combat_log.text = (
				"Dispositivo a recarregar ("
				+ str(sonic_cooldown_left).pad_decimals(1)
				+ " s)."
			)

		return false

	var direction := aim_point - atlas_position

	if direction.length() < 1.0:
		direction = creature_position - atlas_position

	direction = direction.normalized()

	sonic_cooldown_left = sonic_cooldown
	shots_fired += 1

	if atlas_device != null and is_instance_valid(atlas_device):
		atlas_device.pulse()

	var hit := sonic_reaches_creature(direction)

	sonic_waves.append({
		"origin": atlas_position,
		"direction": direction,
		"age": 0.0,
		"hit": hit
	})

	if hit:
		register_sonic_hit(direction)

	elif combat_log != null:
		combat_log.text = "A onda sónica não apanhou a criatura."

	update_ui()

	return hit


func sonic_reaches_creature(direction: Vector2) -> bool:
	var to_creature := creature_position - atlas_position
	var distance := to_creature.length()
	var radius := CREATURE_SIZE.x / 2.0

	if distance > sonic_range + radius:
		return false

	if distance <= radius:
		return true

	var tolerance := deg_to_rad(sonic_half_angle) + atan2(radius, distance)

	return absf(direction.angle_to(to_creature)) <= tolerance


func register_sonic_hit(direction: Vector2) -> void:
	sonic_hits = mini(hits_to_win, sonic_hits + 1)

	creature_position = clamp_creature_position(
		creature_position + direction * CREATURE_KNOCKBACK
	)

	stun_creature(CREATURE_STUN, "hurt")
	update_creature_visual(Vector2.ZERO)

	if combat_log != null:
		combat_log.text = (
			"Golpe sónico! "
			+ str(sonic_hits)
			+ " / "
			+ str(hits_to_win)
		)

	print("SONIC HIT ", sonic_hits, " / ", hits_to_win)

	if sonic_hits >= hits_to_win:
		start_creature_retreat(direction)


func update_sonic_waves(delta: float) -> void:
	for index in range(sonic_waves.size() - 1, -1, -1):
		sonic_waves[index]["age"] += delta

		if sonic_waves[index]["age"] >= WAVE_TIME:
			sonic_waves.remove_at(index)

	if aim_overlay != null and is_instance_valid(aim_overlay):
		aim_overlay.queue_redraw()


func spawn_claw_attack():
	# A garra pode entrar por qualquer uma das quatro margens.
	# A trajetória é dirigida para uma zona aleatória da arena,
	# com variação angular para impedir que o jogador fique num canto.
	var side := rng.randi_range(0, 3)
	var target := Vector2(
		rng.randf_range(arena_size.x * 0.25, arena_size.x * 0.75),
		rng.randf_range(arena_size.y * 0.25, arena_size.y * 0.75)
	)

	var origin := Vector2.ZERO
	var horizontal_entry := side < 2

	match side:
		0:
			origin = Vector2(-90.0, rng.randf_range(35.0, arena_size.y - 35.0))
		1:
			origin = Vector2(arena_size.x + 90.0, rng.randf_range(35.0, arena_size.y - 35.0))
		2:
			origin = Vector2(rng.randf_range(35.0, arena_size.x - 35.0), -90.0)
		3:
			origin = Vector2(rng.randf_range(35.0, arena_size.x - 35.0), arena_size.y + 90.0)

	var base_direction := (target - origin).normalized()
	var perpendicular := Vector2(-base_direction.y, base_direction.x)

	for offset in [-30.0, 0.0, 30.0]:
		var spawn_position: Vector2 = origin + perpendicular * offset
		var hazard_size := Vector2(125.0, 12.0) if horizontal_entry else Vector2(12.0, 125.0)
		var rect := Rect2(spawn_position, hazard_size)
		var angle_variation := deg_to_rad(rng.randf_range(-9.0, 9.0))
		var direction := base_direction.rotated(angle_variation)

		create_hazard(
			rect,
			direction * claw_speed,
			Color(0.95, 0.22, 0.16, 1.0)
		)

func spawn_bite_attack():
	var columns: int = 6

	var lane_width: float = (
		arena_size.x
		/ float(columns)
	)

	var safe_lane = rng.randi_range(
		0,
		columns - 1
	)

	for index in range(
		columns
	):
		if index == safe_lane:
			continue

		var x = (
			index * lane_width
			+ lane_width / 2.0
			- 25.0
		)

		var top_rect = Rect2(
			Vector2(
				x,
				-50
			),
			Vector2(
				50,
				48
			)
		)

		var bottom_rect = Rect2(
			Vector2(
				x,
				arena_size.y + 2
			),
			Vector2(
				50,
				48
			)
		)

		create_hazard(
			top_rect,
			Vector2(
				0,
				bite_speed
			),
			Color(
				0.76,
				0.18,
				0.28,
				1.0
			)
		)

		create_hazard(
			bottom_rect,
			Vector2(
				0,
				-bite_speed
			),
			Color(
				0.76,
				0.18,
				0.28,
				1.0
			)
		)


func create_hazard(
	rect: Rect2,
	velocity: Vector2,
	hazard_color: Color
):
	if arena == null:
		return

	var visual = ColorRect.new()

	visual.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	visual.position = rect.position
	visual.size = rect.size
	visual.color = hazard_color

	arena.add_child(
		visual
	)

	hazards.append({
		"rect": rect,
		"velocity": velocity,
		"visual": visual
	})


func update_hazards(
	delta: float
):
	for index in range(
		hazards.size() - 1,
		-1,
		-1
	):
		var hazard: Dictionary = hazards[
			index
		]

		var rect: Rect2 = hazard[
			"rect"
		]

		var velocity: Vector2 = hazard[
			"velocity"
		]

		rect.position += (
			velocity * delta
		)

		hazard["rect"] = rect

		var visual: ColorRect = hazard[
			"visual"
		]

		if (
			visual != null
			and is_instance_valid(
				visual
			)
		):
			visual.position = rect.position

		check_hazard_collision(
			rect
		)

		if hazard_outside_arena(
			rect
		):
			remove_hazard(
				index
			)


func check_hazard_collision(
	hazard_rect: Rect2
):
	var player_rect = get_actor_rect(
		player_position
	)

	var atlas_rect = get_actor_rect(
		atlas_position
	)

	if hazard_rect.intersects(
		player_rect
	):
		hit_actor(
			"player"
		)

	if hazard_rect.intersects(
		atlas_rect
	):
		hit_actor(
			"atlas"
		)


func hit_actor(
	actor_name: String,
	amount: int = -1
):
	if amount < 0:
		amount = hazard_damage

	if actor_name == "player":

		if player_hit_cooldown > 0.0:
			return

		player_hit_cooldown = (
			hit_invulnerability
		)

	else:

		if atlas_hit_cooldown > 0.0:
			return

		atlas_hit_cooldown = (
			hit_invulnerability
		)

	atlas_hp = max(
		0,
		atlas_hp - amount
	)

	if combat_log != null:

		if actor_name == "player":
			combat_log.text = (
				"PLAYER atingido // Vida Compartilhada -"
				+ str(amount)
			)

		else:
			combat_log.text = (
				"ATLAS atingido // Vida Compartilhada -"
				+ str(amount)
			)

	update_ui()

	if atlas_hp <= 0:
		shared_life_defeat()


func hazard_outside_arena(
	rect: Rect2
) -> bool:
	return (
		rect.end.x < -150.0
		or rect.position.x > arena_size.x + 150.0
		or rect.end.y < -150.0
		or rect.position.y > arena_size.y + 150.0
	)


func remove_hazard(
	index: int
):
	if (
		index < 0
		or index >= hazards.size()
	):
		return

	var hazard: Dictionary = hazards[
		index
	]

	var visual = hazard.get(
		"visual"
	)

	if (
		visual != null
		and is_instance_valid(
			visual
		)
	):
		visual.queue_free()

	hazards.remove_at(
		index
	)


func clear_hazards():
	for hazard in hazards:
		var visual = hazard.get(
			"visual"
		)

		if (
			visual != null
			and is_instance_valid(
				visual
			)
		):
			visual.queue_free()

	hazards.clear()


func update_actor_movement(
	delta: float
):
	var direction := Vector2.ZERO

	if Input.is_key_pressed(
		KEY_W
	):
		direction.y -= 1.0

	if Input.is_key_pressed(
		KEY_S
	):
		direction.y += 1.0

	if Input.is_key_pressed(
		KEY_A
	):
		direction.x -= 1.0

	if Input.is_key_pressed(
		KEY_D
	):
		direction.x += 1.0

	if direction.length() > 1.0:
		direction = direction.normalized()

	if selected_actor == 1:

		player_position += (
			direction
			* actor_move_speed
			* delta
		)

		player_position = clamp_actor_position(
			player_position
		)

	else:

		atlas_position += (
			direction
			* actor_move_speed
			* delta
		)

		atlas_position = clamp_actor_position(
			atlas_position
		)

	update_actor_visuals()


func clamp_actor_position(
	position: Vector2
) -> Vector2:
	var half = actor_size / 2.0

	position.x = clamp(
		position.x,
		half.x,
		arena_size.x - half.x
	)

	position.y = clamp(
		position.y,
		half.y,
		arena_size.y - half.y
	)

	return position


func get_actor_rect(
	position: Vector2
) -> Rect2:
	return Rect2(
		position - actor_size / 2.0,
		actor_size
	)


func reset_actor_positions():
	# Gera posições iniciais variáveis, mantendo distância suficiente
	# entre o jogador e o Atlas para evitar uma abertura injusta.
	var min_distance := 250.0
	var valid_pair := false

	for attempt in range(80):
		player_position = Vector2(
			rng.randf_range(actor_size.x, arena_size.x - actor_size.x),
			rng.randf_range(actor_size.y, arena_size.y - actor_size.y)
		)
		atlas_position = Vector2(
			rng.randf_range(actor_size.x, arena_size.x - actor_size.x),
			rng.randf_range(actor_size.y, arena_size.y - actor_size.y)
		)

		if player_position.distance_to(atlas_position) >= min_distance:
			valid_pair = true
			break

	if not valid_pair:
		player_position = Vector2(actor_size.x, actor_size.y)
		atlas_position = Vector2(
			arena_size.x - actor_size.x,
			arena_size.y - actor_size.y
		)

	player_position = clamp_actor_position(player_position)
	atlas_position = clamp_actor_position(atlas_position)

	selected_actor = 1

	update_actor_visuals()
	update_actor_selection()

func update_actor_visuals():
	if player_token != null:
		player_token.position = (
			player_position
			- actor_size / 2.0
		)

	if atlas_token != null:
		atlas_token.position = (
			atlas_position
			- actor_size / 2.0
		)


# Sprites da luta. Os quadrados continuam a ser a área de colisão (ficam
# meio transparentes por baixo dos pés); os sprites são só o aspeto.
func add_fight_sprites() -> void:
	player_sprite = add_token_sprite(player_token, "player")
	atlas_sprite = add_token_sprite(atlas_token, "atlas")

	# O dispositivo sónico no ombro do Atlas, como no mundo.
	atlas_device = SonicDeviceArt.make(0.8)
	atlas_device.position = Vector2(21.0, 0.0)
	atlas_token.add_child(atlas_device)

	creature_sprite = UISprite.make("monster", "roar", CREATURE_SPRITE_HEIGHT)

	if creature_sprite != null:
		creature_sprite.size = creature_sprite.custom_minimum_size
		creature_sprite.position = Vector2(
			(CREATURE_SIZE.x - creature_sprite.size.x) / 2.0,
			CREATURE_SIZE.y - creature_sprite.size.y + 6.0
		)
		creature_token.add_child(creature_sprite)


func add_token_sprite(token: ColorRect, character: String) -> TextureRect:
	var sprite := UISprite.make(character, "idle_front", actor_size.y * 2.6)
	if sprite == null:
		return null
	token.color.a = 0.35
	sprite.size = sprite.custom_minimum_size
	# Pés na base do quadrado de colisão.
	sprite.position = Vector2(
		(actor_size.x - sprite.size.x) / 2.0,
		actor_size.y - sprite.size.y + 4.0
	)
	token.add_child(sprite)
	return sprite


func update_actor_selection():
	# A personagem controlada anda; a outra fica parada.
	if player_sprite != null:
		player_sprite.play("walk_front" if selected_actor == 1 else "idle_front")
	if atlas_sprite != null:
		atlas_sprite.play("walk_front" if selected_actor == 2 else "idle_front")

	if player_token != null:

		if selected_actor == 1:
			player_token.scale = Vector2(
				1.35,
				1.35
			)

		else:
			player_token.scale = Vector2.ONE

	if atlas_token != null:

		if selected_actor == 2:
			atlas_token.scale = Vector2(
				1.35,
				1.35
			)

		else:
			atlas_token.scale = Vector2.ONE

	if control_label != null:

		if selected_actor == 1:
			control_label.text = (
				"CONTROLO: PLAYER [1] // W A S D para fugir   //   [2] ATLAS"
			)

		else:
			control_label.text = (
				"CONTROLO: ATLAS [2] // rato para apontar, E para disparar   //   [1] PLAYER"
			)


func finish_fight_victory():
	if not fight_active:
		return

	fight_active = false
	fight_phase = FightPhase.ENDING

	clear_hazards()

	if combat_log != null:
		combat_log.text = (
			"A criatura afasta-se da frequência sonora."
		)

	update_ui()

	await get_tree().create_timer(
		0.7,
		true
	).timeout

	destroy_fight_ui()

	get_tree().paused = false

	fight_won.emit(
		atlas_hp
	)

	print("")
	print("======================================")
	print("SONIC FIGHT WON")
	print("SHARED LIFE REMAINING: ", atlas_hp)
	print("SONIC HITS: ", sonic_hits, " / ", hits_to_win)
	print("======================================")


func shared_life_defeat():
	if not fight_active:
		return

	fight_active = false
	fight_phase = FightPhase.ENDING

	atlas_hp = 0

	clear_hazards()

	update_ui()

	await play_defeat_lunge()

	destroy_fight_ui()

	atlas_destroyed.emit()

	show_shared_defeat()


# Antes do ecrã de derrota, a criatura salta para o Player.
func play_defeat_lunge() -> void:
	if creature_token == null or not is_instance_valid(creature_token):
		return

	if phase_label != null:
		phase_label.text = "A CRIATURA APANHOU-VOS"

	if combat_log != null:
		combat_log.text = "A Vida Compartilhada chegou a 0."

	if creature_sprite != null:
		creature_sprite.play("attack")
		creature_sprite.flip_h = player_position.x < creature_position.x

	var tween := creature_token.create_tween()
	tween.tween_property(
		creature_token,
		"position",
		player_position - CREATURE_SIZE / 2.0,
		DEFEAT_LUNGE_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await tween.finished

	creature_position = player_position

	await get_tree().create_timer(0.35, true).timeout


func show_shared_defeat():
	get_tree().paused = true

	if (
		defeat_layer != null
		and is_instance_valid(
			defeat_layer
		)
	):
		defeat_layer.queue_free()

	defeat_layer = CanvasLayer.new()

	defeat_layer.name = "FightDefeat"

	defeat_layer.layer = 1000

	defeat_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		defeat_layer
	)

	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color.BLACK

	defeat_layer.add_child(
		background
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(
		center
	)

	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		650,
		350
	)

	container.add_theme_constant_override(
		"separation",
		24
	)

	center.add_child(
		container
	)

	var creature_sprite := UISprite.make("monster", "roar", 200.0)
	if creature_sprite != null:
		creature_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(creature_sprite)

	var title = Label.new()

	title.text = "DERROTA"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		46
	)

	container.add_child(
		title
	)

	var description = Label.new()

	description.text = (
		"A Vida Compartilhada chegou a zero.\n\n"
		+ "Player e Atlas não conseguiram resistir ao confronto."
	)

	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	description.add_theme_font_size_override(
		"font_size",
		20
	)

	container.add_child(
		description
	)

	var restart_button = Button.new()

	restart_button.text = "RECOMEÇAR"

	restart_button.custom_minimum_size = Vector2(
		0,
		60
	)

	restart_button.pressed.connect(
		restart_game
	)

	container.add_child(
		restart_button
	)

	print("")
	print("======================================")
	print("SONIC FIGHT DEFEAT")
	print("SHARED LIFE: 0")
	print("======================================")


var restart_in_progress := false


func restart_game():
	# Volta ao último autosave, como CONTINUAR JOGO no menu principal.
	# reload_current_scene() recriava a cena do .tscn sem passar pelo
	# SaveManager e deixava o jogador na superfície com a porta selada.
	if restart_in_progress:
		return

	restart_in_progress = true

	var tree := get_tree()
	var scene_path := tree.current_scene.scene_file_path
	var menu_path := get_main_menu_scene_path()

	if await SaveManager.prepare_current_run_load():
		if await SaveManager.load_prepared_scene(scene_path):
			return

	# Sem autosave ou sem backend: abrir o menu com o motivo da falha.
	if menu_path.is_empty():
		push_warning("main_menu_scene_path não definido no PauseMenu.")
		restart_in_progress = false
		return

	open_main_menu_with_message(tree, menu_path, SaveManager.last_error)


func get_main_menu_scene_path() -> String:
	var pause_menu = get_tree().current_scene.get_node_or_null("PauseMenu")

	if pause_menu == null:
		return ""

	return str(pause_menu.get("main_menu_scene_path")).strip_edges()


# Estática para continuar depois de esta cena ser libertada pela troca de cena.
static func open_main_menu_with_message(tree: SceneTree, menu_path: String, message: String) -> void:
	tree.paused = false
	tree.change_scene_to_file(menu_path)

	await tree.scene_changed

	var menu := tree.current_scene

	if menu != null and menu.has_method("set_status"):
		menu.set_status(message)


func create_fight_ui():
	destroy_fight_ui()

	fight_layer = CanvasLayer.new()

	fight_layer.name = "FightUI"

	fight_layer.layer = 700

	fight_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		fight_layer
	)

	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.015,
		0.02,
		0.025,
		1.0
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	fight_layer.add_child(
		background
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	background.add_child(
		center
	)

	var root = VBoxContainer.new()

	root.custom_minimum_size = Vector2(
		820,
		640
	)

	root.add_theme_constant_override(
		"separation",
		10
	)

	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	center.add_child(
		root
	)

	fight_root = root

	var title = Label.new()

	title.text = (
		"ATLAS // SISTEMA DE CONTENÇÃO SONORA"
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		27
	)

	root.add_child(
		title
	)

	var stats = HBoxContainer.new()

	stats.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	stats.add_theme_constant_override(
		"separation",
		60
	)

	root.add_child(
		stats
	)

	life_label = make_stat_label(stats)
	hits_label = make_stat_label(stats)
	cooldown_label = make_stat_label(stats)

	phase_label = Label.new()

	phase_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	phase_label.add_theme_font_size_override(
		"font_size",
		19
	)

	root.add_child(
		phase_label
	)

	control_label = Label.new()

	control_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	control_label.add_theme_font_size_override(
		"font_size",
		15
	)

	root.add_child(
		control_label
	)

	var arena_holder = CenterContainer.new()

	arena_holder.custom_minimum_size = Vector2(
		760,
		440
	)

	arena_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(
		arena_holder
	)

	arena = Control.new()

	arena.name = "Arena"

	arena.custom_minimum_size = (
		arena_size
	)

	arena.size = (
		arena_size
	)

	arena.clip_contents = true

	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE

	arena_holder.add_child(
		arena
	)

	var arena_background = ColorRect.new()

	arena_background.position = Vector2.ZERO
	arena_background.size = arena_size

	arena_background.color = Color(
		0.055,
		0.065,
		0.075,
		1.0
	)

	arena_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	arena.add_child(
		arena_background
	)

	player_token = make_token(Color(0.12, 0.42, 1.0, 1.0))
	atlas_token = make_token(Color(1.0, 0.80, 0.08, 1.0))

	creature_token = Control.new()
	creature_token.name = "Creature"
	creature_token.size = CREATURE_SIZE
	creature_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(creature_token)

	add_fight_sprites()

	# Mira, recarga, ondas e golpes, por cima de tudo.
	aim_overlay = FightOverlay.new()
	aim_overlay.name = "SonicOverlay"
	aim_overlay.fight = self
	aim_overlay.position = Vector2.ZERO
	aim_overlay.size = arena_size
	aim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(aim_overlay)

	combat_log = Label.new()

	combat_log.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	combat_log.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	combat_log.add_theme_font_size_override(
		"font_size",
		16
	)

	root.add_child(
		combat_log
	)

	update_ui()


func make_stat_label(parent: Control) -> Label:
	var label := Label.new()

	label.add_theme_font_size_override(
		"font_size",
		18
	)

	parent.add_child(
		label
	)

	return label


func make_token(token_color: Color) -> ColorRect:
	var token := ColorRect.new()

	token.size = actor_size
	token.color = token_color
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.pivot_offset = actor_size / 2.0

	arena.add_child(
		token
	)

	return token


func update_ui():
	if life_label != null:
		life_label.text = (
			"VIDA: "
			+ str(
				atlas_hp
			)
			+ " / "
			+ str(
				atlas_max_hp
			)
		)

	if hits_label != null:
		hits_label.text = (
			"GOLPES SÓNICOS: "
			+ str(sonic_hits)
			+ " / "
			+ str(hits_to_win)
		)

	if cooldown_label != null:

		if sonic_cooldown_left > 0.0:
			cooldown_label.text = (
				"RECARGA: "
				+ str(sonic_cooldown_left).pad_decimals(1)
				+ " s"
			)

			cooldown_label.add_theme_color_override(
				"font_color",
				Color(1.0, 0.75, 0.2)
			)

		else:
			cooldown_label.text = "DISPOSITIVO: PRONTO"

			cooldown_label.add_theme_color_override(
				"font_color",
				Color(0.4, 1.0, 0.6)
			)


func destroy_fight_ui():
	clear_hazards()

	sonic_waves.clear()

	if (
		fight_layer != null
		and is_instance_valid(
			fight_layer
		)
	):
		fight_layer.queue_free()

	fight_layer = null
	fight_root = null

	life_label = null
	hits_label = null
	cooldown_label = null

	phase_label = null
	control_label = null
	combat_log = null

	arena = null

	player_token = null
	atlas_token = null
	player_sprite = null
	atlas_sprite = null

	creature_token = null
	creature_sprite = null
	aim_overlay = null
	atlas_device = null


func get_shared_life() -> int:
	return atlas_hp


func heal_shared_life(
	amount: int
):
	atlas_hp = min(
		atlas_max_hp,
		atlas_hp + max(
			0,
			amount
		)
	)


func unlock_combat():
	combat_unlocked = true

	print(
		"SONIC COMBAT UNLOCKED"
	)


func is_combat_unlocked() -> bool:
	return combat_unlocked


# Desenha por cima da arena: a mira do Atlas (só com o Atlas selecionado), o
# anel de recarga, as ondas sónicas e os golpes que faltam à criatura.
class FightOverlay extends Control:
	var fight: Node = null

	const READY_COLOR := Color(0.4, 1.0, 1.0)
	const RELOAD_COLOR := Color(1.0, 0.75, 0.2)

	func _draw() -> void:
		if fight == null:
			return

		var half_angle := deg_to_rad(float(fight.sonic_half_angle))
		var reach := float(fight.sonic_range)

		for wave in fight.sonic_waves:
			var t: float = clampf(wave["age"] / WAVE_TIME, 0.0, 1.0)
			var angle: float = wave["direction"].angle()
			var color := READY_COLOR if wave["hit"] else Color(0.6, 0.75, 0.9)
			color.a = 0.9 * (1.0 - t)

			for ring in 3:
				var radius := reach * clampf(t * 1.3 - ring * 0.15, 0.0, 1.0)

				if radius > 6.0:
					draw_arc(wave["origin"], radius, angle - half_angle, angle + half_angle, 18, color, 6.0 - ring * 1.5, true)

		draw_creature_pips()

		if fight.fight_phase != FightPhase.COMBAT:
			return

		var origin: Vector2 = fight.atlas_position
		var cooldown := float(fight.sonic_cooldown)
		var ready_ratio := 1.0 - float(fight.sonic_cooldown_left) / maxf(cooldown, 0.01)
		var ring_color := READY_COLOR if ready_ratio >= 1.0 else RELOAD_COLOR

		draw_arc(origin, 24.0, -PI / 2.0, -PI / 2.0 + TAU * ready_ratio, 32, ring_color, 3.0, true)

		if fight.selected_actor != 2:
			return

		var aim := get_local_mouse_position()
		var direction := aim - origin

		if direction.length() < 1.0:
			return

		var angle := direction.angle()
		var color := ring_color
		color.a = 0.6 if ready_ratio >= 1.0 else 0.35
		var faint := color
		faint.a *= 0.45

		draw_line(origin, origin + Vector2.from_angle(angle - half_angle) * reach, faint, 1.5, true)
		draw_line(origin, origin + Vector2.from_angle(angle + half_angle) * reach, faint, 1.5, true)
		draw_arc(origin, reach, angle - half_angle, angle + half_angle, 18, faint, 2.0, true)
		draw_dashed_line(origin, origin + direction.normalized() * minf(direction.length(), reach), color, 2.0, 8.0)

		draw_arc(aim, 10.0, 0.0, TAU, 24, color, 2.0, true)
		for side in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(aim + side * 6.0, aim + side * 15.0, color, 2.0)

	func draw_creature_pips() -> void:
		var token: Control = fight.creature_token

		if token == null or not is_instance_valid(token) or token.modulate.a < 0.5:
			return

		var total := int(fight.hits_to_win)
		var pip := Vector2(8.0, 6.0)
		var gap := 3.0
		var width := total * pip.x + (total - 1) * gap
		var top: Vector2 = fight.creature_position + Vector2(-width / 2.0, CREATURE_SIZE.y / 2.0 - CREATURE_SPRITE_HEIGHT - 4.0)

		for i in total:
			var rect := Rect2(top + Vector2(i * (pip.x + gap), 0.0), pip)
			var filled: bool = i < int(fight.sonic_hits)
			draw_rect(rect, READY_COLOR if filled else Color(0.15, 0.2, 0.25, 0.85))
			draw_rect(rect, Color(0.05, 0.05, 0.07), false, 1.0)
