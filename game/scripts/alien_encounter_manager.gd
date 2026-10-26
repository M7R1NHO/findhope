extends Node

const TutorialCard := preload("res://scripts/tutorial_card.gd")
const CharacterSprite := preload("res://scripts/character_sprite.gd")
const UISprite := preload("res://scripts/ui_sprite.gd")
const CreatureActor := preload("res://scripts/creature_actor.gd")
const DecorProps := preload("res://scripts/decor_props.gd")


# =========================================================
# SINAIS
# =========================================================

signal encounters_unlocked
signal encounter_started(corridor_id)
signal encounter_option_selected(option, corridor_id)


# =========================================================
# CONFIGURAÇÃO — CORREDORES
# =========================================================

@export var base_encounter_chance: float = 0.30
@export var max_encounter_chance: float = 0.80

@export var run_chance_increase: float = 0.10

@export var trigger_thickness: float = 120.0


# =========================================================
# CONFIGURAÇÃO — RUN
# =========================================================

@export var run_required_presses: int = 28

@export var run_close_door_time: float = 15.0

@export var run_room_offset: float = 180.0


# =========================================================
# CONFIGURAÇÃO — HIDE / SALAS
# =========================================================

@export var room_first_check_min: float = 8.0
@export var room_first_check_max: float = 14.0

@export var room_stalk_chance: float = 0.30

@export var room_retry_min: float = 5.0
@export var room_retry_max: float = 9.0

@export var room_stalk_cooldown: float = 25.0

@export var hide_reach_safe_spot_time: float = 5.0
@export var hide_survive_time: float = 6.0

@export var hide_spot_radius: float = 65.0


# =========================================================
# ESTADO GERAL
# =========================================================

var rng := RandomNumberGenerator.new()

var encounters_enabled: bool = false

var encounter_active: bool = false

var current_encounter_chance: float = 0.30

var fight_safe_next_corridor: bool = false


var current_corridor_id: String = ""

var current_trigger: Area2D = null


# =========================================================
# REFERÊNCIAS
# =========================================================

var underground_root: Node2D = null

var main: Node = null

var fights_won_count: int = 0
var runs_escaped_count: int = 0

var player: CharacterBody2D = null

var atlas: CharacterBody2D = null

var hack_manager: Node = null

var fight_manager: Node = null

var doors_root: Node = null


# =========================================================
# DIREÇÃO DO ENCONTRO
# =========================================================

var encounter_entry_velocity: Vector2 = (
	Vector2.ZERO
)


# =========================================================
# UI PRINCIPAL
# =========================================================

var encounter_layer: CanvasLayer = null

var encounter_overlay: ColorRect = null

var encounter_status: Label = null


# =========================================================
# RUN
# =========================================================

var run_minigame_active: bool = false

var run_press_count: int = 0

var run_progress_bar: ProgressBar = null

var run_counter_label: Label = null


enum RunDoorPhase {
	NONE,
	OPEN_FRONT,
	CLOSE_FRONT
}


var run_closing_active: bool = false

var run_close_time_remaining: float = 0.0

var run_front_door: Node = null

var run_destination_position: Vector2 = (
	Vector2.ZERO
)

var run_destination_side: String = ""

var run_door_phase: RunDoorPhase = (
	RunDoorPhase.NONE
)


var run_chase_layer: CanvasLayer = null

var run_timer_label: Label = null


# =========================================================
# RUN VINDO DE UMA SALA
# =========================================================

var run_forced_destination_side: String = ""

var room_failure_mode: bool = false


# =========================================================
# FIGHT
# =========================================================

var fight_should_teleport: bool = false

var fight_destination: Vector2 = (
	Vector2.ZERO
)


# =========================================================
# SALAS
# =========================================================

var current_room_id: String = ""

var room_stay_time: float = 0.0

var room_next_check_time: float = 0.0

var room_cooldown_remaining: float = 0.0


# =========================================================
# HIDE
# =========================================================

enum HidePhase {
	NONE,
	REACH_SAFE_SPOT,
	STAY_HIDDEN
}


var hide_event_active: bool = false

var hide_phase: HidePhase = (
	HidePhase.NONE
)

var hide_time_remaining: float = 0.0

var active_hide_spot: Area2D = null

# Esconderijo escolhido para o Atlas e para o jogador no HIDE normal.
var atlas_hide_target: Area2D = null

# Guarda o último esconderijo usado em cada sala para evitar repetições seguidas.
var last_hide_spot_index_by_room: Dictionary = {}


# =========================================================
# HIDEINICIAL — primeiro encontro roteirizado
# =========================================================

@export var hide_initial_alert_time: float = 3.0
@export var hide_initial_reach_time: float = 8.0
@export var hide_initial_survive_time: float = 5.0


enum HideInitialPhase {
	NONE,
	ALERT,
	FOLLOW_ATLAS,
	STAY_HIDDEN
}


var hide_initial_started: bool = false
var hide_initial_active: bool = false
var hide_initial_completed: bool = false
var hide_initial_waiting_for_run: bool = false

var hide_initial_phase: HideInitialPhase = HideInitialPhase.NONE
var hide_initial_time_remaining: float = 0.0

var hide_initial_spot: Area2D = null
var hide_initial_atlas_parked: bool = false
var hide_initial_creature_visual: Node2D = null

var corridor_vents: Dictionary = {}
var room_vents: Dictionary = {}
var creature: Node2D = null
# Só para o aspeto (onde a criatura procura); não mexe nos sorteios do jogo.
var visual_rng := RandomNumberGenerator.new()

# Proteção do Player (por exemplo, durante a entrada animada na Phase 3).
# Enquanto houver um motivo ativo, nenhum HIDE, encontro, captura ou Game
# Over pode começar. Cada motivo é retirado por quem o pôs.
var protection_reasons: Dictionary = {}
# Distância (px) que a criatura anda ao aparecer no primeiro encontro.
const HIDE_INITIAL_CREATURE_WALK := 220.0

# Criatura no mundo (creature_actor.gd). Sai de uma conduta no chão: uma por
# corredor (criadas aqui, um pouco à frente do gatilho) e uma por sala
# (postas pela decoração, room_decor.gd, que as regista aqui).
const CORRIDOR_VENT_AHEAD := 150.0
const CORRIDOR_VENT_WALL_GAP := 6.0
const CORRIDOR_SEARCH_TIME := 1.2
const CREATURE_STOP_DISTANCE := 85.0
const CREATURE_ATTACK_TIME := 0.5

# Caixas dos esconderijos: por cima das personagens (z 8 e 9) quando há
# alguém lá dentro, por baixo nos outros casos.
const HIDE_COVER_FRONT_Z := 10
const HIDE_COVER_BEHIND_Z := -6




var hide_layer: CanvasLayer = null

var hide_title_label: Label = null

var hide_timer_label: Label = null

var hide_instruction_label: Label = null


# =========================================================
# SAFE SPOTS
# =========================================================

var room_safe_spots: Dictionary = {}


# =========================================================
# CORREDORES
# =========================================================

var corridor_paths := {

	"Entrance_Hall": [
		Vector2(0, -200),
		Vector2(0, -600)
	],

	"Hall_Storage": [
		Vector2(-300, -1200),
		Vector2(-300, -1650),
		Vector2(-750, -1650)
	],

	"Hall_Technical": [
		Vector2(300, -1200),
		Vector2(300, -1650),
		Vector2(700, -1650)
	],

	"Storage_Support": [
		Vector2(-1450, -1650),
		Vector2(-1850, -1650)
	],

	"Technical_Security": [
		Vector2(1500, -1650),
		Vector2(1850, -1650)
	],

	"Storage_Archives": [
		Vector2(-1100, -1900),
		Vector2(-1100, -2425)
	],

	"Technical_Laboratory": [
		Vector2(1100, -1925),
		Vector2(1100, -2425)
	],

	"Support_Maintenance": [
		Vector2(-2200, -1900),
		Vector2(-2200, -2450)
	],

	"Archives_Sanctuary": [
		Vector2(-1100, -2975),
		Vector2(-1100, -3300),
		Vector2(-1650, -3300),
		Vector2(-1650, -3475)
	],

	"Laboratory_MainCore": [
		Vector2(1100, -2975),
		Vector2(1100, -3300),
		Vector2(1650, -3300),
		Vector2(1650, -3475)
	],

	"Sanctuary_MainCore": [
		Vector2(-1650, -3800),
		Vector2(1650, -3800)
	],

	"Archives_Laboratory": [
		Vector2(-700, -2700),
		Vector2(700, -2700)
	]
}


# =========================================================
# SALAS
# =========================================================

var room_definitions := {

	"Hall": {
		"position": Vector2(
			0,
			-900
		),

		"size": Vector2(
			1000,
			600
		)
	},


	"Storage": {
		"position": Vector2(
			-1100,
			-1650
		),

		"size": Vector2(
			700,
			500
		)
	},


	"TechnicalRoom": {
		"position": Vector2(
			1100,
			-1650
		),

		"size": Vector2(
			800,
			550
		)
	},


	"SupportRoom": {
		"position": Vector2(
			-2200,
			-1650
		),

		"size": Vector2(
			700,
			500
		)
	},


	"Security": {
		"position": Vector2(
			2200,
			-1650
		),

		"size": Vector2(
			700,
			500
		)
	},


	"Archives": {
		"position": Vector2(
			-1100,
			-2700
		),

		"size": Vector2(
			800,
			550
		)
	},


	"Laboratory": {
		"position": Vector2(
			1100,
			-2700
		),

		"size": Vector2(
			800,
			550
		)
	},


	"Maintenance": {
		"position": Vector2(
			-2200,
			-2700
		),

		"size": Vector2(
			700,
			500
		)
	},


	"Sanctuary": {
		"position": Vector2(
			-2200,
			-3800
		),

		"size": Vector2(
			1100,
			650
		)
	},


	"MainCore": {
		"position": Vector2(
			2200,
			-3800
		),

		"size": Vector2(
			1100,
			650
		)
	}
}


# =========================================================
# ROTAS DE FUGA DAS SALAS
# =========================================================

