extends Node
# Etapa 5: entrada na Phase 3 a andar e Sala de Controlo igual à planta do
# confronto, com a animação de chegada antes das instruções.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
const SPAWN := Vector2(8540.0, -3803.0)
const BossView := preload("res://scripts/phase3_boss_view.gd")
var results: Array = []
var SM

func check(id: String, desc: String, cond: bool, info: String = "") -> void:
	results.append(cond)
	print(("PASS " if cond else "FAIL ") + id + " " + desc + ("  [" + info + "]" if info != "" else ""))

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func wait_until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
	return cond.call()

func scene() -> Node: return get_tree().current_scene

func near(a: Vector2, b: Vector2, tolerance: float = 2.0) -> bool:
	return a.distance_to(b) <= tolerance

func press(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_viewport().push_input(event)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	get_viewport().push_input(up)

func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)
	await SM.start_new_run()
	for key in ["intro_completed", "surface_recovery_complete", "protocol_door_opened",
			"facility_security_unlocked", "hide_initial_complete", "main_core_access_unlocked"]:
		SM.set_run_value("story", key, true)
	for id in ["controls", "encounter", "run", "hide", "hack", "fight"]:
		SM.set_run_value("custom", "tutorial_" + id, true)
	SM.set_run_value("world", "main_core_password_solved", true)
	SM.set_run_value("world", "phase3_twist_stage", 3)
	get_tree().change_scene_to_file(MAIN)
	await frames(3)
	while scene() == null or not scene().is_node_ready():
		await get_tree().process_frame
	await frames(15)
	var player: CharacterBody2D = scene().get_node("Player")
	var atlas: CharacterBody2D = scene().get_node("Atlas")
	var layout: Node2D = scene().get_node("Endgame")
	var core: Node = scene().get_node("UndergroundRoot/MainCoreTerminal")

	# --- Entrada na Phase 3 ---
	core.teleport_to_phase3()
	var fade: CanvasLayer = scene().get_node_or_null("Phase3EntryFade")
	var black: ColorRect = fade.get_child(0) if fade != null else null
	check("S5.1", "entrada: ecrã preto e o Player na abertura esquerda da sala 1, a andar sozinho",
		black != null and black.color.a > 0.99 and near(player.global_position, SPAWN + Vector2(-440.0, 0.0)) and player.scripted_move_active,
		str(player.global_position - SPAWN))
	await get_tree().create_timer(0.6).timeout
	check("S5.2", "entrada: durante a caminhada pode-se gravar e o jogo não está pausado", SM.can_manual_save() and not get_tree().paused, SM.get_manual_save_block_reason())
	var cleared: bool = await wait_until(func(): return scene().get_node_or_null("Phase3EntryFade") == null, 3.0)
	check("S5.3", "entrada: o ecrã clareia e o preto sai", cleared)
	var arrived: bool = await wait_until(func(): return not player.scripted_move_active, 4.0)
	check("S5.4", "entrada: o Player chega ao centro da sala e volta a ser controlado",
		arrived and near(player.global_position, SPAWN, 6.0), str(player.global_position - SPAWN))
	check("S5.5", "entrada: o Atlas entrou atrás do Player", atlas.global_position.x > SPAWN.x - 300.0 and atlas.global_position.x < player.global_position.x,
		str(atlas.global_position - SPAWN))
	var saved: bool = await wait_until(func(): return SM.active_run_data.get("last_checkpoint", "") == "phase3_entered", 5.0)
	check("S5.6", "entrada: autosave phase3_entered como antes", saved)
	# Um load ou um teste que mude o Player de sítio acaba a caminhada.
	player.start_scripted_move_to(SPAWN + Vector2(200.0, 0.0))
	await get_tree().physics_frame
	player.global_position = SPAWN + Vector2(0.0, 120.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("S5.7", "caminhada por script acaba se o Player for posto noutro sítio", not player.scripted_move_active)

	# --- Sala de Controlo igual à planta do confronto ---
	var room: Node2D = layout.get_node("Sala_2_Criatura")
	var room_size: Vector2 = layout.control_room_size()
	var view_ratio := BossView.ROOM.size.y / BossView.ROOM.size.x
	check("S5.8", "Sala de Controlo com a proporção da planta (600 x 272)",
		absf(room_size.y / room_size.x - view_ratio) < 0.001 and room_size.x == layout.room_size.x, str(room_size))
	var opening: float = layout.corridor_width + layout.wall_width * 2.0
	check("S5.9", "as portas têm a mesma proporção na sala e no confronto",
		absf(opening / room_size.y - BossView.DOOR_HEIGHT / BossView.ROOM.size.y) < 0.01,
		"%.3f vs %.3f" % [opening / room_size.y, BossView.DOOR_HEIGHT / BossView.ROOM.size.y])
	var structures := layout.get_children().filter(func(c): return String(c.name).begins_with("Estrutura_"))
	var art: Node2D = layout.get_node("ControlRoomArt")
	var console: Node2D = layout.get_node("Consola_Controlo")
	var expected_console := room.position + BossView.to_room(BossView.CONSOLE.get_center(), room_size)
	var shape: RectangleShape2D = console.get_node("Solid").get_child(0).shape
	check("S5.10", "sem as 4 estruturas; consola sólida no mesmo sítio e tamanho da planta",
		structures.is_empty() and near(console.position, expected_console) and shape.size.is_equal_approx(BossView.CONSOLE.size * room_size.x / BossView.ROOM.size.x),
		str(console.position - room.position) + " " + str(shape.size))
	var thermo_left: Rect2 = art.rect(BossView.thermo_rect("left"))
	var thermo_right: Rect2 = art.rect(BossView.thermo_rect("right"))
	check("S5.11", "um termómetro junto a cada porta, dentro da sala",
		thermo_left.position.x < -room_size.x / 2.0 + 80.0 and thermo_left.position.x > -room_size.x / 2.0
		and thermo_right.end.x > room_size.x / 2.0 - 80.0 and thermo_right.end.x < room_size.x / 2.0,
		str(thermo_left) + " " + str(thermo_right))
	var doors_striped := 0
	for door in layout.phase3_exit_doors:
		if door["visual"].get_node_or_null("HazardStripes") != null: doors_striped += 1
	if layout.hangar_door["visual"].get_node_or_null("HazardStripes") != null: doors_striped += 1
	check("S5.12", "as duas portas da sala têm as riscas das portas do confronto", doors_striped == 2, str(doors_striped))

	# --- Chegada à Sala de Controlo ---
	player.global_position = SPAWN + room.position + Vector2(-200.0, 0.0)
	atlas.global_position = SPAWN + room.position + Vector2(-300.0, 0.0)
	var started: bool = await wait_until(func(): return layout.control_room_intro_active, 3.0)
	check("S5.13", "ao entrar começa a animação, antes das instruções; sem save manual e sem pausa",
		started and layout.boss_ui == null and not SM.can_manual_save() and not get_tree().paused, SM.get_manual_save_block_reason())
	var at_console: bool = await wait_until(func(): return layout.control_room_layer != null, 5.0)
	var player_spot: Vector2 = art.to_global(art.player_spot())
	var atlas_spot: Vector2 = art.to_global(art.atlas_spot())
	check("S5.14", "o Player e o Atlas vão para os lugares que têm no confronto, à frente da consola",
		at_console and near(player.global_position, player_spot, 8.0) and near(atlas.global_position, atlas_spot, 8.0)
		and near(BossView.to_room(BossView.PLAYER_FEET, room_size), art.player_spot() + Vector2(0.0, 16.0)),
		str(player.global_position - player_spot) + " " + str(atlas.global_position - atlas_spot))
	await get_tree().create_timer(0.9).timeout
	check("S5.15", "a consola liga-se e aparece a primeira fala", art.awake >= 1.0 and layout.control_room_label.text == layout.CONTROL_ROOM_LINES[0])
	press(KEY_E)
	await frames(3)
	check("S5.16", "[E] passa à fala seguinte", layout.control_room_label.text == layout.CONTROL_ROOM_LINES[1])
	layout.advance_control_room_line()
	await frames(3)
	await get_tree().create_timer(2.7).timeout
	check("S5.17", "na fala do sensor, a porta da esquerda aquece (termómetro e corredor)",
		layout.control_room_label.text == layout.CONTROL_ROOM_LINES[2] and art.heat["left"] > 0.5 and art.temperature("left") >= 28.0,
		"%.1f °C" % art.temperature("left"))
	var lines_seen := 3
	while layout.control_room_layer != null and lines_seen < 10:
		layout.advance_control_room_line()
		lines_seen += 1
		await frames(3)
	await wait_until(func(): return layout.boss_ui != null, 3.0)
	var boss = layout.boss_ui
	check("S5.18", "depois da última fala abrem as instruções do confronto (G1)",
		boss != null and boss.briefing_open and layout.control_room_layer == null and lines_seen == layout.CONTROL_ROOM_LINES.size() + 1)
	check("S5.19", "a animação fica marcada como vista na run e só o bloqueio do confronto fica ativo",
		bool(SM.get_run_value("story", "phase3_control_room_seen", false)) and SM.get_manual_save_block_reason() != "" and not SM.manual_save_blocks.has("cutscene"),
		str(SM.manual_save_blocks.keys()))

	# Fim do confronto: o anel do Hangar fica cheio.
	boss.close_briefing()
	boss.set_process(false)
	var t := 0.0
	while boss.running and t < 61.0:
		boss.step(0.1)
		t += 0.1
	await wait_until(func(): return bool(layout.boss_done), 5.0)
	check("S5.20", "depois do confronto o anel do Hangar fica cheio e o calor desaparece",
		art.hangar_progress >= 1.0 and art.heat["left"] == 0.0 and not get_tree().paused)

	# Já vista: entrar outra vez vai direto ao confronto.
	layout.boss_done = false
	layout.enter_control_room()
	await wait_until(func(): return layout.boss_ui != null, 3.0)
	check("S5.21", "já vista: entrar outra vez vai direto às instruções, sem falas",
		layout.boss_ui != null and layout.control_room_layer == null and not layout.control_room_intro_active)
	if layout.boss_ui != null:
		layout.boss_ui.queue_free()
		layout.boss_ui = null
	get_tree().paused = false

	var passed := results.filter(func(r): return r).size()
	print("RESULTADO S5: %d / %d PASS" % [passed, results.size()])
	get_tree().quit()
