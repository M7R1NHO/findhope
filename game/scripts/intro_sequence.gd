
extends CanvasLayer

const TYPE_SPEED := 0.035
const TEXT_PAUSE := 1.8
const PLAYER_SIZE := Vector2(28, 28)
const PANEL_SIZE := Vector2(48, 58)
const TUTORIAL_SPEED := 240.0
const INTERACTION_DISTANCE := 90.0
const MINIGAME_DURATION := 8.0
const STABILITY_DRAIN := 0.14
const STABILITY_RECOVERY := 0.012

var screen_root: Control
var background: ColorRect
var title_label: Label
var dialogue_label: Label
var subtitle_label: Label
var map_visual: IntroMapVisual

var player: CharacterBody2D
var player_has_moved := false

var tutorial_area: Panel
var tutorial_player: ColorRect
var tutorial_panel: ColorRect
var tutorial_panel_label: Label
var keyboard_visual: Control
var interaction_hint: Control

var tutorial_player_position := Vector2.ZERO
var tutorial_panel_position := Vector2.ZERO
var tutorial_interaction_enabled := false
var tutorial_panel_activated := false

var minigame_active := false
var stabilization := 0.75
var minigame_elapsed := 0.0

var stabilization_panel: Panel
var stabilization_bar: ProgressBar
var stabilization_status: Label
var stabilization_q_hint: Label
var minigame_overlay: ColorRect


func play() -> void:
	layer = 100

	player = get_parent().get_node_or_null("Player")

	if player != null and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(true)

	_create_screen()

	await get_tree().create_timer(1.0).timeout
	await _play_scene_one()
	await _play_scene_two()
	await _play_wake_up()
	await _play_movement_tutorial()
	await _play_panel_tutorial()

	if player != null and is_instance_valid(player):
		if player.has_method("clear_tutorial_interaction_target"):
			player.clear_tutorial_interaction_target()

		if player.has_method("set_tutorial_locked"):
			player.set_tutorial_locked(false)

	queue_free()


func _input(event: InputEvent) -> void:
	if not minigame_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			stabilization = minf(
				stabilization + STABILITY_RECOVERY,
				1.0
			)
			_update_stabilization_display()
			get_viewport().set_input_as_handled()


func _create_screen() -> void:
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)

	background = ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(background)


func _create_intro_labels() -> void:
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.75, 0.9, 1.0)
	)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(title_label)

	dialogue_label = Label.new()
	dialogue_label.anchor_left = 0.08
	dialogue_label.anchor_right = 0.92
	dialogue_label.anchor_top = 0.68
	dialogue_label.anchor_bottom = 0.9
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 23)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(dialogue_label)

	subtitle_label = Label.new()
	subtitle_label.anchor_left = 0.05
	subtitle_label.anchor_right = 0.95
	subtitle_label.anchor_top = 0.92
	subtitle_label.anchor_bottom = 0.99
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.5, 0.7, 0.85)
	)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(subtitle_label)


func _fade_screen_content(duration: float) -> void:
	var tween := create_tween()
	var has_content := false

	for child in screen_root.get_children():
		if child == background:
			continue

		tween.parallel().tween_property(
			child,
			"modulate:a",
			0.0,
			duration
		)
		has_content = true

	if has_content:
		await tween.finished


func _clear_screen_content() -> void:
	for child in screen_root.get_children():
		if child == background:
			continue

		child.queue_free()

	await get_tree().process_frame

	title_label = null
	dialogue_label = null
	subtitle_label = null
	map_visual = null
	tutorial_area = null
	tutorial_player = null
	tutorial_panel = null
	tutorial_panel_label = null
	keyboard_visual = null
	interaction_hint = null

	screen_root.modulate.a = 1.0
	background.color = Color.BLACK
	background.modulate.a = 1.0