var room_escape_routes := {

	"Hall": [
		{
			"corridor": "Hall_Storage",
			"side": "A"
		},

		{
			"corridor": "Hall_Technical",
			"side": "A"
		}
	],


	"Storage": [
		{
			"corridor": "Hall_Storage",
			"side": "B"
		},

		{
			"corridor": "Storage_Support",
			"side": "A"
		},

		{
			"corridor": "Storage_Archives",
			"side": "A"
		}
	],


	"TechnicalRoom": [
		{
			"corridor": "Hall_Technical",
			"side": "B"
		},

		{
			"corridor": "Technical_Security",
			"side": "A"
		},

		{
			"corridor": "Technical_Laboratory",
			"side": "A"
		}
	],


	"SupportRoom": [
		{
			"corridor": "Storage_Support",
			"side": "B"
		},

		{
			"corridor": "Support_Maintenance",
			"side": "A"
		}
	],


	"Security": [
		{
			"corridor": "Technical_Security",
			"side": "B"
		}
	],


	"Archives": [
		{
			"corridor": "Storage_Archives",
			"side": "B"
		},

		{
			"corridor": "Archives_Sanctuary",
			"side": "A"
		},

		{
			"corridor": "Archives_Laboratory",
			"side": "A"
		}
	],


	"Laboratory": [
		{
			"corridor": "Technical_Laboratory",
			"side": "B"
		},

		{
			"corridor": "Laboratory_MainCore",
			"side": "A"
		},

		{
			"corridor": "Archives_Laboratory",
			"side": "B"
		}
	],


	"Maintenance": [
		{
			"corridor": "Support_Maintenance",
			"side": "B"
		}
	],


	"Sanctuary": [
		{
			"corridor": "Archives_Sanctuary",
			"side": "B"
		},

		{
			"corridor": "Sanctuary_MainCore",
			"side": "A"
		}
	],


	"MainCore": [
		{
			"corridor": "Laboratory_MainCore",
			"side": "B"
		},

		{
			"corridor": "Sanctuary_MainCore",
			"side": "B"
		}
	]
}


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = Node.PROCESS_MODE_ALWAYS


	rng.randomize()
	visual_rng.randomize()

	# Recupera o estado do HIDEINICIAL nesta run.
	hide_initial_completed = bool(
		SaveManager.get_run_value(
			"story",
			"hide_initial_complete",
			false
		)
	)
	hide_initial_started = hide_initial_completed


	underground_root = (
		get_parent() as Node2D
	)


	if underground_root == null:

		push_error(
			"AlienEncounterManager precisa estar "
			+ "dentro de UndergroundRoot."
		)

		return


	main = get_tree().current_scene


	if main != null:

		player = main.get_node_or_null(
			"Player"
		)


		atlas = main.get_node_or_null(
			"Atlas"
		)


		hack_manager = main.get_node_or_null(
			"HackManager"
		)


		fight_manager = main.get_node_or_null(
			"FightManager"
		)


	doors_root = (
		underground_root.get_node_or_null(
			"Doors"
		)
	)


	# =====================================================
	# HACK MANAGER
	# =====================================================

	if hack_manager != null:

		hack_manager.hack_succeeded.connect(
			on_hack_manager_succeeded
		)


		hack_manager.hack_cancelled.connect(
			on_hack_manager_cancelled
		)


	else:

		push_warning(
			"AlienEncounterManager não encontrou HackManager."
		)


	# =====================================================
	# FIGHT MANAGER
	# =====================================================

	if fight_manager != null:

		fight_manager.fight_won.connect(
			on_fight_won
		)


		fight_manager.atlas_destroyed.connect(
			on_atlas_destroyed
		)


	else:

		push_warning(
			"AlienEncounterManager não encontrou FightManager."
		)


	current_encounter_chance = (
		base_encounter_chance
	)


	create_all_corridor_triggers()

	create_all_room_triggers()

	create_all_hide_spots()


	# Um save feito depois do HIDEINICIAL volta com os encontros ativos.
	# Antes, encounters_enabled só era ligado no fim do próprio HIDEINICIAL.
	if hide_initial_completed:
		unlock_encounters()


	print("")
	print(
		"======================================"
	)

	print(
		"ALIEN ENCOUNTER MANAGER READY"
	)

	print(
		"CORRIDOR + HIDE + FIGHT SYSTEM READY"
	)

	print(
		"======================================"
	)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):
	update_hide_covers()

	# Com um tutorial aberto, os temporizadores param.
	if TutorialCard.is_open(get_tree()):
		return


	# -----------------------------------------------------
	# RUN
	# -----------------------------------------------------

	if run_closing_active:

		run_close_time_remaining -= delta


		update_run_timer_label()


		if run_close_time_remaining <= 0.0:

			run_close_time_remaining = 0.0

			run_timeout()


	# -----------------------------------------------------
	# COOLDOWN DA SALA
	# -----------------------------------------------------

	if room_cooldown_remaining > 0.0:

		room_cooldown_remaining -= delta


	# -----------------------------------------------------
	# HIDEINICIAL — evento roteirizado prioritário
	# -----------------------------------------------------

	if hide_initial_active:
		update_hide_initial(delta)
		return


	# -----------------------------------------------------
	# HIDE
	# -----------------------------------------------------

	if hide_event_active:

		update_hide_event(
			delta
		)

		return


	# -----------------------------------------------------
	# EVENTO DE SALA
	# -----------------------------------------------------

	update_room_stalk_system(
		delta
	)


# =========================================================
# INPUT
# =========================================================

func _unhandled_input(
	event
):

	if not run_minigame_active:
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


	if event.keycode != KEY_SPACE:
		return


	get_viewport().set_input_as_handled()


	run_press_count += 1


	update_run_progress()


	if (
		run_press_count
		>= run_required_presses
	):

		run_minigame_active = false


		call_deferred(
			"finish_run_minigame"
		)


# =========================================================
# LIBERAR SISTEMA ALIEN
# =========================================================

func unlock_encounters():

	if encounters_enabled:
		return


	encounters_enabled = true


	current_encounter_chance = (
		base_encounter_chance
	)


	room_cooldown_remaining = 15.0


	encounters_unlocked.emit()


	print("")
	print(
		"======================================"
	)

	print(
		"ALIEN ENCOUNTERS UNLOCKED"
	)

	print(
		"CORRIDOR CHANCE: ",
		current_encounter_chance * 100.0,
		"%"
	)

	print(
		"ROOM STALK CHANCE: ",
		room_stalk_chance * 100.0,
		"%"
	)

	print(
		"======================================"
	)


# =========================================================
# CRIAR TRIGGERS DOS CORREDORES
# =========================================================

func create_all_corridor_triggers():

	for corridor_id in corridor_paths.keys():

		if corridor_id == "Entrance_Hall":
			continue


		var path: Array = (
			corridor_paths[
				corridor_id
			]
		)


		create_corridor_trigger(
			corridor_id,
			path
		)


func create_corridor_trigger(
	corridor_id: String,
	path: Array
):

	if path.size() < 2:
		return


	var midpoint_data = (
		get_path_midpoint(
			path
		)
	)


	var midpoint: Vector2 = (
		midpoint_data[
			"position"
		]
	)


	var direction: Vector2 = (
		midpoint_data[
			"direction"
		]
	)


	var trigger = Area2D.new()


	trigger.name = (
		"EncounterTrigger_"
		+ corridor_id
	)


	add_child(
		trigger
	)


	trigger.global_position = (
		underground_root.to_global(
			midpoint
		)
	)


	trigger.collision_layer = 0

	trigger.collision_mask = (
		0xFFFFFFFF
	)


	trigger.monitoring = true

	trigger.monitorable = true


	trigger.set_meta(
		"corridor_id",
		corridor_id
	)


	trigger.set_meta(
		"armed",
		true
	)


	var collision = CollisionShape2D.new()


	var shape = RectangleShape2D.new()


	if abs(direction.x) >= abs(
		direction.y
	):

		shape.size = Vector2(
			trigger_thickness,
			220
		)


	else:

		shape.size = Vector2(
			220,
			trigger_thickness
		)


	collision.shape = shape


	trigger.add_child(
		collision
	)


	trigger.body_entered.connect(
		on_corridor_trigger_entered.bind(
			trigger
		)
	)


	trigger.body_exited.connect(
		on_corridor_trigger_exited.bind(
			trigger
		)
	)

	create_corridor_vent(
		corridor_id,
		path
	)


# =========================================================
# METADE DO CAMINHO
# =========================================================

func get_path_midpoint(
	path: Array
) -> Dictionary:

	var total_length: float = 0.0


	for index in range(
		path.size() - 1
	):

		total_length += (
			path[index]
			.distance_to(
				path[index + 1]
			)
		)


	var target_distance = (
		total_length / 2.0
	)


	var travelled: float = 0.0


	for index in range(
		path.size() - 1
	):

		var start: Vector2 = (
			path[index]
		)


		var end: Vector2 = (
			path[index + 1]
		)


		var segment_length = (
			start.distance_to(
				end
			)
		)


		if (
			travelled
			+ segment_length
			>= target_distance
		):

			var remaining = (
				target_distance
				- travelled
			)


			var ratio = (
				remaining
				/ segment_length
			)


			return {
				"position":
					start.lerp(
						end,
						ratio
					),

				"direction":
					(
						end - start
					).normalized()
			}


		travelled += (
			segment_length
		)


	return {
		"position":
			path[
				path.size() - 1
			],

		"direction":
			Vector2.RIGHT
	}


# =========================================================
# PLAYER ENTROU NO CORREDOR
# =========================================================

func on_corridor_trigger_entered(
	body: Node,
	trigger: Area2D
):

	if not encounters_enabled:
		return


	if encounter_active:
		return


	if not is_player(
		body
	):
		return


	if not bool(
		trigger.get_meta(
			"armed",
			true
		)
	):
		return


	trigger.set_meta(
		"armed",
		false
	)


	var corridor_id = str(
		trigger.get_meta(
			"corridor_id",
			"unknown"
		)
	)


	if body is CharacterBody2D:

		encounter_entry_velocity = (
			body.velocity
		)


	# =====================================================
	# FIGHT PROTEGE O PRÓXIMO CORREDOR
	# =====================================================

	if fight_safe_next_corridor:

		fight_safe_next_corridor = false


		print(
			"FIGHT PROTECTION: "
			+ "NEXT CORRIDOR SAFE"
		)


		return


	# =====================================================
	# ROLL
	# =====================================================

	var roll = rng.randf()


	print(
		"CORRIDOR CHECK: ",
		corridor_id
	)


	print(
		"Chance: ",
		current_encounter_chance * 100.0,
		"%"
	)


	print(
		"Roll: ",
		roll
	)


	if roll <= current_encounter_chance:

		start_corridor_encounter(
			corridor_id,
			trigger
		)


