extends Node
# Etapa 4: condutas, criatura no mundo (surgir, procurar, aproximar, recuar)
# e caixas nos esconderijos.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
var results: Array = []
var SM
var main: Node
var aem: Node
var player: CharacterBody2D

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

func creature_ok() -> bool:
	return aem.creature != null and is_instance_valid(aem.creature)

func reset_world() -> void:
	aem.destroy_creature()
	aem.destroy_encounter_ui()
	aem.destroy_hide_ui()
	aem.encounter_active = false
	aem.hide_event_active = false
	aem.room_failure_mode = false
	player.set_tutorial_locked(false)
	get_tree().paused = false
	await frames(3)

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
	await frames(15)
	main = get_tree().current_scene
	aem = main.get_node("UndergroundRoot/AlienEncounterManager")
	player = main.get_node("Player")
	var layout: Node2D = main.get_node("UndergroundRoot/GeneratedLayout")
	var decor: Node = main.get_node("RoomDecor")

	# --- Condutas ---
	var triggers := aem.get_children().filter(func(c): return String(c.name).begins_with("EncounterTrigger_"))
	check("S4.1", "uma conduta em cada sala (%d) e em cada corredor com gatilho (%d)" % [layout.rooms.size(), triggers.size()],
		aem.room_vents.size() == layout.rooms.size() and aem.corridor_vents.size() == triggers.size() and triggers.size() > 0,
		"salas=%d corredores=%d" % [aem.room_vents.size(), aem.corridor_vents.size()])
	var vent_node: Node = decor.vents[0]["node"] if decor.vents.size() > 0 else null
	check("S4.2", "a conduta usa a imagem vazia dos teus sprites", vent_node != null and vent_node.get_node_or_null("VentSprite") != null)
	var bad := []
	for room_id in aem.room_vents:
		var v: Vector2 = aem.room_vents[room_id]
		for spot in aem.room_safe_spots.get(room_id, []):
			if spot.global_position.distance_to(v) < aem.hide_spot_radius + 40.0: bad.append(room_id)
	check("S4.3", "nenhuma conduta de sala fica em cima de um esconderijo", bad.is_empty(), str(bad))
	var room_skips: Array = decor.skipped.filter(func(x): return x["room"] != "Surface")
	check("S4.4", "a decoração das salas não perdeu objetos por causa das condutas", room_skips.is_empty(),
		"saltados=%s trocados por condutas=%s" % [str(room_skips), str(decor.replaced_by_vents)])

	# --- Caixas dos esconderijos ---
	var room_id: String = "Storage"
	var spot: Area2D = aem.room_safe_spots[room_id][0]
	var cover: Node2D = spot.get_node_or_null("Cover")
	player.global_position = spot.global_position + Vector2(0, 250)
	await frames(3)
	var z_out: int = cover.z_index
	player.global_position = spot.global_position
	await frames(3)
	check("S4.5", "cada esconderijo tem caixas; tapam quem está lá dentro e ficam por trás de quem passa",
		cover != null and cover.get_child_count() == 2 and cover.z_index > 9 and z_out < 8, "fora z=%d dentro z=%d" % [z_out, cover.z_index])

	# --- Corredor ---
	var corridor_id: String = aem.corridor_vents.keys()[0]
	var trigger: Area2D = aem.get_node("EncounterTrigger_" + corridor_id)
	player.global_position = trigger.global_position
	await frames(2)
	aem.start_corridor_encounter(corridor_id, trigger)
	await frames(2)
	check("S4.6", "corredor: a criatura sai da conduta do corredor antes da escolha (jogo ainda não pausado, Player parado)",
		creature_ok() and String(aem.creature.body.animation) == "emerge" and aem.creature.global_position.distance_to(aem.corridor_vents[corridor_id]) < 1.0
		and not get_tree().paused and player.tutorial_locked and aem.encounter_layer == null)
	var searched := await wait_until(func(): return creature_ok() and aem.creature.state == aem.creature.State.SEARCH, 2.5)
	check("S4.7", "corredor: depois procura", searched)
	var approached := await wait_until(func(): return creature_ok() and aem.creature.state == aem.creature.State.APPROACH, 3.0)
	check("S4.8", "corredor: depois vem até ao Player", approached)
	var chosen := await wait_until(func(): return aem.encounter_layer != null, 6.0)
	check("S4.9", "corredor: ao chegar, aparece RUN/FIGHT, o jogo pausa e a criatura sai do mundo",
		chosen and get_tree().paused and not creature_ok() and not player.tutorial_locked)
	await reset_world()

	# --- Esconderijo numa sala: sucesso ---
	aem.current_room_id = room_id
	player.global_position = layout.to_global(layout.rooms[room_id]["position"])
	await frames(2)
	aem.start_hide_event()
	await frames(2)
	check("S4.10", "esconderijo: a criatura sai da conduta da sala", creature_ok() and aem.creature.global_position.distance_to(aem.room_vents[room_id]) < 1.0)
	await get_tree().create_timer(2.0).timeout
	var near_spot := false
	var min_d := INF
	for i in 60:
		for s in aem.room_safe_spots[room_id]:
			min_d = minf(min_d, aem.creature.global_position.distance_to(s.global_position))
		await frames(2)
	near_spot = min_d < aem.hide_spot_radius + 30.0
	check("S4.11", "esconderijo: a criatura procura pela sala sem entrar nos esconderijos", creature_ok() and aem.creature.state == aem.creature.State.SEARCH and not near_spot, "%.0f px" % min_d)
	var leaving: Node2D = aem.creature
	aem.complete_hide_event()
	var went := await wait_until(func(): return not is_instance_valid(leaving), 7.0)
	check("S4.12", "esconderijo com sucesso: a criatura volta à conduta, desce e desaparece", went and not aem.encounter_active)
	await reset_world()

	# --- Esconderijo numa sala: falha ---
	aem.start_hide_event()
	await get_tree().create_timer(1.0).timeout
	aem.fail_hide_event("teste")
	await frames(2)
	check("S4.13", "esconderijo falhado: a criatura vem até ao Player antes da escolha",
		creature_ok() and aem.creature.state in [aem.creature.State.APPROACH, aem.creature.State.ATTACK] and not get_tree().paused and aem.encounter_layer == null)
	var fail_ui := await wait_until(func(): return aem.encounter_layer != null, 6.0)
	check("S4.14", "esconderijo falhado: depois aparece a escolha (A CRIATURA ENCONTROU VOCÊ)", fail_ui and get_tree().paused and aem.room_failure_mode)
	await reset_world()

	# --- HIDEINICIAL ---
	aem.create_hide_initial_creature_visual()
	await frames(2)
	var first: Node2D = aem.hide_initial_creature_visual
	check("S4.15", "esconderijo inicial: sai da conduta da Sala Técnica", first != null and first.global_position.distance_to(aem.get_room_vent("TechnicalRoom")) < 1.0)
	aem.hide_initial_active = true
	aem.complete_hide_initial("teste")
	var first_gone := await wait_until(func(): return not is_instance_valid(first), 8.0)
	check("S4.16", "esconderijo inicial concluído: a criatura volta para a conduta (já não desaparece de repente)", first_gone)
	await reset_world()

	# --- Game Over do RUN ---
	aem.run_closing_active = true
	aem.run_timeout()
	await frames(3)
	check("S4.17", "fim do tempo do RUN: a criatura aparece e vem até ao Player antes do Game Over", creature_ok() and not get_tree().paused)
	var over := await wait_until(func(): return get_tree().paused and not creature_ok(), 7.0)
	check("S4.18", "depois aparece o Game Over de sempre", over)

	var passed := results.count(true)
	print("RESULTADO S4: ", passed, " / ", results.size(), " PASS")
	get_tree().quit(0 if passed == results.size() else 1)
