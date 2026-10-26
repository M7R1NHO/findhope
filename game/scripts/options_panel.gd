extends RefCounted

# Controlos do ecrã OPÇÕES, iguais no menu principal e no menu de pausa:
# volume geral e volume da música (music_player.gd). Mudam o som enquanto se
# arrasta e gravam no perfil ao largar (e ao sair do ecrã).

const ROWS := [["master", "VOLUME GERAL"], ["music", "MÚSICA"]]


static func add_controls(container: Container) -> void:
	var music: Node = container.get_node("/root/Music")
	for row in ROWS:
		var kind: String = row[0]
		var line := HBoxContainer.new()
		line.name = "Row_" + kind
		line.add_theme_constant_override("separation", 14)
		container.add_child(line)
		var label := Label.new()
		label.text = row[1]
		label.custom_minimum_size = Vector2(170, 0)
		line.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = round(music.get_volume(kind) * 100.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(260, 28)
		line.add_child(slider)
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size = Vector2(56, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = "%d%%" % int(slider.value)
		line.add_child(value_label)
		slider.value_changed.connect(func(value: float):
			value_label.text = "%d%%" % int(value)
			music.set_volume(kind, value / 100.0, false))
		slider.drag_ended.connect(func(_changed: bool):
			music.set_volume(kind, slider.value / 100.0, true))
	if music.missing_track:
		var warning := Label.new()
		warning.text = "Banda sonora em falta: " + music.TRACK
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(warning)
	# Ao sair do ecrã grava (por exemplo, depois de usar as setas do teclado).
	container.tree_exiting.connect(func(): SaveManager.save_profile())
