@tool
extends Node2D

class Phase3Interactable extends Node2D:
	var layout: Node2D
	var object_type: String = ""

	func examine() -> void:
		if is_instance_valid(layout) and layout.has_method("show_twist_dialogue"):
			layout.show_twist_dialogue(object_type)

var twist_stage: int = 0
var dialogue_layer: CanvasLayer = null
var dialogue_label: Label = null
var dialogue_button: Button = null
var dialogue_lines: Array[String] = []
var dialogue_index: int = 0
var dialogue_final_stage: int = 0
var interaction_prompt_layer: CanvasLayer = null
var interaction_prompt_label: Label = null
var phase3_exit_doors: Array[Dictionary] = []
var exit_doors_open: bool = false

# Confronto da Sala de Controlo (P3.3).
const Phase3Boss := preload("res://scripts/phase3_boss.gd")
const BossView := preload("res://scripts/phase3_boss_view.gd")
const ControlRoomArt := preload("res://scripts/control_room_art.gd")
const UIStyle := preload("res://scripts/ui_style.gd")
const CharacterFrames := preload("res://scripts/character_frames.gd")
const DepthSort := preload("res://scripts/depth_sort.gd")
var boss_done: bool = false
var boss_active: bool = false
var atlas_damaged: bool = false
var boss_ui: CanvasLayer = null
var hangar_door: Dictionary = {}

# Sala de Controlo igual à do confronto e a animação de chegada (Etapa 5).
const CONTROL_ROOM_SEEN_KEY := "phase3_control_room_seen"
const CONTROL_ROOM_WALK_TIMEOUT := 4.0
const CONTROL_ROOM_HEAT_TIME := 2.5
# Durante as falas a câmara afasta-se para mostrar a sala toda por cima da
# caixa de texto (centro um pouco abaixo do centro da sala).
const CONTROL_ROOM_CAMERA_ZOOM := 1.1
const CONTROL_ROOM_CAMERA_SHIFT := Vector2(0.0, 90.0)
const CONTROL_ROOM_LINES := [
	"ATLAS: Esta é a Sala de Controlo. A porta do Hangar está trancada e só abre a partir desta consola.",
	"ATLAS: Consigo abri-la, mas preciso de 60 segundos ligado ao sistema. Enquanto isso, não consigo fazer mais nada.",
	"SENSOR TÉRMICO: temperatura a subir junto à porta esquerda.",
	"ATLAS: Não há câmaras nesta sala, só estes sensores. A criatura é quente... e está a aproximar-se.",
	"ATLAS: Tu ficas na consola a vigiar o calor das duas portas. Quando um lado aquecer, fecha essa porta.",
	"ATLAS: Cada porta fechada gasta a energia da sala. Fecha só quando for preciso. Vou começar.",
]
var control_room_art: Node2D = null
var control_room_intro_active: bool = false
var control_room_layer: CanvasLayer = null
var control_room_label: Label = null
var control_room_button: Button = null
signal control_room_line_advanced

# Hangar e escolha final (P3.4).
const Phase3Hangar := preload("res://scripts/phase3_hangar.gd")
const EndingScreen := preload("res://scripts/ending_screen.gd")
var hangar_active: bool = false
var hangar_ui: CanvasLayer = null
var final_outcome: String = ""
var ending_screen: CanvasLayer = null

@export var room_size: Vector2 = Vector2(1000.0, 600.0)
@export var corridor_width: float = 180.0
@export var corridor_length: float = 220.0
@export var wall_width: float = 24.0
@export var room_color: Color = Color(0.12, 0.15, 0.18, 1.0)
@export var corridor_color: Color = Color(0.08, 0.10, 0.12, 1.0)
@export var wall_color: Color = Color(0.65, 0.72, 0.75, 1.0)

@export var gerar_layout_agora: bool = false:
	set(value):
		gerar_layout_agora = false
		if value and is_inside_tree():
			rebuild_layout()


func _ready() -> void:
	if not Engine.is_editor_hint():
		# A revelação já vista continua vista depois de carregar um save.
		twist_stage = int(SaveManager.get_run_value("world", "phase3_twist_stage", 0))
		boss_done = bool(SaveManager.get_run_value("story", "phase3_boss_done", false))
		atlas_damaged = bool(SaveManager.get_run_value("story", "atlas_damaged", false))
		rebuild_layout()
		call_deferred("apply_atlas_damage_visual")
		create_interaction_prompt()
		if twist_stage >= 3:
			# Repetir o facto ao carregar: o backend ignora marcos duplicados.
			call_deferred("send_distress_revealed_event")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or interaction_prompt_label == null:
		return
	if get_tree().paused:
		interaction_prompt_label.visible = false
		return

	update_phase3_exit_door()

	var player_node := get_tree().current_scene.find_child("Player", true, false)
	if player_node == null or not player_node is Node2D:
		interaction_prompt_label.visible = false
		return

	var interaction_range: float = 150.0
	if "interaction_range" in player_node:
		interaction_range = float(player_node.get("interaction_range"))

	var nearby := false
	for object in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(object) and object is Node2D:
			if player_node.global_position.distance_to(object.global_position) <= interaction_range:
				nearby = true
				break

	interaction_prompt_label.visible = nearby


