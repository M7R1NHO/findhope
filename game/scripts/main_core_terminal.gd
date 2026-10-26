extends Area2D


var player_nearby: bool = false
var terminal_open: bool = false
var processing: bool = false

var core_unlocked: bool = false
var deep_access_discovered: bool = false

var main: Node = null
var underground_root: Node = null

var terminal_visual: Polygon2D = null
var interaction_label: Label = null

var terminal_layer: CanvasLayer = null
var status_label: Label = null
var data_label: Label = null
var action_button: Button = null
var password_input: LineEdit = null
var password_feedback: Label = null

const MainCoreClues := preload("res://scripts/main_core_clues.gd")
const UIStyle := preload("res://scripts/ui_style.gd")
const PASSWORD_WORDS: Array[String] = MainCoreClues.WORDS
const PASSWORD_SAVE_KEY := MainCoreClues.PASSWORD_KEY
const PASSWORD_SOLVED_KEY := MainCoreClues.SOLVED_KEY
const PHASE3_SPAWN_POSITION := Vector2(8540.0, -3803.0)
# Entrada na Phase 3: o Player e o Atlas aparecem na abertura esquerda da
# Ala de Comunicações e entram a andar enquanto o ecrã clareia.
const PHASE3_ENTRY_OFFSET := Vector2(-440.0, 0.0)
const PHASE3_ATLAS_ENTRY_OFFSET := Vector2(-478.0, -34.0)
const PHASE3_FADE_HOLD := 0.35
const PHASE3_FADE_TIME := 0.9
const PHASE3_WALK_TIMEOUT := 4.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene
	underground_root = get_parent()
	load_or_create_password()

	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	monitoring = true
	monitorable = true

	create_collision()
	create_world_visual()
	create_interaction_label()

	# Depois de carregar um save, o Núcleo já resolvido continua resolvido.
	if is_password_solved():
		core_unlocked = true
		deep_access_discovered = true
		if terminal_visual != null:
			terminal_visual.color = Color(0.15, 0.62, 0.52, 1.0)
		if interaction_label != null:
			interaction_label.text = "[E] REABRIR NÚCLEO"

	body_entered.connect(
		on_body_entered
	)

	body_exited.connect(
		on_body_exited
	)

	print("")
	print("======================================")
	print("MAIN CORE TERMINAL READY")
	print("======================================")


func _unhandled_input(event):
	if terminal_open:
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

	open_terminal()


func create_collision():
	var collision = CollisionShape2D.new()

	var shape = RectangleShape2D.new()

	shape.size = Vector2(
		250,
		190
	)

	collision.shape = shape

	add_child(
		collision
	)


func create_world_visual():
	terminal_visual = Polygon2D.new()

	terminal_visual.name = "MainCoreVisual"

	terminal_visual.polygon = PackedVector2Array([
		Vector2(-110, -65),
		Vector2(110, -65),
		Vector2(110, 65),
		Vector2(-110, 65)
	])

	terminal_visual.color = Color(
		0.18,
		0.12,
		0.24,
		1.0
	)

	terminal_visual.z_index = 5

	add_child(
		terminal_visual
	)


	var title = Label.new()

	title.text = "NÚCLEO PRINCIPAL"

	title.position = Vector2(
		-145,
		-22
	)

	title.size = Vector2(
		290,
		45
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		16
	)

	title.z_index = 7

	add_child(
		title
	)


