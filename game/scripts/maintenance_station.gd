extends Area2D


@export var heal_amount: int = 30


var player_nearby: bool = false
var station_used: bool = false

var main: Node = null
var fight_manager: Node = null

var station_visual: Polygon2D = null
var interaction_label: Label = null
var status_label: Label = null


func _ready():
	main = get_tree().current_scene

	if main != null:
		fight_manager = (
			main.get_node_or_null(
				"FightManager"
			)
		)

	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	monitoring = true
	monitorable = true

	create_collision()
	create_visual()
	create_labels()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print(
		"MAINTENANCE STATION READY"
	)


func _unhandled_input(event):
	if not player_nearby:
		return

	if station_used:
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

	if event.keycode != KEY_E:
		return

	get_viewport().set_input_as_handled()

	use_station()


func create_collision():
	var collision = CollisionShape2D.new()

	collision.name = "InteractionArea"

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		220,
		170
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_visual():
	station_visual = Polygon2D.new()

	station_visual.name = "StationVisual"

	station_visual.polygon = PackedVector2Array([
		Vector2(-85, -55),
		Vector2(85, -55),
		Vector2(85, 55),
		Vector2(-85, 55)
	])

	station_visual.color = Color(
		0.16,
		0.36,
		0.42,
		1.0
	)

	station_visual.z_index = 5

	add_child(
		station_visual
	)


func create_labels():
	status_label = Label.new()

	status_label.name = "StatusLabel"

	status_label.text = (
		"ESTAÇÃO DE MANUTENÇÃO"
	)

	status_label.position = Vector2(
		-150,
		-25
	)

	status_label.size = Vector2(
		300,
		50
	)

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	status_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	status_label.add_theme_font_size_override(
		"font_size",
		16
	)

	status_label.z_index = 7

	add_child(
		status_label
	)


	interaction_label = Label.new()

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] UTILIZAR ESTAÇÃO"
	)

	interaction_label.position = Vector2(
		-170,
		-110
	)

	interaction_label.size = Vector2(
		340,
		45
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.add_theme_font_size_override(
		"font_size",
		17
	)

	interaction_label.visible = false

	interaction_label.z_index = 10

	add_child(
		interaction_label
	)


func on_body_entered(
	body: Node
):
	if not is_player(
		body
	):
		return

	player_nearby = true

	interaction_label.visible = true

	update_interaction_text()


func on_body_exited(
	body: Node
):
	if not is_player(
		body
	):
		return

	player_nearby = false

	interaction_label.visible = false


func use_station():
	if station_used:
		return

	if fight_manager == null:
		push_error(
			"MaintenanceStation não encontrou FightManager."
		)

		return

	if not fight_manager.has_method(
		"get_shared_life"
	):
		push_error(
			"FightManager não possui get_shared_life()."
		)

		return

	if not fight_manager.has_method(
		"heal_shared_life"
	):
		push_error(
			"FightManager não possui heal_shared_life()."
		)

		return


	var current_life: int = int(
		fight_manager.get_shared_life()
	)


	var max_life: int = int(
		fight_manager.get(
			"atlas_max_hp"
		)
	)


	if current_life >= max_life:

		if (
			main != null
			and main.has_method(
				"add_chat_message"
			)
		):
			main.add_chat_message(
				"ANDROID",
				"A nossa condição já está no nível máximo. "
				+ "Usar a estação agora seria desnecessário."
			)

		return


	var life_before: int = current_life


	fight_manager.heal_shared_life(
		heal_amount
	)


	var life_after: int = int(
		fight_manager.get_shared_life()
	)


	var healed: int = (
		life_after
		- life_before
	)


	station_used = true


	station_visual.color = Color(
		0.16,
		0.18,
		0.19,
		1.0
	)


	status_label.text = (
		"ESTAÇÃO SEM ENERGIA"
	)


	interaction_label.text = (
		"ESTAÇÃO JÁ UTILIZADA"
	)


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"A estação ainda tinha energia suficiente "
			+ "para uma única sequência de manutenção. "
			+ "Vida Compartilhada restaurada em "
			+ str(healed)
			+ " pontos. "
			+ "Não conseguiremos utilizá-la novamente."
		)


	send_gameplay_context(
		healed,
		life_after
	)


	print("")
	print(
		"======================================"
	)

	print(
		"MAINTENANCE STATION USED"
	)

	print(
		"HEALED: +",
		healed
	)

	print(
		"SHARED LIFE: ",
		life_after,
		" / ",
		max_life
	)

	print(
		"======================================"
	)


func update_interaction_text():
	if interaction_label == null:
		return

	if station_used:
		interaction_label.text = (
			"ESTAÇÃO JÁ UTILIZADA"
		)

	else:
		interaction_label.text = (
			"[E] UTILIZAR ESTAÇÃO"
		)


func send_gameplay_context(
	healed: int,
	current_life: int
):
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"maintenance_station_used",
		"maintenance_station_used",
		"Atlas e o jogador encontraram uma estação funcional "
		+ "na Oficina / Manutenção da instalação subterrânea. "
		+ "A estação realizou uma única sequência de manutenção "
		+ "e recuperou "
		+ str(healed)
		+ " pontos de Vida Compartilhada. "
		+ "A Vida Compartilhada ficou em "
		+ str(current_life)
		+ ". "
		+ "Depois da utilização, a estação ficou sem energia "
		+ "suficiente para outra reparação.",
		true
	)


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


func is_station_used() -> bool:
	return station_used
