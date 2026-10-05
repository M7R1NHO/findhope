extends Node


# =========================================================
# SINAIS
# =========================================================

signal fight_won(atlas_hp)
signal atlas_destroyed


# =========================================================
# CONFIGURAÇÃO
# =========================================================

@export var atlas_max_hp: int = 100
@export var creature_max_hp: int = 70

@export var energy_per_turn: int = 3
@export var cards_per_turn: int = 4


# =========================================================
# CARTAS
# =========================================================

const CARD_PULSE := "pulse"
const CARD_FOCUSED := "focused"
const CARD_BARRIER := "barrier"
const CARD_COUNTER := "counter"
const CARD_OVERLOAD := "overload"
const CARD_REPAIR := "repair"


const CARD_DATA := {

	CARD_PULSE: {
		"name": "DISPARO DE PULSO",
		"cost": 1,
		"damage": 9,
		"block": 0,
		"heal": 0,
		"self_damage": 0,
		"description": "9 DANO"
	},


	CARD_FOCUSED: {
		"name": "RAJADA CONCENTRADA",
		"cost": 2,
		"damage": 20,
		"block": 0,
		"heal": 0,
		"self_damage": 0,
		"description": "20 DANO"
	},


	CARD_BARRIER: {
		"name": "BARREIRA CINÉTICA",
		"cost": 1,
		"damage": 0,
		"block": 12,
		"heal": 0,
		"self_damage": 0,
		"description": "+12 DEFESA"
	},


	CARD_COUNTER: {
		"name": "CONTRA-ATAQUE",
		"cost": 2,
		"damage": 10,
		"block": 8,
		"heal": 0,
		"self_damage": 0,
		"description": "10 DANO | +8 DEFESA"
	},


	CARD_OVERLOAD: {
		"name": "SOBRECARGA",
		"cost": 3,
		"damage": 32,
		"block": 0,
		"heal": 0,
		"self_damage": 6,
		"description": "32 DANO | ATLAS -6 HP"
	},


	CARD_REPAIR: {
		"name": "REPARO DE CAMPO",
		"cost": 2,
		"damage": 0,
		"block": 0,
		"heal": 9,
		"self_damage": 0,
		"description": "ATLAS +9 HP"
	}
}


const CARD_IDS := [
	CARD_PULSE,
	CARD_FOCUSED,
	CARD_BARRIER,
	CARD_COUNTER,
	CARD_OVERLOAD,
	CARD_REPAIR
]


# =========================================================
# ESTADO PERSISTENTE
# =========================================================

var atlas_hp: int = 100


# =========================================================
# ESTADO DO COMBATE
# =========================================================

var rng := RandomNumberGenerator.new()

var fight_active: bool = false
var turn_locked: bool = false

var creature_hp: int = 0

var current_energy: int = 0
var current_block: int = 0

var turn_number: int = 1

var enemy_intent_name: String = ""
var enemy_intent_damage: int = 0


# =========================================================
# UI
# =========================================================

var fight_layer: CanvasLayer = null

var atlas_hp_bar: ProgressBar = null
var creature_hp_bar: ProgressBar = null

var atlas_hp_label: Label = null
var creature_hp_label: Label = null

var energy_label: Label = null
var block_label: Label = null

var intent_label: Label = null
var turn_label: Label = null
var combat_log: Label = null

var cards_container: GridContainer = null

var end_turn_button: Button = null


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = Node.PROCESS_MODE_ALWAYS


	rng.randomize()


	atlas_hp = atlas_max_hp


	print(
		"FIGHT MANAGER READY | ATLAS HP: ",
		atlas_hp
	)


# =========================================================
# COMEÇAR COMBATE
# =========================================================

func start_fight():

	if fight_active:
		return


	fight_active = true

	turn_locked = false


	creature_hp = (
		creature_max_hp
	)


	current_energy = 0

	current_block = 0


	turn_number = 1


	get_tree().paused = true


	create_fight_ui()


	start_player_turn()


	print("")
	print(
		"======================================"
	)

	print(
		"FIGHT STARTED"
	)

	print(
		"ATLAS HP: ",
		atlas_hp,
		" / ",
		atlas_max_hp
	)

	print(
		"CREATURE HP: ",
		creature_hp
	)

	print(
		"======================================"
	)


