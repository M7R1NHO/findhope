extends CanvasLayer

# Cartão de tutorial: explica uma mecânica na primeira vez que ela aparece.
#
# Uso:
#   TutorialCard.show_once(self, "fight")   # só abre se ainda não foi visto
#   TutorialCard.open(self, "fight")        # abre sempre (menu COMO JOGAR)
#
# Enquanto o cartão está aberto:
#   - o jogo fica pausado (e volta ao estado anterior ao fechar);
#   - os temporizadores do AlienEncounterManager e do FightManager param
#     (eles correm com PROCESS_MODE_ALWAYS, por isso perguntam is_open());
#   - o cartão fica com todas as teclas, para não irem parar ao jogo.
#
# O que já foi visto fica na run, em custom.tutorial_<id>, e vai no save.
# Os textos descrevem as regras que estão no código; não mudam nenhuma.

const UIStyle := preload("res://scripts/ui_style.gd")

const GROUP := "tutorial_card"
const LAYER := 1500

# Ordem do menu COMO JOGAR.
const ORDER := ["controls", "encounter", "run", "fight", "hide", "hack", "boss"]

const TUTORIALS := {
	"controls": {
		"title": "CONTROLOS BÁSICOS",
		"steps": [
			["W A S D", "Mover o Player."],
			["E", "Interagir com terminais, portas, peças e equipamentos."],
			["ESPAÇO", "O Atlas analisa o que está à volta."],
			["ESC", "Pausa: gravar, carregar, COMO JOGAR."],
			["CHAT", "Escreve na caixa de texto em baixo para falar com o Atlas."],
		],
		"tip": "Se não souberes o que fazer, pergunta ao Atlas.",
	},
	"encounter": {
		"title": "ENCONTRO COM A CRIATURA",
		"steps": [
			["!", "A criatura pode aparecer nos corredores. O jogo para até escolheres o que fazer."],
			["RUN", "Fugir: carregas ESPAÇO depressa e depois passas uma porta com um hack antes de ela vos apanhar."],
			["FIGHT", "Lutar: só aparece depois de ligares o equipamento sonoro ao Atlas. Se venceres, o corredor seguinte fica seguro."],
		],
		"tip": "Cada fuga torna um novo encontro mais provável.",
	},
	"run": {
		"title": "FUGIR (RUN)",
		"steps": [
			["ESPAÇO", "Carrega repetidamente até encher a barra."],
			["HACK", "Depois, abre a porta com um hack e fecha-a atrás de vocês com outro."],
			["15 s", "Tens 15 segundos para selar a porta. Se o tempo acabar, a criatura apanha-vos: Game Over."],
		],
		"tip": "No hack, lê a regra no topo do ecrã: cada protocolo é diferente.",
	},
	"fight": {
		"title": "LUTA SONORA (FIGHT)",
		"steps": [
			["1. FUGIR", "A criatura persegue o Player. [1] controla o Player: foge com W A S D."],
			["2. APONTAR", "[2] controla o Atlas. Aponta com o rato para a criatura."],
			["3. DISPARAR", "Com o Atlas, carrega E para disparar o dispositivo sónico. Depois espera 2 s de recarga."],
			["VITÓRIA", "10 golpes sónicos na criatura e ela recua."],
		],
		"tip": "Garras, mordidas e o toque da criatura tiram VIDA. A VIDA é partilhada; se chegar a 0, perdem.",
	},
	"hide": {
		"title": "ESCONDER (HIDE)",
		"steps": [
			["!", "A criatura pode entrar na sala onde estás."],
			["IR", "Segue o Atlas ou a marca até ao esconderijo antes de o tempo acabar."],
			["FICAR", "Fica lá dentro, sem sair, até o temporizador terminar e ela ir embora."],
			["FALHAR", "Se não chegares a tempo ou saíres antes, ela encontra-vos e só podem fugir (RUN)."],
		],
		"tip": "O temporizador no topo do ecrã diz quanto falta.",
	},
	"hack": {
		"title": "HACKS",
		"steps": [
			["SORTEIO", "Cada hack é um minijogo sorteado: setas, contar teclas, memória de cores, matriz, rotas, texto."],
			["REGRA", "A regra está sempre escrita no topo do ecrã. Lê-a antes de começar."],
			["ERRAR", "Se errares aparece ACCESS DENIED e tens de tentar outra vez."],
		],
		"tip": "Durante uma fuga o relógio continua a contar enquanto fazes o hack.",
	},
	"boss": {
		"title": "SALA DE CONTROLO",
		"steps": [
			["60 s", "O Atlas precisa de 60 segundos para abrir o Hangar."],
			["SENSOR", "A criatura é quente: ~12 °C longe, 21 no corredor, 30 perto, 39 à porta."],
			["A / D", "Fecham e abrem as portas. Uma porta fechada aguenta 25 s de energia, as duas 12,5 s."],
			["2,5 s", "À porta, ela espera 2,5 s. Porta aberta: entra e o Atlas fica danificado, o que muda o final."],
		],
		"tip": "Fecha só a porta que ficar vermelha e abre-a quando arrefecer.",
	},
}