# =========================================================
# PLAYER SAIU DO TRIGGER
# =========================================================

func on_corridor_trigger_exited(
	body: Node,
	trigger: Area2D
):

	if not is_player(
		body
	):
		return


	call_deferred(
		"rearm_corridor_trigger",
		trigger
	)


func rearm_corridor_trigger(
	trigger: Area2D
):

	await get_tree().create_timer(
		1.0,
		true
	).timeout


	if (
		trigger != null
		and is_instance_valid(
			trigger
		)
	):

		trigger.set_meta(
			"armed",
			true
		)


# =========================================================
# CRIAR TRIGGERS DAS SALAS
# =========================================================

func create_all_room_triggers():

	for room_id in room_definitions.keys():

		var data: Dictionary = (
			room_definitions[
				room_id
			]
		)


		var trigger = Area2D.new()


		trigger.name = (
			"RoomTrigger_"
			+ room_id
		)


		add_child(
			trigger
		)


		trigger.global_position = (
			underground_root.to_global(
				data[
					"position"
				]
			)
		)


		trigger.collision_layer = 0

		trigger.collision_mask = (
			0xFFFFFFFF
		)


		trigger.monitoring = true

		trigger.monitorable = true


		trigger.set_meta(
			"room_id",
			room_id
		)


		var collision = CollisionShape2D.new()


		var shape = RectangleShape2D.new()


		var room_size: Vector2 = (
			data[
				"size"
			]
		)


		shape.size = Vector2(
			max(
				100.0,
				room_size.x - 120.0
			),

			max(
				100.0,
				room_size.y - 120.0
			)
		)


		collision.shape = shape


		trigger.add_child(
			collision
		)


		trigger.body_entered.connect(
			on_room_entered.bind(
				trigger
			)
		)


		trigger.body_exited.connect(
			on_room_exited.bind(
				trigger
			)
		)


# =========================================================
# PLAYER ENTROU NA SALA
# =========================================================

func on_room_entered(
	body: Node,
	trigger: Area2D
):

	if not is_player(
		body
	):
		return


	current_room_id = str(
		trigger.get_meta(
			"room_id",
			""
		)
	)


	reset_room_stalk_timer()


	print(
		"PLAYER ENTERED ROOM: ",
		current_room_id
	)
	
	if current_room_id == "TechnicalRoom":
		call_deferred("try_start_hide_initial")


# =========================================================
# PLAYER SAIU DA SALA
# =========================================================

func on_room_exited(
	body: Node,
	trigger: Area2D
):

	if not is_player(
		body
	):
		return


	var room_id = str(
		trigger.get_meta(
			"room_id",
			""
		)
	)


	if room_id != current_room_id:
		return


	if hide_initial_active and room_id == "TechnicalRoom":
		register_behavior("hide_failed")
		fail_hide_initial("Afastou-se do esconderijo antes de a criatura sair.")
		return


	if hide_event_active:
		return


	current_room_id = ""

	room_stay_time = 0.0


# =========================================================
# RESET STALK
# =========================================================

func reset_room_stalk_timer():

	room_stay_time = 0.0


	room_next_check_time = rng.randf_range(
		room_first_check_min,
		room_first_check_max
	)


# =========================================================
# SISTEMA DE STALK
# =========================================================

func update_room_stalk_system(
	delta: float
):

	if not encounters_enabled:
		return


	if is_player_protected():
		return


	if encounter_active:
		return


	if current_room_id.is_empty():
		return


	if room_cooldown_remaining > 0.0:
		return


	if run_minigame_active:
		return


	if run_closing_active:
		return


	if (
		fight_manager != null
		and bool(
			fight_manager.get(
				"fight_active"
			)
		)
	):
		return


	if (
		hack_manager != null
		and bool(
			hack_manager.get(
				"hack_active"
			)
		)
	):
		return


	room_stay_time += delta


	if room_stay_time < room_next_check_time:
		return


	var roll = rng.randf()


	print(
		"ROOM STALK CHECK: ",
		current_room_id,
		" | chance=",
		room_stalk_chance * 100.0,
		"% | roll=",
		roll
	)


	if roll <= room_stalk_chance:

		start_hide_event()


	else:

		room_next_check_time += (
			rng.randf_range(
				room_retry_min,
				room_retry_max
			)
		)


# =========================================================
# CRIAR ESCONDERIJOS
# =========================================================

func create_all_hide_spots():

	for room_id in room_definitions.keys():

		var data: Dictionary = (
			room_definitions[
				room_id
			]
		)


		var room_position: Vector2 = (
			data[
				"position"
			]
		)


		var room_size: Vector2 = (
			data[
				"size"
			]
		)


		var x_offset = (
			room_size.x * 0.28
		)


		var y_offset = (
			room_size.y * 0.20
		)


		var offsets := [

			Vector2(
				-x_offset,
				-y_offset
			),

			Vector2(
				x_offset,
				y_offset
			)
		]


		var spots: Array = []


		for index in range(
			offsets.size()
		):

			var local_position = (
				room_position
				+ offsets[index]
			)


			var spot = create_hide_spot(
				room_id,
				index,
				local_position
			)


			spots.append(
				spot
			)


		room_safe_spots[
			room_id
		] = spots


# =========================================================
# CRIAR ESCONDERIJO
# =========================================================

func create_hide_spot(
	room_id: String,
	index: int,
	local_position: Vector2
) -> Area2D:

	var spot = Area2D.new()


	spot.name = (
		"HideSpot_"
		+ room_id
		+ "_"
		+ str(index + 1)
	)


	add_child(
		spot
	)


	spot.global_position = (
		underground_root.to_global(
			local_position
		)
	)


	spot.collision_layer = 0

	spot.collision_mask = (
		0xFFFFFFFF
	)


	spot.monitoring = true

	spot.monitorable = true


	var collision = CollisionShape2D.new()


	var shape = CircleShape2D.new()


	shape.radius = (
		hide_spot_radius
	)


	collision.shape = shape


	spot.add_child(
		collision
	)


	var visual = Polygon2D.new()


	visual.name = "Visual"


	visual.polygon = create_circle_polygon(
		hide_spot_radius,
		20
	)


	visual.color = Color(
		0.15,
		0.85,
		0.55,
		0.38
	)


	visual.z_index = 25

	visual.visible = false


	spot.add_child(
		visual
	)


	spot.set_meta(
		"visual",
		visual
	)

	add_hide_cover(
		spot,
		index
	)


	return spot


# =========================================================
# CÍRCULO
# =========================================================

func create_circle_polygon(
	radius: float,
	points: int
) -> PackedVector2Array:

	var polygon = PackedVector2Array()


	for index in range(
		points
	):

		var angle = (
			TAU
			* float(index)
			/ float(points)
		)


		polygon.append(
			Vector2(
				cos(angle),
				sin(angle)
			)
			* radius
		)


	return polygon


# =========================================================
# ESCOLHER ESCONDERIJO DO HIDE NORMAL
# =========================================================

func choose_hide_spot_for_room(room_id: String) -> Area2D:
	if not room_safe_spots.has(room_id):
		return null

	var spots: Array = room_safe_spots[room_id]
	if spots.is_empty():
		return null

	var possible_indices: Array[int] = []
	var last_index := int(last_hide_spot_index_by_room.get(room_id, -1))

	for index in range(spots.size()):
		if spots.size() <= 1 or index != last_index:
			possible_indices.append(index)

	if possible_indices.is_empty():
		for index in range(spots.size()):
			possible_indices.append(index)

	var chosen_index: int = possible_indices[
		rng.randi_range(0, possible_indices.size() - 1)
	]

	last_hide_spot_index_by_room[room_id] = chosen_index
	return spots[chosen_index] as Area2D


# =========================================================
# COMEÇAR HIDE
# =========================================================

func start_hide_event():

	if current_room_id.is_empty():
		return


	if is_player_protected():
		return


	if hide_event_active:
		return


	encounter_active = true

	hide_event_active = true


	hide_phase = (
		HidePhase.REACH_SAFE_SPOT
	)


	hide_time_remaining = (
		hide_reach_safe_spot_time
	)


	active_hide_spot = null

	atlas_hide_target = choose_hide_spot_for_room(current_room_id)

	if atlas_hide_target == null:
		hide_event_active = false
		hide_phase = HidePhase.NONE
		encounter_active = false
		push_warning(
			"HIDE: não foi possível escolher um esconderijo para "
			+ current_room_id
		)
		return

	if atlas != null and is_instance_valid(atlas):
		if atlas.has_method("start_scripted_move_to"):
			atlas.start_scripted_move_to(
				atlas_hide_target.global_position
			)
		else:
			push_warning(
				"HIDE: Atlas não tem o método start_scripted_move_to()."
			)

	show_selected_hide_spot(
		current_room_id,
		atlas_hide_target
	)

	create_hide_ui()

	if hide_instruction_label != null:
		hide_instruction_label.text = "SIGA ATLAS ATÉ AO ESCONDERIJO"

	# A criatura entra pela conduta da sala e procura, longe dos esconderijos.
	spawn_creature(get_room_vent(current_room_id))
	creature.emerge_then_search(room_search_points(current_room_id))

	TutorialCard.show_once(self, "hide")


	print("")
	print(
		"======================================"
	)

	print(
		"ROOM STALK EVENT"
	)

	print(
		"ROOM: ",
		current_room_id
	)

	print(
		"FIND A SAFE SPOT"
	)

	print(
		"======================================"
	)


# =========================================================
# UI DO HIDE
# =========================================================

