extends Node


signal fight_won(atlas_hp)
signal atlas_destroyed


@export var atlas_max_hp: int = 100

@export var attack_phase_duration: float = 6.0
@export var position_phase_duration: float = 5.0

@export var actor_move_speed: float = 280.0

@export var claw_speed: float = 470.0
@export var bite_speed: float = 330.0

@export var hit_invulnerability: float = 0.45


var atlas_hp: int = 100

var sonic_damage: int = 1

var fight_active: bool = false
var turn_number: int = 1

var combat_unlocked: bool = false

var rng := RandomNumberGenerator.new()


enum FightPhase {
	NONE,
	CHOICE,
	DODGE,
	POSITION,
	RESOLVE,
	ENDING
}


var fight_phase: int = FightPhase.NONE


var fight_layer: CanvasLayer = null

var fight_root: Control = null

var life_label: Label = null
var damage_label: Label = null
var turn_label: Label = null

var phase_label: Label = null
var timer_label: Label = null
var control_label: Label = null
var combat_log: Label = null

var cards_container: HBoxContainer = null


var arena: Control = null

var arena_size := Vector2(
	720,
	420
)


var player_token: ColorRect = null
var atlas_token: ColorRect = null

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

var attack_time_remaining: float = 0.0
var attack_spawn_timer: float = 0.0

var current_attack_type: String = ""


var red_zone: ColorRect = null
var blue_zone: ColorRect = null

var red_zone_rect := Rect2()
var blue_zone_rect := Rect2()

var position_time_remaining: float = 0.0


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

	player_hit_cooldown = max(
		0.0,
		player_hit_cooldown - delta
	)

	atlas_hit_cooldown = max(
		0.0,
		atlas_hit_cooldown - delta
	)

	if (
		fight_phase == FightPhase.DODGE
		or fight_phase == FightPhase.POSITION
	):
		update_actor_movement(
			delta
		)

	if fight_phase == FightPhase.DODGE:
		update_dodge_phase(
			delta
		)

	elif fight_phase == FightPhase.POSITION:
		update_position_phase(
			delta
		)


func _unhandled_input(event):
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

	if event.keycode == KEY_1:
		selected_actor = 1

		update_actor_selection()

		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_2:
		selected_actor = 2

		update_actor_selection()

		get_viewport().set_input_as_handled()


func start_fight():
	if fight_active:
		return

	fight_active = true

	fight_phase = FightPhase.NONE

	turn_number = 1

	sonic_damage = 1

	player_hit_cooldown = 0.0
	atlas_hit_cooldown = 0.0

	get_tree().paused = true

	create_fight_ui()

	reset_actor_positions()

	start_choice_phase()

	print("")
	print("======================================")
	print("SONIC FIGHT STARTED")
	print("SHARED LIFE: ", atlas_hp)
	print("STARTING SONIC DAMAGE: ", sonic_damage)
	print("======================================")


func start_choice_phase():
	if not fight_active:
		return

	fight_phase = FightPhase.CHOICE

	clear_hazards()

	hide_position_zones()

	if cards_container != null:
		cards_container.visible = true

	if phase_label != null:
		phase_label.text = (
			"ESCOLHA UM AJUSTE ANTES DO ATAQUE"
		)

	if timer_label != null:
		timer_label.text = ""

	if combat_log != null:
		combat_log.text = (
			"A criatura prepara o próximo ataque."
		)

	create_turn_cards()

	update_ui()


func create_turn_cards():
	clear_cards()

	create_card_button(
		"+10 VIDA",
		"Recupera 10 de Vida Compartilhada",
		"heal"
	)

	create_card_button(
		"+3 DANO",
		"Aumenta o Dano Sonoro em 3",
		"damage"
	)

	create_card_button(
		"+5 VIDA / +2 DANO",
		"Recupera 5 de Vida e aumenta 2 de Dano",
		"balanced"
	)