# =========================================================
# COMEÇAR TURNO DO PLAYER
# =========================================================

func start_player_turn():

	if not fight_active:
		return


	# =====================================================
	# DESBLOQUEAR NOVO TURNO
	# =====================================================

	turn_locked = false


	current_energy = (
		energy_per_turn
	)


	current_block = 0


	# =====================================================
	# IMPORTANTE
	#
	# O botão era desativado no final do turno anterior,
	# mas não estava sendo reativado.
	# =====================================================

	if end_turn_button != null:

		end_turn_button.disabled = false


	choose_enemy_intent()


	draw_cards()


	update_ui()


	if combat_log != null:

		combat_log.text = (
			"Escolha os modos de ataque do Atlas."
		)


	print(
		"PLAYER TURN STARTED: ",
		turn_number
	)


# =========================================================
# INTENÇÃO DA CRIATURA
# =========================================================

func choose_enemy_intent():

	var intents := [

		{
			"name": "MORDIDA",
			"damage": 10
		},

		{
			"name": "INVESTIDA",
			"damage": 16
		},

		{
			"name": "ATAQUE BRUTAL",
			"damage": 20
		},

		{
			"name": "CIRCUNDAR",
			"damage": 0
		}
	]


	var intent: Dictionary = (
		intents[
			rng.randi_range(
				0,
				intents.size() - 1
			)
		]
	)


	enemy_intent_name = str(
		intent[
			"name"
		]
	)


	enemy_intent_damage = int(
		intent[
			"damage"
		]
	)


# =========================================================
# COMPRAR CARTAS
# =========================================================

func draw_cards():

	clear_cards()


	var pool = (
		CARD_IDS.duplicate()
	)


	pool.shuffle()


	var amount = min(
		cards_per_turn,
		pool.size()
	)


	for index in range(
		amount
	):

		create_card_button(
			pool[
				index
			]
		)


# =========================================================
# CRIAR CARTA
# =========================================================

func create_card_button(
	card_id: String
):

	var data: Dictionary = (
		CARD_DATA[
			card_id
		]
	)


	var button = Button.new()


	button.custom_minimum_size = Vector2(
		310,
		90
	)


	button.text = (
		str(
			data[
				"name"
			]
		)
		+ "\n"
		+ str(
			data[
				"description"
			]
		)
		+ "\nCUSTO: "
		+ str(
			data[
				"cost"
			]
		)
	)


	button.add_theme_font_size_override(
		"font_size",
		16
	)


	button.set_meta(
		"card_id",
		card_id
	)


	button.set_meta(
		"used",
		false
	)


	button.pressed.connect(
		on_card_pressed.bind(
			card_id,
			button
		)
	)


	cards_container.add_child(
		button
	)


# =========================================================
# JOGAR CARTA
# =========================================================

func on_card_pressed(
	card_id: String,
	button: Button
):

	if not fight_active:
		return


	if turn_locked:
		return


	if button == null:
		return


	if bool(
		button.get_meta(
			"used",
			false
		)
	):
		return


	var data: Dictionary = (
		CARD_DATA[
			card_id
		]
	)


	var cost = int(
		data[
			"cost"
		]
	)


	# =====================================================
	# ENERGIA
	# =====================================================

	if current_energy < cost:

		if combat_log != null:

			combat_log.text = (
				"ENERGIA INSUFICIENTE"
			)


		return


	current_energy -= cost


	button.set_meta(
		"used",
		true
	)


	button.disabled = true


	# =====================================================
	# DANO
	# =====================================================

	var damage = int(
		data[
			"damage"
		]
	)


	if damage > 0:

		creature_hp = max(
			0,
			creature_hp - damage
		)


	# =====================================================
	# DEFESA
	# =====================================================

	var block = int(
		data[
			"block"
		]
	)


	if block > 0:

		current_block += block


	# =====================================================
	# REPARAÇÃO
	# =====================================================

	var heal = int(
		data[
			"heal"
		]
	)


	if heal > 0:

		atlas_hp = min(
			atlas_max_hp,
			atlas_hp + heal
		)


	# =====================================================
	# AUTO-DANO
	# =====================================================

	var self_damage = int(
		data[
			"self_damage"
		]
	)


	if self_damage > 0:

		atlas_hp = max(
			0,
			atlas_hp - self_damage
		)


	# =====================================================
	# LOG
	# =====================================================

	if combat_log != null:

		combat_log.text = (
			str(
				data[
					"name"
				]
			)
			+ " executado."
		)


	update_ui()


	update_card_availability()


	# =====================================================
	# ATLAS MORREU
	# =====================================================

	if atlas_hp <= 0:

		atlas_death()

		return


	# =====================================================
	# CRIATURA MORREU
	# =====================================================

	if creature_hp <= 0:

		finish_fight_victory()