func create_interaction_prompt() -> void:
	interaction_prompt_layer = CanvasLayer.new()
	interaction_prompt_layer.name = "Phase3InteractionPrompt"
	interaction_prompt_layer.layer = 739
	add_child(interaction_prompt_layer)

	interaction_prompt_label = Label.new()
	interaction_prompt_label.name = "InteractionPrompt"
	interaction_prompt_label.text = "[E] INTERAGIR"
	interaction_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt_label.position = Vector2(-100.0, -100.0)
	interaction_prompt_label.size = Vector2(200.0, 44.0)
	interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt_label.add_theme_font_size_override("font_size", 22)
	interaction_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	interaction_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	interaction_prompt_layer.add_child(interaction_prompt_label)
	interaction_prompt_label.visible = false


func rebuild_layout() -> void:
	if not is_inside_tree():
		return

	for child in get_children():
		if child.is_in_group("phase3_generated"):
			remove_child(child)
			child.free()

	var step_x: float = room_size.x + corridor_length
	var room_1_x: float = 0.0
	var room_2_x: float = step_x
	var room_3_x: float = step_x * 2.0

	create_room("Sala_1_Android", Vector2(room_1_x, 0.0), true, true, "ALA DE COMUNICAÇÕES")
	create_room("Sala_2_Criatura", Vector2(room_2_x, 0.0), true, true, "SALA DE CONTROLO", control_room_size())
	create_room("Sala_3_Nave", Vector2(room_3_x, 0.0), true, false, "HANGAR")

	create_corridor("Corredor_Android_Criatura", Vector2(room_1_x + room_size.x / 2.0 + corridor_length / 2.0, 0.0))
	create_corridor("Corredor_Criatura_Nave", Vector2(room_2_x + room_size.x / 2.0 + corridor_length / 2.0, 0.0))

	# Criar os objetos narrativos interativos da Sala 1.
	create_phase3_story_objects()
	phase3_exit_doors.clear()
	# Portas nas duas extremidades do corredor entre o Android e a Criatura.
	create_phase3_exit_door("Porta_Saida_Android", Vector2(room_size.x / 2.0, 0.0))
	create_phase3_exit_door("Porta_Entrada_Criatura", Vector2(step_x - room_size.x / 2.0, 0.0))
	create_boss_trigger(Vector2(room_2_x, 0.0))
	create_hangar_door(Vector2(room_2_x + room_size.x / 2.0, 0.0))
	create_control_room(Vector2(room_2_x, 0.0))
	create_explorer_ship(Vector2(room_3_x + 250.0, 0.0))
	create_hangar_trigger(Vector2(room_3_x - 150.0, 0.0))

	# Limites invisiveis exteriores da Fase 3.
	var left_edge: float = -room_size.x / 2.0
	var right_edge: float = room_3_x + room_size.x / 2.0
	var top_edge: float = -room_size.y / 2.0
	var bottom_edge: float = room_size.y / 2.0
	var thickness: float = 40.0
	var middle_x: float = (left_edge + right_edge) / 2.0
	var total_width: float = right_edge - left_edge + thickness

	create_invisible_wall("Limite_Superior", Vector2(middle_x, top_edge - thickness / 2.0), Vector2(total_width, thickness))
	create_invisible_wall("Limite_Inferior", Vector2(middle_x, bottom_edge + thickness / 2.0), Vector2(total_width, thickness))
	create_invisible_wall("Limite_Esquerdo", Vector2(left_edge - thickness / 2.0, 0.0), Vector2(thickness, room_size.y + thickness * 2.0))
	create_invisible_wall("Limite_Direito", Vector2(right_edge + thickness / 2.0, 0.0), Vector2(thickness, room_size.y + thickness * 2.0))

	print("PHASE 3: salas, corredores, estruturas e limites invisiveis criados.")


func create_room(room_name: String, center: Vector2, opening_left: bool, opening_right: bool, label_text: String, size: Vector2 = Vector2.ZERO) -> void:
	if size == Vector2.ZERO:
		size = room_size
	var room := Node2D.new()
	room.name = room_name
	room.position = center
	room.add_to_group("phase3_generated")
	add_child(room)

	@warning_ignore("shadowed_global_identifier")
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = rectangle(size)
	floor.color = room_color
	floor.z_index = -2
	room.add_child(floor)

	# Sem título visível no chão; o nome fica guardado na sala.
	room.set_meta("display_name", label_text)

	var wall_body := StaticBody2D.new()
	wall_body.name = "WallCollision"
	room.add_child(wall_body)

	var half_x: float = size.x / 2.0
	var half_y: float = size.y / 2.0
	# A abertura fica ligeiramente maior que o corredor para evitar colisao nas bordas.
	var opening_half: float = (corridor_width + wall_width * 2.0) / 2.0
	var side_length: float = half_y - opening_half

	create_wall(wall_body, Vector2(0.0, -half_y), Vector2(size.x, wall_width))
	create_wall(wall_body, Vector2(0.0, half_y), Vector2(size.x, wall_width))

	if opening_left:
		create_wall(wall_body, Vector2(-half_x, -(opening_half + side_length / 2.0)), Vector2(wall_width, side_length))
		create_wall(wall_body, Vector2(-half_x, opening_half + side_length / 2.0), Vector2(wall_width, side_length))
	else:
		create_wall(wall_body, Vector2(-half_x, 0.0), Vector2(wall_width, size.y))

	if opening_right:
		create_wall(wall_body, Vector2(half_x, -(opening_half + side_length / 2.0)), Vector2(wall_width, side_length))
		create_wall(wall_body, Vector2(half_x, opening_half + side_length / 2.0), Vector2(wall_width, side_length))
	else:
		create_wall(wall_body, Vector2(half_x, 0.0), Vector2(wall_width, size.y))


