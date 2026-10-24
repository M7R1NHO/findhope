extends CanvasLayer

# Confronto final da Sala de Controlo, inspirado em Five Nights at Freddy's.
#
# O Player fica preso à consola durante 60 segundos enquanto o Atlas abre o
# Hangar. A criatura aproxima-se pela porta esquerda ou pela direita. Não há
# câmaras: o único aviso é o sensor de temperatura do Atlas, que mostra o
# calor junto de cada porta. Fechar uma porta gasta ENERGIA.
#
# Só há dois resultados (decididos pelo código, nunca pela IA):
#   INTEIRO    - a criatura nunca entrou;
#   DANIFICADO - a criatura entrou por uma porta aberta e o Atlas pôs-se à
#                frente do Player. Acontece no máximo uma vez.
# Não há Game Over aqui e a VIDA não muda.
#
# Antes de começar, um ecrã de instruções explica as regras com o tempo
# parado (open_briefing). Durante o confronto, o Atlas dá três dicas, cada
# uma uma só vez. As instruções e as dicas não mudam nenhuma regra.

signal finished(atlas_damaged: bool, stats: Dictionary)
signal door_knocked(side: String)        # bateu numa porta fechada
signal creature_entered(side: String)    # entrou por uma porta aberta

const UIStyle := preload("res://scripts/ui_style.gd")
const BossView := preload("res://scripts/phase3_boss_view.gd")

const DURATION := 60.0
const MAX_ENERGY := 100.0
const DOOR_DRAIN_PER_SEC := 4.0       # por porta fechada
const SENSOR_INTERVAL := 1.0          # o sensor atualiza a cada segundo
const MOVE_INTERVAL_START := 4.0      # a criatura mexe-se mais depressa
const MOVE_INTERVAL_END := 2.5        # à medida que o tempo passa
const DOOR_WAIT := 2.5                # tempo à porta antes de tentar entrar
const BASE_TEMP := 12.0
const TEMP_PER_STEP := 9.0            # 12, 21, 30, 39 °C
const DOOR_STEP := 3                  # 0 longe, 1 corredor, 2 perto, 3 à porta

const SIDES := ["left", "right"]

const HOT_TEMP := 28.0                # a partir daqui o sensor fica vermelho
const LOW_ENERGY := 30.0              # aviso de energia baixa

var rng := RandomNumberGenerator.new()
var running: bool = false
var time_left: float = DURATION
var energy: float = MAX_ENERGY
var doors_closed: Dictionary = {"left": false, "right": false}
var creature_side: String = "left"
var creature_step: int = 0
var move_timer: float = 0.0
var door_timer: float = 0.0
var sensor_timer: float = 0.0
var sensor_readings: Dictionary = {"left": BASE_TEMP, "right": BASE_TEMP}
var atlas_damaged: bool = false
var breaches: int = 0
var blocked: int = 0
var power_out: bool = false

# Ecrã de instruções e dicas (cada dica aparece uma só vez).
var briefing_open: bool = false
var briefing_seed: int = 0
var briefing_panel: Control = null
var hints_shown: Dictionary = {"hot": false, "retreat": false, "low_energy": false}

var timer_label: Label
var energy_bar: ProgressBar
var sensor_labels: Dictionary = {}
var door_buttons: Dictionary = {}
var atlas_label: Label
var view: Control = null
var energy_fill: StyleBoxFlat = null


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_ui()


# Mostra as instruções com o tempo parado. O confronto só começa quando o
# Player carrega em COMEÇAR (ou ESPAÇO / ENTER).
func open_briefing(seed: int = 0) -> void:
	briefing_seed = seed
	briefing_open = true
	running = false
	time_left = DURATION
	energy = MAX_ENERGY
	refresh_ui()
	briefing_panel = create_briefing()
	add_child(briefing_panel)


func close_briefing() -> void:
	if not briefing_open:
		return
	briefing_open = false
	if is_instance_valid(briefing_panel):
		briefing_panel.queue_free()
	briefing_panel = null
	start(briefing_seed)


