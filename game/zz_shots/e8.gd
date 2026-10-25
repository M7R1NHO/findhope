extends Node
func frames(n):
	for i in n: await get_tree().process_frame
func shot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/" + name + ".png")
func find_intro(node):
	for child in node.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("intro_sequence.gd"):
			return child
	return null
func _ready():
	await frames(3)
	var SM = get_node("/root/SaveManager")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(5)
	await get_tree().create_timer(1.5).timeout
	await shot("e8_menu")
	await SM.start_new_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(5)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	var intro = null
	while intro == null:
		intro = find_intro(get_tree().current_scene)
		await frames(1)
	await get_tree().create_timer(3.5).timeout
	await shot("e8_intro_titulo")
	while intro.screen_root == null or intro.screen_root.get_node_or_null("FlyingShip") == null:
		await frames(1)
	await get_tree().create_timer(0.3).timeout
	await shot("e8_intro_salto")
	await get_tree().create_timer(0.5).timeout
	await shot("e8_intro_travar")
	await get_tree().create_timer(3.0).timeout
	await shot("e8_intro_nave")
	intro.request_skip()
	while not is_instance_valid(intro.tutorial_player): await frames(1)
	await frames(10)
	await SM.start_new_run()
	for k in ["intro_completed", "surface_recovery_complete", "protocol_door_opened", "facility_security_unlocked", "hide_initial_complete"]:
		SM.set_run_value("story", k, true)
	for id in ["controls", "encounter", "run", "hide", "hack", "fight"]:
		SM.set_run_value("custom", "tutorial_" + id, true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(5)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	await frames(30)
	var main = get_tree().current_scene
	var aem = main.get_node("UndergroundRoot/AlienEncounterManager")
	var player = main.get_node("Player")
	var atlas = main.get_node("Atlas")
	var shots_done := 0
	for cid in aem.corridor_vents.keys():
		if shots_done >= 2: break
		var v: Vector2 = aem.corridor_vents[cid]
		player.global_position = v + Vector2(60, 70)
		atlas.global_position = v + Vector2(-90, 70)
		await frames(15)
		await shot("e8_conduta_corredor_%d" % shots_done)
		shots_done += 1
	var room = "Storage"
	var rv: Vector2 = aem.room_vents[room]
	player.global_position = rv + Vector2(0, 110)
	atlas.global_position = rv + Vector2(-120, 110)
	await frames(15)
	await shot("e8_conduta_sala")
	get_tree().quit()