func create_hide_ui():

	destroy_hide_ui()


	hide_layer = CanvasLayer.new()


	hide_layer.layer = 400


	hide_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		hide_layer
	)


	var panel = ColorRect.new()


	panel.set_anchors_preset(
		Control.PRESET_CENTER_TOP
	)


	panel.position = Vector2(
		-350,
		20
	)


	panel.size = Vector2(
		700,
		150
	)


	panel.color = Color(
		0.0,
		0.0,
		0.0,
		0.78
	)


	panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	hide_layer.add_child(
		panel
	)


	var container = VBoxContainer.new()


	container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	container.add_theme_constant_override(
		"separation",
		8
	)


	panel.add_child(
		container
	)


	hide_title_label = Label.new()


	hide_title_label.text = (
		"A CRIATURA ESTÁ NA SALA"
	)


	hide_title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	hide_title_label.add_theme_font_size_override(
		"font_size",
		26
	)


	hide_title_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.25,
			1.0
		)
	)


	container.add_child(
		hide_title_label
	)


	hide_instruction_label = Label.new()


	hide_instruction_label.text = (
		"ENCONTRE UM LOCAL SEGURO"
	)


	hide_instruction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	hide_instruction_label.add_theme_font_size_override(
		"font_size",
		18
	)


	container.add_child(
		hide_instruction_label
	)


	hide_timer_label = Label.new()


	hide_timer_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	hide_timer_label.add_theme_font_size_override(
		"font_size",
		22
	)


	container.add_child(
		hide_timer_label
	)


	update_hide_ui()


# =========================================================
# ATUALIZAR HIDE
# =========================================================

func update_hide_event(
	delta: float
):

	match hide_phase:

		HidePhase.REACH_SAFE_SPOT:

			hide_time_remaining -= delta

			var spot = (
				get_player_hide_spot()
			)


			if spot != null:

				active_hide_spot = spot


				hide_phase = (
					HidePhase.STAY_HIDDEN
				)


				hide_time_remaining = (
					hide_survive_time
				)


				if hide_instruction_label != null:

					hide_instruction_label.text = (
						"FIQUE ESCONDIDO"
					)


				print(
					"PLAYER HIDING"
				)


			elif hide_time_remaining <= 0.0:

				fail_hide_event(
					"A criatura viu você."
				)

				return


		HidePhase.STAY_HIDDEN:

			if not player_inside_spot(
				active_hide_spot
			):

				fail_hide_event(
					"Você saiu do esconderijo."
				)

				return


			hide_time_remaining -= delta


			if hide_time_remaining <= 0.0:

				complete_hide_event()

				return


	update_hide_ui()


# =========================================================
# DETETAR ESCONDERIJO
# =========================================================

func get_player_hide_spot() -> Area2D:

	if atlas_hide_target == null:
		return null

	if not is_instance_valid(atlas_hide_target):
		return null

	if player_inside_spot(atlas_hide_target):
		return atlas_hide_target

	return null

func player_inside_spot(
	spot: Area2D
) -> bool:

	if spot == null:
		return false


	if not is_instance_valid(
		spot
	):
		return false


	var bodies = (
		spot.get_overlapping_bodies()
	)


	for body in bodies:

		if is_player(
			body
		):

			return true


	return false


# =========================================================
# MOSTRAR ESCONDERIJOS
# =========================================================

func show_hide_spots(
	room_id: String,
	visible: bool
):

	if not room_safe_spots.has(
		room_id
	):
		return


	for spot in room_safe_spots[
		room_id
	]:

		var visual = spot.get_meta(
			"visual",
			null
		)


		if (
			visual != null
			and is_instance_valid(
				visual
			)
		):

			visual.visible = visible


func show_selected_hide_spot(room_id: String, selected_spot: Area2D) -> void:
	if not room_safe_spots.has(room_id):
		return

	for spot in room_safe_spots[room_id]:
		var visual = spot.get_meta("visual", null)
		if visual != null and is_instance_valid(visual):
			visual.visible = spot == selected_spot


# =========================================================
# UI HIDE
# =========================================================

func update_hide_ui():

	if hide_timer_label == null:
		return


	hide_timer_label.text = (
		"%.1f s"
		% max(
			0.0,
			hide_time_remaining
		)
	)


# =========================================================
# HIDE SUCESSO
# =========================================================

func complete_hide_event():

	register_behavior("hide_success")

	print("")
	print(
		"======================================"
	)

	print(
		"HIDE SUCCESS"
	)

	print(
		"THE CREATURE LEFT THE ROOM"
	)

	print(
		"======================================"
	)


	show_hide_spots(
		current_room_id,
		false
	)


	destroy_hide_ui()


	hide_event_active = false

	hide_phase = (
		HidePhase.NONE
	)


	active_hide_spot = null

	if atlas != null and is_instance_valid(atlas):
		if atlas.has_method("stop_scripted_move_to"):
			atlas.stop_scripted_move_to()

	atlas_hide_target = null

	send_creature_home()

	encounter_active = false

	room_cooldown_remaining = (
		room_stalk_cooldown
	)


	reset_room_stalk_timer()


# =========================================================
# HIDE FALHOU
# =========================================================

func fail_hide_event(
	reason: String
):

	# Protegido (entrada na Phase 3): o HIDE acaba sem ataque nem castigo.
	if is_player_protected():
		cancel_hide_event()
		return

	register_behavior("hide_failed")

	print(
		"HIDE FAILED: ",
		reason
	)


	show_hide_spots(
		current_room_id,
		false
	)


	destroy_hide_ui()


	hide_event_active = false

	hide_phase = (
		HidePhase.NONE
	)


	active_hide_spot = null

	if atlas != null and is_instance_valid(atlas):
		if atlas.has_method("stop_scripted_move_to"):
			atlas.stop_scripted_move_to()

	atlas_hide_target = null

	room_failure_mode = true

	# A criatura encontra-os e aproxima-se antes da escolha.
	await creature_catch_player()

	# A proteção pode ter começado durante a aproximação (entrada na Phase 3).
	if is_player_protected():
		room_failure_mode = false
		send_creature_home()
		encounter_active = false
		return

	get_tree().paused = true


	create_threat_choice_ui(
		"A CRIATURA ENCONTROU VOCÊ",
		reason
		+ "\nDecida como reagir."
	)


# =========================================================
# ENCONTRO DE CORREDOR
# =========================================================

func start_corridor_encounter(
	corridor_id: String,
	trigger: Area2D
):

	if is_player_protected():
		return


	if encounter_active:
		return


	encounter_active = true


	room_failure_mode = false


	run_forced_destination_side = ""


	current_corridor_id = (
		corridor_id
	)


	current_trigger = trigger


	encounter_started.emit(
		corridor_id
	)

	# A criatura sai da conduta, procura e vem até ao Player; só depois
	# aparece a escolha RUN / FIGHT.
	await play_corridor_creature(
		corridor_id
	)

	if not encounter_active:
		return

	get_tree().paused = true


	create_threat_choice_ui(
		"MOVIMENTO DETETADO",
		"A criatura bloqueou o corredor.\n"
		+ "Decida rapidamente como reagir."
	)


	print("")
	print(
		"======================================"
	)

	print(
		"ALIEN ENCOUNTER"
	)

	print(
		"CORRIDOR: ",
		corridor_id
	)

	print(
		"======================================"
	)


# =========================================================
# UI RUN / FIGHT
# =========================================================

