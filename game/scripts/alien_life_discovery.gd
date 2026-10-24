extends Area2D

const CharacterSprite := preload("res://scripts/character_sprite.gd")


# =========================================================
# CONFIGURAÇÃO
# =========================================================

@export var trigger_size: Vector2 = Vector2(
	500,
	350
)

@export var creature_position: Vector2 = Vector2(
	80,
	0
)

@export var creature_size: Vector2 = Vector2(
	90,
	55
)


# =========================================================
# ESTADO
# =========================================================

var alien_life_confirmed: bool = false

var event_running: bool = false


# =========================================================
# REFERÊNCIAS
# =========================================================

var main: Node = null

var player: CharacterBody2D = null

var atlas: CharacterBody2D = null

var creature_visual: Polygon2D = null


# =========================================================
# READY
# =========================================================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	main = get_tree().current_scene


	if main != null:
		player = main.get_node_or_null(
			"Player"
		)

		atlas = main.get_node_or_null(
			"Atlas"
		)


	create_trigger_collision()

	create_creature_placeholder()


	body_entered.connect(
		on_body_entered
	)


	print(
		"ALIEN LIFE DISCOVERY READY"
	)


# =========================================================
# COLLISION
# =========================================================

func create_trigger_collision():
	var collision = CollisionShape2D.new()

	collision.name = "DiscoveryTrigger"


	var shape = RectangleShape2D.new()

	shape.size = trigger_size


	collision.shape = shape


	add_child(
		collision
	)


# =========================================================
# PLACEHOLDER DA CRIATURA
# =========================================================

func create_creature_placeholder():
	creature_visual = Polygon2D.new()

	creature_visual.name = "AlienCreature"

	creature_visual.position = (
		creature_position
	)


	creature_visual.polygon = (
		create_creature_polygon()
	)


	creature_visual.color = Color(
		0.32,
		0.08,
		0.09,
		1.0
	)


	creature_visual.z_index = 3


	add_child(
		creature_visual
	)

	# Sprite da criatura por cima do polígono, que fica só como reserva.
	var sprite := CharacterSprite.monster(creature_visual, "idle_front", creature_size.y * 1.6)
	if sprite != null:
		creature_visual.color = Color(0, 0, 0, 0)


# =========================================================
# FORMATO TEMPORÁRIO DO BICHO
# =========================================================

func create_creature_polygon() -> PackedVector2Array:
	var half_x = creature_size.x / 2.0
	var half_y = creature_size.y / 2.0


	return PackedVector2Array([
		Vector2(
			-half_x,
			-half_y * 0.45
		),

		Vector2(
			-half_x * 0.45,
			-half_y
		),

		Vector2(
			half_x * 0.4,
			-half_y * 0.8
		),

		Vector2(
			half_x,
			0
		),

		Vector2(
			half_x * 0.35,
			half_y * 0.75
		),

		Vector2(
			-half_x * 0.45,
			half_y
		),

		Vector2(
			-half_x,
			half_y * 0.35
		)
	])


# =========================================================
# ENTRADA DO PLAYER
# =========================================================

func on_body_entered(
	body: Node
):
	if alien_life_confirmed:
		return


	if event_running:
		return


	if not is_player(
		body
	):
		return


	event_running = true


	call_deferred(
		"run_first_contact_event"
	)


# =========================================================
# IDENTIFICAR PLAYER
# =========================================================

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
# PRIMEIRO CONTACTO
# =========================================================

func run_first_contact_event():
	get_tree().paused = true


	var overlay_data = create_event_overlay()


	var overlay_layer: CanvasLayer = (
		overlay_data["layer"]
	)

	var message_label: Label = (
		overlay_data["message"]
	)


	# -----------------------------------------------------
	# ESCURECER
	# -----------------------------------------------------

	message_label.text = (
		"MOVIMENTO DETECTADO"
	)


	await get_tree().create_timer(
		1.0,
		true
	).timeout


	# -----------------------------------------------------
	# PRIMEIRO ALERTA
	# -----------------------------------------------------

	message_label.text = (
		"SINAL BIOLÓGICO NÃO IDENTIFICADO"
	)


	await get_tree().create_timer(
		1.3,
		true
	).timeout


	# -----------------------------------------------------
	# CONFIRMAÇÃO
	# -----------------------------------------------------

	message_label.text = (
		"VIDA EXTRATERRESTRE CONFIRMADA"
	)


	await get_tree().create_timer(
		1.5,
		true
	).timeout


	alien_life_confirmed = true


	# -----------------------------------------------------
	# REMOVER TELA
	# -----------------------------------------------------

	if (
		overlay_layer != null
		and is_instance_valid(
			overlay_layer
		)
	):
		overlay_layer.queue_free()


	get_tree().paused = false


	# -----------------------------------------------------
	# ATLAS REAGE
	# -----------------------------------------------------

	if (
		main != null
		and main.has_method(
			"add_chat_message"
		)
	):
		main.add_chat_message(
			"ANDROID",
			"...é vida. "
			+ "Não uma hipótese. "
			+ "Estou a detectar atividade biológica "
			+ "autónoma. Esta é uma forma de vida "
			+ "extraterrestre confirmada."
		)


	# -----------------------------------------------------
	# CONTEXTO DE GAMEPLAY
	# -----------------------------------------------------

	if (
		main != null
		and main.has_method(
			"send_gameplay_context_event"
		)
	):
		main.send_gameplay_context_event(
			"alien_life_01_confirmed",
			"alien_life_confirmed",
			"Atlas e o jogador confirmaram "
			+ "a existência de uma forma de vida "
			+ "extraterrestre na instalação subterrânea.",
			true
		)


	# -----------------------------------------------------
	# FUTURO ALIEN ENCOUNTER MANAGER
	# -----------------------------------------------------

	var encounter_manager = get_node_or_null(
		"../AlienEncounterManager"
	)


	if (
		encounter_manager != null
		and encounter_manager.has_method(
			"unlock_encounters"
		)
	):
		encounter_manager.unlock_encounters()


	print("")
	print(
		"======================================"
	)

	print(
		"ALIEN LIFE CONFIRMED"
	)

	print(
		"FIRST CONTACT EVENT COMPLETE"
	)

	print(
		"======================================"
	)


	event_running = false


# =========================================================
# CRIAR OVERLAY
# =========================================================

func create_event_overlay() -> Dictionary:
	var layer = CanvasLayer.new()

	layer.name = "AlienDiscoveryOverlay"

	layer.layer = 200

	layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		layer
	)


	var background = ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.0,
		0.0,
		0.0,
		1.0
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	layer.add_child(
		background
	)


	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	background.add_child(
		center
	)


	var message = Label.new()

	message.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	message.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	message.add_theme_font_size_override(
		"font_size",
		30
	)

	message.add_theme_color_override(
		"font_color",
		Color(
			0.9,
			0.95,
			0.95,
			1.0
		)
	)


	center.add_child(
		message
	)


	return {
		"layer": layer,
		"message": message
	}
