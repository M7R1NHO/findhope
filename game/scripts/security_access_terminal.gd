extends Node2D


const SAVE_ID := "security_access_terminal"


@export var interaction_distance: float = 170.0


var main: Node = null
var underground_root: Node = null

var player: CharacterBody2D = null

var hack_manager: Node = null
var progression_manager: Node = null


var interaction_label: Label = null
var terminal_status: Label = null

var hack_in_progress: bool = false
var security_unlocked: bool = false


func _ready():
	add_to_group(
		"saveable"
	)

	underground_root = get_parent()

	main = get_tree().current_scene

	if main != null:
		player = main.get_node_or_null(
			"Player"
		)

		hack_manager = main.get_node_or_null(
			"HackManager"
		)

	if underground_root != null:
		progression_manager = (
			underground_root.get_node_or_null(
				"FacilityProgressionManager"
			)
		)

	security_unlocked = bool(
		SaveManager.get_run_value(
			"story",
			"facility_security_unlocked",
			false
		)
	)

	create_visuals()

	refresh_terminal_state()


func _process(_delta):
	if player == null:
		return

	if hack_in_progress:
		interaction_label.visible = false
		return

	var distance = global_position.distance_to(
		player.global_position
	)

	interaction_label.visible = (
		distance <= interaction_distance
	)


func _unhandled_input(event):
	if player == null:
		return

	if hack_in_progress:
		return

	if not (
		event is InputEventKey
	):
		return

	if not event.pressed:
		return

	if event.echo:
		return

	if event.keycode != KEY_E:
		return

	var distance = global_position.distance_to(
		player.global_position
	)

	if distance > interaction_distance:
		return

	get_viewport().set_input_as_handled()

	examine()