func create_threat_choice_ui(
	title_text: String,
	description_text: String
):
	destroy_encounter_ui()

	destroy_creature()

	encounter_layer = CanvasLayer.new()

	encounter_layer.layer = 300

	encounter_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		encounter_layer
	)

	encounter_overlay = ColorRect.new()

	encounter_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	encounter_overlay.color = Color.BLACK

	encounter_overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	encounter_layer.add_child(
		encounter_overlay
	)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	encounter_overlay.add_child(
		center
	)

	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		600,
		350
	)

	container.add_theme_constant_override(
		"separation",
		20
	)

	center.add_child(
		container
	)

	var creature_sprite := UISprite.make("monster", "roar", 190.0)
	if creature_sprite != null:
		creature_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(creature_sprite)

	var title = Label.new()

	title.text = title_text

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		34
	)

	title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.25,
			1.0
		)
	)

	container.add_child(
		title
	)

	var description = Label.new()

	description.text = (
		description_text
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

	create_choice_button(
		container,
		"RUN",
		"run"
	)

	if (
		not hide_initial_waiting_for_run
		and fight_manager != null
		and fight_manager.has_method(
			"is_combat_unlocked"
		)
		and fight_manager.is_combat_unlocked()
	):
		create_choice_button(
			container,
			"FIGHT",
			"fight"
		)

	encounter_status = Label.new()

	if hide_initial_waiting_for_run:
		encounter_status.text = "RUN é obrigatório para escapar."
	elif (
		fight_manager != null
		and fight_manager.has_method(
			"is_combat_unlocked"
		)
		and fight_manager.is_combat_unlocked()
	):
		encounter_status.text = (
			"Escolha uma ação."
		)
	else:
		encounter_status.text = (
			"Atlas ainda não possui um método "
			+ "para enfrentar a criatura."
		)

	encounter_status.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	container.add_child(
		encounter_status
	)

	TutorialCard.show_once(self, "encounter")


# =========================================================
# BOTÃO
# =========================================================

func create_choice_button(
	container: VBoxContainer,
	text: String,
	option: String
):

	var button = Button.new()


	button.text = text


	button.custom_minimum_size = Vector2(
		0,
		65
	)


	button.add_theme_font_size_override(
		"font_size",
		24
	)


	button.pressed.connect(
		on_encounter_choice.bind(
			option
		)
	)


	container.add_child(
		button
	)


# =========================================================
# ESCOLHA
# =========================================================

func on_encounter_choice(
	option: String
):

	call_deferred(
		"launch_encounter_choice",
		option
	)


func launch_encounter_choice(
	option: String
):

	encounter_option_selected.emit(
		option,
		current_corridor_id
	)


	match option:

		"run":

			if room_failure_mode:

				prepare_room_failure_run()


			start_run_minigame()


		"fight":

			if hide_initial_waiting_for_run:
				return

			start_fight_encounter()


# =========================================================
# PREPARAR RUN APÓS HIDE
# =========================================================

func prepare_room_failure_run():

	if current_room_id.is_empty():
		return


	if not room_escape_routes.has(
		current_room_id
	):
		return


	var routes: Array = (
		room_escape_routes[
			current_room_id
		]
	)


	if routes.is_empty():
		return


	# Só sortear corredores que a progressão já abriu. Antes podia sair
	# Laboratory_MainCore ou Sanctuary_MainCore ainda trancados, e a porta
	# recusava o hack: o RUN acabava sempre em Game Over.
	var open_routes: Array = []

	for candidate in routes:
		if is_escape_route_open(candidate):
			open_routes.append(candidate)

	if open_routes.is_empty():
		push_warning(
			"Nenhuma rota de fuga aberta em " + current_room_id + "."
		)
		open_routes = routes


	var route: Dictionary = (
		open_routes[
			rng.randi_range(
				0,
				open_routes.size() - 1
			)
		]
	)


	current_corridor_id = str(
		route[
			"corridor"
		]
	)


	var room_side = str(
		route[
			"side"
		]
	)


	if room_side == "A":

		run_forced_destination_side = (
			"B"
		)


	else:

		run_forced_destination_side = (
			"A"
		)


	current_trigger = null


	print(
		"HIDE FAILURE RUN ROUTE: ",
		current_room_id,
		" -> ",
		current_corridor_id,
		" -> side ",
		run_forced_destination_side
	)


func is_escape_route_open(route: Dictionary) -> bool:

	var corridor_id := str(route.get("corridor", ""))

	for side in ["A", "B"]:
		var door = get_corridor_door(corridor_id, side)

		if door != null and door.has_method("is_progression_locked") and door.is_progression_locked():
			return false

	return true


# =========================================================
# FIGHT
# =========================================================

func start_fight_encounter():

	if fight_manager == null:

		push_error(
			"FightManager não encontrado."
		)

		return


	# -----------------------------------------------------
	# FIGHT DE CORREDOR:
	#
	# Após vencer, chegamos à sala para a qual
	# estávamos indo.
	#
	# FIGHT depois de HIDE:
	#
	# Já estamos numa sala, então não teleportamos.
	# -----------------------------------------------------

	fight_should_teleport = (
		not room_failure_mode
	)


	fight_destination = (
		Vector2.ZERO
	)


	if fight_should_teleport:

		var traversal = (
			get_run_traversal_data()
		)


		fight_destination = (
			traversal[
				"destination"
			]
		)


	destroy_encounter_ui()


	fight_manager.start_fight()


# =========================================================
# FIGHT VENCIDO
# =========================================================

func on_fight_won(
	atlas_hp_remaining: int
):

	fights_won_count += 1
	register_behavior("fight_won")
	send_encounter_context(
		"creature_repelled_by_sonic",
		"creature_repelled",
		"Atlas afastou a criatura com o equipamento sonoro "
		+ str(fights_won_count) + " vez(es) nesta sessão. "
		+ "A criatura recua, mas não foi destruída."
	)

	if fight_should_teleport:

		teleport_after_run(
			fight_destination
		)


	register_fight_result()


	encounter_active = false

	room_failure_mode = false


	current_corridor_id = ""

	current_trigger = null


	run_forced_destination_side = ""


	fight_should_teleport = false

	fight_destination = (
		Vector2.ZERO
	)


	room_cooldown_remaining = 10.0


	get_tree().paused = false


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):

		main.add_chat_message(
			"ANDROID",
			"A ameaça foi temporariamente neutralizada. "
			+ "Integridade estrutural atual: "
			+ str(atlas_hp_remaining)
			+ "%."
		)


	print("")
	print(
		"======================================"
	)

	print(
		"FIGHT COMPLETE"
	)

	print(
		"ATLAS HP: ",
		atlas_hp_remaining
	)

	print(
		"NEXT CORRIDOR: SAFE"
	)

	print(
		"======================================"
	)


# =========================================================
# ATLAS DESTRUÍDO
# =========================================================

func on_atlas_destroyed():

	encounter_active = false

	room_failure_mode = false


	fight_should_teleport = false

	fight_destination = (
		Vector2.ZERO
	)


	run_forced_destination_side = ""


	print(
		"ATLAS DESTROYED DURING FIGHT"
	)


# =========================================================
# RUN
# =========================================================

func start_run_minigame():

	destroy_encounter_ui()


	get_tree().paused = true


	run_minigame_active = true

	run_press_count = 0


	encounter_layer = CanvasLayer.new()


	encounter_layer.layer = 300


	encounter_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		encounter_layer
	)


	var background = ColorRect.new()


	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	background.color = Color(
		0.02,
		0.02,
		0.02,
		1.0
	)


	encounter_layer.add_child(
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
		300
	)


	container.add_theme_constant_override(
		"separation",
		25
	)


	center.add_child(
		container
	)


	# Perseguição: a criatura atrás, o Player à frente.
	var chase_row := HBoxContainer.new()
	chase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chase_row.add_theme_constant_override("separation", 120)
	for sprite in [UISprite.make("monster", "walk_side", 150.0), UISprite.make("player", "walk_front", 120.0)]:
		if sprite != null:
			sprite.size_flags_vertical = Control.SIZE_SHRINK_END
			chase_row.add_child(sprite)
	container.add_child(chase_row)

	var title = Label.new()


	title.text = "RUN"


	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	title.add_theme_font_size_override(
		"font_size",
		42
	)


	container.add_child(
		title
	)


	var instruction = Label.new()


	instruction.text = (
		"PRESSIONE SPACE REPETIDAMENTE PARA FUGIR"
	)


	instruction.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	instruction.add_theme_font_size_override(
		"font_size",
		20
	)


	container.add_child(
		instruction
	)


	run_progress_bar = ProgressBar.new()


	run_progress_bar.min_value = 0

	run_progress_bar.max_value = (
		run_required_presses
	)


	run_progress_bar.value = 0


	run_progress_bar.custom_minimum_size = Vector2(
		0,
		65
	)


	container.add_child(
		run_progress_bar
	)


	run_counter_label = Label.new()


	run_counter_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	run_counter_label.add_theme_font_size_override(
		"font_size",
		24
	)


	container.add_child(
		run_counter_label
	)


	update_run_progress()

	TutorialCard.show_once(self, "run")


# =========================================================
# RUN PROGRESSO
# =========================================================

func update_run_progress():

	if run_progress_bar != null:

		run_progress_bar.value = (
			run_press_count
		)


	if run_counter_label != null:

		run_counter_label.text = (
			str(run_press_count)
			+ " / "
			+ str(run_required_presses)
		)


# =========================================================
# RUN COMPLETO
# =========================================================

func finish_run_minigame():

	var traversal = (
		get_run_traversal_data()
	)


	run_destination_position = (
		traversal[
			"destination"
		]
	)


	run_destination_side = str(
		traversal[
			"destination_side"
		]
	)


	run_front_door = (
		get_corridor_door(
			current_corridor_id,
			run_destination_side
		)
	)


	destroy_encounter_ui()


	start_run_chase()


# =========================================================
# CALCULAR DESTINO
# =========================================================

func get_run_traversal_data() -> Dictionary:

	var path: Array = (
		corridor_paths[
			current_corridor_id
		]
	)


	# -----------------------------------------------------
	# RUN VINDO DE HIDE FALHADO
	# -----------------------------------------------------

	if not run_forced_destination_side.is_empty():

		return get_destination_for_side(
			path,
			run_forced_destination_side
		)

	# -----------------------------------------------------
	# RUN/FIGHT NORMAL NO CORREDOR
	# -----------------------------------------------------
	
	
	if current_corridor_id == "Archives_Sanctuary":
		var sanctuary_trigger_position: Vector2 = current_trigger.global_position
		var sanctuary_entry: Vector2 = underground_root.to_global(
		Vector2(-1650, -3475)
		)
		var archives_entry: Vector2 = underground_root.to_global(
		Vector2(-1100, -2975)
		)

		var distance_to_archives: float = sanctuary_trigger_position.distance_to(
		archives_entry
		)
		var distance_to_sanctuary: float = sanctuary_trigger_position.distance_to(
		sanctuary_entry
		)

		if distance_to_archives < distance_to_sanctuary:
			return get_destination_for_side(path, "A")
		else:
			return get_destination_for_side(path, "B")


	var first: Vector2 = (
		path[0]
	)


	var last: Vector2 = (
		path[
			path.size() - 1
		]
	)


	var first_global = (
		underground_root.to_global(
			first
		)
	)


	var last_global = (
		underground_root.to_global(
			last
		)
	)


	var trigger_position = (
		current_trigger.global_position
	)


	var movement_direction = (
		encounter_entry_velocity.normalized()
	)


	var go_to_end := true


	if movement_direction.length() > 0.01:

		var toward_start = (
			first_global
			- trigger_position
		).normalized()


		var toward_end = (
			last_global
			- trigger_position
		).normalized()


		go_to_end = (
			movement_direction.dot(
				toward_end
			)
			>=
			movement_direction.dot(
				toward_start
			)
		)


	if go_to_end:

		return get_destination_for_side(
			path,
			"B"
		)


	return get_destination_for_side(
		path,
		"A"
	)


# =========================================================
# DESTINO DE UM LADO
# =========================================================

func get_destination_for_side(
	path: Array,
	side: String
) -> Dictionary:

	if side == "B":

		var last: Vector2 = (
			path[
				path.size() - 1
			]
		)


		var previous: Vector2 = (
			path[
				path.size() - 2
			]
		)


		@warning_ignore("confusable_local_declaration")
		var run_direction = (
			last - previous
		).normalized()


		@warning_ignore("confusable_local_declaration")
		var run_destination_local = (
			last
			+ run_direction
			* run_room_offset
		)


		return {
			"destination":
				underground_root.to_global(
					run_destination_local
				),

			"destination_side":
				"B"
		}


	var first: Vector2 = (
		path[0]
	)


	var second: Vector2 = (
		path[1]
	)


	var direction = (
		second - first
	).normalized()


	var destination_local = (
		first
		- direction
		* run_room_offset
	)


	return {
		"destination":
			underground_root.to_global(
				destination_local
			),

		"destination_side":
			"A"
	}


# =========================================================
# COMEÇAR PERSEGUIÇÃO RUN
# =========================================================

