extends Node
# Etapa 8 (25/10): erro do facing_time, colisões da superfície e das
# condutas, condutas dos corredores mais pequenas, confronto final mais
# difícil, planetas no menu e intro com o cenário do menu.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
const MENU := "res://scenes/main_menu.tscn"
const Boss := preload("res://scripts/phase3_boss.gd")
const BossBefore := preload("res://zz_tests/phase3_boss_antes.gd")
const CreatureActor := preload("res://scripts/creature_actor.gd")
const MenuBackdrop := preload("res://scripts/menu_backdrop.gd")
const Layout := preload("res://scripts/phase3_layout.gd")
const PLAYER_RADIUS := 15.0

var results: Array = []
var SM
var main: Node2D

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

func open(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await frames(3)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame

# Um círculo do tamanho do Player cabe ali (só corpos sólidos, sem áreas)?
func free_at(point: Vector2, exclude: Array) -> bool:
	var space: PhysicsDirectSpaceState2D = main.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	query.shape = circle
	query.transform = Transform2D(0.0, point)
	query.collide_with_areas = false
	query.exclude = exclude
	return space.intersect_shape(query, 1).is_empty()

# Simulação do confronto: o Player fecha a porta quente e abre a fria,
# com "react" segundos de atraso.
func simulate(boss, react: float) -> Dictionary:
	boss.set_process(false)
	var t := 0.0
	var pending: Array = []
	var last_reading := {"left": -1.0, "right": -1.0}
	while boss.running and t < 61.0:
		for side in ["left", "right"]:
			if boss.sensor_readings[side] != last_reading[side]:
				last_reading[side] = boss.sensor_readings[side]
				pending.append([t + react, side, boss.sensor_readings[side] >= 28.0])
		for item in pending.duplicate():
			if item[0] <= t:
				pending.erase(item)
				if boss.doors_closed[item[1]] != item[2]:
					boss.toggle_door(item[1])
		boss.step(0.05)
		t += 0.05
	return boss.get_stats()

func damage_rate(script, react: float, runs: int) -> float:
	var damaged := 0
	for seed in range(1, runs + 1):
		var boss = script.new()
		add_child(boss)
		boss.start(seed)
		if simulate(boss, react)["atlas_damaged"]:
			damaged += 1
		boss.queue_free()
	return float(damaged) / runs


func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)

	# --- 1. Erro "facing_time" com o character_sprite.gd antigo ---
	var old_sprite_script := GDScript.new()
	old_sprite_script.source_code = "extends AnimatedSprite2D\nvar facing: String = \"front\"\n"
	old_sprite_script.reload()
	var body := Node2D.new()
	var old_sprite = old_sprite_script.new()
	old_sprite.name = "CharacterSprite"
	body.add_child(old_sprite)
	add_child(body)
	var layout_probe = Layout.new()
	layout_probe.face(body, "back", true)
	check("S8.1", "face() funciona com o character_sprite.gd antigo (sem facing_time nem facing_left)", old_sprite.facing == "back")
	body.queue_free()
	layout_probe.free()

	# --- 2. Superfície ---
	await SM.start_new_run()
	SM.set_run_value("story", "intro_completed", true)
	for id in ["controls", "encounter", "run", "hide", "hack", "fight"]:
		SM.set_run_value("custom", "tutorial_" + id, true)
	await open(MAIN)
	await frames(15)
	main = get_tree().current_scene
	var decor: Node = main.get_node("RoomDecor")
	var player: CharacterBody2D = main.get_node("Player")
	var atlas: CharacterBody2D = main.get_node("Atlas")
	var surface: Array = decor.placed.filter(func(x): return x["room"] == "Surface")
	var not_solid: Array = []
	for item in surface:
		if item["kind"] != "skid" and item["node"].get_node_or_null("Solid") == null:
			not_solid.append(item["kind"])
	var kinds := {}
	for item in surface:
		kinds[item["kind"]] = true
	check("S8.2", "superfície: todas as decorações têm colisão (exceto o rasto do despiste no chão)", not_solid.is_empty() and surface.size() > 20,
		"%d objetos, tipos %s, sem colisão %s" % [surface.size(), str(kinds.keys()), str(not_solid)])

	# Caminhos: do Player até às 6 peças, à porta do protocolo e à nave.
	var exclude: Array = [player.get_rid(), atlas.get_rid()]
	var ground: Polygon2D = main.get_node("Ground")
	var ground_points := PackedVector2Array()
	for p in ground.polygon:
		ground_points.append(ground.global_transform * p)
	var step := 20.0
	var origin := player.global_position
	var seen := {}
	var queue: Array = [Vector2i(0, 0)]
	seen[Vector2i(0, 0)] = true
	var reached: Array = []
	var head := 0
	while head < queue.size() and queue.size() < 60000:
		var cell: Vector2i = queue[head]
		head += 1
		reached.append(origin + Vector2(cell) * step)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + d
			if seen.has(next):
				continue
			seen[next] = true
			var point := origin + Vector2(next) * step
			if Geometry2D.is_point_in_polygon(point, ground_points) and free_at(point, exclude):
				queue.append(next)
	var unreachable: Array = []
	for target_name in ["ShipPart1", "ShipPart2", "ShipPart3", "ShipPart4", "ShipPart5", "ShipPart6", "ProtocolDoor", "Ship"]:
		var target: Node2D = main.get_node_or_null(target_name)
		if target == null:
			continue
		var reach := 90.0 if target_name != "Ship" else 260.0
		var ok := false
		for point in reached:
			if point.distance_to(target.global_position) <= reach:
				ok = true
				break
		if not ok:
			unreachable.append(target_name)
	check("S8.3", "superfície: com as colisões novas, o Player ainda chega às 6 peças, à porta e à nave", unreachable.is_empty(),
		"%d pontos alcançáveis; sem caminho: %s" % [reached.size(), str(unreachable)])

	# --- 3. Condutas ---
	var aem: Node = main.get_node("UndergroundRoot/AlienEncounterManager")
	var room_vents_ok := true
	for item in decor.vents:
		var solid: StaticBody2D = item["node"].get_node_or_null("Solid")
		if solid == null or free_at(item["node"].global_position, exclude):
			room_vents_ok = false
	check("S8.4", "condutas das salas (%d): têm colisão, não se anda por cima" % decor.vents.size(), room_vents_ok and decor.vents.size() == 11)

	var small := true
	var blocked: Array = []
	var corridor_size := CreatureActor.vent_size(CreatureActor.CORRIDOR_VENT_SCALE)
	for cid in aem.corridor_vents:
		var vent: Node2D = aem.get_node_or_null("Vent_" + cid)
		if vent == null or vent.get_meta("vent_scale", 0.0) != CreatureActor.CORRIDOR_VENT_SCALE or vent.get_node_or_null("Solid") == null:
			small = false
			continue
		if free_at(vent.global_position, exclude):
			small = false
		# Lugar para o Player ao lado da conduta (para baixo ou para a direita,
		# o lado contrário à parede onde está encostada).
		var beside_down := vent.global_position + Vector2(0.0, corridor_size.y / 2.0 + PLAYER_RADIUS + 4.0)
		var beside_right := vent.global_position + Vector2(corridor_size.x / 2.0 + PLAYER_RADIUS + 4.0, 0.0)
		if not free_at(beside_down, exclude) and not free_at(beside_right, exclude):
			blocked.append(cid)
	check("S8.5", "condutas dos corredores (%d): mais pequenas (%.0f x %.0f), sólidas e com passagem ao lado" % [aem.corridor_vents.size(), corridor_size.x, corridor_size.y],
		small and blocked.is_empty() and aem.corridor_vents.size() > 0, "sem passagem: " + str(blocked))

	# A criatura sai da conduta do corredor ao tamanho dela e cresce a procurar.
	var cid0: String = aem.corridor_vents.keys()[0]
	var creature: Node2D = aem.spawn_creature(aem.corridor_vents[cid0])
	creature.emerge_then_search([])
	await frames(2)
	var emerge_scale: float = creature.body.scale.x
	await wait_until(func(): return creature.state == creature.State.SEARCH, 3.0)
	await get_tree().create_timer(CreatureActor.GROW_TIME + 0.1).timeout
	check("S8.6", "a criatura sai da conduta pequena ao tamanho dela e depois fica do tamanho normal",
		is_equal_approx(emerge_scale, CreatureActor.CORRIDOR_VENT_SCALE) and is_equal_approx(creature.body.scale.x, CreatureActor.SPRITE_SCALE),
		"%.2f -> %.2f" % [emerge_scale, creature.body.scale.x])
	aem.destroy_creature()

	# --- 4. Confronto final mais difícil ---
	var before_fast := damage_rate(BossBefore, 0.4, 150)
	var after_fast := damage_rate(Boss, 0.4, 150)
	var after_slow := damage_rate(Boss, 0.8, 150)
	check("S8.7", "confronto: o Atlas pode ficar danificado mesmo a jogar bem (150 simulações cada)",
		before_fast < 0.1 and after_fast >= 0.15 and after_slow > after_fast and after_slow < 0.9,
		"antes %.0f%%; agora %.0f%% (reação 0,4 s), %.0f%% (reação 0,8 s)" % [before_fast * 100.0, after_fast * 100.0, after_slow * 100.0])
	var rushes := 0
	for seed in range(1, 41):
		var boss = Boss.new()
		add_child(boss)
		boss.start(seed)
		rushes += int(simulate(boss, 0.4)["rushes"])
		boss.queue_free()
	check("S8.8", "investidas só na segunda metade e acontecem", rushes > 0, "%d em 40 confrontos" % rushes)
	var briefing = Boss.new()
	add_child(briefing)
	briefing.open_briefing(3)
	await frames(2)
	var text := ""
	for label in briefing.briefing_panel.find_children("*", "Label", true, false):
		text += label.text + "\n"
	check("S8.9", "as instruções mostram os valores novos (1,6 s à porta, 20 s com uma porta, 10 s com as duas)",
		text.contains("1,6 s") and text.contains("aguenta 20 s") and text.contains("só 10 s") and text.contains("aos saltos") and text.contains("-5 /s"))
	briefing.queue_free()

	# --- 5. Menu com planetas ---
	await open(MENU)
	await frames(10)
	var menu := get_tree().current_scene
	var backdrop: Control = menu.find_child("MenuBackdrop", true, false)
	var panel_rect := Rect2()
	for panel in menu.find_children("*", "PanelContainer", true, false):
		if panel.get_global_rect().get_area() > panel_rect.get_area():
			panel_rect = panel.get_global_rect()
	var clear := true
	for planet in MenuBackdrop.PLANETS:
		var r: float = backdrop.size.y * planet[1] * (1.75 if planet[4] else 1.0)
		var c := Vector2(planet[0].x * backdrop.size.x, planet[0].y * backdrop.size.y)
		if panel_rect.intersects(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)):
			clear = false
	check("S8.10", "menu: três planetas, nenhum por trás do painel dos botões", backdrop != null and MenuBackdrop.PLANETS.size() == 3 and clear and backdrop.warp == 0.0, str(panel_rect))

	# --- 6. Intro com o cenário do menu ---
	await SM.start_new_run()
	await open(MAIN)
	var intro: Node = null
	for i in 120:
		for child in get_tree().current_scene.get_children():
			if child.get_script() != null and child.get_script().resource_path.ends_with("intro_sequence.gd"):
				intro = child
		if intro != null:
			break
		await frames(1)
	var has_backdrop: bool = await wait_until(func(): return intro.screen_root != null and intro.screen_root.get_node_or_null("IntroBackdrop") != null, 10.0)
	var intro_backdrop: Control = intro.screen_root.get_node_or_null("IntroBackdrop") if has_backdrop else null
	check("S8.11", "intro: a cena 1 usa o mesmo espaço do menu (planetas, horizonte), sem a nave parada",
		intro_backdrop != null and intro_backdrop.get_script() == MenuBackdrop and intro_backdrop.ship == null)
	Engine.time_scale = 3.0
	var appeared: bool = await wait_until(func(): return intro.screen_root.get_node_or_null("FlyingShip") != null, 40.0)
	var ship: Node2D = intro.screen_root.get_node_or_null("FlyingShip")
	await frames(6)
	var warp_peak: float = intro_backdrop.warp if intro_backdrop != null else 0.0
	var flash: bool = intro.screen_root.get_node_or_null("WarpFlash") != null
	await get_tree().create_timer(2.0).timeout
	var width: float = intro.get_viewport().get_visible_rect().size.x
	var arrived: bool = ship != null and is_instance_valid(ship) and ship.position.x >= width * 0.25 and ship.drift.x > 0.0
	check("S8.12", "intro: a Nave 47 sai do salto (estrelas em riscos e clarão), trava e segue devagar",
		appeared and warp_peak > 0.1 and flash and arrived and intro_backdrop.warp < 0.05,
		"warp %.2f, x %.0f / %.0f" % [warp_peak, ship.position.x if ship != null and is_instance_valid(ship) else -1.0, width])
	Engine.time_scale = 1.0
	intro.request_skip()
	await frames(10)

	var passed := results.filter(func(r): return r).size()
	print("RESULTADO S8: %d / %d PASS" % [passed, results.size()])
	get_tree().quit()