func create_interaction_label():
	interaction_label = Label.new()

	interaction_label.name = "InteractionLabel"

	interaction_label.text = (
		"[E] ACESSAR NÚCLEO"
	)

	interaction_label.position = Vector2(
		-190,
		-120
	)

	interaction_label.size = Vector2(
		380,
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


func open_terminal():
	if terminal_open:
		return

	terminal_open = true

	get_tree().paused = true

	create_terminal_ui()
	update_terminal_content()


func close_terminal():
	if processing:
		return

	terminal_open = false

	destroy_terminal_ui()

	get_tree().paused = false


func create_terminal_ui():
	destroy_terminal_ui()

	terminal_layer = CanvasLayer.new()

	terminal_layer.name = "MainCoreTerminalUI"
	terminal_layer.layer = 730

	terminal_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		terminal_layer
	)


	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.008,
		0.008,
		0.015,
		0.97
	)

	terminal_layer.add_child(
		background
	)
	UIStyle.apply(background)


	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(
		center
	)


	var container = VBoxContainer.new()

	container.custom_minimum_size = Vector2(
		780,
		0
	)

	container.add_theme_constant_override(
		"separation",
		12
	)

	center.add_child(
		container
	)
	UIStyle.frame(container)


	var title = Label.new()

	title.text = (
		"NÚCLEO PRINCIPAL // CONTROLO CENTRAL"
	)

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		26
	)

	UIStyle.title(title)
	container.add_child(
		title
	)


	var separator = HSeparator.new()

	container.add_child(
		separator
	)


	status_label = Label.new()

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	status_label.add_theme_font_size_override(
		"font_size",
		19
	)

	container.add_child(
		status_label
	)


	data_label = Label.new()

	data_label.custom_minimum_size = Vector2(
		720,
		200
	)

	data_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	data_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	data_label.add_theme_font_size_override(
		"font_size",
		17
	)

	container.add_child(
		data_label
	)

	password_input = LineEdit.new()
	password_input.name = "PasswordInput"
	password_input.placeholder_text = "Introduz a palavra-passe..."
	password_input.custom_minimum_size = Vector2(0, 48)
	password_input.max_length = 40
	password_input.add_theme_font_size_override("font_size", 19)
	password_input.process_mode = Node.PROCESS_MODE_ALWAYS
	password_input.text_submitted.connect(_on_password_submitted)
	container.add_child(password_input)

	password_feedback = Label.new()
	password_feedback.name = "PasswordFeedback"
	password_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	password_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	password_feedback.add_theme_font_size_override("font_size", 16)
	container.add_child(password_feedback)


	action_button = Button.new()

	action_button.custom_minimum_size = Vector2(
		0,
		52
	)

	action_button.add_theme_font_size_override(
		"font_size",
		18
	)

	action_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	action_button.pressed.connect(
		on_action_pressed
	)

	container.add_child(
		action_button
	)


	var close_button = Button.new()

	close_button.text = "FECHAR"

	close_button.custom_minimum_size = Vector2(
		0,
		46
	)

	close_button.add_theme_font_size_override(
		"font_size",
		17
	)

	close_button.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	close_button.pressed.connect(
		close_terminal
	)

	container.add_child(
		close_button
	)


func update_terminal_content():
	if status_label == null or data_label == null or action_button == null:
		return

	if is_password_solved():
		status_label.text = "PALAVRA-PASSE ACEITE"
		data_label.text = "Autenticação concluída. O acesso profundo foi autorizado."
		action_button.text = "AVANÇAR PARA A ÁREA SEGUINTE"
		action_button.visible = true
		action_button.disabled = false
		if password_input != null:
			password_input.visible = false
		if password_feedback != null:
			password_feedback.text = ""
		return

	status_label.text = "AUTENTICAÇÃO SEMÂNTICA // NÚCLEO PRINCIPAL"
	data_label.text = (
		"Introduz a palavra que liga as três pistas. "
		+ "É uma de dez palavras possíveis.\n\n"
		+ "PISTAS RECUPERADAS (" + str(MainCoreClues.count_found()) + "/3):\n\n"
		+ MainCoreClues.describe_found_clues()
	)
	action_button.text = "VALIDAR PALAVRA-PASSE"
	action_button.visible = true
	action_button.disabled = false
	if password_input != null:
		password_input.visible = true
		password_input.editable = true
	if password_feedback != null:
		password_feedback.text = ""


func on_action_pressed():
	if processing:
		return
	if is_password_solved():
		teleport_to_phase3()
	else:
		validate_password()