func create_corridor(corridor_name: String, center: Vector2) -> void:
	var corridor := Node2D.new()
	corridor.name = corridor_name
	corridor.position = center
	corridor.add_to_group("phase3_generated")
	add_child(corridor)

	@warning_ignore("shadowed_global_identifier")
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = rectangle(Vector2(corridor_length, corridor_width))
	floor.color = corridor_color
	floor.z_index = -1
	corridor.add_child(floor)

	# Paredes físicas e visuais ao longo dos dois lados do corredor.
	var walls := StaticBody2D.new()
	walls.name = "CorridorWalls"
	corridor.add_child(walls)
	for side in [-1.0, 1.0]:
		var wall_size := Vector2(corridor_length, wall_width)
		var wall_center := Vector2(0.0, side * (corridor_width / 2.0 + wall_width / 2.0))
		create_wall(walls, wall_center, wall_size)

func create_wall(parent: Node2D, center: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	parent.add_child(collision)

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = rectangle(size)
	visual.position = center
	visual.color = wall_color
	visual.z_index = 1
	parent.add_child(visual)


func create_invisible_wall(wall_name: String, center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = center
	wall.add_to_group("phase3_generated")

	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)


func create_phase3_exit_door(door_name: String, center: Vector2) -> void:
	var door := StaticBody2D.new()
	door.name = door_name
	door.position = center
	door.add_to_group("phase3_generated")
	add_child(door)

	var door_size := Vector2(wall_width + 8.0, corridor_width + wall_width * 2.0 + 12.0)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = rectangle(door_size)
	visual.color = wall_color
	# Porta numa parede lateral: desenhada como as paredes, por baixo das
	# personagens (antes ficava por cima delas, z 5).
	visual.z_index = 1
	door.add_child(visual)

	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = door_size
	collision.shape = shape
	door.add_child(collision)
	phase3_exit_doors.append({"body": door, "visual": visual, "collision": collision, "player_passed": false, "atlas_passed": false})
	print("PHASE 3: porta criada: ", door_name)


func update_phase3_exit_door() -> void:
	if phase3_exit_doors.is_empty():
		return

	# Ambas as portas abrem depois da revelação narrativa.
	if not exit_doors_open and twist_stage >= 3:
		exit_doors_open = true
		for door_data in phase3_exit_doors:
			door_data["collision"].set_deferred("disabled", true)
			door_data["visual"].visible = false
		print("PHASE 3: portas abertas após a descoberta.")

	if not exit_doors_open:
		return

	var player_node := get_tree().current_scene.find_child("Player", true, false)
	var atlas_node := get_tree().current_scene.find_child("Atlas", true, false)
	if not player_node is Node2D or not atlas_node is Node2D:
		return

	for door_data in phase3_exit_doors:
		var door: StaticBody2D = door_data["body"]
		var threshold_x: float = door.global_position.x + 100.0
		if player_node.global_position.x > threshold_x:
			door_data["player_passed"] = true
		if atlas_node.global_position.x > threshold_x:
			door_data["atlas_passed"] = true

		# Cada porta fecha apenas depois de ambos atravessarem.
		if door_data["player_passed"] and door_data["atlas_passed"] and not door_data["visual"].visible:
			door_data["visual"].visible = true
			door_data["collision"].set_deferred("disabled", false)
			print("PHASE 3: Player e Atlas passaram; porta fechada: ", door.name)

func rectangle(size: Vector2) -> PackedVector2Array:
	var half: Vector2 = size / 2.0
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])


