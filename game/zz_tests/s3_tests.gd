extends Node
# Etapa 3: o Atlas recebe o dispositivo sónico quando o equipamento é ligado.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
var results: Array = []
var SM

func check(id: String, desc: String, cond: bool, info: String = "") -> void:
	results.append(cond)
	print(("PASS " if cond else "FAIL ") + id + " " + desc + ("  [" + info + "]" if info != "" else ""))

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)
	await SM.start_new_run()
	for k in ["intro_completed", "surface_recovery_complete", "protocol_door_opened", "facility_security_unlocked", "hide_initial_complete"]:
		SM.set_run_value("story", k, true)
	for id in ["controls", "encounter", "run", "hide", "hack", "fight"]:
		SM.set_run_value("custom", "tutorial_" + id, true)
	get_tree().change_scene_to_file(MAIN)
	await frames(3)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	await frames(10)
	var main := get_tree().current_scene
	var player: CharacterBody2D = main.get_node("Player")
	var atlas: CharacterBody2D = main.get_node("Atlas")
	var fm: Node = main.get_node("FightManager")
	var sonic: Node = null
	for n in get_tree().get_nodes_in_group("saveable"):
		if n.has_method("connect_equipment"): sonic = n
	check("S3.0", "equipamento sónico encontrado e o Atlas ainda sem dispositivo", sonic != null and atlas.get_node_or_null("SonicDevice") == null)

	player.teleport_to(sonic.global_position + Vector2(-60, 140)) if player.has_method("teleport_to") else player.set("global_position", sonic.global_position + Vector2(-60, 140))
	atlas.global_position = sonic.global_position + Vector2(150, 160)
	await get_tree().physics_frame
	sonic.collect_tools()
	sonic.connect_equipment()
	await frames(2)
	check("S3.1", "ao ligar, começa a animação: Player parado e gravação manual bloqueada",
		sonic.equip_animation_active and player.tutorial_locked and SM.manual_save_blocks.has("sonic_equip"))
	check("S3.2", "o combate fica desbloqueado e as flags gravadas logo no início",
		fm.is_combat_unlocked() and bool(SM.get_run_value("story", "sonic_equipment_connected", false)))
	var saw_energy := false
	var saw_flying := false
	var t0 := Time.get_ticks_msec()
	while sonic.equip_animation_active and Time.get_ticks_msec() - t0 < 8000:
		if sonic.get_node_or_null("EquipEnergy") != null: saw_energy = true
		for c in main.get_children():
			if c.name.begins_with("SonicDevice") and c.get_parent() == main: saw_flying = true
		await frames(1)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var stand: Vector2 = sonic.global_position + sonic.EQUIP_STAND_OFFSET
	check("S3.3", "o Atlas vai até à bancada", atlas.global_position.distance_to(stand) < 12.0, "%.0f px" % atlas.global_position.distance_to(stand))
	check("S3.4", "há descarga de energia e o dispositivo voa da bancada para o Atlas", saw_energy and saw_flying)
	var device: Node2D = atlas.get_node_or_null("SonicDevice")
	check("S3.5", "no fim, o dispositivo fica no ombro do Atlas", device != null and device.visible and device.modulate.a > 0.99)
	check("S3.6", "a animação dura poucos segundos e depois tudo volta ao normal",
		took < 6.0 and not player.tutorial_locked and not SM.manual_save_blocks.has("sonic_equip") and atlas.modulate == Color.WHITE and not atlas.scripted_move_active,
		"%.1f s" % took)
	await frames(5)
	check("S3.7", "a fala do Atlas aparece depois da animação", sonic.interaction_label.text == "SISTEMA SONORO OPERACIONAL")

	# Segue a vista
	var sprite = atlas.get_node("CharacterSprite")
	sprite.facing = "side"; sprite.facing_left = false
	await frames(2)
	var right_x: float = device.position.x
	sprite.facing_left = true
	await frames(2)
	check("S3.8", "de lado, o dispositivo fica nas costas e troca de lado com a vista", right_x < 0.0 and device.position.x > 0.0, "%.0f / %.0f" % [right_x, device.position.x])
	sprite.facing = "front"; sprite.facing_left = false

	# Carregar um save
	device.free()
	sonic.load_save_data({"tools_collected": true, "equipment_connected": true})
	await frames(3)
	check("S3.9", "ao carregar um save com o equipamento ligado, o Atlas volta a ter o dispositivo (só um)",
		atlas.get_node_or_null("SonicDevice") != null and atlas.get_children().filter(func(c): return c.name.begins_with("SonicDevice")).size() == 1)

	# Luta
	fm.start_fight()
	await frames(3)
	var fight_device: Node2D = fm.atlas_device
	check("S3.10", "na luta, o Atlas também tem o dispositivo", fight_device != null and fight_device.get_parent() == fm.atlas_token)
	fm.selected_actor = 2
	fm.sonic_cooldown_left = 0.0
	fm.fire_sonic(fm.creature_position)
	check("S3.11", "ao disparar, o dispositivo brilha", fight_device.glow > 0.9)
	fm.destroy_fight_ui()
	fm.fight_active = false
	get_tree().paused = false

	var passed := results.count(true)
	print("RESULTADO S3: ", passed, " / ", results.size(), " PASS")
	get_tree().quit(0 if passed == results.size() else 1)