func start_run_chase():

	if run_front_door == null:

		push_error(
			"RUN: porta da frente não encontrada."
		)

		return


	run_closing_active = true


	run_close_time_remaining = (
		run_close_door_time
	)


	create_run_chase_ui()


	if bool(
		run_front_door.get(
			"is_open"
		)
	):

		teleport_after_run(
			run_destination_position
		)


		run_door_phase = (
			RunDoorPhase.CLOSE_FRONT
		)


		start_close_front_door()


	else:

		run_door_phase = (
			RunDoorPhase.OPEN_FRONT
		)


		start_open_front_door()


# =========================================================
# ABRIR PORTA
# =========================================================

func start_open_front_door():

	print(
		"RUN PHASE: OPEN FRONT DOOR"
	)


	if run_front_door.has_method(
		"request_open_hack"
	):

		run_front_door.request_open_hack()


# =========================================================
# FECHAR PORTA
# =========================================================

func start_close_front_door():

	print(
		"RUN PHASE: CLOSE FRONT DOOR"
	)


	if run_front_door.has_method(
		"request_close_hack"
	):

		run_front_door.request_close_hack()


# =========================================================
# HACK SUCESSO
# =========================================================

func on_hack_manager_succeeded(
	target
):

	if not run_closing_active:
		return


	if target != run_front_door:
		return


	call_deferred(
		"process_run_door_hack_success"
	)


func process_run_door_hack_success():

	if not run_closing_active:
		return


	if (
		run_door_phase
		== RunDoorPhase.OPEN_FRONT
	):

		teleport_after_run(
			run_destination_position
		)


		run_door_phase = (
			RunDoorPhase.CLOSE_FRONT
		)


		start_close_front_door()


		return


	if (
		run_door_phase
		== RunDoorPhase.CLOSE_FRONT
	):

		complete_run_escape()


# =========================================================
# HACK CANCELADO
# =========================================================

func on_hack_manager_cancelled():

	if not run_closing_active:
		return


	call_deferred(
		"restart_current_run_hack"
	)


func restart_current_run_hack():

	await get_tree().create_timer(
		0.12,
		true
	).timeout


	if not run_closing_active:
		return


	if run_close_time_remaining <= 0.0:
		return


	match run_door_phase:

		RunDoorPhase.OPEN_FRONT:

			start_open_front_door()


		RunDoorPhase.CLOSE_FRONT:

			start_close_front_door()


# =========================================================
# PEGAR PORTA
# =========================================================

func get_corridor_door(
	corridor_id: String,
	side: String
) -> Node:

	if doors_root == null:

		doors_root = (
			underground_root.get_node_or_null(
				"Doors"
			)
		)


	if doors_root == null:
		return null


	if doors_root.has_method(
		"get_door_for_corridor"
	):

		return doors_root.get_door_for_corridor(
			corridor_id,
			side
		)


	return null


# =========================================================
# TELEPORTE
# =========================================================

func teleport_after_run(
	destination: Vector2
):

	if player != null:

		if player.has_method(
			"teleport_to"
		):

			player.teleport_to(
				destination
			)


		else:

			player.global_position = (
				destination
			)


	if atlas != null:

		atlas.global_position = (
			destination
			+ Vector2(
				80,
				0
			)
		)


		atlas.velocity = (
			Vector2.ZERO
		)


# =========================================================
# UI TIMER RUN
# =========================================================

func create_run_chase_ui():

	destroy_run_chase_ui()


	run_chase_layer = CanvasLayer.new()


	run_chase_layer.layer = 500


	run_chase_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		run_chase_layer
	)


	run_timer_label = Label.new()


	run_timer_label.set_anchors_preset(
		Control.PRESET_CENTER_TOP
	)


	run_timer_label.position = Vector2(
		-250,
		25
	)


	run_timer_label.size = Vector2(
		500,
		80
	)


	run_timer_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	run_timer_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	run_timer_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	run_timer_label.add_theme_font_size_override(
		"font_size",
		28
	)


	run_timer_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.25,
			0.25,
			1.0
		)
	)


	run_chase_layer.add_child(
		run_timer_label
	)


	update_run_timer_label()


func update_run_timer_label():

	if run_timer_label == null:
		return


	var action_text = ""


	match run_door_phase:

		RunDoorPhase.OPEN_FRONT:

			action_text = (
				"ABRA A PORTA"
			)


		RunDoorPhase.CLOSE_FRONT:

			action_text = (
				"FECHE A PORTA"
			)


		_:

			action_text = "FUJA"


	run_timer_label.text = (
		action_text
		+ "\n"
		+ "%.1f"
		% run_close_time_remaining
		+ " s"
	)


# =========================================================
# RUN VENCIDO
# =========================================================

func complete_run_escape():

	runs_escaped_count += 1
	register_behavior("run_escaped")
	send_encounter_context(
		"creature_escaped_run",
		"creature_escape",
		"Atlas e o jogador fugiram da criatura e fecharam uma porta atrás de si "
		+ str(runs_escaped_count) + " vez(es) nesta sessão."
	)

	if not run_closing_active:
		return


	run_closing_active = false


	run_door_phase = (
		RunDoorPhase.NONE
	)


	destroy_run_chase_ui()


	register_run_result()


	encounter_active = false

	room_failure_mode = false


	current_corridor_id = ""

	current_trigger = null


	run_front_door = null

	run_destination_side = ""

	run_forced_destination_side = ""


	run_press_count = 0


	room_cooldown_remaining = 10.0


	get_tree().paused = false

	if hide_initial_waiting_for_run:
		hide_initial_waiting_for_run = false
		complete_hide_initial("Conseguimos fugir. A criatura perdeu-nos o rasto, por agora.")


	print("")
	print(
		"======================================"
	)

	print(
		"RUN ESCAPE COMPLETE"
	)

	print(
		"NEW ENCOUNTER CHANCE: ",
		current_encounter_chance * 100.0,
		"%"
	)

	print(
		"======================================"
	)


# =========================================================
# RUN TIMEOUT
# =========================================================

func run_timeout():

	if not run_closing_active:
		return


	run_closing_active = false


	run_door_phase = (
		RunDoorPhase.NONE
	)


	destroy_run_chase_ui()


	if (
		hack_manager != null
		and bool(
			hack_manager.get(
				"hack_active"
			)
		)
	):

		hack_manager.cancel_hack()

	call_deferred(
		"capture_then_game_over"
	)


# =========================================================
# GAME OVER
# =========================================================

func show_run_game_over():
	destroy_creature()

	get_tree().paused = true


	var layer = CanvasLayer.new()


	layer.layer = 600


	layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		layer
	)


	var background = ColorRect.new()


	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	background.color = Color.BLACK


	layer.add_child(
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
		600,
		260
	)


	container.add_theme_constant_override(
		"separation",
		25
	)


	center.add_child(
		container
	)


	var creature_sprite := UISprite.make("monster", "roar", 200.0)
	if creature_sprite != null:
		creature_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(creature_sprite)


	var title = Label.new()


	title.text = "GAME OVER"


	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	title.add_theme_font_size_override(
		"font_size",
		42
	)


	container.add_child(
		title
	)


	var description = Label.new()


	description.text = (
		"A criatura alcançou você "
		+ "antes que o acesso fosse selado."
	)


	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	container.add_child(
		description
	)


	var button = Button.new()


	button.text = "REINICIAR"


	button.custom_minimum_size = Vector2(
		0,
		60
	)


	button.pressed.connect(
		restart_after_game_over
	)


	container.add_child(
		button
		)


# =========================================================
# REINICIAR
# =========================================================

func restart_after_game_over():

	# O FightManager trata o regresso ao último autosave para os dois
	# ecrãs de Game Over (RUN e FIGHT).
	if fight_manager != null:
		fight_manager.restart_game()
		return


	get_tree().paused = false


	get_tree().reload_current_scene()


# =========================================================
# RESULTADO RUN
# =========================================================

func register_run_result():

	current_encounter_chance = min(
		max_encounter_chance,
		current_encounter_chance
		+ run_chance_increase
	)


	print(
		"RUN PRESSURE -> ",
		current_encounter_chance * 100.0,
		"%"
	)


# =========================================================
# RESULTADO FIGHT
# =========================================================

func register_fight_result():

	fight_safe_next_corridor = true


	print(
		"FIGHT RESULT -> "
		+ "NEXT CORRIDOR SAFE"
	)


# =========================================================
# PLAYER
# =========================================================

func is_player(
	body: Node
) -> bool:

	if body.name == "Player":
		return true


	if body.is_in_group(
		"player"
	):
		return true


	return false


# =========================================================
# DESTRUIR UI ENCONTRO
# =========================================================

func destroy_encounter_ui():

	if (
		encounter_layer != null
		and is_instance_valid(
			encounter_layer
		)
	):

		encounter_layer.queue_free()


	encounter_layer = null

	encounter_overlay = null

	encounter_status = null

	run_progress_bar = null

	run_counter_label = null


# =========================================================
# DESTRUIR UI RUN
# =========================================================

func destroy_run_chase_ui():

	if (
		run_chase_layer != null
		and is_instance_valid(
			run_chase_layer
		)
	):

		run_chase_layer.queue_free()


	run_chase_layer = null

	run_timer_label = null


# =========================================================
# DESTRUIR UI HIDE
# =========================================================

func destroy_hide_ui():

	if (
		hide_layer != null
		and is_instance_valid(
			hide_layer
		)
	):

		hide_layer.queue_free()


	hide_layer = null

	hide_title_label = null

	hide_timer_label = null

	hide_instruction_label = null