func create_phase3_story_objects() -> void:
	# Objetos provisórios sem sprites: serão substituídos pela arte final depois.
	# Terminal onde ficou gravado o pedido de socorro (não é a nave do Hangar).
	var terminal := Phase3Interactable.new()
	terminal.name = "Terminal_Comunicacoes"
	terminal.add_to_group("phase3_generated")
	terminal.position = Vector2(-220.0, 80.0)
	terminal.object_type = "terminal"
	terminal.layout = self
	terminal.add_to_group("interactable")
	add_child(terminal)

	var terminal_visual := Polygon2D.new()
	terminal_visual.name = "PlaceholderVisual"
	terminal_visual.polygon = rectangle(Vector2(150.0, 90.0))
	terminal_visual.color = Color(0.22, 0.34, 0.42, 1.0)
	terminal.add_child(terminal_visual)

	var terminal_label := Label.new()
	terminal_label.text = "TERMINAL DE COMUNICAÇÕES"
	terminal_label.position = Vector2(-140.0, 50.0)
	terminal_label.size = Vector2(280.0, 30.0)
	terminal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(terminal_label)
	# O terminal é ordenado pela base (depth_sort.gd); o nome fica por cima.
	DepthSort.register(terminal)
	DepthSort.set_label(terminal_label)
	# Sólido, para o Player e o Atlas andarem à volta dele.
	terminal.add_child(make_solid(Vector2(150.0, 90.0)))

	var android := Phase3Interactable.new()
	android.name = "Android_Danificado"
	android.add_to_group("phase3_generated")
	android.position = Vector2(220.0, 100.0)
	android.object_type = "android"
	android.layout = self
	android.add_to_group("interactable")
	add_child(android)

	var android_body := Polygon2D.new()
	android_body.name = "PlaceholderVisual"
	android_body.polygon = PackedVector2Array([
		Vector2(-28.0, -12.0), Vector2(28.0, -12.0),
		Vector2(35.0, 55.0), Vector2(18.0, 72.0),
		Vector2(-18.0, 72.0), Vector2(-35.0, 55.0)
	])
	android_body.color = Color(0.38, 0.42, 0.45, 1.0)
	android.add_child(android_body)

	var android_head := Polygon2D.new()
	android_head.name = "HeadPlaceholder"
	android_head.polygon = PackedVector2Array([
		Vector2(-24.0, -50.0), Vector2(24.0, -50.0),
		Vector2(28.0, -20.0), Vector2(15.0, -8.0),
		Vector2(-15.0, -8.0), Vector2(-28.0, -20.0)
	])
	android_head.color = Color(0.48, 0.54, 0.58, 1.0)
	android.add_child(android_head)

	# O outro androide usa o sprite do Atlas, caído e mais escuro.
	var android_texture := CharacterFrames.first_texture("atlas", "idle_front")
	if android_texture != null:
		android_body.visible = false
		android_head.visible = false
		var android_sprite := Sprite2D.new()
		android_sprite.name = "AndroidSprite"
		android_sprite.texture = android_texture
		android_sprite.scale = Vector2(0.8, 0.8)
		android_sprite.rotation_degrees = -78.0
		android_sprite.position = Vector2(0.0, 40.0)
		android_sprite.modulate = Color(0.55, 0.5, 0.48)
		android.add_child(android_sprite)

	var android_label := Label.new()
	android_label.text = "UNIDADE DANIFICADA"
	android_label.position = Vector2(-110.0, 80.0)
	android_label.size = Vector2(220.0, 30.0)
	android_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	android.add_child(android_label)
	DepthSort.register(android)
	DepthSort.set_label(android_label)
	# O corpo caído no chão é sólido.
	android.add_child(make_solid(Vector2(110.0, 50.0), Vector2(0.0, 40.0)))


