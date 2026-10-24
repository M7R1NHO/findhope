extends Node
# Etapa 2: FIGHT 3.0 (sem cartas; a criatura persegue o Player; o Atlas
# aponta com o rato e dispara com E; 2 s de recarga; 10 golpes e recua).
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
var results: Array = []
var SM
var won_count := 0
var destroyed_count := 0

func check(id: String, desc: String, cond: bool, info: String = "") -> void:
	results.append(cond)
	print(("PASS " if cond else "FAIL ") + id + " " + desc + ("  [" + info + "]" if info != "" else ""))

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func key(code: Key, echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.echo = echo
	Input.parse_input_event(ev)
	await frames(1)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)

func find_by_script(node: Node, suffix: String) -> Node:
	if node.get_script() != null and node.get_script().resource_path.ends_with(suffix):
		return node
	for child in node.get_children():
		var found := find_by_script(child, suffix)
		if found != null: return found
	return null

func count_buttons(node: Node) -> int:
	var n := 1 if node is Button else 0
	for child in node.get_children():
		n += count_buttons(child)
	return n

# Põe a criatura parada a 200 px à direita do Atlas, ao alcance.
func line_up(fm: Node) -> void:
	fm.atlas_position = Vector2(200, 210)
	fm.player_position = Vector2(60, 60)
	fm.creature_position = Vector2(400, 210)
	fm.creature_stun = 5.0
	fm.update_actor_visuals()
	fm.update_creature_visual(Vector2.ZERO)