var tutorial_id: String = ""
var was_paused: bool = false
var panel: Control = null

signal closed(tutorial_id: String)


static func is_open(tree: SceneTree) -> bool:
	return tree != null and tree.get_nodes_in_group(GROUP).size() > 0


static func seen_key(id: String) -> String:
	return "tutorial_" + id


static func was_seen(id: String) -> bool:
	return bool(SaveManager.get_run_value("custom", seen_key(id), false))


# Abre o tutorial só na primeira vez nesta run. Devolve o cartão ou null.
static func show_once(host: Node, id: String) -> Node:
	if was_seen(id):
		return null
	SaveManager.set_run_value("custom", seen_key(id), true)
	return open(host, id)


static func open(host: Node, id: String) -> Node:
	if host == null or not host.is_inside_tree() or not TUTORIALS.has(id):
		return null
	var tree := host.get_tree()
	# Nunca dois cartões ao mesmo tempo.
	for other in tree.get_nodes_in_group(GROUP):
		other.close()
	var card = load("res://scripts/tutorial_card.gd").new()
	card.tutorial_id = id
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(card)
	return card


func _ready() -> void:
	add_to_group(GROUP)
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	was_paused = get_tree().paused
	get_tree().paused = true
	panel = build(TUTORIALS[tutorial_id])
	add_child(panel)


func close() -> void:
	if not is_inside_tree():
		return
	remove_from_group(GROUP)
	get_tree().paused = was_paused
	closed.emit(tutorial_id)
	queue_free()


# Todas as teclas ficam no cartão. ESPAÇO, ENTER ou ESC fecham-no.
func _input(event: InputEvent) -> void:
	if not is_in_group(GROUP) or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		close()


func build(data: Dictionary) -> Control:
	var shade := ColorRect.new()
	shade.name = "TutorialShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var frame := PanelContainer.new()
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760.0, 0.0)
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)

	var kicker := Label.new()
	kicker.text = "COMO JOGAR"
	kicker.add_theme_font_size_override("font_size", 14)
	UIStyle.subtitle(kicker)
	box.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.text = data["title"]
	title.add_theme_font_size_override("font_size", 28)
	UIStyle.title(title)
	box.add_child(title)

	box.add_child(HSeparator.new())

	for step in data["steps"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		row.add_child(key_chip(step[0]))
		var text := Label.new()
		text.text = step[1]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 17)
		row.add_child(text)

	if data.has("tip"):
		var tip := Label.new()
		tip.text = "Dica: " + data["tip"]
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_font_size_override("font_size", 16)
		tip.add_theme_color_override("font_color", UIStyle.ACCENT)
		box.add_child(tip)

	var button := Button.new()
	button.name = "OkButton"
	button.text = "PERCEBI  [ESPAÇO]"
	button.custom_minimum_size = Vector2(280.0, 50.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(close)
	box.add_child(button)
	return shade


# Tecla ou palavra-chave desenhada como uma tecla do teclado.
func key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(120.0, 40.0)
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyle.BUTTON_BG_HOVER
	style.border_color = UIStyle.ACCENT_DIM
	style.set_border_width_all(1)
	style.border_width_bottom = 4
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6.0)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIStyle.ACCENT)
	chip.add_child(label)
	return chip
