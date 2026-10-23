extends Area2D


@export var scan_duration: float = 2.5

@export var interaction_radius: Vector2 = Vector2(
	180,
	160
)


var player_nearby: bool = false

var scanning: bool = false

var scan_progress: float = 0.0

var map_acquired: bool = false


var main: Node = null


var terminal_visual: Polygon2D = null

var interaction_label: Label = null


var scan_layer: CanvasLayer = null

var scan_bar: ProgressBar = null

var scan_label: Label = null


# =========================================================
# READY
# =========================================================

func _ready():
	main = get_tree().current_scene


	collision_layer = 0

	collision_mask = 0xFFFFFFFF

	monitoring = true

	monitorable = true


	create_collision()

	create_terminal_visual()

	create_interaction_label()


	# A planta já adquirida continua adquirida depois de carregar um save.
	if bool(SaveManager.get_run_value("world", "facility_map_acquired", false)):
		map_acquired = true
		interaction_label.text = "PLANTA ADQUIRIDA"
		if terminal_visual != null:
			terminal_visual.color = Color(0.12, 0.75, 0.55, 1.0)
		call_deferred("refresh_room_tracker")


	body_entered.connect(
		on_body_entered
	)


	body_exited.connect(
		on_body_exited
	)


	print(
		"FACILITY MAP TERMINAL READY"
	)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):
	if map_acquired:
		return


	if not player_nearby:

		if scanning:
			cancel_scan()

		return


	if Input.is_key_pressed(
		KEY_SPACE
	):

		if not scanning:
			start_scan()


		scan_progress += delta


		update_scan_ui()


		if scan_progress >= scan_duration:
			complete_scan()


	else:

		if scanning:
			cancel_scan()


# =========================================================
# COLLISION
# =========================================================

func create_collision():
	var collision = CollisionShape2D.new()


	collision.name = "InteractionArea"


	var shape = RectangleShape2D.new()


	shape.size = interaction_radius


	collision.shape = shape


	add_child(
		collision
	)


# =========================================================
# VISUAL
# =========================================================

func create_terminal_visual():
	terminal_visual = Polygon2D.new()


	terminal_visual.name = "TerminalVisual"


	terminal_visual.polygon = PackedVector2Array([
		Vector2(-55, -35),
		Vector2(55, -35),
		Vector2(55, 35),
		Vector2(-55, 35)
	])


	terminal_visual.color = Color(
		0.08,
		0.45,
		0.55,
		1.0
	)


	terminal_visual.z_index = 5


	add_child(
		terminal_visual
	)


# =========================================================
# LABEL
# =========================================================

func create_interaction_label():
	interaction_label = Label.new()


	interaction_label.name = (
		"InteractionLabel"
	)


	interaction_label.text = (
		"[SPACE] ANALISAR TERMINAL"
	)


	interaction_label.position = Vector2(
		-140,
		-85
	)


	interaction_label.size = Vector2(
		280,
		40
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


# =========================================================
# PLAYER ENTER / EXIT
# =========================================================

func on_body_entered(
	body: Node
):
	if not is_player(
		body
	):
		return


	player_nearby = true


	if not map_acquired:
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


	if scanning:
		cancel_scan()


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


# =========================================================
# START SCAN
# =========================================================

func start_scan():
	if scanning:
		return


	scanning = true

	scan_progress = 0.0


	interaction_label.visible = false


	create_scan_ui()


	print(
		"FACILITY MAP SCAN STARTED"
	)


# =========================================================
# CANCEL SCAN
# =========================================================

func cancel_scan():
	scanning = false

	scan_progress = 0.0


	destroy_scan_ui()


	if (
		player_nearby
		and not map_acquired
	):
		interaction_label.visible = true


# =========================================================
# UI
# =========================================================

func create_scan_ui():
	destroy_scan_ui()


	scan_layer = CanvasLayer.new()


	scan_layer.name = (
		"FacilityMapScanUI"
	)


	scan_layer.layer = 250


	add_child(
		scan_layer
	)


	var container = VBoxContainer.new()


	container.set_anchors_preset(
		Control.PRESET_CENTER
	)


	container.position = Vector2(
		-250,
		-80
	)


	container.size = Vector2(
		500,
		160
	)


	container.add_theme_constant_override(
		"separation",
		15
	)


	scan_layer.add_child(
		container
	)


	scan_label = Label.new()


	scan_label.text = (
		"ATLAS // ANALISANDO TERMINAL"
	)


	scan_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	scan_label.add_theme_font_size_override(
		"font_size",
		22
	)


	container.add_child(
		scan_label
	)


	scan_bar = ProgressBar.new()


	scan_bar.min_value = 0.0

	scan_bar.max_value = scan_duration

	scan_bar.value = 0.0


	scan_bar.show_percentage = false


	scan_bar.custom_minimum_size = Vector2(
		500,
		45
	)


	container.add_child(
		scan_bar
	)


# =========================================================
# UPDATE UI
# =========================================================

func update_scan_ui():
	if scan_bar != null:
		scan_bar.value = scan_progress


	if scan_label != null:

		var percentage: int = int(
			clamp(
				scan_progress / scan_duration,
				0.0,
				1.0
			)
			* 100.0
		)


		scan_label.text = (
			"ATLAS // ANALISANDO TERMINAL\n"
			+ str(percentage)
			+ "%"
		)


# =========================================================
# COMPLETE
# =========================================================

func complete_scan():
	if map_acquired:
		return


	map_acquired = true
	SaveManager.set_run_value("world", "facility_map_acquired", true)

	scanning = false

	scan_progress = scan_duration


	destroy_scan_ui()


	interaction_label.text = (
		"PLANTA ADQUIRIDA"
	)


	interaction_label.visible = true


	if terminal_visual != null:

		terminal_visual.color = Color(
			0.12,
			0.75,
			0.55,
			1.0
		)


	send_map_context_to_backend()


	refresh_room_tracker()


	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"Consegui reconstruir a planta da instalação. "
			+ "Agora consigo orientar-nos pelos setores conhecidos."
		)


	print("")
	print(
		"======================================"
	)

	print(
		"FACILITY MAP ACQUIRED"
	)

	print(
		"ATLAS NOW KNOWS FACILITY LAYOUT"
	)

	print(
		"======================================"
	)


