extends Node2D


var main: Node = null
var player: CharacterBody2D = null

var power_restored: bool = false
var restoring_power: bool = false

var active_relays: Dictionary = {
	"A": false,
	"B": false,
	"C": false
}

var nearby_interactable: Area2D = null

var console_area: Area2D = null
var console_visual: Polygon2D = null
var console_label: Label = null

var security_barrier: StaticBody2D = null
var security_barrier_collision: CollisionShape2D = null
var security_barrier_visual: Polygon2D = null
var security_barrier_label: Label = null

var restoration_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene

	if main != null:
		player = main.get_node_or_null(
			"Player"
		)

	create_relay(
		"A",
		Vector2(
			850,
			-1740
		)
	)

	create_relay(
		"B",
		Vector2(
			1100,
			-1740
		)
	)

	create_relay(
		"C",
		Vector2(
			1350,
			-1740
		)
	)

	create_power_console()

	create_security_power_barrier()

	print("")
	print("======================================")
	print("TECHNICAL ENERGY SYSTEM READY")
	print("POWER RESTORED: ", power_restored)
	print("======================================")


func _unhandled_input(event):
	if power_restored:
		return

	if restoring_power:
		return

	if nearby_interactable == null:
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

	var interaction_type = str(
		nearby_interactable.get_meta(
			"interaction_type",
			""
		)
	)

	if interaction_type == "relay":
		var relay_id = str(
			nearby_interactable.get_meta(
				"relay_id",
				""
			)
		)

		activate_relay(
			nearby_interactable,
			relay_id
		)

	elif interaction_type == "console":
		try_restore_power()


func create_relay(
	relay_id: String,
	relay_position: Vector2
):
	var area = Area2D.new()

	area.name = (
		"EnergyRelay_"
		+ relay_id
	)

	area.position = relay_position

	area.collision_layer = 0
	area.collision_mask = 0xFFFFFFFF

	area.monitoring = true
	area.monitorable = true

	area.set_meta(
		"interaction_type",
		"relay"
	)

	area.set_meta(
		"relay_id",
		relay_id
	)

	add_child(
		area
	)


	var collision = CollisionShape2D.new()

	collision.name = "InteractionArea"

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		150,
		130
	)

	collision.shape = shape

	area.add_child(
		collision
	)


	var visual = Polygon2D.new()

	visual.name = "RelayVisual"

	visual.polygon = PackedVector2Array([
		Vector2(-45, -35),
		Vector2(45, -35),
		Vector2(45, 35),
		Vector2(-45, 35)
	])

	visual.color = Color(
		0.28,
		0.12,
		0.12,
		1.0
	)

	visual.z_index = 5

	area.add_child(
		visual
	)

	area.set_meta(
		"visual",
		visual
	)


	var id_label = Label.new()

	id_label.text = (
		"RELÉ "
		+ relay_id
	)

	id_label.position = Vector2(
		-70,
		-20
	)

	id_label.size = Vector2(
		140,
		40
	)

	id_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	id_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	id_label.add_theme_font_size_override(
		"font_size",
		15
	)

	id_label.z_index = 7

	area.add_child(
		id_label
	)


	var interaction_label = Label.new()

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] ATIVAR RELÉ "
		+ relay_id
	)

	interaction_label.position = Vector2(
		-130,
		-85
	)

	interaction_label.size = Vector2(
		260,
		40
	)

	interaction_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	interaction_label.add_theme_font_size_override(
		"font_size",
		16
	)

	interaction_label.visible = false

	interaction_label.z_index = 10

	area.add_child(
		interaction_label
	)

	area.set_meta(
		"interaction_label",
		interaction_label
	)


	area.body_entered.connect(
		on_interactable_body_entered.bind(
			area
		)
	)

	area.body_exited.connect(
		on_interactable_body_exited.bind(
			area
		)
	)