func try_start_hide_initial() -> void:
	if hide_initial_started or hide_initial_completed:
		return

	if hide_initial_active or hide_initial_waiting_for_run:
		return

	# O evento só começa depois de a Segurança ter sido desbloqueada.
	var security_unlocked := bool(
		SaveManager.get_run_value(
			"story",
			"facility_security_unlocked",
			false
		)
	)

	if not security_unlocked:
		return

	if current_room_id != "TechnicalRoom":
		return

	if not room_safe_spots.has("TechnicalRoom"):
		push_warning("HIDEINICIAL: não existem esconderijos na Sala Técnica.")
		return

	var spots: Array = room_safe_spots["TechnicalRoom"]
	if spots.is_empty():
		push_warning("HIDEINICIAL: a lista de esconderijos está vazia.")
		return

	if player == null or not is_instance_valid(player):
		push_warning("HIDEINICIAL: jogador não encontrado.")
		return

	if atlas == null or not is_instance_valid(atlas):
		push_warning("HIDEINICIAL: Atlas não encontrado.")
		return

	if not atlas.has_method("start_scripted_move_to"):
		push_warning("HIDEINICIAL: falta start_scripted_move_to() no Atlas.")
		return

	var index := rng.randi_range(0, spots.size() - 1)
	hide_initial_spot = spots[index] as Area2D

	hide_initial_started = true
	hide_initial_active = true
	hide_initial_completed = false

	send_encounter_context(
		"hide_initial_started",
		"creature_first_encounter",
		"Atlas e o jogador viram pela primeira vez uma criatura "
		+ "desconhecida na instalação subterrânea. Atlas mandou o jogador "
		+ "esconder-se. Atlas não sabe o que é a criatura nem de onde veio."
	)
	hide_initial_waiting_for_run = false
	hide_initial_atlas_parked = false
	hide_initial_phase = HideInitialPhase.ALERT
	hide_initial_time_remaining = hide_initial_alert_time
	encounter_active = true
	room_failure_mode = false
	active_hide_spot = null

	create_hide_initial_creature_visual()
	create_hide_initial_ui()
	update_hide_initial_ui()
	TutorialCard.show_once(self, "hide")

	if main != null and main.has_method("add_chat_message"):
		main.add_chat_message(
			"ANDROID",
			"Movimento detetado. Fique perto de mim."
		)

	print("")
	print("======================================")
	print("HIDEINICIAL: ALERTA INICIADO")
	print("SALA: TechnicalRoom")
	print("FASE: ALERT")
	print("======================================")


func update_hide_initial(delta: float) -> void:
	if not hide_initial_active:
		return

	if player == null or not is_instance_valid(player):
		fail_hide_initial("Não foi possível localizar o jogador.")
		return

	if hide_initial_spot == null or not is_instance_valid(hide_initial_spot):
		fail_hide_initial("O esconderijo deixou de estar disponível.")
		return

	hide_initial_time_remaining -= delta

	match hide_initial_phase:
		HideInitialPhase.ALERT:
			if hide_initial_time_remaining <= 0.0:
				hide_initial_phase = HideInitialPhase.FOLLOW_ATLAS
				hide_initial_time_remaining = hide_initial_reach_time
				atlas.start_scripted_move_to(hide_initial_spot.global_position)
				set_hide_initial_text(
					"ATLAS ESTÁ A PROCURAR ABRIGO",
					"Siga Atlas até ao esconderijo."
				)
				print("HIDEINICIAL: Atlas começou a deslocar-se.")

		HideInitialPhase.FOLLOW_ATLAS:
			if atlas != null and is_instance_valid(atlas):
				if atlas.global_position.distance_to(hide_initial_spot.global_position) <= 3.0:
					if atlas.has_method("stop_scripted_move_to"):
						hide_initial_atlas_parked = true

			if player_inside_spot(hide_initial_spot):
				hide_initial_phase = HideInitialPhase.STAY_HIDDEN
				hide_initial_time_remaining = hide_initial_survive_time
				active_hide_spot = hide_initial_spot
				set_hide_initial_text(
					"FIQUE ESCONDIDO",
					"Não saia do esconderijo até o temporizador terminar."
				)
				if main != null and main.has_method("add_chat_message"):
					main.add_chat_message(
						"ANDROID",
						"Não se mova. Aguarde até a ameaça se afastar."
					)
				print("HIDEINICIAL: jogador chegou ao esconderijo.")
			elif hide_initial_time_remaining <= 0.0:
				register_behavior("hide_failed")
				fail_hide_initial("Não chegou ao esconderijo a tempo.")
				return

		HideInitialPhase.STAY_HIDDEN:
			if not player_inside_spot(hide_initial_spot):
				register_behavior("hide_failed")
				fail_hide_initial("Saiu do esconderijo antes de a ameaça se afastar.")
				return

			if hide_initial_time_remaining <= 0.0:
				register_behavior("hide_success")
				complete_hide_initial("A ameaça afastou-se. Pode continuar.")
				return

	update_hide_initial_ui()


func create_hide_initial_ui() -> void:
	destroy_hide_ui()

	hide_layer = CanvasLayer.new()
	hide_layer.name = "HideInitialUI"
	hide_layer.layer = 400
	hide_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hide_layer)

	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-360.0, 20.0)
	panel.size = Vector2(720.0, 175.0)
	panel.color = Color(0.02, 0.02, 0.025, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_layer.add_child(panel)

	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 7)
	panel.add_child(container)

	hide_title_label = Label.new()
	hide_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_title_label.add_theme_font_size_override("font_size", 25)
	hide_title_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22, 1.0))
	container.add_child(hide_title_label)

	hide_instruction_label = Label.new()
	hide_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hide_instruction_label.add_theme_font_size_override("font_size", 18)
	container.add_child(hide_instruction_label)

	hide_timer_label = Label.new()
	hide_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_timer_label.add_theme_font_size_override("font_size", 22)
	container.add_child(hide_timer_label)


func set_hide_initial_text(title_text: String, instruction_text: String) -> void:
	if hide_title_label != null and is_instance_valid(hide_title_label):
		hide_title_label.text = title_text

	if hide_instruction_label != null and is_instance_valid(hide_instruction_label):
		hide_instruction_label.text = instruction_text


func update_hide_initial_ui() -> void:
	if hide_timer_label == null or not is_instance_valid(hide_timer_label):
		return

	var phase_text := ""
	match hide_initial_phase:
		HideInitialPhase.ALERT:
			phase_text = "ALERTA"
		HideInitialPhase.FOLLOW_ATLAS:
			phase_text = "SIGA ATLAS"
		HideInitialPhase.STAY_HIDDEN:
			phase_text = "MANTENHA-SE ESCONDIDO"
		_:
			phase_text = ""

	hide_timer_label.text = "%s  |  %.1f s" % [
		phase_text,
		max(0.0, hide_initial_time_remaining)
	]


func create_hide_initial_creature_visual() -> void:
	destroy_hide_initial_creature_visual()

	if underground_root == null or player == null:
		return

	# A criatura sai da conduta da Sala Técnica e procura pela sala enquanto
	# o Atlas leva o Player ao esconderijo. Só visual.
	hide_initial_creature_visual = spawn_creature(get_room_vent("TechnicalRoom"))
	hide_initial_creature_visual.emerge_then_search(room_search_points("TechnicalRoom"))


func destroy_hide_initial_creature_visual() -> void:
	if hide_initial_creature_visual != null and is_instance_valid(hide_initial_creature_visual):
		hide_initial_creature_visual.queue_free()
	if creature == hide_initial_creature_visual:
		creature = null
	hide_initial_creature_visual = null


func fail_hide_initial(reason: String) -> void:
	if not hide_initial_active:
		return

	print("HIDEINICIAL FALHOU: ", reason)

	hide_initial_active = false
	hide_initial_waiting_for_run = true
	hide_initial_phase = HideInitialPhase.NONE
	hide_initial_time_remaining = 0.0
	room_failure_mode = true
	encounter_active = true

	if atlas != null and is_instance_valid(atlas) and atlas.has_method("stop_scripted_move_to"):
		atlas.stop_scripted_move_to()

	destroy_hide_ui()
	hide_initial_creature_visual = null
	# A criatura encontra-os e aproxima-se antes da escolha.
	await creature_catch_player()
	get_tree().paused = true
	create_threat_choice_ui(
		"A CRIATURA ENCONTROU VOCÊ",
		reason + "\nRUN é a única forma de escapar."
	)


func complete_hide_initial(message: String) -> void:
	hide_initial_active = false
	hide_initial_waiting_for_run = false
	hide_initial_completed = true
	hide_initial_started = true
	hide_initial_phase = HideInitialPhase.NONE
	hide_initial_time_remaining = 0.0
	hide_initial_atlas_parked = false
	active_hide_spot = null
	hide_initial_spot = null
	room_failure_mode = false
	encounter_active = false

	if atlas != null and is_instance_valid(atlas) and atlas.has_method("stop_scripted_move_to"):
		atlas.stop_scripted_move_to()

	destroy_hide_ui()
	hide_initial_creature_visual = null
	send_creature_home()

	SaveManager.set_run_value(
		"story",
		"hide_initial_complete",
		true
	)

	if main != null and main.has_method("add_chat_message"):
		main.add_chat_message("ANDROID", message)

	room_cooldown_remaining = 15.0
	reset_room_stalk_timer()
	unlock_encounters()

	send_encounter_context(
		"hide_initial_completed",
		"creature_first_encounter_survived",
		"Atlas e o jogador sobreviveram ao primeiro encontro com a criatura. "
		+ "A partir daqui, a criatura pode voltar a aparecer "
		+ "nos corredores e nas salas da instalação."
	)

	# Autosave #4 da Bíblia: depois do HIDEINICIAL.
	SaveManager.autosave_when_safe("hide_initial_completed")

	# Atlas 2.0: o Atlas reage por iniciativa própria ao primeiro encontro.
	if main != null and main.has_method("request_atlas_spontaneous"):
		main.request_atlas_spontaneous("hide_initial_completed")

	print("")
	print("======================================")
	print("HIDEINICIAL CONCLUÍDO")
	print("ENCONTROS ALEATÓRIOS DESBLOQUEADOS")
	print("======================================")


func reset_hide_initial_after_failure() -> void:
	hide_initial_active = false
	hide_initial_phase = HideInitialPhase.NONE
	hide_initial_time_remaining = 0.0
	hide_initial_spot = null
	hide_initial_atlas_parked = false
	active_hide_spot = null
	destroy_hide_ui()
	destroy_hide_initial_creature_visual()


# Factos dos encontros para o Atlas. O código decide o que aconteceu;
# o Atlas só decide como o diz.
func send_encounter_context(event_id: String, event_type: String, description: String) -> void:
	if main != null and main.has_method("send_gameplay_context_event"):
		main.send_gameplay_context_event(event_id, event_type, description, true)


# Atlas 2.0: comportamento observado (contadores no save + contexto do Atlas).
func register_behavior(event: String) -> void:
	if main != null and main.has_method("register_behavior"):
		main.register_behavior(event)