func create_card_button(
	title: String,
	description: String,
	card_id: String
):
	if cards_container == null:
		return

	var button = Button.new()

	button.custom_minimum_size = Vector2(
		225,
		82
	)

	button.text = (
		title
		+ "\n"
		+ description
	)

	button.add_theme_font_size_override(
		"font_size",
		14
	)

	button.pressed.connect(
		on_card_selected.bind(
			card_id
		)
	)

	cards_container.add_child(
		button
	)


func on_card_selected(
	card_id: String
):
	if not fight_active:
		return

	if fight_phase != FightPhase.CHOICE:
		return

	fight_phase = FightPhase.RESOLVE

	set_cards_disabled(
		true
	)

	match card_id:

		"heal":
			atlas_hp = min(
				atlas_max_hp,
				atlas_hp + 10
			)

			if combat_log != null:
				combat_log.text = (
					"Vida Compartilhada +10."
				)

		"damage":
			sonic_damage += 3

			if combat_log != null:
				combat_log.text = (
					"Dano Sonoro +3."
				)

		"balanced":
			atlas_hp = min(
				atlas_max_hp,
				atlas_hp + 5
			)

			sonic_damage += 2

			if combat_log != null:
				combat_log.text = (
					"Vida +5 // Dano Sonoro +2."
				)

	update_ui()

	await get_tree().create_timer(
		0.55,
		true
	).timeout

	if not fight_active:
		return

	start_dodge_phase()


func start_dodge_phase():
	fight_phase = FightPhase.DODGE

	clear_cards()

	if cards_container != null:
		cards_container.visible = false

	hide_position_zones()

	selected_actor = 1

	update_actor_selection()

	attack_time_remaining = (
		attack_phase_duration
	)

	attack_spawn_timer = 0.15

	if turn_number % 2 == 1:
		current_attack_type = "claw"

	else:
		current_attack_type = "bite"

	if current_attack_type == "claw":
		if phase_label != null:
			phase_label.text = (
				"ATAQUE DA CRIATURA // GARRA"
			)

	else:
		if phase_label != null:
			phase_label.text = (
				"ATAQUE DA CRIATURA // MORDIDA"
			)

	if combat_log != null:
		combat_log.text = (
			"[1] PLAYER   [2] ATLAS   //   WASD PARA MOVER"
		)

	print(
		"TURN ",
		turn_number,
		" CREATURE ATTACK: ",
		current_attack_type.to_upper()
	)