func create_visuals():
	var terminal_body = Polygon2D.new()

	terminal_body.name = "TerminalBody"

	terminal_body.polygon = PackedVector2Array([
		Vector2(-70, -55),
		Vector2(70, -55),
		Vector2(70, 55),
		Vector2(-70, 55)
	])

	terminal_body.color = Color(
		0.10,
		0.18,
		0.22,
		1.0
	)

	add_child(
		terminal_body
	)


	terminal_status = Label.new()

	terminal_status.name = "TerminalStatus"

	terminal_status.position = Vector2(
		-110,
		-25
	)

	terminal_status.size = Vector2(
		220,
		50
	)

	terminal_status.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	terminal_status.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	terminal_status.add_theme_font_size_override(
		"font_size",
		16
	)

	add_child(
		terminal_status
	)


	interaction_label = Label.new()

	interaction_label.name = "InteractionLabel"

	interaction_label.position = Vector2(
		-120,
		-100
	)

	interaction_label.size = Vector2(
		240,
		40
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.add_theme_font_size_override(
		"font_size",
		17
	)

	interaction_label.visible = false

	add_child(
		interaction_label
	)


func refresh_terminal_state():
	if security_unlocked:
		terminal_status.text = (
			"SECURITY ACCESS\nUNLOCKED"
		)

		interaction_label.text = (
			"[E] CONSULTAR TERMINAL"
		)

		return

	if not is_facility_power_restored():
		terminal_status.text = (
			"SECURITY ACCESS\nNO POWER"
		)

		interaction_label.text = (
			"[E] TERMINAL SEM ENERGIA"
		)

		return

	terminal_status.text = (
		"SECURITY ACCESS\nLOCKED"
	)

	interaction_label.text = (
		"[E] ACESSAR TERMINAL"
	)


func examine():
	if security_unlocked:
		if (
			main != null
			and main.has_method(
				"add_chat_message"
			)
		):
			main.add_chat_message(
				"ANDROID",
				"O controlo de segurança central "
				+ "permanece desativado. "
				+ "Os setores internos estão acessíveis."
			)

		return

	if not is_facility_power_restored():
		refresh_terminal_state()

		if (
			main != null
			and main.has_method(
				"add_chat_message"
			)
		):
			main.add_chat_message(
				"ANDROID",
				"Este terminal não possui energia suficiente. "
				+ "Precisamos restaurar a rede auxiliar."
			)

		return

	start_security_hack()


func start_security_hack():
	if hack_in_progress:
		return

	if security_unlocked:
		return

	if hack_manager == null:
		if main != null:
			hack_manager = (
				main.get_node_or_null(
					"HackManager"
				)
			)

	if hack_manager == null:
		push_warning(
			"SecurityAccessTerminal não encontrou HackManager."
		)

		return

	hack_in_progress = true

	terminal_status.text = (
		"SECURITY ACCESS\nHACKING"
	)

	interaction_label.visible = false

	print(
		"SECURITY TERMINAL HACK STARTED"
	)

	hack_manager.start_hack(
		self
	)

func on_hack_success():
	hack_in_progress = false

	security_unlocked = true

	
	print("[SECURITY HACK] Run ativa: ", not SaveManager.active_run_data.is_empty())
	print(
		"[SECURITY HACK] Estado antes: ",
		SaveManager.get_run_value(
			"story",
			"facility_security_unlocked",
			false
		)
	)

	SaveManager.set_run_value(
		"story",
		"facility_security_unlocked",
		true
	)

	print(
		"[SECURITY HACK] Estado depois: ",
		SaveManager.get_run_value(
			"story",
			"facility_security_unlocked",
			false
		)
	)

	if progression_manager == null:
		if underground_root != null:
			progression_manager = (
				underground_root.get_node_or_null(
					"FacilityProgressionManager"
				)
			)

	if (
		progression_manager != null
		and progression_manager.has_method(
			"unlock_security_network"
		)
	):
		progression_manager.unlock_security_network()

	refresh_terminal_state()

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Acesso de segurança obtido. "
			+ "As restrições internas foram removidas."
		)

		main.add_chat_message(
			"ANDROID",
			"O Núcleo Principal ainda utiliza "
			+ "uma autorização independente."
		)

	if (
		main != null
		and main.has_method(
			"send_gameplay_context_event"
		)
	):
		main.send_gameplay_context_event(
			"facility_security_network_unlocked",
			"facility_security_unlocked",
			"Atlas e o jogador obtiveram acesso "
			+ "ao terminal central de segurança. "
			+ "Os bloqueios dos setores regulares "
			+ "da instalação foram removidos. "
			+ "O Núcleo Principal continua protegido "
			+ "por uma autorização separada.",
			true
		)

	print("")
	print("======================================")
	print("SECURITY TERMINAL HACK SUCCESS")
	print("REGULAR FACILITY ACCESS UNLOCKED")
	print("======================================")


func on_hack_cancelled():
	hack_in_progress = false

	refresh_terminal_state()

	print(
		"SECURITY TERMINAL HACK CANCELLED"
	)


func is_facility_power_restored() -> bool:
	if underground_root == null:
		return false

	return bool(
		underground_root.get_meta(
			"facility_power_restored",
			false
		)
	)


func get_save_id() -> String:
	return SAVE_ID


func get_save_data() -> Dictionary:
	return {
		"security_unlocked":
			security_unlocked
	}


func load_save_data(
	data: Dictionary
):
	security_unlocked = bool(
		data.get(
			"security_unlocked",
			false
		)
	)

	hack_in_progress = false

	SaveManager.set_run_value(
		"story",
		"facility_security_unlocked",
		security_unlocked
	)

	if security_unlocked:
		if progression_manager == null:
			if underground_root != null:
				progression_manager = (
					underground_root.get_node_or_null(
						"FacilityProgressionManager"
					)
				)

		if (
			progression_manager != null
			and progression_manager.has_method(
				"unlock_security_network"
			)
		):
			progression_manager.unlock_security_network()

	refresh_terminal_state()