func _play_scene_one() -> void:
	background.color = Color(0.005, 0.008, 0.025)

	_create_intro_labels()

	title_label.text = ""
	dialogue_label.text = ""
	subtitle_label.text = ""

	var stars := _create_stars()

	for star in stars:
		star.modulate.a = 0.0

	var background_tween := create_tween()
	background_tween.tween_property(
		background,
		"color",
		Color(0.005, 0.008, 0.025),
		2.0
	)
	await background_tween.finished

	for star in stars:
		var star_tween := create_tween()
		star_tween.tween_property(
			star,
			"modulate:a",
			1.0,
			randf_range(0.4, 1.4)
		)

	title_label.text = "PROJECT FIND HOPE"
	title_label.modulate.a = 0.0

	var title_tween := create_tween()
	title_tween.tween_property(
		title_label,
		"modulate:a",
		1.0,
		2.0
	)
	await title_tween.finished

	await get_tree().create_timer(1.0).timeout

	var narrative := [
		"ANO 2046. A Terra enfrenta uma crise de recursos.",
		"O Project Find Hope procura novas possibilidades de sobrevivência fora do planeta.",
		"A Nave 47, construída pela RIGHTSIDE, inicia uma missão de exploração.",
		"A bordo segue um androide de apoio da série PYSSOA.",
		"A missão deveria seguir uma rota previamente definida.",
		"Mas algo começa a interferir na navegação."
	]

	for line in narrative:
		title_label.text = ""
		await _type_text(dialogue_label, line)
		await get_tree().create_timer(TEXT_PAUSE).timeout

	await _fade_screen_content(0.5)
	await _clear_screen_content()


func _play_scene_two() -> void:
	background.color = Color(0.005, 0.012, 0.04)

	title_label = _make_label(
		"SISTEMA DE NAVEGAÇÃO DA NAVE 47",
		0.05, 0.04, 0.95, 0.12, 22
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.3, 0.85, 1.0)
	)

	map_visual = IntroMapVisual.new()
	map_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(map_visual)

	dialogue_label = _make_label(
		"",
		0.08, 0.72, 0.92, 0.88, 21
	)

	subtitle_label = _make_label(
		"ALERTA: TRAJETÓRIA INCONSISTENTE",
		0.05, 0.92, 0.95, 0.99, 13
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.5, 0.75, 0.9)
	)

	await get_tree().process_frame
	map_visual.queue_redraw()

	await get_tree().create_timer(2.0).timeout

	var atlas_lines := [
		"Atlas: A rota registada não corresponde à trajetória atual.",
		"Atlas: Estou a detetar um desvio que não foi solicitado.",
		"Atlas: Os comandos de correção não estão a produzir efeito.",
		"Atlas: A aproximação ao planeta é inevitável. A preparar aterragem de emergência."
	]

	map_visual.route_is_red = true
	map_visual.queue_redraw()

	for line in atlas_lines:
		await _type_text(dialogue_label, line)
		await get_tree().create_timer(TEXT_PAUSE).timeout

	await _fade_screen_content(0.8)
	await _clear_screen_content()


func _play_wake_up() -> void:
	background.color = Color.BLACK

	_create_intro_labels()

	title_label.text = ""
	dialogue_label.text = ""
	subtitle_label.text = ""

	if player != null and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(true)

	await get_tree().create_timer(1.5).timeout

	dialogue_label.text = "Acorde."
	dialogue_label.modulate.a = 0.0

	var wake_tween := create_tween()
	wake_tween.tween_property(
		dialogue_label,
		"modulate:a",
		1.0,
		1.0
	)
	await wake_tween.finished

	await get_tree().create_timer(1.5).timeout

	title_label.text = "SISTEMA DE EMERGÊNCIA"
	title_label.modulate.a = 0.0
	dialogue_label.text = "Integridade da nave comprometida.\nSinais vitais detetados."
	dialogue_label.modulate.a = 1.0

	var emergency_tween := create_tween()
	emergency_tween.tween_property(
		title_label,
		"modulate:a",
		1.0,
		1.0
	)
	await emergency_tween.finished

	await get_tree().create_timer(2.0).timeout

	await _fade_screen_content(0.6)
	await _clear_screen_content()


func _play_movement_tutorial() -> void:
	if player == null or not is_instance_valid(player):
		push_warning("Tutorial: não foi encontrado o nó Player.")
		return

	if player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(true)

	background.color = Color(0.008, 0.015, 0.03, 1.0)

	title_label = _make_label(
		"RECUPERAÇÃO DE CONSCIÊNCIA",
		0.05, 0.04, 0.95, 0.13, 23
	)

	dialogue_label = _make_label(
		"Estás a bordo da Nave 47.\nUsa WASD para te movimentares.",
		0.08, 0.79, 0.92, 0.9, 19
	)

	subtitle_label = _make_label(
		"MOVIMENTO",
		0.1, 0.93, 0.9, 0.99, 14
	)

	_create_tutorial_playfield()

	player_has_moved = false
	var starting_position := tutorial_player_position

	while is_instance_valid(tutorial_player) and not player_has_moved:
		await get_tree().process_frame
		_move_tutorial_player()

		if tutorial_player_position.distance_to(starting_position) > 8.0:
			player_has_moved = true

	if not is_instance_valid(tutorial_player):
		return

	if is_instance_valid(keyboard_visual):
		keyboard_visual.queue_free()

	dialogue_label.text = "Muito bem. Agora encontra o painel."
	subtitle_label.text = "Continua a movimentar o quadrado com WASD."