func validate_password():
	if password_input == null:
		return
	var submitted := normalize_password(password_input.text)
	if submitted.is_empty():
		show_password_feedback("Introduz uma palavra-passe.")
		return
	if submitted != normalize_password(get_selected_password()):
		show_password_feedback("Palavra-passe incorreta. Reinterpreta as três pistas e tenta novamente.")
		password_input.select_all()
		password_input.grab_focus()
		return

	processing = true
	action_button.disabled = true
	password_input.editable = false
	status_label.text = "PALAVRA-PASSE ACEITE"
	show_password_feedback("Autenticação concluída. Acesso autorizado.")
	await get_tree().create_timer(1.0, true).timeout

	core_unlocked = true
	deep_access_discovered = true
	processing = false
	save_password_solved()
	if underground_root != null:
		underground_root.set_meta("main_core_unlocked", true)
		underground_root.set_meta("phase3_unlocked", true)
	if terminal_visual != null:
		terminal_visual.color = Color(0.15, 0.62, 0.52, 1.0)
	if interaction_label != null:
		interaction_label.text = "[E] REABRIR NÚCLEO"
	register_discovery()
	teleport_to_phase3()


func show_password_feedback(message: String) -> void:
	if password_feedback != null:
		password_feedback.text = message


func normalize_password(value: String) -> String:
	var result := value.strip_edges().to_upper()
	for pair in [["Á", "A"], ["À", "A"], ["Â", "A"], ["Ã", "A"], ["É", "E"], ["Ê", "E"], ["Í", "I"], ["Ó", "O"], ["Ô", "O"], ["Õ", "O"], ["Ú", "U"], ["Ç", "C"]]:
		result = result.replace(pair[0], pair[1])
	return result.replace(" ", "")


func load_or_create_password() -> void:
	MainCoreClues.ensure_password_word()


func get_selected_password() -> String:
	return MainCoreClues.get_password_word()


func is_password_solved() -> bool:
	var manager := get_node_or_null("/root/SaveManager")
	if manager != null and manager.has_method("get_run_value"):
		if bool(manager.get_run_value("world", PASSWORD_SOLVED_KEY, false)):
			return true
	return underground_root != null and bool(underground_root.get_meta(PASSWORD_SOLVED_KEY, false))


func save_password_solved() -> void:
	var manager := get_node_or_null("/root/SaveManager")
	if manager != null and manager.has_method("set_run_value"):
		manager.set_run_value("world", PASSWORD_SOLVED_KEY, true)
	if underground_root != null:
		underground_root.set_meta(PASSWORD_SOLVED_KEY, true)


func _on_password_submitted(_value: String) -> void:
	validate_password()


func teleport_to_phase3() -> void:
	if not is_password_solved():
		push_warning("MainCore: teletransporte bloqueado; palavra-passe não validada.")
		return
	var player_node: Node = null
	if main != null:
		player_node = main.get_node_or_null("Player")
	if player_node == null:
		push_error("MainCore: não foi possível encontrar Main/Player.")
		show_password_feedback("Palavra-passe aceite, mas o jogador não foi encontrado.")
		return

	# Durante a entrada animada o Player fica protegido: um HIDE que já
	# estivesse a decorrer na sala do MainCore acaba sem ataque, e nada novo
	# começa até ao fim da caminhada (play_phase3_entry).
	set_phase3_entry_protection(true)

	var entry_position := PHASE3_SPAWN_POSITION + PHASE3_ENTRY_OFFSET
	player_node.global_position = entry_position
	if player_node is CharacterBody2D:
		player_node.set_movement_bounds(
			9000.0,
			12500.0,
			-4500.0,
			-2000.0
		)
		player_node.velocity = Vector2.ZERO

	player_node.global_position = entry_position

	if main != null:
		var atlas_node := main.get_node_or_null("Atlas")
		if atlas_node is Node2D:
			atlas_node.global_position = PHASE3_SPAWN_POSITION + PHASE3_ATLAS_ENTRY_OFFSET
		if atlas_node is CharacterBody2D:
			atlas_node.velocity = Vector2.ZERO
	if underground_root != null:
		underground_root.set_meta("main_core_unlocked", true)
		underground_root.set_meta("phase3_unlocked", true)

	terminal_open = false
	destroy_terminal_ui()
	get_tree().paused = false
	print("MAIN CORE PASSWORD: ACCEPTED")
	print("PHASE 3 TELEPORT: ", PHASE3_SPAWN_POSITION)

	# Autosave à entrada da área seguinte: um Game Over ali já não
	# devolve o jogador ao subterrâneo.
	if not bool(SaveManager.get_run_value("story", "phase3_entered", false)):
		SaveManager.set_run_value("story", "phase3_entered", true)
		SaveManager.autosave_when_safe("phase3_entered")

	play_phase3_entry(player_node)


