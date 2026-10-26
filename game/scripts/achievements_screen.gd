extends CanvasLayer

# Ecrã CONQUISTAS: as 16 conquistas, desbloqueadas a cores e bloqueadas a
# cinzento, com a raridade, o que é preciso fazer, o progresso das que têm
# contador (conversas, lutas, minijogos, finais [x/16]) e a data em que cada
# uma foi desbloqueada. Fecha com VOLTAR ou ESC.

signal closed

const UIStyle := preload("res://scripts/ui_style.gd")
const AchievementList := preload("res://scripts/achievements.gd")


static func open(parent: Node) -> CanvasLayer:
	var layer = load("res://scripts/achievements_screen.gd").new()
	layer.name = "AchievementsScreen"
	parent.add_child(layer)
	return layer


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	build()


func achievements() -> Node:
	return get_node("/root/Achievements")


func build() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.92)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	UIStyle.apply(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "CONQUISTAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	UIStyle.title(title)
	column.add_child(title)

	var summary := Label.new()
	summary.name = "Summary"
	summary.text = "%d / %d desbloqueadas" % [achievements().unlocked_count(), AchievementList.LIST.size()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.subtitle(summary)
	column.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for item in AchievementList.LIST:
		grid.add_child(make_card(item))

	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(close)
	column.add_child(back)
	back.grab_focus.call_deferred()


func make_card(item: Dictionary) -> PanelContainer:
	var id: String = item["id"]
	var is_unlocked: bool = achievements().is_unlocked(id)
	var color: Color = AchievementList.RARITY_COLORS.get(item["rarity"], Color.WHITE)
	var card := PanelContainer.new()
	card.name = "Card_" + id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("unlocked", is_unlocked)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.1) if is_unlocked else Color(0.04, 0.045, 0.05)
	style.border_color = color if is_unlocked else Color(0.18, 0.2, 0.22)
	style.set_border_width_all(2 if is_unlocked else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var rarity := Label.new()
	rarity.text = str(item["rarity"])
	rarity.add_theme_font_size_override("font_size", 12)
	rarity.add_theme_color_override("font_color", color if is_unlocked else Color(0.4, 0.44, 0.48))
	rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rarity)
	var state := Label.new()
	state.name = "State"
	state.add_theme_font_size_override("font_size", 12)
	if is_unlocked:
		var entry: Dictionary = SaveManager.profile.get("achievements", {}).get(id, {})
		state.text = "DESBLOQUEADA " + str(entry.get("unlocked_at", "")).split("T")[0]
		state.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		state.text = "BLOQUEADA"
		state.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	head.add_child(state)

	var title := Label.new()
	title.text = str(item["title"])
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UIStyle.TEXT if is_unlocked else Color(0.55, 0.58, 0.62))
	box.add_child(title)
	var description := Label.new()
	description.text = str(item["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", UIStyle.TEXT_MUTED if is_unlocked else Color(0.42, 0.45, 0.49))
	box.add_child(description)

	if item.has("goal"):
		var values: Array = achievements().progress(id)
		if is_unlocked:
			values = [values[1], values[1]] if id != "eu_achei_esperanca" else values
		var bar := ProgressBar.new()
		bar.name = "Progress"
		bar.max_value = values[1]
		bar.value = values[0]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		box.add_child(bar)
		var count := Label.new()
		count.name = "Count"
		count.text = "[%d/%d]" % [values[0], values[1]]
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_color_override("font_color", UIStyle.TEXT_MUTED)
		box.add_child(count)
	return card


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