func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)
	await SM.start_new_run()
	for k in ["intro_completed", "surface_recovery_complete", "protocol_door_opened", "facility_security_unlocked", "hide_initial_complete"]:
		SM.set_run_value("story", k, true)
	for id in ["controls", "encounter", "run", "hide", "hack"]:
		SM.set_run_value("custom", "tutorial_" + id, true)
	get_tree().change_scene_to_file(MAIN)
	await frames(3)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	await frames(10)
	var main := get_tree().current_scene
	var fm: Node = main.get_node("FightManager")
	fm.fight_won.connect(func(_hp): won_count += 1)
	fm.atlas_destroyed.connect(func(): destroyed_count += 1)

	# --- Início ---
	fm.start_fight()
	await frames(3)
	var card_open: bool = fm.TutorialCard.is_open(get_tree())
	check("S2.1", "primeira luta abre o cartão FIGHT com o texto novo (fugir, apontar, E, 10 golpes)",
		card_open and get_tree().root.find_children("*", "", true, false).any(func(n): return n is Label and n.text.contains("dispositivo sónico")))
	for c in get_tree().get_nodes_in_group(fm.TutorialCard.GROUP): c.close()
	await frames(2)
	check("S2.2", "sem cartas de escolha: a luta começa logo em combate",
		count_buttons(fm.fight_layer) == 0 and fm.fight_phase == fm.FightPhase.COMBAT and get_tree().paused,
		"botões=%d" % count_buttons(fm.fight_layer))
	check("S2.3", "a criatura está na arena (sprite próprio) e começa longe do Player",
		fm.fight_layer.find_child("MonsterSprite", true, false) != null and fm.creature_position.distance_to(fm.player_position) > 250.0,
		"%.0f px" % fm.creature_position.distance_to(fm.player_position))
	var d0: float = fm.creature_position.distance_to(fm.player_position)
	# Espera pela aproximação (com folga para frames lentos), em vez de um tempo fixo.
	var chase_start := Time.get_ticks_msec()
	while fm.creature_position.distance_to(fm.player_position) >= d0 - 60.0 and Time.get_ticks_msec() - chase_start < 5000:
		await get_tree().process_frame
	var d1: float = fm.creature_position.distance_to(fm.player_position)
	check("S2.4", "a criatura persegue o Player (a distância diminui)", d1 < d0 - 60.0, "%.0f -> %.0f px" % [d0, d1])

	# --- Disparo ---
	fm.hit_invulnerability = 99.0
	fm.player_hit_cooldown = 99.0
	fm.atlas_hit_cooldown = 99.0
	fm.attack_timer = 999.0
	fm.clear_hazards()
	line_up(fm)
	fm.selected_actor = 1
	fm.update_actor_selection()
	var shots_before: int = fm.shots_fired
	await key(KEY_E)
	check("S2.5", "com o Player selecionado, o E não dispara", fm.shots_fired == shots_before and fm.sonic_hits == 0)
	await key(KEY_2)
	check("S2.6", "[2] seleciona o Atlas e mostra os controlos de mira", fm.selected_actor == 2 and fm.control_label.text.contains("rato"))
	var miss: bool = fm.fire_sonic(fm.atlas_position + Vector2(-200, 0))
	check("S2.7", "apontar para o lado contrário falha e gasta o disparo (recarga de 2 s)",
		not miss and fm.sonic_hits == 0 and is_equal_approx(fm.sonic_cooldown_left, 2.0))
	var during: bool = fm.fire_sonic(fm.creature_position)
	check("S2.8", "durante a recarga, apontar à criatura não conta", not during and fm.sonic_hits == 0)
	fm.sonic_cooldown_left = 0.0
	var before_pos: Vector2 = fm.creature_position
	var hit: bool = fm.fire_sonic(fm.creature_position + Vector2(0, 30))
	check("S2.9", "apontar à criatura acerta: 1 golpe, recua e fica atordoada",
		hit and fm.sonic_hits == 1 and fm.creature_position.x > before_pos.x + 50.0 and fm.creature_stun > 0.0)
	check("S2.10", "a interface mostra GOLPES 1 / 10 e a recarga", fm.hits_label.text == "GOLPES SÓNICOS: 1 / 10" and fm.cooldown_label.text.begins_with("RECARGA"),
		fm.hits_label.text + " | " + fm.cooldown_label.text)

	# --- Sem contagens a dobrar ---
	fm.sonic_cooldown_left = 0.0
	line_up(fm)
	var shots := int(fm.shots_fired)
	await key(KEY_E)
	await key(KEY_E)
	await key(KEY_E, true)
	check("S2.11", "E três vezes seguidas (uma em eco): só sai 1 disparo", fm.shots_fired == shots + 1, "disparos=%d" % (fm.shots_fired - shots))
	var hits_now := int(fm.sonic_hits)
	check("S2.12", "um disparo conta no máximo 1 golpe", hits_now <= 2, str(hits_now))

	# --- E não abre terminais durante a luta ---
	var terminal: Node = find_by_script(main, "laboratory_terminal.gd")
	terminal.player_nearby = true
	fm.sonic_cooldown_left = 0.0
	await key(KEY_E)
	check("S2.13", "durante a luta, o E não abre o terminal ao lado do jogador", terminal != null and not terminal.terminal_open)
	terminal.player_nearby = false

	# --- 10 golpes: recua e vitória ---
	var guard := 0
	while fm.sonic_hits < 10 and guard < 30:
		guard += 1
		fm.sonic_cooldown_left = 0.0
		line_up(fm)
		fm.fire_sonic(fm.creature_position)
	check("S2.14", "ao 10.º golpe a criatura recua (fase de retirada)", fm.sonic_hits == 10 and fm.fight_phase == fm.FightPhase.RETREAT)
	fm.sonic_cooldown_left = 0.0
	check("S2.15", "depois dos 10, mais disparos não contam", not fm.fire_sonic(fm.creature_position) and fm.sonic_hits == 10)
	var t0 := Time.get_ticks_msec()
	while fm.fight_active and Time.get_ticks_msec() - t0 < 5000:
		await frames(1)
	await get_tree().create_timer(1.2).timeout
	check("S2.16", "a criatura sai da arena e fight_won é emitido uma vez; o jogo despausa",
		won_count == 1 and not fm.fight_active and not get_tree().paused and fm.fight_layer == null,
		"won=%d paused=%s" % [won_count, str(get_tree().paused)])

	# --- Toque da criatura ---
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false
	fm.start_fight()
	await frames(3)
	fm.attack_timer = 999.0
	fm.hit_invulnerability = 0.45
	fm.player_hit_cooldown = 0.0
	fm.atlas_hit_cooldown = 0.0
	var hp0 := int(fm.atlas_hp)
	fm.atlas_position = Vector2(650, 380)
	fm.player_position = Vector2(300, 200)
	fm.creature_position = Vector2(320, 200)
	fm.creature_stun = 0.0
	await get_tree().create_timer(0.3).timeout
	check("S2.17", "a criatura apanha o Player: tira %d de VIDA uma vez e recua" % fm.contact_damage,
		hp0 - int(fm.atlas_hp) == fm.contact_damage and fm.creature_position.distance_to(fm.player_position) > 40.0,
		"%d -> %d" % [hp0, fm.atlas_hp])

	# --- Derrota ---
	fm.atlas_hp = 2
	fm.player_hit_cooldown = 0.0
	var creature_start: Vector2 = fm.creature_position
	fm.hit_actor("player")
	check("S2.18", "VIDA a 0: a luta acaba logo e a criatura avança para o Player", not fm.fight_active and fm.fight_phase == fm.FightPhase.ENDING)
	await get_tree().create_timer(0.5).timeout
	var mid_dist: float = (fm.creature_token.position + fm.CREATURE_SIZE / 2.0).distance_to(fm.player_position) if is_instance_valid(fm.creature_token) else -1.0
	await get_tree().create_timer(1.2).timeout
	check("S2.19", "depois da aproximação, aparece o ecrã de derrota e atlas_destroyed é emitido uma vez",
		destroyed_count == 1 and fm.defeat_layer != null and is_instance_valid(fm.defeat_layer) and mid_dist >= 0.0 and mid_dist < creature_start.distance_to(fm.player_position) + 1.0,
		"destroyed=%d dist_meio=%.0f" % [destroyed_count, mid_dist])

	var passed := results.count(true)
	print("RESULTADO S2: ", passed, " / ", results.size(), " PASS")
	get_tree().quit(0 if passed == results.size() else 1)