func _play_panel_tutorial() -> void:
	if not is_instance_valid(tutorial_player):
		return

	dialogue_label.text = "Aproxima-te do bloco que representa o painel."
	subtitle_label.text = "Move-te com WASD até ao bloco."

	while is_instance_valid(tutorial_player):
		await get_tree().process_frame
		_move_tutorial_player()

		if _is_panel_in_range():
			break

	if not is_instance_valid(tutorial_player):
		return

	tutorial_interaction_enabled = true

	dialogue_label.text = "Estás junto ao painel.\nPressiona E para interagir."
	subtitle_label.text = "E  |  INTERAGIR"

	interaction_hint = Control.new()
	interaction_hint.anchor_left = 0.5
	interaction_hint.anchor_right = 0.5
	interaction_hint.anchor_top = 0.5
	interaction_hint.anchor_bottom = 0.5
	interaction_hint.position = Vector2(-75, 85)
	interaction_hint.size = Vector2(180, 60)
	interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(interaction_hint)

	_add_key_button(interaction_hint, "E", 0, 0)

	var interaction_label := Label.new()
	interaction_label.position = Vector2(57, 0)
	interaction_label.size = Vector2(115, 48)
	interaction_label.text = "INTERAGIR"
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 13)
	interaction_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.95, 1.0)
	)
	interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_hint.add_child(interaction_label)

	while not tutorial_panel_activated and is_instance_valid(tutorial_player):
		await get_tree().process_frame
		_move_tutorial_player()

	if tutorial_panel_activated:
		tutorial_interaction_enabled = false

		if is_instance_valid(interaction_hint):
			interaction_hint.queue_free()

		dialogue_label.text = "Painel de emergência identificado."
		subtitle_label.text = "A iniciar estabilização..."

		await get_tree().create_timer(0.8).timeout
		await _play_stabilization_minigame()
		return