# =========================================================
# DISPONIBILIDADE DAS CARTAS
# =========================================================

func update_card_availability():

	if cards_container == null:
		return


	for child in (
		cards_container.get_children()
	):

		if not (
			child is Button
		):
			continue


		var button: Button = child


		if bool(
			button.get_meta(
				"used",
				false
			)
		):

			button.disabled = true

			continue


		var card_id = str(
			button.get_meta(
				"card_id",
				""
			)
		)


		if card_id.is_empty():
			continue


		var data: Dictionary = (
			CARD_DATA[
				card_id
			]
		)


		var cost = int(
			data[
				"cost"
			]
		)


		# Agora as cartas caras ficam visualmente
		# indisponíveis se não houver energia.
		button.disabled = (
			current_energy < cost
		)


# =========================================================
# TERMINAR TURNO
# =========================================================

func end_player_turn():

	if not fight_active:
		return


	if turn_locked:
		return


	turn_locked = true


	# =====================================================
	# BLOQUEAR INPUT DURANTE TURNO DA CRIATURA
	# =====================================================

	set_cards_disabled(
		true
	)


	if end_turn_button != null:

		end_turn_button.disabled = true


	print(
		"PLAYER TURN ENDED: ",
		turn_number
	)


	# =====================================================
	# ATAQUE DA CRIATURA
	# =====================================================

	var damage_received = max(
		0,
		enemy_intent_damage
		- current_block
	)


	atlas_hp = max(
		0,
		atlas_hp
		- damage_received
	)


	if combat_log != null:

		if enemy_intent_damage <= 0:

			combat_log.text = (
				"A criatura circunda Atlas "
				+ "e não ataca neste turno."
			)


		elif damage_received <= 0:

			combat_log.text = (
				"Atlas bloqueou completamente "
				+ enemy_intent_name
				+ "."
			)


		else:

			combat_log.text = (
				enemy_intent_name
				+ " atingiu Atlas: -"
				+ str(
					damage_received
				)
				+ " HP"
			)


	update_ui()


	print(
		"CREATURE ACTION: ",
		enemy_intent_name,
		" | DAMAGE RECEIVED: ",
		damage_received
	)


	# =====================================================
	# ATLAS DESTRUÍDO
	# =====================================================

	if atlas_hp <= 0:

		await get_tree().create_timer(
			0.8,
			true
		).timeout


		atlas_death()

		return


	# =====================================================
	# ESPERA PEQUENA
	# =====================================================

	await get_tree().create_timer(
		0.7,
		true
	).timeout


	if not fight_active:
		return


	# =====================================================
	# PRÓXIMO TURNO
	# =====================================================

	turn_number += 1


	start_player_turn()


# =========================================================
# VITÓRIA
# =========================================================

func finish_fight_victory():

	if not fight_active:
		return


	fight_active = false

	turn_locked = true


	if combat_log != null:

		combat_log.text = (
			"AMEAÇA TEMPORARIAMENTE NEUTRALIZADA"
		)


	update_ui()


	set_cards_disabled(
		true
	)


	if end_turn_button != null:

		end_turn_button.disabled = true


	await get_tree().create_timer(
		0.9,
		true
	).timeout


	destroy_fight_ui()


	get_tree().paused = false


	fight_won.emit(
		atlas_hp
	)


	print("")
	print(
		"======================================"
	)

	print(
		"FIGHT WON"
	)

	print(
		"ATLAS HP REMAINING: ",
		atlas_hp,
		" / ",
		atlas_max_hp
	)

	print(
		"======================================"
	)


# =========================================================
# MORTE DO ATLAS
# =========================================================

func atlas_death():

	if not fight_active:
		return


	fight_active = false

	turn_locked = true


	atlas_hp = 0


	destroy_fight_ui()


	atlas_destroyed.emit()


	show_atlas_death_ending()