func update_dodge_phase(
	delta: float
):
	attack_time_remaining -= delta

	attack_spawn_timer -= delta

	if timer_label != null:
		timer_label.text = (
			"ATAQUE: "
			+ str(
				max(
					0.0,
					attack_time_remaining
				)
			).pad_decimals(1)
			+ "s"
		)

	if attack_spawn_timer <= 0.0:

		if current_attack_type == "claw":
			spawn_claw_attack()

			attack_spawn_timer = 0.72

		else:
			spawn_bite_attack()

			attack_spawn_timer = 1.05

	update_hazards(
		delta
	)

	if attack_time_remaining <= 0.0:
		start_position_phase()


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
	actor_name: String
):
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
		atlas_hp - 3
	)

	if combat_log != null:

		if actor_name == "player":
			combat_log.text = (
				"PLAYER atingido // Vida Compartilhada -3"
			)

		else:
			combat_log.text = (
				"ATLAS atingido // Vida Compartilhada -3"
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


func start_position_phase():
	if not fight_active:
		return

	fight_phase = FightPhase.POSITION

	clear_hazards()

	position_time_remaining = (
		position_phase_duration
	)

	selected_actor = 1

	create_position_zones()

	update_actor_selection()

	if phase_label != null:
		phase_label.text = (
			"POSICIONAMENTO PARA DESCARGA SONORA"
		)

	if combat_log != null:
		combat_log.text = (
			"PLAYER → ZONA AZUL   //   ATLAS → ZONA VERMELHA (POSIÇÕES VARIÁVEIS)"
		)

	print(
		"POSITION PHASE | SONIC DAMAGE: ",
		sonic_damage
	)


func create_position_zones():
	if red_zone == null or blue_zone == null:
		return

	var zone_size := Vector2(155.0, 140.0)
	var max_x := arena_size.x - zone_size.x
	var max_y := arena_size.y - zone_size.y

	var red_position := Vector2.ZERO
	var blue_position := Vector2.ZERO
	var valid_pair := false

	# Tenta várias combinações até encontrar duas zonas separadas.
	# Os limites garantem que ambas ficam dentro da arena.
	for attempt in range(60):
		red_position = Vector2(
			rng.randf_range(0.0, max_x),
			rng.randf_range(0.0, max_y)
		)
		blue_position = Vector2(
			rng.randf_range(0.0, max_x),
			rng.randf_range(0.0, max_y)
		)

		var red_rect := Rect2(red_position, zone_size)
		var blue_rect := Rect2(blue_position, zone_size)
		var centers_far_enough := red_rect.get_center().distance_to(
			blue_rect.get_center()
		) >= 235.0

		if not red_rect.intersects(blue_rect) and centers_far_enough:
			valid_pair = true
			break

	# Combinação de recurso para garantir duas zonas válidas.
	if not valid_pair:
		red_position = Vector2(20.0, 20.0)
		blue_position = Vector2(
			arena_size.x - zone_size.x - 20.0,
			arena_size.y - zone_size.y - 20.0
		)

	red_zone_rect = Rect2(red_position, zone_size)
	blue_zone_rect = Rect2(blue_position, zone_size)

	red_zone.position = red_zone_rect.position
	red_zone.size = red_zone_rect.size
	blue_zone.position = blue_zone_rect.position
	blue_zone.size = blue_zone_rect.size

	red_zone.visible = true
	blue_zone.visible = true

func hide_position_zones():
	if red_zone != null:
		red_zone.visible = false

	if blue_zone != null:
		blue_zone.visible = false


func update_position_phase(
	delta: float
):
	position_time_remaining -= delta

	if timer_label != null:
		timer_label.text = (
			"POSICIONE-SE: "
			+ str(
				max(
					0.0,
					position_time_remaining
				)
			).pad_decimals(1)
			+ "s"
		)

	if position_time_remaining <= 0.0:
		finish_position_phase()


func finish_position_phase():
	if not fight_active:
		return

	if fight_phase != FightPhase.POSITION:
		return

	fight_phase = FightPhase.RESOLVE

	var atlas_ready = (
		red_zone_rect.has_point(
			atlas_position
		)
	)

	var player_safe = (
		blue_zone_rect.has_point(
			player_position
		)
	)

	hide_position_zones()

	if not player_safe:

		atlas_hp = max(
			0,
			atlas_hp - 1
		)

		if combat_log != null:
			combat_log.text = (
				"PLAYER fora da zona segura // Vida -1"
			)

		update_ui()

		if atlas_hp <= 0:
			shared_life_defeat()

			return

	if atlas_ready:

		if sonic_damage >= 10:

			if combat_log != null:
				combat_log.text = (
					"DESCARGA SONORA: "
					+ str(
						sonic_damage
					)
					+ " // A CRIATURA RECUA"
				)

			await get_tree().create_timer(
				0.8,
				true
			).timeout

			finish_fight_victory()

			return

		else:

			if combat_log != null:
				combat_log.text = (
					"Atlas emite uma onda sonora de "
					+ str(
						sonic_damage
					)
					+ ". Ainda não é suficiente."
				)

	else:

		if combat_log != null:
			combat_log.text = (
				"Atlas não alcançou a zona de emissão. "
				+ "A onda sonora não foi disparada."
			)

	await get_tree().create_timer(
		0.85,
		true
	).timeout

	if not fight_active:
		return

	turn_number += 1

	start_choice_phase()


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


func update_actor_selection():
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
				"CONTROLO: PLAYER [1]   //   [2] ATLAS"
			)

		else:
			control_label.text = (
				"CONTROLO: ATLAS [2]   //   [1] PLAYER"
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
	print("FINAL SONIC DAMAGE: ", sonic_damage)
	print("======================================")


func shared_life_defeat():
	if not fight_active:
		return

	fight_active = false
	fight_phase = FightPhase.ENDING

	atlas_hp = 0

	clear_hazards()

	destroy_fight_ui()

	atlas_destroyed.emit()

	show_shared_defeat()


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

	background.add_child(
		center
	)

	var root = VBoxContainer.new()

	root.custom_minimum_size = Vector2(
		820,
		690
	)

	root.add_theme_constant_override(
		"separation",
		10
	)

	center.add_child(
		root
	)

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

	life_label = Label.new()

	life_label.add_theme_font_size_override(
		"font_size",
		18
	)

	stats.add_child(
		life_label
	)

	damage_label = Label.new()

	damage_label.add_theme_font_size_override(
		"font_size",
		18
	)

	stats.add_child(
		damage_label
	)

	turn_label = Label.new()

	turn_label.add_theme_font_size_override(
		"font_size",
		18
	)

	stats.add_child(
		turn_label
	)

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

	timer_label = Label.new()

	timer_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	timer_label.add_theme_font_size_override(
		"font_size",
		16
	)

	root.add_child(
		timer_label
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

	red_zone = ColorRect.new()

	red_zone.color = Color(
		0.8,
		0.08,
		0.08,
		0.50
	)

	red_zone.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	red_zone.visible = false

	arena.add_child(
		red_zone
	)

	var red_label = Label.new()

	red_label.text = "ATLAS"

	red_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	red_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	red_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	red_zone.add_child(
		red_label
	)

	blue_zone = ColorRect.new()

	blue_zone.color = Color(
		0.08,
		0.28,
		0.9,
		0.50
	)

	blue_zone.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	blue_zone.visible = false

	arena.add_child(
		blue_zone
	)

	var blue_label = Label.new()

	blue_label.text = "PLAYER"

	blue_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	blue_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	blue_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	blue_zone.add_child(
		blue_label
	)

	player_token = ColorRect.new()

	player_token.size = actor_size

	player_token.color = Color(
		0.12,
		0.42,
		1.0,
		1.0
	)

	player_token.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	player_token.pivot_offset = (
		actor_size / 2.0
	)

	arena.add_child(
		player_token
	)

	atlas_token = ColorRect.new()

	atlas_token.size = actor_size

	atlas_token.color = Color(
		1.0,
		0.80,
		0.08,
		1.0
	)

	atlas_token.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	atlas_token.pivot_offset = (
		actor_size / 2.0
	)

	arena.add_child(
		atlas_token
	)

	cards_container = HBoxContainer.new()

	cards_container.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	cards_container.add_theme_constant_override(
		"separation",
		12
	)

	root.add_child(
		cards_container
	)

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

	if damage_label != null:
		damage_label.text = (
			"DANO SONORO: "
			+ str(
				sonic_damage
			)
		)

	if turn_label != null:
		turn_label.text = (
			"TURNO: "
			+ str(
				turn_number
			)
		)


func set_cards_disabled(
	disabled: bool
):
	if cards_container == null:
		return

	for child in (
		cards_container.get_children()
	):
		if child is Button:
			child.disabled = disabled


func clear_cards():
	if cards_container == null:
		return

	for child in (
		cards_container.get_children()
	):
		child.queue_free()


func destroy_fight_ui():
	clear_hazards()

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
	damage_label = null
	turn_label = null

	phase_label = null
	timer_label = null
	control_label = null
	combat_log = null

	cards_container = null

	arena = null

	player_token = null
	atlas_token = null

	red_zone = null
	blue_zone = null


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
