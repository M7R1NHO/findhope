extends Node
# Etapa 6: Nave 47 a voar na intro, novo menu principal e moldura comum dos
# minijogos.
# Precisa do backend de teste: GROQ_API_KEY=dummy python -m zz_phase3.fake_server
const MAIN := "res://scenes/main.tscn"
const MENU := "res://scenes/main_menu.tscn"
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

func open(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await frames(3)
	while scene() == null or not scene().is_node_ready():
		await get_tree().process_frame
	await frames(5)

func find_intro(node: Node) -> Node:
	for child in node.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("intro_sequence.gd"):
			return child
	return null

func find_by_class(node: Node, type_name: String, out: Array) -> void:
	if node.is_class(type_name):
		out.append(node)
	for child in node.get_children():
		find_by_class(child, type_name, out)

func _ready() -> void:
	SM = get_node("/root/SaveManager")
	await frames(3)

	# --- Intro: a Nave 47 a voar ---
	await SM.start_new_run()
	await open(MAIN)
	var intro: Node = null
	for i in 60:
		intro = find_intro(scene())
		if intro != null: break
		await frames(1)
	Engine.time_scale = 4.0
	var appeared: bool = await wait_until(func(): return intro.screen_root != null and intro.screen_root.get_node_or_null("FlyingShip") != null, 40.0)
	var ship: Node2D = intro.screen_root.get_node_or_null("FlyingShip") if appeared else null
	var line: String = intro.dialogue_label.text if is_instance_valid(intro.dialogue_label) else ""
	check("S6.1", "intro: a Nave 47 entra quando a frase da missão começa", ship != null and ship.style == "nave47_voo" and ship.interference == 0.0, line)
	var x0: float = ship.position.x if ship != null else 0.0
	await get_tree().create_timer(1.0).timeout
	check("S6.2", "intro: a nave atravessa o ecrã da esquerda para a direita", ship != null and ship.position.x > x0 + 30.0, "%.0f -> %.0f" % [x0, ship.position.x if ship != null else 0.0])
	var ship_ref: WeakRef = weakref(ship)
	var shaking: bool = await wait_until(func(): return ship_ref.get_ref() != null and ship_ref.get_ref().interference >= 1.0, 40.0)
	check("S6.3", "intro: na última frase (interferência) os motores falham", shaking and intro.dialogue_label.text.begins_with("M"), intro.dialogue_label.text)
	var gone: bool = await wait_until(func(): return ship_ref.get_ref() == null, 30.0)
	check("S6.4", "intro: a nave sai com o resto da primeira cena", gone)
	Engine.time_scale = 1.0
	intro.request_skip()
	await wait_until(func(): return is_instance_valid(intro.tutorial_player), 10.0)
	await frames(5)

	# --- Menu principal ---
	await open(MENU)
	var menu: Control = scene()
	var backdrop: Control = menu.find_child("MenuBackdrop", true, false)
	var menu_ship: Node2D = menu.find_child("MenuShip", true, false)
	check("S6.5", "menu: fundo com estrelas e a Nave 47 a voar, sem apanhar o rato",
		backdrop != null and menu_ship != null and menu_ship.style == "nave47_voo" and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# O estado com mais botões (DIÁRIOS): 8 botões têm de caber no ecrã.
	if menu.find_child("DIÁRIOS", true, false) == null:
		menu.create_menu_button("DIÁRIOS", func(): pass)
	await frames(5)
	var buttons: Array = []
	find_by_class(menu, "Button", buttons)
	var view := menu.get_viewport_rect()
	var outside := buttons.filter(func(b): return not view.encloses(b.get_global_rect()))
	var column_height: float = menu.root_container.get_parent().size.y
	check("S6.6", "menu: com 8 botões, a caixa cabe num ecrã de 720 px de altura", buttons.size() >= 8 and outside.is_empty() and column_height <= 700.0,
		"%d botões, %d fora, caixa com %.0f px" % [buttons.size(), outside.size(), column_height])
	var ship_rect := Rect2(menu_ship.global_position - menu_ship.size / 2.0, menu_ship.size)
	var frame: Control = menu.root_container.get_parent()
	check("S6.7", "menu: os botões estão numa caixa e a nave não fica por cima deles",
		frame is PanelContainer and not frame.get_global_rect().intersects(ship_rect), str(frame.get_global_rect()) + " " + str(ship_rect))
	var first: Button = buttons[0]
	check("S6.8", "menu: os botões continuam a receber cliques", first.mouse_filter == Control.MOUSE_FILTER_STOP and not first.disabled or first.text == "CONTINUAR JOGO")

	# --- Minijogos: moldura comum ---
	await SM.start_new_run()
	for k in ["intro_completed", "surface_recovery_complete", "protocol_door_opened", "facility_security_unlocked", "hide_initial_complete"]:
		SM.set_run_value("story", k, true)
	await open(MAIN)
	await frames(15)
	var hack: Node = scene().get_node("HackManager")
	hack.create_base_ui()
	await frames(3)
	var backdrop_art: Control = hack.overlay.get_node_or_null("HackFrame_backdrop")
	var panel_art: Control = hack.main_panel.get_node_or_null("HackFrame_panel")
	check("S6.9", "minijogos: fundo com linhas de varrimento e moldura de terminal no painel",
		backdrop_art != null and panel_art != null and hack.main_panel.has_theme_stylebox_override("panel"))
	check("S6.10", "minijogos: a moldura fica por trás do conteúdo e não apanha o rato",
		panel_art.get_index() < hack.content.get_parent().get_index() and panel_art.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop_art.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	hack.destroy_ui()

	var passed := results.filter(func(r): return r).size()
	print("RESULTADO S6: %d / %d PASS" % [passed, results.size()])
	get_tree().quit()