# =========================================================
# FINAL — ATLAS DESTRUÍDO
# =========================================================

func show_atlas_death_ending():

	get_tree().paused = true


	var layer = CanvasLayer.new()


	layer.name = (
		"AtlasDeathEnding"
	)


	layer.layer = 1000


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


	background.color = Color.BLACK


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


	var container = VBoxContainer.new()


	container.custom_minimum_size = Vector2(
		700,
		400
	)


	container.add_theme_constant_override(
		"separation",
		25
	)


	center.add_child(
		container
	)


	var final_label = Label.new()


	final_label.text = "FINAL"


	final_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	final_label.add_theme_font_size_override(
		"font_size",
		28
	)


	container.add_child(
		final_label
	)


	var title = Label.new()


	title.text = "ÚLTIMA DEFESA"


	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	title.add_theme_font_size_override(
		"font_size",
		46
	)


	container.add_child(
		title
	)


	var description = Label.new()


	description.text = (
		"A integridade estrutural de Atlas "
		+ "chegou a zero durante o confronto.\n\n"
		+ "O Android deixou de responder."
	)


	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	description.add_theme_font_size_override(
		"font_size",
		21
	)


	container.add_child(
		description
	)


	var restart_button = Button.new()


	restart_button.text = (
		"VOLTAR AO INÍCIO"
	)


	restart_button.custom_minimum_size = Vector2(
		0,
		65
	)


	restart_button.pressed.connect(
		restart_game
	)


	container.add_child(
		restart_button
	)


	print("")
	print(
		"======================================"
	)

	print(
		"ENDING: ULTIMA DEFESA"
	)

	print(
		"ATLAS DESTROYED"
	)

	print(
		"======================================"
	)


# =========================================================
# RESTART
# =========================================================

func restart_game():

	get_tree().paused = false


	get_tree().reload_current_scene()


# =========================================================
# CRIAR UI DO COMBATE
# =========================================================

func create_fight_ui():

	destroy_fight_ui()


	fight_layer = CanvasLayer.new()


	fight_layer.name = (
		"FightUI"
	)


	fight_layer.layer = 700


	fight_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_child(
		fight_layer
	)


	var background = ColorRect.new()


	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	background.color = Color(
		0.015,
		0.02,
		0.025,
		1.0
	)


	fight_layer.add_child(
		background
	)


	var center = CenterContainer.new()


	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	background.add_child(
		center
	)


	var root = VBoxContainer.new()


	root.custom_minimum_size = Vector2(
		850,
		650
	)


	root.add_theme_constant_override(
		"separation",
		14
	)


	center.add_child(
		root
	)


	# =====================================================
	# TÍTULO
	# =====================================================

	var title = Label.new()


	title.text = (
		"ATLAS // COMBAT MODE"
	)


	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	title.add_theme_font_size_override(
		"font_size",
		30
	)


	root.add_child(
		title
	)


	# =====================================================
	# TURNO
	# =====================================================

	turn_label = Label.new()


	turn_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	turn_label.add_theme_font_size_override(
		"font_size",
		18
	)


	root.add_child(
		turn_label
	)


	# =====================================================
	# ATLAS
	# =====================================================

	atlas_hp_label = Label.new()


	root.add_child(
		atlas_hp_label
	)


	atlas_hp_bar = ProgressBar.new()


	atlas_hp_bar.min_value = 0

	atlas_hp_bar.max_value = (
		atlas_max_hp
	)


	atlas_hp_bar.show_percentage = false


	atlas_hp_bar.custom_minimum_size = Vector2(
		0,
		35
	)


	root.add_child(
		atlas_hp_bar
	)


	# =====================================================
	# CRIATURA
	# =====================================================

	creature_hp_label = Label.new()


	root.add_child(
		creature_hp_label
	)


	creature_hp_bar = ProgressBar.new()


	creature_hp_bar.min_value = 0

	creature_hp_bar.max_value = (
		creature_max_hp
	)


	creature_hp_bar.show_percentage = false


	creature_hp_bar.custom_minimum_size = Vector2(
		0,
		35
	)


	root.add_child(
		creature_hp_bar
	)


	# =====================================================
	# INTENÇÃO
	# =====================================================

	intent_label = Label.new()


	intent_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	intent_label.add_theme_font_size_override(
		"font_size",
		20
	)


	root.add_child(
		intent_label
	)


	# =====================================================
	# ENERGIA / DEFESA
	# =====================================================

	var state_row = HBoxContainer.new()


	state_row.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)


	state_row.add_theme_constant_override(
		"separation",
		80
	)


	root.add_child(
		state_row
	)


	energy_label = Label.new()


	energy_label.add_theme_font_size_override(
		"font_size",
		20
	)


	state_row.add_child(
		energy_label
	)


	block_label = Label.new()


	block_label.add_theme_font_size_override(
		"font_size",
		20
	)


	state_row.add_child(
		block_label
	)


	# =====================================================
	# CARTAS
	# =====================================================

	cards_container = GridContainer.new()


	cards_container.columns = 2


	cards_container.add_theme_constant_override(
		"h_separation",
		12
	)


	cards_container.add_theme_constant_override(
		"v_separation",
		12
	)


	root.add_child(
		cards_container
	)


	# =====================================================
	# LOG
	# =====================================================

	combat_log = Label.new()


	combat_log.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	combat_log.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	combat_log.add_theme_font_size_override(
		"font_size",
		17
	)


	root.add_child(
		combat_log
	)


	# =====================================================
	# TERMINAR TURNO
	# =====================================================

	end_turn_button = Button.new()


	end_turn_button.text = (
		"TERMINAR TURNO"
	)


	end_turn_button.custom_minimum_size = Vector2(
		0,
		55
	)


	end_turn_button.pressed.connect(
		end_player_turn
	)


	root.add_child(
		end_turn_button
	)