# O ecrã começa preto e clareia enquanto o Player entra a andar até ao
# centro da sala; o Atlas segue-o como sempre. Não bloqueia o save: é curta
# e o Player já está na Phase 3.
func play_phase3_entry(player_node: Node) -> void:
	var fade := CanvasLayer.new()
	fade.name = "Phase3EntryFade"
	fade.layer = 1100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.add_child(black)
	get_tree().current_scene.add_child(fade)

	if player_node.has_method("start_scripted_move_to"):
		player_node.start_scripted_move_to(PHASE3_SPAWN_POSITION)

	await get_tree().create_timer(PHASE3_FADE_HOLD, false).timeout
	var tween := fade.create_tween()
	tween.tween_property(black, "color:a", 0.0, PHASE3_FADE_TIME)
	await tween.finished
	fade.queue_free()

	var waited := PHASE3_FADE_HOLD + PHASE3_FADE_TIME
	while is_instance_valid(player_node) and player_node.get("scripted_move_active") and waited < PHASE3_WALK_TIMEOUT:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if is_instance_valid(player_node) and player_node.has_method("stop_scripted_move_to"):
		player_node.stop_scripted_move_to()
	set_phase3_entry_protection(false)


func set_phase3_entry_protection(active: bool) -> void:
	var encounters: Node = null
	if underground_root != null:
		encounters = underground_root.get_node_or_null("AlienEncounterManager")
	if encounters != null and encounters.has_method("set_player_protected"):
		encounters.set_player_protected("phase3_entry", active)


func register_discovery():
	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Autorização aceite. "
			+ "Existe um acesso abaixo desta instalação. "
			+ "A estrutura além dele não corresponde "
			+ "completamente ao restante complexo. "
			+ "Não consigo determinar a sua origem daqui."
		)


	send_gameplay_context()


	print("")
	print("======================================")
	print("MAIN CORE UNLOCKED")
	print("PASSWORD: ", get_selected_password())
	print("DEEP ACCESS: DISCOVERED")
	print("PHASE 3: UNLOCKED")
	print("======================================")


func send_gameplay_context():
	if main == null:
		return

	if not main.has_method(
		"send_gameplay_context_event"
	):
		return

	main.send_gameplay_context_event(
		"main_core_deep_access_discovered",
		"deep_access_discovered",
		"Atlas e o jogador juntaram as pistas do Laboratório, "
		+ "dos Arquivos e do Santuário e descobriram a palavra-passe "
		+ "do Núcleo Principal, que foi aceite pelo sistema. "
		+ "O Núcleo revelou a existência de uma rota restrita "
		+ "que conduz para uma estrutura abaixo da instalação. "
		+ "Essa estrutura não corresponde completamente "
		+ "aos padrões arquitetónicos observados no complexo. "
		+ "A origem e função dessa estrutura permanecem desconhecidas. "
		+ "Atlas não deve afirmar ainda que sabe o que existe lá.",
		true
	)



func destroy_terminal_ui():
	if (
		terminal_layer != null
		and is_instance_valid(
			terminal_layer
		)
	):
		terminal_layer.queue_free()

	terminal_layer = null

	status_label = null
	data_label = null
	action_button = null
	password_input = null
	password_feedback = null


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


func is_core_unlocked() -> bool:
	return core_unlocked


func is_phase3_unlocked() -> bool:
	return core_unlocked