# ---------------------------------------------------------------------------
# Criatura no mundo e condutas
# ---------------------------------------------------------------------------

func register_room_vent(room_id: String, vent_global: Vector2) -> void:
	room_vents[room_id] = vent_global


func get_room_vent(room_id: String) -> Vector2:
	if room_vents.has(room_id):
		return room_vents[room_id]

	# Sem conduta registada (a decoração ainda não correu): perto da parede de cima.
	if room_definitions.has(room_id) and underground_root != null:
		var data: Dictionary = room_definitions[room_id]
		return underground_root.to_global(data["position"] + Vector2(0.0, -data["size"].y * 0.3))

	if player != null:
		return player.global_position + Vector2(220.0, 0.0)

	return Vector2.ZERO


func create_corridor_vent(corridor_id: String, path: Array) -> void:
	if underground_root == null:
		return

	var total := 0.0

	for index in range(path.size() - 1):
		total += path[index].distance_to(path[index + 1])

	var distance := clampf(total / 2.0 + CORRIDOR_VENT_AHEAD, total / 2.0, maxf(total / 2.0, total - 110.0))
	var vent := CreatureActor.make_vent(CreatureActor.CORRIDOR_VENT_SCALE)
	vent.name = "Vent_" + corridor_id
	add_child(vent)
	vent.global_position = underground_root.to_global(path_point_at(path, distance) + corridor_vent_side(path, distance))
	corridor_vents[corridor_id] = vent.global_position


# A conduta do corredor fica encostada a uma parede (a de cima nos
# corredores deitados, a da esquerda nos de pé), para sobrar caminho ao lado.
func corridor_vent_side(path: Array, distance: float) -> Vector2:
	var before := path_point_at(path, maxf(distance - 20.0, 0.0))
	var after := path_point_at(path, distance + 20.0)
	var direction := after - before
	var half_width := 80.0
	var layout := underground_root.get_node_or_null("GeneratedLayout")
	if layout != null and "corridor_width" in layout:
		half_width = float(layout.corridor_width) / 2.0
	var vent_size := CreatureActor.vent_size(CreatureActor.CORRIDOR_VENT_SCALE)
	if absf(direction.x) >= absf(direction.y):
		return Vector2(0.0, -(half_width - vent_size.y / 2.0 - CORRIDOR_VENT_WALL_GAP))
	return Vector2(-(half_width - vent_size.x / 2.0 - CORRIDOR_VENT_WALL_GAP), 0.0)


func path_point_at(path: Array, distance: float) -> Vector2:
	var travelled := 0.0

	for index in range(path.size() - 1):
		var start: Vector2 = path[index]
		var end: Vector2 = path[index + 1]
		var length := start.distance_to(end)

		if travelled + length >= distance:
			return start.lerp(end, (distance - travelled) / maxf(length, 0.001))

		travelled += length

	return path[path.size() - 1]


func nearest_vent(point: Vector2) -> Vector2:
	var best := point + Vector2(220.0, 0.0)
	var best_distance := INF

	for vent in room_vents.values() + corridor_vents.values():
		var distance := point.distance_to(vent)

		if distance < best_distance:
			best = vent
			best_distance = distance

	return best


# Pontos ao acaso na sala para a criatura procurar, longe dos esconderijos:
# procura, mas não olha lá para dentro.
func room_search_points(room_id: String, count: int = 4) -> Array:
	var points: Array = []

	if not room_definitions.has(room_id) or underground_root == null:
		return points

	var data: Dictionary = room_definitions[room_id]
	var center := underground_root.to_global(data["position"])
	var half: Vector2 = data["size"] / 2.0 - Vector2(90.0, 90.0)
	var spots: Array = room_safe_spots.get(room_id, [])

	for attempt in 40:
		if points.size() >= count:
			break

		var point := center + Vector2(
			visual_rng.randf_range(-half.x, half.x),
			visual_rng.randf_range(-half.y, half.y)
		)
		var near_spot := false

		for spot in spots:
			if is_instance_valid(spot) and spot.global_position.distance_to(point) < hide_spot_radius + 110.0:
				near_spot = true

		if not near_spot:
			points.append(point)

	return points


func spawn_creature(vent_global: Vector2) -> Node2D:
	destroy_creature()
	var scale_of_vent := CreatureActor.SPRITE_SCALE
	for corridor_vent in corridor_vents.values():
		if corridor_vent.distance_to(vent_global) < 1.0:
			scale_of_vent = CreatureActor.CORRIDOR_VENT_SCALE
	creature = CreatureActor.spawn(underground_root if underground_root != null else self, vent_global, scale_of_vent)
	return creature


func destroy_creature() -> void:
	if creature != null and is_instance_valid(creature):
		creature.queue_free()

	creature = null


# A criatura volta à conduta e desaparece sozinha.
func send_creature_home() -> void:
	if creature != null and is_instance_valid(creature):
		creature.go_back()

	creature = null


# O Player fica parado e a criatura vem até ele (se ainda não estiver no
# mundo, sai da conduta mais próxima). Dura no máximo uns 4 s.
func creature_catch_player() -> void:
	if player == null or not is_instance_valid(player) or underground_root == null:
		return

	if is_player_protected():
		return

	set_player_frozen(true)

	if creature == null or not is_instance_valid(creature):
		spawn_creature(nearest_vent(player.global_position))
		creature.emerge_then_search([])
		await wait_for_signal(creature.emerged, 2.0)

	if creature != null and is_instance_valid(creature):
		creature.approach(player, CREATURE_STOP_DISTANCE)
		await wait_for_signal(creature.reached, 3.5)
		await wait_seconds(CREATURE_ATTACK_TIME)

	set_player_frozen(false)


# Encontro no corredor: sai da conduta, procura um instante e vem até ao Player.
func play_corridor_creature(corridor_id: String) -> void:
	if player == null or not is_instance_valid(player) or underground_root == null:
		return

	var vent: Vector2 = corridor_vents.get(corridor_id, nearest_vent(player.global_position))

	set_player_frozen(true)
	spawn_creature(vent)
	creature.emerge_then_search([])
	await wait_for_signal(creature.emerged, 2.0)
	await wait_seconds(CORRIDOR_SEARCH_TIME)

	await creature_catch_player()


# Game Over do RUN: a criatura apanha o Player e só depois aparece o ecrã.
func capture_then_game_over() -> void:
	if is_player_protected():
		return

	if not get_tree().paused:
		await creature_catch_player()

	show_run_game_over()


func set_player_frozen(frozen: bool) -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(frozen)


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


# Espera por um sinal, no máximo "seconds" de jogo (a pausa não conta).
func wait_for_signal(sig: Signal, seconds: float) -> void:
	var state := {"done": false}
	var on_signal := func(_a = null, _b = null): state["done"] = true
	sig.connect(on_signal, CONNECT_ONE_SHOT)
	var waited := 0.0

	while not state["done"] and waited < seconds:
		await get_tree().process_frame

		if not get_tree().paused:
			waited += get_process_delta_time()

	if is_instance_valid(sig.get_object()) and sig.is_connected(on_signal):
		sig.disconnect(on_signal)


# Caixas à frente de cada esconderijo: quem está lá dentro (Player ou Atlas)
# fica tapado da cintura para baixo, para se perceber que não está à vista.
func add_hide_cover(spot: Area2D, index: int) -> void:
	var cover := Node2D.new()
	cover.name = "Cover"
	cover.z_as_relative = false
	cover.z_index = HIDE_COVER_BEHIND_Z
	spot.add_child(cover)

	var big := DecorProps.make("crate", Vector2(60.0, 52.0), false, index)
	big.position = Vector2(-28.0, 6.0)
	cover.add_child(big)

	var small := DecorProps.make("crate", Vector2(48.0, 40.0), false, index + 1)
	small.position = Vector2(30.0, 12.0)
	cover.add_child(small)

	spot.set_meta("cover", cover)


# As caixas ficam à frente das personagens só quando alguém está dentro do
# esconderijo; quem passa ao lado continua a ser desenhado por cima delas.
func update_hide_covers() -> void:
	for spots in room_safe_spots.values():
		for spot in spots:
			if not is_instance_valid(spot) or not spot.has_meta("cover"):
				continue

			var inside := false

			for body in [player, atlas]:
				if body != null and is_instance_valid(body) and body.global_position.distance_to(spot.global_position) <= hide_spot_radius:
					inside = true

			spot.get_meta("cover").z_index = HIDE_COVER_FRONT_Z if inside else HIDE_COVER_BEHIND_Z


# =========================================================
# PROTEÇÃO DO PLAYER
# =========================================================

func set_player_protected(reason: String, active: bool) -> void:
	if active:
		protection_reasons[reason] = true
		abort_active_threats()
	else:
		protection_reasons.erase(reason)
		# Ao sair da proteção, o temporizador da sala recomeça do zero.
		reset_room_stalk_timer()


func is_player_protected() -> bool:
	return not protection_reasons.is_empty()


# Acaba, sem castigo, o que pudesse atacar o Player: um HIDE a decorrer e a
# criatura no mundo. Também esquece a sala atual, para o temporizador do
# HIDE não continuar a contar depois de o Player sair dali.
func abort_active_threats() -> void:
	if hide_event_active:
		cancel_hide_event()
	elif not run_minigame_active and not run_closing_active and not hide_initial_active:
		send_creature_home()
	current_room_id = ""
	room_stay_time = 0.0


# Termina um HIDE sem sucesso nem falha: a criatura volta à conduta, o Atlas
# deixa o esconderijo e não fica registado como HIDE falhado.
func cancel_hide_event() -> void:
	if not hide_event_active:
		return
	show_hide_spots(current_room_id, false)
	destroy_hide_ui()
	hide_event_active = false
	hide_phase = HidePhase.NONE
	active_hide_spot = null
	if atlas != null and is_instance_valid(atlas) and atlas.has_method("stop_scripted_move_to"):
		atlas.stop_scripted_move_to()
	atlas_hide_target = null
	send_creature_home()
	encounter_active = false
	room_cooldown_remaining = room_stalk_cooldown
	reset_room_stalk_timer()
	print("HIDE CANCELADO (Player protegido)")
