extends Area2D

const SonicDeviceArt := preload("res://scripts/sonic_device_art.gd")

# Animação de ligar o equipamento ao Atlas.
const EQUIP_WALK_TIMEOUT := 2.0
const EQUIP_ENERGY_TIME := 1.0
const EQUIP_FLY_TIME := 0.7
const EQUIP_STAND_OFFSET := Vector2(0.0, 80.0)

var player_nearby: bool = false

var tools_collected: bool = false
var equipment_connected: bool = false

var main: Node = null
var fight_manager: Node = null

var equipment_visual: Polygon2D = null
var energy_visual: Polygon2D = null
var interaction_label: Label = null

var equip_animation_active: bool = false


func _ready():
	add_to_group("saveable")
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
	create_visuals()
	create_interaction_label()

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print(
		"SONIC EQUIPMENT READY"
	)


func _unhandled_input(event):
	if equipment_connected:
		return

	if not player_nearby:
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

	if not tools_collected:
		collect_tools()

	else:
		connect_equipment()


func create_collision():
	var collision = CollisionShape2D.new()

	collision.name = "InteractionArea"

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		190,
		150
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_visuals():
	equipment_visual = Polygon2D.new()

	equipment_visual.name = "SonicDevice"

	equipment_visual.polygon = PackedVector2Array([
		Vector2(-65, -35),
		Vector2(65, -35),
		Vector2(65, 35),
		Vector2(-65, 35)
	])

	equipment_visual.color = Color(
		0.25,
		0.28,
		0.30,
		1.0
	)

	equipment_visual.z_index = 5

	add_child(
		equipment_visual
	)


	energy_visual = Polygon2D.new()

	energy_visual.name = "AlienEnergy"

	energy_visual.polygon = PackedVector2Array([
		Vector2(-22, -22),
		Vector2(22, -22),
		Vector2(22, 22),
		Vector2(-22, 22)
	])

	energy_visual.position = Vector2(
		90,
		0
	)

	energy_visual.color = Color(
		0.18,
		0.75,
		0.72,
		1.0
	)

	energy_visual.z_index = 6

	add_child(
		energy_visual
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.name = (
		"InteractionLabel"
	)

	interaction_label.text = (
		"[E] RECOLHER FERRAMENTAS"
	)

	interaction_label.position = Vector2(
		-180,
		-100
	)

	interaction_label.size = Vector2(
		360,
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


func on_body_exited(
	body: Node
):
	if not is_player(
		body
	):
		return

	player_nearby = false

	interaction_label.visible = false


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


func collect_tools():
	if tools_collected:
		return

	tools_collected = true
	SaveManager.set_run_value("story", "sonic_tools_collected", true)

	equipment_visual.color = Color(
		0.35,
		0.43,
		0.46,
		1.0
	)

	interaction_label.text = (
		"[E] CONECTAR ATLAS À ENERGIA"
	)

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Estas ferramentas fazem parte de um sistema acústico. "
			+ "A estrutura parece compatível comigo, "
			+ "mas precisa de uma fonte de energia."
		)

	print("")
	print(
		"SONIC TOOLS COLLECTED"
	)


func connect_equipment():
	if equipment_connected:
		return

	if not tools_collected:
		return

	if fight_manager == null:
		push_error(
			"FightManager não encontrado."
		)

		return

	if not fight_manager.has_method(
		"unlock_combat"
	):
		push_error(
			"FightManager não possui unlock_combat()."
		)

		return

	equipment_connected = true
	SaveManager.set_run_value("story", "sonic_equipment_connected", true)
	# Autosave #5 da Bíblia: sistema sonoro ligado, FIGHT desbloqueado.
	SaveManager.autosave_when_safe("sonic_equipment_connected")

	fight_manager.unlock_combat()

	equipment_visual.color = Color(
		0.15,
		0.82,
		0.68,
		1.0
	)

	energy_visual.color = Color(
		0.30,
		1.0,
		0.82,
		1.0
	)

	interaction_label.text = (
		"SISTEMA SONORO OPERACIONAL"
	)

	await play_equip_animation()

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Conexão concluída. "
			+ "O equipamento utiliza energia desta instalação "
			+ "para gerar ondas sonoras de alta intensidade. "
			+ "Se encontrarmos novamente aquela criatura, "
			+ "agora tenho uma forma de a afastar."
		)

	send_gameplay_context()

	print("")
	print(
		"======================================"
	)

	print(
		"SONIC COMBAT EQUIPMENT CONNECTED"
	)

	print(
		"FIGHT UNLOCKED"
	)

	print(
		"======================================"
	)


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"sonic_equipment_connected",
		"combat_equipment_acquired",
		"Atlas recolheu ferramentas no Armazém / Peças "
		+ "e integrou um equipamento acústico da instalação "
		+ "a uma fonte de energia alienígena. "
		+ "O equipamento produz ondas sonoras de alta intensidade "
		+ "que podem afastar a criatura. "
		+ "Atlas não utiliza uma arma de projéteis: "
		+ "o seu método de combate atual depende de emissão sonora. "
		+ "O dispositivo ficou preso ao ombro do Atlas. "
		+ "Na luta, a criatura persegue o jogador, que tem de fugir, "
		+ "enquanto o Atlas aponta e dispara ondas sonoras contra ela; "
		+ "o dispositivo precisa de 2 segundos para recarregar.",
		true
	)

	# Atlas 2.0: o Atlas reage por iniciativa própria.
	if main.has_method("request_atlas_spontaneous"):
		main.request_atlas_spontaneous("sonic_equipment_connected")