func create_power_console():
	console_area = Area2D.new()

	console_area.name = "PowerConsole"

	console_area.position = Vector2(
		1100,
		-1550
	)

	console_area.collision_layer = 0
	console_area.collision_mask = 0xFFFFFFFF

	console_area.monitoring = true
	console_area.monitorable = true

	console_area.set_meta(
		"interaction_type",
		"console"
	)

	add_child(
		console_area
	)


	var collision = CollisionShape2D.new()

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		190,
		140
	)

	collision.shape = shape

	console_area.add_child(
		collision
	)


	console_visual = Polygon2D.new()

	console_visual.polygon = PackedVector2Array([
		Vector2(-75, -40),
		Vector2(75, -40),
		Vector2(75, 40),
		Vector2(-75, 40)
	])

	console_visual.color = Color(
		0.20,
		0.22,
		0.24,
		1.0
	)

	console_visual.z_index = 5

	console_area.add_child(
		console_visual
	)


	var title = Label.new()

	title.text = "CONTROLO DE ENERGIA"

	title.position = Vector2(
		-110,
		-18
	)

	title.size = Vector2(
		220,
		40
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		14
	)

	title.z_index = 7

	console_area.add_child(
		title
	)


	console_label = Label.new()

	console_label.name = (
		"InteractionLabel"
	)

	console_label.position = Vector2(
		-180,
		-100
	)

	console_label.size = Vector2(
		360,
		50
	)

	console_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	console_label.add_theme_font_size_override(
		"font_size",
		16
	)

	console_label.visible = false

	console_label.z_index = 10

	console_area.add_child(
		console_label
	)

	console_area.set_meta(
		"interaction_label",
		console_label
	)

	update_console_state()


	console_area.body_entered.connect(
		on_interactable_body_entered.bind(
			console_area
		)
	)

	console_area.body_exited.connect(
		on_interactable_body_exited.bind(
			console_area
		)
	)


func create_security_power_barrier():
	security_barrier = StaticBody2D.new()

	security_barrier.name = (
		"SecurityPowerBarrier"
	)

	security_barrier.position = Vector2(
		1600,
		-1650
	)

	add_child(
		security_barrier
	)


	security_barrier_collision = (
		CollisionShape2D.new()
	)

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		28,
		160
	)

	security_barrier_collision.shape = shape

	security_barrier.add_child(
		security_barrier_collision
	)


	security_barrier_visual = Polygon2D.new()

	security_barrier_visual.polygon = PackedVector2Array([
		Vector2(-14, -80),
		Vector2(14, -80),
		Vector2(14, 80),
		Vector2(-14, 80)
	])

	security_barrier_visual.color = Color(
		0.85,
		0.08,
		0.08,
		0.80
	)

	security_barrier_visual.z_index = 20

	security_barrier.add_child(
		security_barrier_visual
	)


	security_barrier_label = Label.new()

	security_barrier_label.text = (
		"SETOR SEM ENERGIA"
	)

	security_barrier_label.position = Vector2(
		-115,
		-125
	)

	security_barrier_label.size = Vector2(
		230,
		40
	)

	security_barrier_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	security_barrier_label.add_theme_font_size_override(
		"font_size",
		15
	)

	security_barrier_label.z_index = 25

	security_barrier.add_child(
		security_barrier_label
	)


func on_interactable_body_entered(
	body: Node,
	area: Area2D
):
	if not is_player(
		body
	):
		return

	nearby_interactable = area

	update_interaction_label(
		area,
		true
	)


func on_interactable_body_exited(
	body: Node,
	area: Area2D
):
	if not is_player(
		body
	):
		return

	update_interaction_label(
		area,
		false
	)

	if nearby_interactable == area:
		nearby_interactable = null


func update_interaction_label(
	area: Area2D,
	visible: bool
):
	var label = area.get_meta(
		"interaction_label",
		null
	)

	if label == null:
		return

	if not is_instance_valid(
		label
	):
		return

	label.visible = visible


func activate_relay(
	area: Area2D,
	relay_id: String
):
	if not active_relays.has(
		relay_id
	):
		return

	if active_relays[
		relay_id
	]:
		return

	active_relays[
		relay_id
	] = true


	var visual = area.get_meta(
		"visual",
		null
	)

	if (
		visual != null
		and is_instance_valid(
			visual
		)
	):
		visual.color = Color(
			0.12,
			0.72,
			0.54,
			1.0
		)


	var label = area.get_meta(
		"interaction_label",
		null
	)

	if (
		label != null
		and is_instance_valid(
			label
		)
	):
		label.text = (
			"RELÉ "
			+ relay_id
			+ " ATIVO"
		)


	print(
		"ENERGY RELAY ",
		relay_id,
		" ACTIVATED"
	)


	if all_relays_active():

		update_console_state()

		if (
			main != null
			and main.has_method(
				"add_chat_message"
			)
		):
			main.add_chat_message(
				"ANDROID",
				"Os três relés estão sincronizados. "
				+ "O painel central já pode tentar "
				+ "restaurar a rede auxiliar."
			)