func _create_tutorial_playfield() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	var area_width: float = minf(viewport_size.x * 0.72, 620.0)
	var area_height: float = minf(viewport_size.y * 0.48, 340.0)

	tutorial_area = Panel.new()
	tutorial_area.name = "TutorialPlayfield"
	tutorial_area.anchor_left = 0.5
	tutorial_area.anchor_right = 0.5
	tutorial_area.anchor_top = 0.5
	tutorial_area.anchor_bottom = 0.5
	tutorial_area.offset_left = -area_width / 2.0
	tutorial_area.offset_right = area_width / 2.0
	tutorial_area.offset_top = -area_height / 2.0 - 15.0
	tutorial_area.offset_bottom = area_height / 2.0 - 15.0
	tutorial_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var area_style := StyleBoxFlat.new()
	area_style.bg_color = Color(0.018, 0.04, 0.065, 1.0)
	area_style.border_color = Color(0.12, 0.48, 0.65, 1.0)
	area_style.set_border_width_all(2)
	area_style.set_corner_radius_all(12)
	tutorial_area.add_theme_stylebox_override("panel", area_style)
	screen_root.add_child(tutorial_area)

	for i in range(1, 10):
		var line := ColorRect.new()
		line.color = Color(0.1, 0.35, 0.48, 0.18)
		line.size = Vector2(1, area_height)
		line.position = Vector2(area_width * i / 10.0, 0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_area.add_child(line)

	for i in range(1, 6):
		var line := ColorRect.new()
		line.color = Color(0.1, 0.35, 0.48, 0.18)
		line.size = Vector2(area_width, 1)
		line.position = Vector2(0, area_height * i / 6.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_area.add_child(line)

	var area_label := Label.new()
	area_label.position = Vector2(12, 8)
	area_label.size = Vector2(area_width - 24, 25)
	area_label.text = "NAVE 47  |  ÁREA DE TREINO"
	area_label.add_theme_font_size_override("font_size", 12)
	area_label.add_theme_color_override(
		"font_color",
		Color(0.35, 0.8, 1.0)
	)
	area_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_area.add_child(area_label)

	tutorial_player = ColorRect.new()
	tutorial_player.name = "TutorialPlayer"
	tutorial_player.size = PLAYER_SIZE
	tutorial_player.color = Color(0.2, 0.85, 1.0)
	tutorial_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_area.add_child(tutorial_player)

	tutorial_player_position = Vector2(
		area_width * 0.25,
		area_height * 0.55
	)
	_update_tutorial_player_position()

	tutorial_panel = ColorRect.new()
	tutorial_panel.name = "TutorialPanelBlock"
	tutorial_panel.size = PANEL_SIZE
	tutorial_panel.color = Color(0.75, 0.72, 0.18)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_area.add_child(tutorial_panel)

	tutorial_panel_position = Vector2(
		area_width * 0.75,
		area_height * 0.55
	)
	tutorial_panel.position = tutorial_panel_position - PANEL_SIZE / 2.0

	tutorial_panel_label = Label.new()
	tutorial_panel_label.position = Vector2(
		tutorial_panel_position.x - 60,
		tutorial_panel_position.y + PANEL_SIZE.y / 2.0 + 8
	)
	tutorial_panel_label.size = Vector2(120, 24)
	tutorial_panel_label.text = "PAINEL"
	tutorial_panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_panel_label.add_theme_font_size_override("font_size", 13)
	tutorial_panel_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	tutorial_panel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_area.add_child(tutorial_panel_label)

	keyboard_visual = Control.new()
	keyboard_visual.anchor_left = 0.5
	keyboard_visual.anchor_right = 0.5
	keyboard_visual.anchor_top = 0.5
	keyboard_visual.anchor_bottom = 0.5
	keyboard_visual.position = Vector2(-72, -70)
	keyboard_visual.size = Vector2(144, 105)
	keyboard_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(keyboard_visual)

	_add_key_button(keyboard_visual, "W", 48, 0)
	_add_key_button(keyboard_visual, "A", 0, 51)
	_add_key_button(keyboard_visual, "S", 48, 51)
	_add_key_button(keyboard_visual, "D", 96, 51)


func _move_tutorial_player() -> void:
	if not is_instance_valid(tutorial_player):
		return

	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if direction == Vector2.ZERO:
		return

	direction = direction.normalized()
	tutorial_player_position += direction * TUTORIAL_SPEED * get_process_delta_time()

	var half_size := PLAYER_SIZE / 2.0
	var area_size := tutorial_area.size

	tutorial_player_position.x = clampf(
		tutorial_player_position.x,
		half_size.x + 5.0,
		area_size.x - half_size.x - 5.0
	)
	tutorial_player_position.y = clampf(
		tutorial_player_position.y,
		half_size.y + 35.0,
		area_size.y - half_size.y - 5.0
	)

	_update_tutorial_player_position()

	if tutorial_interaction_enabled and Input.is_key_pressed(KEY_E):
		if _is_panel_in_range():
			_activate_tutorial_panel()


func _update_tutorial_player_position() -> void:
	if not is_instance_valid(tutorial_player):
		return

	tutorial_player.position = tutorial_player_position - PLAYER_SIZE / 2.0


func _is_panel_in_range() -> bool:
	if not is_instance_valid(tutorial_player):
		return false

	return tutorial_player_position.distance_to(
		tutorial_panel_position
	) <= INTERACTION_DISTANCE


func _activate_tutorial_panel() -> void:
	if tutorial_panel_activated:
		return

	tutorial_panel_activated = true

	if is_instance_valid(tutorial_panel):
		tutorial_panel.color = Color(0.15, 0.8, 0.35)

	if is_instance_valid(tutorial_panel_label):
		tutorial_panel_label.text = "ATIVADO"


func _play_stabilization_minigame() -> void:
	minigame_active = true
	stabilization = 0.75
	minigame_elapsed = 0.0

	background.color = Color(0.005, 0.008, 0.02, 1.0)

	if is_instance_valid(tutorial_area):
		tutorial_area.visible = false

	if is_instance_valid(keyboard_visual):
		keyboard_visual.visible = false

	if is_instance_valid(interaction_hint):
		interaction_hint.visible = false

	title_label.text = "SISTEMA DE ESTABILIZAÇÃO"
	dialogue_label.text = "A nave está a perder estabilidade!\nPressiona Q repetidamente para tentar compensar."
	subtitle_label.text = "FALHA DE NAVEGAÇÃO DETETADA"

	stabilization_panel = Panel.new()
	stabilization_panel.name = "StabilizationMinigame"
	stabilization_panel.anchor_left = 0.5
	stabilization_panel.anchor_right = 0.5
	stabilization_panel.anchor_top = 0.5
	stabilization_panel.anchor_bottom = 0.5
	stabilization_panel.offset_left = -210
	stabilization_panel.offset_right = 210
	stabilization_panel.offset_top = -100
	stabilization_panel.offset_bottom = 125

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.06, 1.0)
	panel_style.border_color = Color(0.15, 0.65, 0.85, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	stabilization_panel.add_theme_stylebox_override("panel", panel_style)
	screen_root.add_child(stabilization_panel)

	var heading := Label.new()
	heading.position = Vector2(20, 12)
	heading.size = Vector2(380, 30)
	heading.text = "ESTABILIDADE DA NAVE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override(
		"font_color",
		Color(0.4, 0.85, 1.0)
	)
	stabilization_panel.add_child(heading)

	stabilization_bar = ProgressBar.new()
	stabilization_bar.position = Vector2(25, 58)
	stabilization_bar.size = Vector2(360, 28)
	stabilization_bar.min_value = 0.0
	stabilization_bar.max_value = 1.0
	stabilization_bar.value = stabilization
	stabilization_bar.show_percentage = false
	stabilization_panel.add_child(stabilization_bar)

	stabilization_status = Label.new()
	stabilization_status.position = Vector2(25, 95)
	stabilization_status.size = Vector2(360, 25)
	stabilization_status.text = "COMPENSAÇÃO ATIVA"
	stabilization_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stabilization_status.add_theme_font_size_override("font_size", 14)
	stabilization_status.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	stabilization_panel.add_child(stabilization_status)

	stabilization_q_hint = Label.new()
	stabilization_q_hint.anchor_left = 0.5
	stabilization_q_hint.anchor_right = 0.5
	stabilization_q_hint.anchor_top = 0.5
	stabilization_q_hint.anchor_bottom = 0.5
	stabilization_q_hint.offset_left = -180
	stabilization_q_hint.offset_right = 180
	stabilization_q_hint.offset_top = 145
	stabilization_q_hint.offset_bottom = 185
	stabilization_q_hint.text = "[ Q ]  COMPENSAR ESTABILIDADE"
	stabilization_q_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stabilization_q_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stabilization_q_hint.add_theme_font_size_override("font_size", 17)
	stabilization_q_hint.add_theme_color_override(
		"font_color",
		Color(0.45, 0.9, 1.0)
	)
	screen_root.add_child(stabilization_q_hint)

	while minigame_elapsed < MINIGAME_DURATION:
		var delta_time := get_process_delta_time()

		minigame_elapsed += delta_time
		stabilization = maxf(
			stabilization - STABILITY_DRAIN * delta_time,
			0.0
		)

		if minigame_elapsed >= 2.0:
			stabilization_status.text = "ERRO DE COMPENSAÇÃO"
		if minigame_elapsed >= 4.0:
			stabilization_status.text = "SISTEMA SEM RESPOSTA"
		if minigame_elapsed >= 6.0:
			stabilization_status.text = "FALHA CRÍTICA"

		_update_stabilization_display()
		await get_tree().process_frame

	minigame_active = false

	if is_instance_valid(stabilization_panel):
		stabilization_panel.queue_free()

	if is_instance_valid(stabilization_q_hint):
		stabilization_q_hint.queue_free()

	stabilization_bar = null
	stabilization_status = null
	stabilization_q_hint = null

	await _show_stabilization_failure()


func _update_stabilization_display() -> void:
	if is_instance_valid(stabilization_bar):
		stabilization_bar.value = stabilization

	if is_instance_valid(stabilization_status):
		if stabilization <= 0.25:
			stabilization_status.add_theme_color_override(
				"font_color",
				Color(1.0, 0.15, 0.15)
			)
		elif stabilization <= 0.5:
			stabilization_status.add_theme_color_override(
				"font_color",
				Color(1.0, 0.65, 0.15)
			)
		else:
			stabilization_status.add_theme_color_override(
				"font_color",
				Color.WHITE
			)


func _show_stabilization_failure() -> void:
	background.color = Color(0.25, 0.005, 0.005, 1.0)

	title_label.text = "ESTABILIZAÇÃO FALHOU"
	dialogue_label.text = ""
	subtitle_label.text = "FALHA CRÍTICA"

	await get_tree().create_timer(1.2).timeout

	title_label.text = ""
	dialogue_label.text = "Atlas: Segure-se."
	subtitle_label.text = ""

	await get_tree().create_timer(1.5).timeout

	background.color = Color.BLACK
	title_label.text = ""
	dialogue_label.text = ""
	subtitle_label.text = ""

	await get_tree().create_timer(2.0).timeout


func _add_key_button(
	parent: Control,
	key_text: String,
	x: float,
	y: float,
	width: float = 42.0,
	height: float = 42.0
) -> void:
	var key_button := Panel.new()
	key_button.position = Vector2(x, y)
	key_button.size = Vector2(width, height)
	key_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.07, 0.11, 0.98)
	style.border_color = Color(0.2, 0.8, 1.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	key_button.add_theme_stylebox_override("panel", style)
	parent.add_child(key_button)

	var key_label := Label.new()
	key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_label.text = key_text
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 20)
	key_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.95, 1.0)
	)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_button.add_child(key_label)


