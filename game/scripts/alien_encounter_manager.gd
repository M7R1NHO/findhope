extends Node


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
# COMEÇAR HIDE
# =========================================================

func start_hide_event():

	if current_room_id.is_empty():
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


	show_hide_spots(
		current_room_id,
		true
	)


	create_hide_ui()


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

	if not room_safe_spots.has(
		current_room_id
	):
		return null


	var spots: Array = (
		room_safe_spots[
			current_room_id
		]
	)


	for spot in spots:

		if player_inside_spot(
			spot
		):

			return spot


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


	room_failure_mode = true


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
		fight_manager != null
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

	if (
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


	var route: Dictionary = (
		routes[
			rng.randi_range(
				0,
				routes.size() - 1
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


		var direction = (
			last - previous
		).normalized()


		var destination_local = (
			last
			+ direction
			* run_room_offset
		)


		return {
			"destination":
				underground_root.to_global(
					destination_local
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
		"show_run_game_over"
	)


# =========================================================
# GAME OVER
# =========================================================

func show_run_game_over():

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
