extends CanvasLayer

# Hangar: a nave do explorador e a escolha final.
#
# Tudo é uma sequência visual; as escolhas aparecem como botões fixos no
# ecrã, sem limite de tempo. O desfecho é decidido só pelo código:
#   A - Atlas INTEIRO: correm juntos para a nave.
#   B - Atlas DANIFICADO, o Player foge sozinho.
#   C - Atlas DANIFICADO, o Player volta e salvam-se os dois (VIDA >= 40).
#   D - Atlas DANIFICADO, o Player volta e morre no resgate (VIDA < 40).
# A IA escolhe depois apenas a variante do Atlas dentro do desfecho (P3.5).

signal outcome_chosen(outcome: String, facts: Dictionary)

const UIStyle := preload("res://scripts/ui_style.gd")

const RESCUE_MIN_VIDA := 40

var atlas_damaged: bool = false
var vida: int = 100
var player: Node2D = null
var atlas: Node2D = null
var ship_position: Vector2 = Vector2.ZERO

var text_label: Label
var buttons_box: HBoxContainer
var background: ColorRect
var chosen: bool = false


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_ui()


# O desfecho de VOLTAR depende só da VIDA que o Player traz da run.
static func rescue_outcome(current_vida: int) -> String:
	return "C" if current_vida >= RESCUE_MIN_VIDA else "D"


func start() -> void:
	if atlas_damaged:
		show_text("ATLAS: É a nave do explorador. Os sistemas ainda respondem... mas eu não consigo acompanhar-te. Vai.")
		add_choice("FUGIR SOZINHO", _on_flee_alone)
		add_choice("VOLTAR PARA SALVAR O ATLAS", _on_go_back)
	else:
		show_text("ATLAS: É a nave do explorador. Os sistemas ainda respondem. Corre, eu vou contigo!")
		add_choice("CORRER PARA A NAVE COM O ATLAS", _on_run_together)


func _on_run_together() -> void:
	await choose("A", "run_together")


func _on_flee_alone() -> void:
	await choose("B", "flee_alone")


func _on_go_back() -> void:
	await choose(rescue_outcome(vida), "go_back")


func choose(outcome: String, choice: String) -> void:
	if chosen:
		return
	chosen = true
	clear_choices()
	await play_outcome_visual(outcome)
	outcome_chosen.emit(outcome, {
		"outcome": outcome,
		"choice": choice,
		"atlas_damaged": atlas_damaged,
		"vida": vida
	})


# Sequência visual curta (sem sprites): o Player e o Atlas movem-se no mundo
# por trás de um ecrã semitransparente.
func play_outcome_visual(outcome: String) -> void:
	background.color = Color(0.0, 0.0, 0.0, 0.35)
	match outcome:
		"A":
			show_text("Correm os dois para a nave.")
			await move_together([player, atlas], ship_position)
		"B":
			show_text("Corres para a nave. O Atlas fica para trás.")
			await move_together([player], ship_position)
		"C":
			show_text("Voltas atrás, levantas o Atlas e arrastas-o até à nave.")
			if is_instance_valid(atlas):
				await move_together([player], atlas.global_position)
			await move_together([player, atlas], ship_position)
		"D":
			show_text("Voltas atrás pelo Atlas. A criatura é mais rápida.")
			if is_instance_valid(atlas):
				await move_together([player], atlas.global_position)
			var tween := create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(background, "color", Color(0.45, 0.0, 0.0, 0.85), 1.2)
			await tween.finished
	background.color = Color(0.0, 0.0, 0.0, 0.92)


func move_together(nodes: Array, target: Vector2) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	var spacing := 0.0
	for node in nodes:
		if is_instance_valid(node):
			tween.tween_property(node, "global_position", target + Vector2(spacing, 0.0), 1.4)
			spacing += 70.0
	await tween.finished


func show_text(text: String) -> void:
	if text_label != null:
		text_label.text = text


func add_choice(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(360.0, 56.0)
	button.pressed.connect(callback)
	buttons_box.add_child(button)


func clear_choices() -> void:
	for child in buttons_box.get_children():
		child.queue_free()


func get_choice_labels() -> Array:
	var labels := []
	for child in buttons_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			labels.append(child.text)
	return labels


func create_ui() -> void:
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.6)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply(background)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-460.0, -260.0)
	box.size = Vector2(920.0, 220.0)
	box.add_theme_constant_override("separation", 24)
	background.add_child(box)

	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(920.0, 90.0)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 23)
	box.add_child(text_label)

	buttons_box = HBoxContainer.new()
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_box.add_theme_constant_override("separation", 30)
	box.add_child(buttons_box)