# Corpo estático retangular ("Solid"), como os da decoração.
func make_solid(size: Vector2, offset: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid"
	body.position = offset
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func show_twist_dialogue(object_type: String) -> void:
	if dialogue_layer != null and is_instance_valid(dialogue_layer):
		return

	dialogue_lines.clear()
	dialogue_index = 0
	dialogue_final_stage = twist_stage

	if object_type == "terminal":
		if twist_stage == 0:
			dialogue_lines = [
				"ATLAS: Este registo ficou preservado na memória do terminal.",
				"REGISTO: A alteração de rota não foi provocada por uma falha de navegação.",
				"ATLAS: Recebi um pedido de socorro. Alguém transmitiu um sinal deliberado... e eu respondi."
			]
			dialogue_final_stage = 1
		elif twist_stage >= 2 and twist_stage < 3:
			dialogue_lines = [
				"ATLAS: O sinal veio desta unidade. Não era um pedido automático.",
				"REGISTO RECUPERADO: Um humano e uma unidade androide foram detetados juntos nesta instalação.",
				"ATLAS: Foram capturados. A criatura que encontrámos era o humano. O outro androide foi deixado para trás.",
				"ATLAS: Não foi um erro na minha rota. Foi alguém como eu a pedir ajuda."
			]
			dialogue_final_stage = 3
		else:
			dialogue_lines = ["Os registos do terminal já foram analisados. Não há mais dados recuperáveis."]
	else:
		if twist_stage == 0:
			dialogue_lines = ["ATLAS: Devo analisar primeiro o terminal de comunicações. O sinal pode ter ficado guardado lá."]
		elif twist_stage == 1:
			dialogue_lines = [
				"ATLAS: A unidade está danificada, mas o emissor de socorro é compatível com a sua arquitetura.",
				"REGISTO PARCIAL: ...preciso de ajuda... há um humano comigo...", 
				"ATLAS: Este androide pediu ajuda. Não foi uma transmissão automática."
			]
			dialogue_final_stage = 2
		else:
			dialogue_lines = ["O androide está inativo. Já recuperámos os dados essenciais da sua transmissão."]

	create_twist_dialogue_ui()
	update_twist_dialogue()


func create_twist_dialogue_ui() -> void:
	# Esconde a indicacao [E] enquanto a cutscene estiver aberta.
	if is_instance_valid(interaction_prompt_label):
		interaction_prompt_label.visible = false

	dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "Phase3TwistDialogue"
	dialogue_layer.layer = 1000
	dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(dialogue_layer)

	# Ecrã preto integral, semelhante à abertura do jogo.
	var background := ColorRect.new()
	background.name = "BlackBackground"
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(background)

	var content := VBoxContainer.new()
	content.name = "DialogueContent"
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-450.0, -190.0)
	content.size = Vector2(900.0, 380.0)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 32)
	background.add_child(content)

	var title := Label.new()
	title.name = "EmergencyTitle"
	title.text = "SISTEMA DE EMERGÊNCIA"
	title.custom_minimum_size = Vector2(900.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#b8e5ff"))
	content.add_child(title)

	dialogue_label = Label.new()
	dialogue_label.name = "DialogueText"
	dialogue_label.custom_minimum_size = Vector2(900.0, 130.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 23)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(dialogue_label)

	dialogue_button = Button.new()
	dialogue_button.name = "ContinueButton"
	dialogue_button.text = "CONTINUAR"
	dialogue_button.custom_minimum_size = Vector2(260.0, 48.0)
	dialogue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialogue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_button.pressed.connect(_on_twist_dialogue_button_pressed)
	content.add_child(dialogue_button)

	# Bíblia 4.5: não se grava durante cutscenes.
	SaveManager.set_manual_save_block("cutscene", true)
	get_tree().paused = true

func update_twist_dialogue() -> void:
	if dialogue_label == null or dialogue_button == null:
		return
	dialogue_label.text = dialogue_lines[dialogue_index]
	dialogue_button.text = "CONTINUAR" if dialogue_index < dialogue_lines.size() - 1 else "FECHAR"


func _on_twist_dialogue_button_pressed() -> void:
	if dialogue_index < dialogue_lines.size() - 1:
		dialogue_index += 1
		update_twist_dialogue()
		return

	var previous_stage := twist_stage
	twist_stage = max(twist_stage, dialogue_final_stage)
	SaveManager.set_run_value("world", "phase3_twist_stage", twist_stage)
	if dialogue_layer != null and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()
	dialogue_layer = null
	dialogue_label = null
	dialogue_button = null
	SaveManager.set_manual_save_block("cutscene", false)
	get_tree().paused = false
	# O prompt volta a ser atualizado pelo _process quando o jogo retomar.

	if previous_stage < 3 and twist_stage >= 3:
		send_distress_revealed_event()
		var main := get_tree().current_scene
		if main != null and main.has_method("request_atlas_spontaneous"):
			main.request_atlas_spontaneous("phase3_distress_revealed")


# A revelação completa é um facto confirmado pelo jogo: leva o Atlas
# ao estágio narrativo 7 ("algo_mais"). O Atlas só a conhece a partir daqui.
func send_distress_revealed_event() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("send_gameplay_context_event"):
		return
	main.send_gameplay_context_event(
		"phase3_distress_revealed",
		"discovery",
		"Os registos confirmaram que o desvio da Nave 47 foi a resposta de Atlas a um pedido de socorro de outro androide, capturado nesta instalação com um humano. A criatura era esse humano."
	)


# =========================================================
# CONFRONTO DA SALA DE CONTROLO (estilo FNAF)
# =========================================================

func create_boss_trigger(center: Vector2) -> void:
	var trigger := Area2D.new()
	trigger.name = "ConfrontoSalaControlo"
	trigger.position = center
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.add_to_group("phase3_generated")
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 220.0
	shape_node.shape = shape
	trigger.add_child(shape_node)
	add_child(trigger)
	trigger.body_entered.connect(_on_boss_trigger_entered)


# Porta do Hangar: só abre quando o Atlas termina de a abrir durante o confronto.
func create_hangar_door(center: Vector2) -> void:
	var door := StaticBody2D.new()
	door.name = "Porta_Hangar"
	door.position = center
	door.add_to_group("phase3_generated")
	add_child(door)
	var door_size := Vector2(wall_width + 8.0, corridor_width + wall_width * 2.0 + 12.0)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = rectangle(door_size)
	visual.color = Color(0.55, 0.32, 0.22, 1.0)
	# Porta numa parede lateral: desenhada como as paredes, por baixo das
	# personagens (antes ficava por cima delas, z 5).
	visual.z_index = 1
	door.add_child(visual)
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = door_size
	collision.shape = shape
	door.add_child(collision)
	hangar_door = {"body": door, "visual": visual, "collision": collision}
	set_hangar_door_open(boss_done)


func set_hangar_door_open(open: bool) -> void:
	if hangar_door.is_empty():
		return
	hangar_door["visual"].visible = not open
	hangar_door["collision"].set_deferred("disabled", open)


func _on_boss_trigger_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	enter_control_room()


# =========================================================
# SALA DE CONTROLO: IGUAL À DO CONFRONTO + ANIMAÇÃO DE CHEGADA
# =========================================================

# A sala tem a proporção da planta do confronto (600 x 272): mesma largura
# das outras salas, menos alta.
func control_room_size() -> Vector2:
	return BossView.room_size_for(room_size.x)


func create_control_room(center: Vector2) -> void:
	var art := ControlRoomArt.new()
	art.layout = self
	art.room_size = control_room_size()
	art.corridor_size = Vector2(corridor_length, corridor_width)
	art.position = center
	art.add_to_group("phase3_generated")
	add_child(art)
	control_room_art = art
	if boss_done:
		art.awake = 1.0
		art.hangar_progress = 1.0

	# A consola é sólida, como os terminais.
	var desk: Rect2 = art.console_rect()
	var console := Node2D.new()
	console.name = "Consola_Controlo"
	console.position = center + desk.get_center()
	console.add_to_group("phase3_generated")
	add_child(console)
	# A colisão tem de estar dentro de um StaticBody2D: pendurada num
	# Node2D (como estava) não bloqueava nada e atravessava-se a consola.
	console.add_child(make_solid(desk.size))

	# As portas da sala ganham as riscas das portas do confronto.
	var door_visuals: Array = []
	for door in phase3_exit_doors:
		if String(door["body"].name) == "Porta_Entrada_Criatura":
			door_visuals.append(door["visual"])
	if not hangar_door.is_empty():
		door_visuals.append(hangar_door["visual"])
	for visual in door_visuals:
		var bounds := Rect2(visual.polygon[0], visual.polygon[2] - visual.polygon[0])
		visual.add_child(ControlRoomArt.make_door_stripes(bounds.size))


# Na primeira vez, o Player e o Atlas vão até à consola e percebem o que
# têm de fazer; só depois aparecem as instruções do confronto. Depois de
# vista (fica na run), entrar outra vez vai direto ao confronto.
func enter_control_room() -> void:
	if boss_done or boss_active or control_room_intro_active or twist_stage < 3:
		return
	if bool(SaveManager.get_run_value("story", CONTROL_ROOM_SEEN_KEY, false)) or control_room_art == null:
		start_boss()
		return
	await play_control_room_intro()
	if is_inside_tree():
		start_boss()


func play_control_room_intro() -> void:
	control_room_intro_active = true
	SaveManager.set_manual_save_block("cutscene", true)
	var main := get_tree().current_scene
	var player: Node2D = main.find_child("Player", true, false)
	var atlas: Node2D = main.find_child("Atlas", true, false)
	var art: Node2D = control_room_art

	# 1. Vão até aos lugares que têm no confronto, à frente da consola.
	await walk_to_console(player, atlas)
	face(player, "back")
	face(atlas, "back")

	# 2. A câmara mostra a sala toda e a consola liga-se.
	var camera: Camera2D = player.get_node_or_null("Camera2D") if player != null else null
	var camera_zoom := camera.zoom if camera != null else Vector2.ONE
	if camera != null:
		var frame := create_tween().set_parallel()
		frame.tween_property(camera, "offset", art.global_position + CONTROL_ROOM_CAMERA_SHIFT - player.global_position, 0.8)
		frame.tween_property(camera, "zoom", Vector2.ONE * CONTROL_ROOM_CAMERA_ZOOM, 0.8)
	var wake := create_tween()
	wake.tween_property(art, "awake", 1.0, 0.8)
	create_control_room_dialogue()
	await show_control_room_line(0)
	await show_control_room_line(1)

	# 3. O sensor da porta por onde entraram começa a aquecer.
	var warm := create_tween()
	warm.tween_method(func(value: float): art.heat["left"] = value, 0.0, 0.62, CONTROL_ROOM_HEAT_TIME)
	face(player, "side", true)
	await show_control_room_line(2)
	face(atlas, "side", true)
	await show_control_room_line(3)

	# 4. O Atlas liga-se à consola; o Player fica a vigiar.
	face(player, "back")
	face(atlas, "back")
	art.beam_from = atlas
	await show_control_room_line(4)
	await show_control_room_line(5)

	destroy_control_room_dialogue()
	if camera != null and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
		camera.zoom = camera_zoom
	SaveManager.set_run_value("story", CONTROL_ROOM_SEEN_KEY, true)
	SaveManager.set_manual_save_block("cutscene", false)
	if player != null and player.has_method("set_tutorial_locked"):
		player.set_tutorial_locked(false)
	control_room_intro_active = false


func walk_to_console(player: Node2D, atlas: Node2D) -> void:
	var art: Node2D = control_room_art
	var player_target: Vector2 = art.to_global(art.player_spot())
	var atlas_target: Vector2 = art.to_global(art.atlas_spot())
	if player != null and player.has_method("start_scripted_move_to"):
		player.start_scripted_move_to(player_target)
	if atlas != null and atlas.has_method("start_scripted_move_to"):
		atlas.start_scripted_move_to(atlas_target)
	var waited := 0.0
	while waited < CONTROL_ROOM_WALK_TIMEOUT:
		var player_there: bool = player == null or player.global_position.distance_to(player_target) <= 6.0
		var atlas_there: bool = atlas == null or atlas.global_position.distance_to(atlas_target) <= 6.0
		if player_there and atlas_there:
			break
		await get_tree().physics_frame
		if not get_tree().paused:
			waited += get_physics_process_delta_time()
	if atlas != null and atlas.has_method("stop_scripted_move_to"):
		atlas.stop_scripted_move_to()
	if player != null:
		if player.has_method("stop_scripted_move_to"):
			player.stop_scripted_move_to()
		if player.has_method("set_tutorial_locked"):
			player.set_tutorial_locked(true)


# Vira o sprite parado de uma personagem (frente, costas ou lado).
func face(body: Node2D, facing: String, left: bool = false) -> void:
	if body == null:
		return
	var sprite := body.get_node_or_null("CharacterSprite")
	if sprite == null or not "facing" in sprite:
		return
	sprite.facing = facing
	# Versões mais antigas do character_sprite.gd não têm estes dois.
	if "facing_left" in sprite:
		sprite.facing_left = left
	if "facing_time" in sprite:
		sprite.facing_time = 0.0


func show_control_room_line(index: int) -> void:
	if control_room_label == null:
		return
	control_room_label.text = CONTROL_ROOM_LINES[index]
	control_room_button.text = "CONTINUAR  [E]" if index < CONTROL_ROOM_LINES.size() - 1 else "COMEÇAR  [E]"
	await control_room_line_advanced


# Também usado pelos testes.
func advance_control_room_line() -> void:
	if control_room_intro_active and control_room_layer != null:
		control_room_line_advanced.emit()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or control_room_layer == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			advance_control_room_line()


# Caixa de falas em baixo: a sala continua à vista.
func create_control_room_dialogue() -> void:
	if is_instance_valid(interaction_prompt_label):
		interaction_prompt_label.visible = false
	control_room_layer = CanvasLayer.new()
	control_room_layer.name = "ControlRoomDialogue"
	control_room_layer.layer = 1000
	get_tree().current_scene.add_child(control_room_layer)

	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -470.0
	panel.offset_right = 470.0
	panel.offset_top = -190.0
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel", UIStyle._box(Color(UIStyle.PANEL_BG, 1.0), UIStyle.ACCENT, 2, 6, 24.0, 16.0))
	UIStyle.apply(panel)
	control_room_layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	control_room_label = Label.new()
	control_room_label.name = "DialogueText"
	control_room_label.custom_minimum_size = Vector2(880.0, 80.0)
	control_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_room_label.add_theme_font_size_override("font_size", 22)
	control_room_label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(control_room_label)

	control_room_button = Button.new()
	control_room_button.name = "ContinueButton"
	control_room_button.custom_minimum_size = Vector2(240.0, 42.0)
	control_room_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	control_room_button.focus_mode = Control.FOCUS_NONE
	control_room_button.pressed.connect(advance_control_room_line)
	box.add_child(control_room_button)


func destroy_control_room_dialogue() -> void:
	if control_room_layer != null and is_instance_valid(control_room_layer):
		control_room_layer.queue_free()
	control_room_layer = null
	control_room_label = null
	control_room_button = null


func start_boss(boss_seed: int = 0) -> void:
	if boss_done or boss_active or twist_stage < 3:
		return
	boss_active = true
	SaveManager.set_manual_save_block("confronto", true)
	var player := get_tree().current_scene.find_child("Player", true, false)
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	# Autosave antes do confronto: sair do jogo a meio volta a este ponto.
	await SaveManager.autosave_when_safe("phase3_boss_start")
	if not is_inside_tree():
		return

	boss_ui = Phase3Boss.new()
	boss_ui.name = "Phase3BossUI"
	get_tree().current_scene.add_child(boss_ui)
	boss_ui.finished.connect(_on_boss_finished)
	get_tree().paused = true
	boss_ui.open_briefing(boss_seed)


func _on_boss_finished(damaged: bool, stats: Dictionary) -> void:
	# Deixar o Player ler a última fala do Atlas antes de fechar a consola.
	await get_tree().create_timer(2.5, true, false, true).timeout
	boss_done = true
	atlas_damaged = damaged
	SaveManager.set_run_value("story", "phase3_boss_done", true)
	SaveManager.set_run_value("story", "atlas_damaged", damaged)
	SaveManager.set_run_value("story", "phase3_boss_stats", stats)
	if is_instance_valid(boss_ui):
		boss_ui.queue_free()
	boss_ui = null
	boss_active = false
	SaveManager.set_manual_save_block("confronto", false)
	get_tree().paused = false
	set_hangar_door_open(true)
	apply_atlas_damage_visual()
	if control_room_art != null and is_instance_valid(control_room_art):
		control_room_art.awake = 1.0
		control_room_art.hangar_progress = 1.0
		control_room_art.heat = {"left": 0.0, "right": 0.0}
		control_room_art.beam_from = null

	var main := get_tree().current_scene
	if main != null and main.has_method("send_gameplay_context_event"):
		main.send_gameplay_context_event(
			"phase3_boss_survived",
			"event",
			(
				"Atlas e o jogador sobreviveram ao confronto na Sala de Controlo. "
				+ (
					"A criatura entrou e o Atlas ficou danificado ao proteger o jogador."
					if damaged
					else "A criatura nunca chegou a entrar e o Atlas saiu inteiro."
				)
			)
		)
	SaveManager.autosave_when_safe("phase3_boss_completed")


# Sem sprites: o Atlas danificado fica mais escuro e avermelhado.
func apply_atlas_damage_visual() -> void:
	if not atlas_damaged or not is_inside_tree():
		return
	var atlas_node := get_tree().current_scene.find_child("Atlas", true, false)
	if atlas_node is CanvasItem:
		atlas_node.modulate = Color(0.85, 0.45, 0.4, 1.0)


# =========================================================
# HANGAR: NAVE DO EXPLORADOR E ESCOLHA FINAL
# =========================================================

func create_explorer_ship(center: Vector2) -> void:
	var ship := Node2D.new()
	ship.name = "Nave_Explorador"
	ship.position = center
	ship.add_to_group("phase3_generated")
	add_child(ship)
	var hull := Polygon2D.new()
	hull.name = "PlaceholderVisual"
	hull.polygon = PackedVector2Array([
		Vector2(-170.0, -70.0), Vector2(90.0, -70.0), Vector2(190.0, 0.0),
		Vector2(90.0, 70.0), Vector2(-170.0, 70.0), Vector2(-120.0, 0.0)
	])
	hull.color = Color(0.30, 0.36, 0.40, 1.0)
	ship.add_child(hull)
	var label := Label.new()
	label.text = "NAVE DO EXPLORADOR"
	label.position = Vector2(-120.0, 80.0)
	label.size = Vector2(240.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship.add_child(label)
	DepthSort.register(ship, 75.0)
	DepthSort.set_label(label)


func create_hangar_trigger(center: Vector2) -> void:
	var trigger := Area2D.new()
	trigger.name = "EntradaHangar"
	trigger.position = center
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.add_to_group("phase3_generated")
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 200.0
	shape_node.shape = shape
	trigger.add_child(shape_node)
	add_child(trigger)
	trigger.body_entered.connect(_on_hangar_trigger_entered)


func _on_hangar_trigger_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	start_hangar()


func start_hangar() -> void:
	if not boss_done or hangar_active or not final_outcome.is_empty():
		return
	hangar_active = true
	# A partir daqui a run caminha para o final: não há mais saves.
	SaveManager.set_manual_save_block("final", true)
	var main := get_tree().current_scene
	var player_node := main.find_child("Player", true, false)
	var atlas_node := main.find_child("Atlas", true, false)
	if player_node is CharacterBody2D:
		player_node.velocity = Vector2.ZERO
	var room_3_x := (room_size.x + corridor_length) * 2.0
	if atlas_damaged and atlas_node is Node2D:
		# O Atlas danificado fica caído à entrada do Hangar.
		atlas_node.global_position = global_position + Vector2(room_3_x - 400.0, 140.0)
		atlas_node.rotation = deg_to_rad(80.0)

	var vida := 100
	var fight_manager := main.get_node_or_null("FightManager")
	if fight_manager != null and fight_manager.has_method("get_shared_life"):
		vida = int(fight_manager.get_shared_life())

	hangar_ui = Phase3Hangar.new()
	hangar_ui.name = "Phase3HangarUI"
	hangar_ui.atlas_damaged = atlas_damaged
	hangar_ui.vida = vida
	hangar_ui.player = player_node
	hangar_ui.atlas = atlas_node
	hangar_ui.ship_position = global_position + Vector2(room_3_x + 150.0, 0.0)
	main.add_child(hangar_ui)
	hangar_ui.outcome_chosen.connect(_on_final_outcome_chosen)
	get_tree().paused = true
	hangar_ui.start()


func _on_final_outcome_chosen(outcome: String, facts: Dictionary) -> void:
	final_outcome = outcome
	SaveManager.set_run_value("story", "final_outcome", outcome)
	SaveManager.set_run_value("story", "final_choice", str(facts.get("choice", "")))
	SaveManager.set_run_value("story", "final_vida", int(facts.get("vida", 0)))
	print("PHASE 3 FINAL OUTCOME: ", facts)
	if is_instance_valid(hangar_ui):
		hangar_ui.queue_free()
	hangar_ui = null
	# P3.6: o ecrã do final pede ao backend a variante do Atlas e as falas.
	ending_screen = EndingScreen.new()
	ending_screen.name = "EndingScreen"
	get_tree().current_scene.add_child(ending_screen)
	ending_screen.start(facts)