func get_save_id() -> String:
	return "sonic_equipment"


func get_save_data() -> Dictionary:
	return {"tools_collected": tools_collected, "equipment_connected": equipment_connected}


func load_save_data(data: Dictionary):
	equipment_connected = bool(data.get("equipment_connected", false))
	tools_collected = equipment_connected or bool(data.get("tools_collected", false))
	if equipment_connected:
		equipment_visual.color = Color(0.15, 0.82, 0.68, 1.0)
		energy_visual.color = Color(0.30, 1.0, 0.82, 1.0)
		interaction_label.text = "SISTEMA SONORO OPERACIONAL"
		call_deferred("mount_device_on_atlas")
	elif tools_collected:
		equipment_visual.color = Color(0.35, 0.43, 0.46, 1.0)
		interaction_label.text = "[E] CONECTAR ATLAS À ENERGIA"
	else:
		interaction_label.text = "[E] RECOLHER FERRAMENTAS"


func get_atlas() -> Node2D:
	if main == null or not is_instance_valid(main):
		main = get_tree().current_scene

	if main == null:
		return null

	return main.get_node_or_null("Atlas")


func mount_device_on_atlas() -> Node2D:
	return SonicDeviceArt.mount_on(get_atlas())


# O Atlas vai até à bancada, a energia passa para ele e o dispositivo sónico
# sai da bancada e prende-se ao ombro dele. O Player fica parado e não se
# pode gravar à mão enquanto dura (cerca de 3 s).
func play_equip_animation() -> void:
	var atlas := get_atlas()

	if atlas == null:
		return

	equip_animation_active = true
	SaveManager.set_manual_save_block("sonic_equip", true)

	var player: Node = main.get_node_or_null("Player")

	if player != null and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(true)

	# 1. O Atlas aproxima-se da bancada.
	var stand := global_position + EQUIP_STAND_OFFSET

	if atlas.has_method("start_scripted_move_to"):
		atlas.start_scripted_move_to(stand)

		var waited := 0.0

		while waited < EQUIP_WALK_TIMEOUT and atlas.global_position.distance_to(stand) > 6.0:
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()

		atlas.stop_scripted_move_to()

	# 2. Descarga de energia da fonte para o Atlas.
	var energy := Line2D.new()
	energy.name = "EquipEnergy"
	energy.width = 3.0
	energy.default_color = Color(0.45, 1.0, 0.95, 0.9)
	energy.z_as_relative = false
	energy.z_index = 20
	add_child(energy)

	var elapsed := 0.0

	while elapsed < EQUIP_ENERGY_TIME:
		var from := energy_visual.position
		var to := to_local(atlas.global_position + Vector2(0.0, -26.0))
		energy.points = lightning_points(from, to)
		energy.modulate.a = 0.55 + 0.45 * randf()
		equipment_visual.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 2.0, 2.0), 0.5 + 0.5 * sin(elapsed * 30.0))
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	energy.queue_free()
	equipment_visual.modulate = Color.WHITE

	# 3. O dispositivo sai da bancada e vai para o ombro do Atlas.
	var mounted := SonicDeviceArt.mount_on(atlas)
	mounted.modulate.a = 0.0
	mounted.follow_view()

	var flying := SonicDeviceArt.make(1.8)
	flying.z_as_relative = false
	flying.z_index = 20
	main.add_child(flying)
	flying.global_position = equipment_visual.global_position

	var tween := flying.create_tween().set_parallel(true)
	tween.tween_property(flying, "global_position", mounted.global_position, EQUIP_FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "scale", Vector2.ONE, EQUIP_FLY_TIME)
	await tween.finished

	flying.queue_free()
	mounted.modulate.a = 1.0
	mounted.pulse()

	# 4. O Atlas pisca com a energia do dispositivo.
	var flash := atlas.create_tween()

	for i in 2:
		flash.tween_property(atlas, "modulate", Color(0.6, 1.6, 1.6), 0.12)
		flash.tween_property(atlas, "modulate", Color.WHITE, 0.12)

	await flash.finished
	await get_tree().create_timer(0.4).timeout

	if player != null and is_instance_valid(player) and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(false)

	SaveManager.set_manual_save_block("sonic_equip", false)
	equip_animation_active = false


# Raio em ziguezague entre dois pontos.
func lightning_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var normal := (to - from).orthogonal().normalized()

	for i in range(1, 8):
		var t := i / 8.0
		points.append(from.lerp(to, t) + normal * randf_range(-10.0, 10.0))

	points.append(to)
	return points