# seed > 0 torna o confronto reprodutível (usado nos testes).
func start(seed: int = 0) -> void:
	if seed > 0:
		rng.seed = seed
	else:
		rng.randomize()
	running = true
	hints_shown = {"hot": false, "retreat": false, "low_energy": false}
	time_left = DURATION
	energy = MAX_ENERGY
	creature_side = SIDES[rng.randi_range(0, 1)]
	creature_step = 0
	move_timer = MOVE_INTERVAL_START
	sensor_timer = 0.0
	update_sensor()
	say("Preciso de 60 segundos para abrir o Hangar. Vou vigiar o calor junto às portas. Fecha a porta que aquecer.")
	refresh_ui()


func _process(delta: float) -> void:
	if running:
		step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if briefing_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			close_briefing()
			get_viewport().set_input_as_handled()
		return
	if not running or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_A:
		toggle_door("left")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_D:
		toggle_door("right")
		get_viewport().set_input_as_handled()


func step(delta: float) -> void:
	if not running:
		return
	time_left = max(0.0, time_left - delta)

	# ENERGIA: cada porta fechada gasta. Sem energia, as portas abrem.
	var closed_count := int(doors_closed["left"]) + int(doors_closed["right"])
	energy = max(0.0, energy - DOOR_DRAIN_PER_SEC * closed_count * delta)
	if energy <= 0.0 and not power_out:
		power_out = true
		doors_closed["left"] = false
		doors_closed["right"] = false
		say("Sem energia. As portas abriram e não consigo voltar a fechá-las.")
	elif energy < LOW_ENERGY and not power_out and not hints_shown["low_energy"]:
		hints_shown["low_energy"] = true
		say("Energia abaixo de 30%. Fecha só a porta que estiver quente e abre-a quando arrefecer.")

	if creature_step >= DOOR_STEP:
		door_timer -= delta
		if door_timer <= 0.0:
			try_enter()
	else:
		move_timer -= delta
		if move_timer <= 0.0:
			move_creature()

	sensor_timer -= delta
	if sensor_timer <= 0.0:
		sensor_timer = SENSOR_INTERVAL
		update_sensor()

	if time_left <= 0.0:
		finish()
		return
	refresh_ui()


func current_move_interval() -> float:
	var progress := 1.0 - time_left / DURATION
	return lerp(MOVE_INTERVAL_START, MOVE_INTERVAL_END, progress)


func move_creature() -> void:
	move_timer = current_move_interval()
	# Na maior parte das vezes avança; às vezes recua ou muda de lado.
	var roll := rng.randf()
	if creature_step == 0 and roll < 0.35:
		creature_side = "right" if creature_side == "left" else "left"
	elif roll < 0.8:
		creature_step += 1
	elif creature_step > 0:
		creature_step -= 1
	if creature_step >= DOOR_STEP:
		creature_step = DOOR_STEP
		door_timer = DOOR_WAIT


func try_enter() -> void:
	var side := creature_side
	if doors_closed[side]:
		blocked += 1
		door_knocked.emit(side)
		if not hints_shown["retreat"]:
			hints_shown["retreat"] = true
			say("Bateu na porta e recuou. Já podes abri-la para poupar energia.")
		else:
			say("Bateu na porta e recuou. A temperatura está a descer.")
	else:
		breaches += 1
		creature_entered.emit(side)
		if not atlas_damaged:
			atlas_damaged = true
			say("Entrou! Pus-me à frente... os meus sistemas foram danificados. Continua, ainda consigo abrir o Hangar.")
		else:
			say("Voltou a entrar. Já não aguento muito mais.")
	creature_step = 0
	creature_side = SIDES[rng.randi_range(0, 1)]
	move_timer = current_move_interval()


# O sensor só mede calor; o Player tem de interpretar os números.
func update_sensor() -> void:
	for side in SIDES:
		var steps := creature_step if side == creature_side else 0
		var noise := rng.randf_range(-1.5, 1.5)
		sensor_readings[side] = BASE_TEMP + TEMP_PER_STEP * steps + noise
	maybe_hint_hot_door()


# Primeira vez que uma porta aberta aquece: o Atlas diz qual tecla usar.
func maybe_hint_hot_door() -> void:
	if not running or hints_shown["hot"] or power_out:
		return
	for side in SIDES:
		if sensor_readings[side] >= HOT_TEMP and not doors_closed[side]:
			hints_shown["hot"] = true
			var key := "[A]" if side == "left" else "[D]"
			var name_text := "esquerda" if side == "left" else "direita"
			say("A porta " + name_text + " está a aquecer: está perto! Carrega " + key + " para a fechar.")
			return