# =========================================================
# BACKEND MAP CONTEXT
# =========================================================

func send_map_context_to_backend():
	if main == null:
		return


	if not main.has_method(
		"send_gameplay_context_event"
	):
		return


	var description: String = (
		"ATLAS ADQUIRIU A PLANTA DA INSTALAÇÃO SUBTERRÂNEA. "
		+ "Esta planta é uma fonte válida de informação espacial e estrutural. "

		+ "A Entrada liga ao Hall de Entrada. "

		+ "O Hall liga ao Armazém / Peças "
		+ "e à Sala Técnica / Energia. "

		+ "O Armazém liga ao Hall, "
		+ "à Sala de Suporte "
		+ "e aos Arquivos / Registos. "

		+ "A Sala Técnica liga ao Hall, "
		+ "à Segurança / Contenção "
		+ "e ao Laboratório / Análise. "

		+ "A Sala de Suporte liga ao Armazém "
		+ "e à Oficina / Manutenção. "

		+ "Segurança / Contenção liga "
		+ "à Sala Técnica. "

		+ "Os Arquivos ligam ao Armazém, "
		+ "ao Laboratório "
		+ "e ao Santuário. "

		+ "O Laboratório liga à Sala Técnica, "
		+ "aos Arquivos "
		+ "e ao Núcleo Principal. "

		+ "A Oficina / Manutenção liga "
		+ "à Sala de Suporte. "

		+ "O Santuário liga aos Arquivos "
		+ "e ao Núcleo Principal. "

		+ "O Núcleo Principal liga "
		+ "ao Laboratório "
		+ "e ao Santuário. "

		+ "Atlas pode utilizar esta planta para responder "
		+ "perguntas sobre localização, direção, salas adjacentes "
		+ "e rotas entre setores. "

		+ "Perguntas espaciais baseadas na planta NÃO exigem "
		+ "sensores em tempo real. "

		+ "Exemplo: se a localização atual confirmada for o Hall, "
		+ "uma pergunta como 'qual sala fica à direita?' "
		+ "pode ser respondida através da planta. "

		+ "IMPORTANTE: a planta revela apenas estrutura, "
		+ "ligações e rótulos dos setores. "

		+ "O nome ou rótulo de uma sala NÃO confirma "
		+ "o conteúdo existente dentro dela. "

		+ "Atlas NÃO deve afirmar que visitou, analisou "
		+ "ou encontrou algo numa sala apenas porque "
		+ "o nome dessa sala sugere esse conteúdo. "

		+ "O setor chamado Santuário ainda não confirma "
		+ "a presença de esculturas observadas por Atlas. "

		+ "A escultura antiga conhecida anteriormente "
		+ "foi descoberta na SUPERFÍCIE do planeta, "
		+ "não no Santuário subterrâneo. "

		+ "Informações sobre acontecimentos, objetos, criaturas, "
		+ "experiências ou conteúdo interno de uma sala "
		+ "continuam desconhecidas até o gameplay "
		+ "confirmar a descoberta."
	)


	main.send_gameplay_context_event(
		"facility_map_acquired",
		"facility_map_acquired",
		description,
		true
	)


# =========================================================
# REFRESH TRACKER
# =========================================================

func refresh_room_tracker():
	var parent_node = get_parent()


	if parent_node == null:
		return


	var tracker = (
		parent_node.get_node_or_null(
			"FacilityRoomTracker"
		)
	)


	if tracker == null:
		return


	if tracker.has_method(
		"refresh_current_location_context"
	):
		tracker.refresh_current_location_context()


# =========================================================
# DESTROY UI
# =========================================================

func destroy_scan_ui():
	if (
		scan_layer != null
		and is_instance_valid(
			scan_layer
		)
	):
		scan_layer.queue_free()


	scan_layer = null

	scan_bar = null

	scan_label = null