func _make_label(
	message: String,
	left: float,
	top: float,
	right: float,
	bottom: float,
	font_size: int
) -> Label:
	var label := Label.new()
	label.text = message
	label.anchor_left = left
	label.anchor_top = top
	label.anchor_right = right
	label.anchor_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(label)
	return label


func _type_text(label: Label, message: String) -> void:
	label.text = ""

	for i in range(message.length()):
		label.text += message[i]
		await get_tree().create_timer(TYPE_SPEED).timeout


func _create_stars() -> Array[ColorRect]:
	var stars: Array[ColorRect] = []
	var viewport_size := get_viewport().get_visible_rect().size

	for i in range(100):
		var star := ColorRect.new()
		var star_size := randf_range(1.0, 3.0)

		star.size = Vector2(star_size, star_size)
		star.position = Vector2(
			randf_range(0.0, viewport_size.x),
			randf_range(0.0, viewport_size.y)
		)
		star.color = Color(0.65, 0.82, 1.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_root.add_child(star)
		stars.append(star)

	return stars


class IntroMapVisual extends Control:
	var route_is_red: bool = false

	func _draw() -> void:
		var viewport_size := get_rect().size

		for i in range(65):
			var x := fmod(float(i * 137 + 41), maxf(viewport_size.x, 1.0))
			var y := fmod(float(i * 83 + 17), maxf(viewport_size.y, 1.0))
			draw_circle(
				Vector2(x, y),
				1.3,
				Color(0.65, 0.8, 1.0, 0.8)
			)

		var start := Vector2(viewport_size.x * 0.16, viewport_size.y * 0.35)
		var waypoint := Vector2(viewport_size.x * 0.47, viewport_size.y * 0.29)
		var planned_end := Vector2(viewport_size.x * 0.79, viewport_size.y * 0.25)
		var deviation := Vector2(viewport_size.x * 0.64, viewport_size.y * 0.43)
		var planet := Vector2(viewport_size.x * 0.77, viewport_size.y * 0.53)

		draw_line(start, waypoint, Color(0.15, 0.65, 1.0), 3.0, true)
		draw_line(waypoint, planned_end, Color(0.15, 0.65, 1.0, 0.8), 3.0, true)

		if route_is_red:
			draw_line(waypoint, deviation, Color(1.0, 0.12, 0.12), 4.0, true)
			draw_line(deviation, planet, Color(1.0, 0.12, 0.12), 4.0, true)
			draw_circle(deviation, 6.0, Color(1.0, 0.2, 0.2))
		else:
			draw_circle(waypoint, 5.0, Color(0.2, 0.8, 1.0))

		draw_circle(start, 7.0, Color(0.4, 0.9, 1.0))
		draw_string(
			ThemeDB.fallback_font,
			start + Vector2(-30, 25),
			"NAVE 47",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color.WHITE
		)

		draw_circle(planet, 39.0, Color(0.35, 0.24, 0.65))
		draw_arc(
			planet,
			41.0,
			0.0,
			TAU,
			64,
			Color(0.45, 0.75, 1.0),
			2.0
		)
		draw_string(
			ThemeDB.fallback_font,
			planet + Vector2(-42, 60),
			"PLANETA",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.WHITE
		)