func toggle_door(side: String) -> void:
	if not running or power_out:
		return
	doors_closed[side] = not doors_closed[side]
	refresh_ui()


func finish() -> void:
	running = false
	refresh_ui()
	if atlas_damaged:
		say("O Hangar está aberto. Não consigo andar bem... mas estamos vivos.")
	else:
		say("O Hangar está aberto. Saímos inteiros.")
	finished.emit(atlas_damaged, get_stats())


func get_stats() -> Dictionary:
	return {
		"atlas_damaged": atlas_damaged,
		"breaches": breaches,
		"blocked": blocked,
		"energy_left": int(round(energy)),
		"power_out": power_out
	}


func say(text: String) -> void:
	if atlas_label != null:
		atlas_label.text = "ATLAS: " + text


func create_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.025, 0.035, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply(background)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	box.add_child(header)

	var title := Label.new()
	title.text = "SALA DE CONTROLO"
	title.add_theme_font_size_override("font_size", 20)
	UIStyle.title(title)
	header.add_child(title)

	timer_label = Label.new()
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 20)
	header.add_child(timer_label)

	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 12)
	box.add_child(energy_row)
	var energy_title := Label.new()
	energy_title.text = "ENERGIA"
	energy_title.add_theme_color_override("font_color", UIStyle.TEXT_MUTED)
	energy_row.add_child(energy_title)
	energy_bar = ProgressBar.new()
	energy_bar.max_value = MAX_ENERGY
	energy_bar.custom_minimum_size = Vector2(900.0, 20.0)
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_fill = StyleBoxFlat.new()
	energy_fill.set_corner_radius_all(4)
	energy_bar.add_theme_stylebox_override("fill", energy_fill)
	var energy_back := StyleBoxFlat.new()
	energy_back.bg_color = Color(0.08, 0.09, 0.11)
	energy_back.set_corner_radius_all(4)
	energy_bar.add_theme_stylebox_override("background", energy_back)
	energy_row.add_child(energy_bar)

	# Planta da sala (só desenho; ver phase3_boss_view.gd).
	view = BossView.new()
	view.name = "BossView"
	view.bind(self)
	box.add_child(view)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	for side in SIDES:
		var column := HBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		row.add_child(column)
		var sensor := Label.new()
		sensor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sensor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sensor.custom_minimum_size = Vector2(190.0, 46.0)
		sensor.add_theme_font_size_override("font_size", 20)
		var button := Button.new()
		button.custom_minimum_size = Vector2(250.0, 46.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(toggle_door.bind(side))
		# O sensor fica do lado de fora, como na planta.
		if side == "left":
			column.add_child(sensor)
			column.add_child(button)
		else:
			column.add_child(button)
			column.add_child(sensor)
		sensor_labels[side] = sensor
		door_buttons[side] = button

	atlas_label = Label.new()
	atlas_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atlas_label.custom_minimum_size = Vector2(1000.0, 62.0)
	atlas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_label.add_theme_font_size_override("font_size", 19)
	box.add_child(atlas_label)


func refresh_ui() -> void:
	if timer_label == null:
		return
	timer_label.text = "HANGAR ABERTO EM " + str(int(ceil(time_left))) + " s"
	energy_bar.value = energy
	if energy_fill != null:
		if energy > 50.0:
			energy_fill.bg_color = Color(0.25, 0.7, 0.45)
		elif energy > 25.0:
			energy_fill.bg_color = Color(0.85, 0.62, 0.16)
		else:
			energy_fill.bg_color = UIStyle.DANGER
	for side in SIDES:
		var name_text := "ESQUERDA" if side == "left" else "DIREITA"
		var temperature: float = sensor_readings[side]
		sensor_labels[side].text = name_text + ": " + str(snapped(temperature, 0.1)) + " °C"
		sensor_labels[side].add_theme_color_override(
			"font_color", UIStyle.DANGER if temperature >= HOT_TEMP else UIStyle.TEXT
		)
		var key := "[A]" if side == "left" else "[D]"
		var state := "FECHADA" if doors_closed[side] else "ABERTA"
		door_buttons[side].text = key + " PORTA " + name_text + ": " + state
		door_buttons[side].disabled = power_out or not running


# ---------------------------------------------------------------------------
# Ecrã de instruções
# ---------------------------------------------------------------------------

func create_briefing() -> Control:
	var shade := ColorRect.new()
	shade.name = "Briefing"
	shade.color = Color(0.0, 0.0, 0.0, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "COMO SOBREVIVER À SALA DE CONTROLO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	UIStyle.title(title)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)

	grid.add_child(briefing_card(
		"1. OBJETIVO",
		"O Atlas precisa de 60 segundos para abrir o Hangar. Tu ficas na consola a proteger-vos.",
		timer_illustration()
	))
	grid.add_child(briefing_card(
		"2. SENSOR DE TEMPERATURA",
		"Não há câmaras. A criatura é quente: quanto mais perto de uma porta, mais sobe a temperatura desse lado.",
		temperature_illustration()
	))
	grid.add_child(briefing_card(
		"3. PORTAS E ENERGIA",
		"[A] fecha/abre a esquerda, [D] a direita. Cada porta fechada gasta energia: uma aguenta 25 s, as duas só 12,5 s. Sem energia, ficam abertas.",
		keys_illustration()
	))
	grid.add_child(briefing_card(
		"4. SE ELA ENTRAR",
		"À porta, a criatura espera 2,5 s antes de entrar. Se a porta estiver aberta, o Atlas põe-se à tua frente e fica danificado. Isso muda o final.",
		danger_illustration()
	))

	var tip := Label.new()
	tip.text = "Dica: fecha só a porta que ficar vermelha e volta a abri-la quando arrefecer."
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", UIStyle.ACCENT)
	box.add_child(tip)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "COMEÇAR  [ESPAÇO]"
	start_button.custom_minimum_size = Vector2(320.0, 52.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(close_briefing)
	box.add_child(start_button)
	return shade


func briefing_card(heading: String, body: String, illustration: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500.0, 196.0)
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyle.PANEL_BG
	style.border_color = UIStyle.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_size_override("font_size", 18)
	UIStyle.title(heading_label)
	column.add_child(heading_label)

	column.add_child(illustration)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(470.0, 0.0)
	body_label.add_theme_font_size_override("font_size", 15)
	column.add_child(body_label)
	return card


# Ilustrações simples, feitas com caixas de cor (sem imagens).

func chip(text: String, background: Color, width: float = 100.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 34.0)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4.0)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	return panel


func illustration_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func timer_illustration() -> Control:
	var row := illustration_row()
	var bar := ProgressBar.new()
	bar.max_value = DURATION
	bar.value = DURATION * 0.35
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(330.0, 22.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(chip("HANGAR 60 s", UIStyle.BUTTON_BG_PRESSED, 120.0))
	return row


func temperature_illustration() -> Control:
	var row := illustration_row()
	var steps := [
		["~12 °C longe", Color(0.16, 0.32, 0.5)],
		["~21 corredor", Color(0.45, 0.42, 0.18)],
		["~30 perto", Color(0.72, 0.36, 0.14)],
		["~39 à porta", Color(0.75, 0.16, 0.16)],
	]
	for step_info in steps:
		row.add_child(chip(step_info[0], step_info[1], 112.0))
	return row


func keys_illustration() -> Control:
	var row := illustration_row()
	row.add_child(chip("[A]", UIStyle.BUTTON_BG_HOVER, 50.0))
	row.add_child(chip("PORTA ESQ.", UIStyle.BUTTON_BG, 110.0))
	row.add_child(chip("[D]", UIStyle.BUTTON_BG_HOVER, 50.0))
	row.add_child(chip("PORTA DIR.", UIStyle.BUTTON_BG, 110.0))
	row.add_child(chip("-4 /s", Color(0.45, 0.33, 0.1), 80.0))
	return row


func danger_illustration() -> Control:
	var row := illustration_row()
	row.add_child(chip("À PORTA", Color(0.75, 0.16, 0.16), 110.0))
	row.add_child(chip("2,5 s", UIStyle.BUTTON_BG, 70.0))
	row.add_child(chip("FECHADA: RECUA", Color(0.12, 0.42, 0.3), 150.0))
	row.add_child(chip("ABERTA: ATLAS DANIFICADO", Color(0.5, 0.12, 0.12), 0.0))
	return row
