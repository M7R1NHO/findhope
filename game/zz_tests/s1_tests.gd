extends Node
# Etapa 1: bug do [E] no tutorial, SKIP CUTSCENE e títulos das salas.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
var results: Array = []
var SM

func check(id: String, desc: String, cond: bool, info: String = "") -> void:
	results.append(cond)
	print(("PASS " if cond else "FAIL ") + id + " " + desc + ("  [" + info + "]" if info != "" else ""))

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func find_intro(node: Node) -> Node:
	for child in node.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("intro_sequence.gd"):
			return child
	return null

func labels_named(node: Node, names: Array, out: Array) -> void:
	if node is Label and names.has(String(node.name)):
		out.append(node.get_path())
	for child in node.get_children():
		labels_named(child, names, out)

func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)
	await SM.start_new_run()
	get_tree().change_scene_to_file(MAIN)
	await frames(3)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	var main := get_tree().current_scene
	var intro: Node = null
	for i in 60:
		intro = find_intro(main)
		if intro != null: break
		await frames(1)
	check("S1.0", "nova partida abre a cutscene inicial", intro != null)
	if intro == null:
		finish()
		return

	# --- SKIP CUTSCENE ---
	await get_tree().create_timer(2.5).timeout
	var button: Button = intro.get_node_or_null("SkipCutsceneButton")
	check("S1.1", "o botão SKIP CUTSCENE está visível durante a cutscene", button != null and button.is_visible_in_tree() and button.text.contains("SKIP CUTSCENE"))
	var started := Time.get_ticks_msec()
	button.pressed.emit()
	button.pressed.emit()
	while not is_instance_valid(intro.tutorial_player) and Time.get_ticks_msec() - started < 8000:
		await frames(1)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	check("S1.2", "ao carregar, salta logo para o tutorial de movimento (em vez de ~45 s)",
		is_instance_valid(intro.tutorial_player) and took < 3.0, "%.2f s" % took)
	await frames(2)
	check("S1.3", "o tutorial começa como depois da cutscene completa (título, texto, jogador bloqueado)",
		is_instance_valid(intro.title_label) and intro.title_label.text == "RECUPERAÇÃO DE CONSCIÊNCIA"
		and intro.dialogue_label.text.contains("WASD") and intro.player.tutorial_locked == true,
		"%s" % (intro.title_label.text if is_instance_valid(intro.title_label) else "?"))
	check("S1.4", "depois do salto, o botão desaparece e as esperas voltam ao normal (clicar duas vezes não salta o tutorial)",
		intro.get_node_or_null("SkipCutsceneButton") == null and intro.skip_requested == false)
	check("S1.5", "o bloqueio de save da cutscene continua ativo depois do salto (até ao fim da intro)", SM.manual_save_blocks.has("cutscene"))

	# --- Bug do [E] ---
	key(KEY_D, true)
	await get_tree().create_timer(0.3).timeout
	key(KEY_D, false)
	for i in 30:
		if intro.dialogue_label.text.contains("painel"): break
		await frames(1)
	# leva o quadrado para junto do painel sem carregar em teclas de movimento
	intro.tutorial_player_position = intro.tutorial_panel_position + Vector2(-60, 0)
	for i in 30:
		if intro.tutorial_interaction_enabled: break
		await frames(1)
	check("S1.6", "parado junto do painel, o tutorial pede o E", intro.tutorial_interaction_enabled)
	intro.tutorial_player_position = intro.tutorial_panel_position + Vector2(-250, 0)
	key(KEY_E, true)
	await frames(5)
	key(KEY_E, false)
	check("S1.7", "longe do painel, o E não ativa nada", not intro.tutorial_panel_activated)
	intro.tutorial_player_position = intro.tutorial_panel_position + Vector2(-60, 0)
	await frames(2)
	key(KEY_E, true)
	await frames(5)
	key(KEY_E, false)
	check("S1.8", "parado junto do painel (sem WASD), o E ativa o painel", intro.tutorial_panel_activated)

	# --- Títulos das salas ---
	var found := []
	labels_named(main, ["RoomName", "RoomLabel"], found)
	check("S1.9", "nenhum título de sala no chão (RoomName / RoomLabel)", found.is_empty(), str(found))
	var tracker: Node = main.get_facility_room_tracker() if main.has_method("get_facility_room_tracker") else null
	check("S1.10", "o rastreio de salas usado pelo Atlas continua a ter os nomes", tracker != null and tracker.rooms.size() >= 10, str(tracker.rooms.size() if tracker else -1))
	finish()

func finish() -> void:
	var passed := results.count(true)
	print("RESULTADO S1: ", passed, " / ", results.size(), " PASS")
	get_tree().quit(0 if passed == results.size() else 1)