func all_relays_active() -> bool:
	return (
		active_relays["A"]
		and active_relays["B"]
		and active_relays["C"]
	)


func update_console_state():
	if console_label == null:
		return

	if power_restored:
		console_label.text = (
			"ENERGIA RESTAURADA"
		)

		return

	if all_relays_active():
		console_label.text = (
			"[E] RESTAURAR REDE AUXILIAR"
		)

	else:
		var active_count: int = 0

		for relay_id in active_relays.keys():

			if active_relays[
				relay_id
			]:
				active_count += 1

		console_label.text = (
			"RELÉS ATIVOS: "
			+ str(
				active_count
			)
			+ " / 3"
		)


func try_restore_power():
	if power_restored:
		return

	if not all_relays_active():

		if (
			main != null
			and main.has_method(
				"add_chat_message"
			)
		):
			main.add_chat_message(
				"ANDROID",
				"A rede não responde. "
				+ "Ainda precisamos ativar "
				+ "os três relés da sala."
			)

		return

	restore_power()


func restore_power():
	if restoring_power:
		return

	restoring_power = true

	get_tree().paused = true

	create_restoration_ui()

	await get_tree().create_timer(
		1.5,
		true
	).timeout

	power_restored = true
	restoring_power = false

	set_meta(
		"power_restored",
		true
	)

	if get_parent() != null:
		get_parent().set_meta(
			"facility_power_restored",
			true
		)

	remove_security_barrier()

	update_console_state()

	if console_visual != null:
		console_visual.color = Color(
			0.10,
			0.72,
			0.58,
			1.0
		)

	destroy_restoration_ui()

	get_tree().paused = false


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Rede auxiliar restaurada. "
			+ "O setor de Segurança / Contenção "
			+ "voltou a receber energia."
		)


	send_gameplay_context()


	print("")
	print("======================================")
	print("FACILITY AUXILIARY POWER RESTORED")
	print("SECURITY ACCESS POWERED")
	print("======================================")


func remove_security_barrier():
	if security_barrier_collision != null:
		security_barrier_collision.set_deferred(
			"disabled",
			true
		)

	if security_barrier_visual != null:
		security_barrier_visual.visible = false

	if security_barrier_label != null:
		security_barrier_label.visible = false


func create_restoration_ui():
	destroy_restoration_ui()

	restoration_layer = CanvasLayer.new()

	restoration_layer.name = (
		"PowerRestorationUI"
	)

	restoration_layer.layer = 650

	restoration_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		restoration_layer
	)


	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.0,
		0.0,
		0.0,
		0.82
	)

	restoration_layer.add_child(
		background
	)


	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(
		center
	)


	var label = Label.new()

	label.text = (
		"RESTAURANDO REDE AUXILIAR...\n\n"
		+ "SINCRONIZAÇÃO DE ENERGIA"
	)

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	label.add_theme_font_size_override(
		"font_size",
		26
	)

	center.add_child(
		label
	)


func destroy_restoration_ui():
	if (
		restoration_layer != null
		and is_instance_valid(
			restoration_layer
		)
	):
		restoration_layer.queue_free()

	restoration_layer = null


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"facility_auxiliary_power_restored",
		"facility_power_restored",
		"Atlas e o jogador restauraram a rede auxiliar "
		+ "da instalação subterrânea através da Sala Técnica / Energia. "
		+ "Os três relés da sala foram ativados e sincronizados. "
		+ "O setor de Segurança / Contenção voltou a receber energia "
		+ "e o bloqueio energético que impedia o acesso foi removido. "
		+ "Isto não revela automaticamente o conteúdo da Segurança; "
		+ "apenas confirma que o setor voltou a estar acessível.",
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


func is_power_restored() -> bool:
	return power_restored