# =========================================================
# ATUALIZAR UI
# =========================================================

func update_ui():

	if not fight_active:
		return


	if atlas_hp_bar != null:

		atlas_hp_bar.value = (
			atlas_hp
		)


	if creature_hp_bar != null:

		creature_hp_bar.value = (
			creature_hp
		)


	if atlas_hp_label != null:

		atlas_hp_label.text = (
			"ATLAS // HP "
			+ str(
				atlas_hp
			)
			+ " / "
			+ str(
				atlas_max_hp
			)
		)


	if creature_hp_label != null:

		creature_hp_label.text = (
			"CRIATURA // HP "
			+ str(
				creature_hp
			)
			+ " / "
			+ str(
				creature_max_hp
			)
		)


	if energy_label != null:

		energy_label.text = (
			"ENERGIA: "
			+ str(
				current_energy
			)
			+ " / "
			+ str(
				energy_per_turn
			)
		)


	if block_label != null:

		block_label.text = (
			"DEFESA: "
			+ str(
				current_block
			)
		)


	if turn_label != null:

		turn_label.text = (
			"TURNO "
			+ str(
				turn_number
			)
		)


	if intent_label != null:

		if enemy_intent_damage > 0:

			intent_label.text = (
				"PRÓXIMA AÇÃO DA CRIATURA: "
				+ enemy_intent_name
				+ " // "
				+ str(
					enemy_intent_damage
				)
				+ " DANO"
			)


		else:

			intent_label.text = (
				"PRÓXIMA AÇÃO DA CRIATURA: "
				+ enemy_intent_name
				+ " // SEM ATAQUE"
			)


# =========================================================
# DESATIVAR CARTAS
# =========================================================

func set_cards_disabled(
	disabled: bool
):

	if cards_container == null:
		return


	for child in (
		cards_container.get_children()
	):

		if child is Button:

			child.disabled = disabled


# =========================================================
# LIMPAR CARTAS
# =========================================================

func clear_cards():

	if cards_container == null:
		return


	for child in (
		cards_container.get_children()
	):

		child.hide()

		child.queue_free()


# =========================================================
# DESTRUIR UI
# =========================================================

func destroy_fight_ui():

	if (
		fight_layer != null
		and is_instance_valid(
			fight_layer
		)
	):

		fight_layer.queue_free()


	fight_layer = null


	atlas_hp_bar = null

	creature_hp_bar = null


	atlas_hp_label = null

	creature_hp_label = null


	energy_label = null

	block_label = null


	intent_label = null

	turn_label = null

	combat_log = null


	cards_container = null

	end_turn_button = null
