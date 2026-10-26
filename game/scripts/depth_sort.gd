extends Node

# Profundidade (ordem de desenho) dos objetos altos em relação ao Player e
# ao Atlas.
#
# Num jogo visto de cima em perspetiva, quem está mais abaixo no ecrã está
# mais perto da câmara e deve ser desenhado por cima. Antes, cada objeto
# tinha um z_index fixo (2, 3 ou 5) e ficava SEMPRE por cima das
# personagens (z 0), mesmo quando elas estavam à frente dele.
#
# Aqui comparamos a "linha dos pés" de cada objeto (a base da pegada no chão)
# com a linha dos pés das duas personagens e escolhemos uma de cinco camadas:
#
#   Z_BEHIND (2)   objeto atrás das duas personagens
#   Z_UPPER  (3)   personagem que está mais acima no ecrã
#   Z_BETWEEN (4)  objeto entre as duas (à frente de uma, atrás da outra)
#   Z_LOWER  (5)   personagem que está mais abaixo no ecrã
#   Z_FRONT  (6)   objeto à frente das duas
#
# Com só duas personagens que se movem, isto dá sempre uma ordem correta,
# sem pôr tudo na mesma camada e sem esconder objetos. Os objetos de chão
# (condutas, tapetes, a escotilha da PROTOCOL DOOR) não entram aqui: ficam
# sempre por baixo (FLOOR_Z). Textos por cima dos objetos usam LABEL_Z.

const Z_BEHIND := 2
const Z_UPPER := 3
const Z_BETWEEN := 4
const Z_LOWER := 5
const Z_FRONT := 6
# Objetos no chão: acima de todos os pisos (subterrâneo -7/-6, Phase 3 -2/-1)
# e das linhas das paredes do subterrâneo (-4), e abaixo das personagens.
const FLOOR_Z := 0
# Nomes e estados por cima de tudo o que é ordenado.
const LABEL_Z := 20
# Os pés da personagem ficam 16 px abaixo do centro do corpo (CharacterSprite).
const FEET_Y := 16.0
const GROUP := "depth_sorted"
const CHARACTERS := ["Player", "Atlas"]

var characters: Array = []


# Põe o ordenador na cena principal (uma vez).
static func install(main: Node) -> Node:
	var existing := main.get_node_or_null("DepthSort")
	if existing != null:
		return existing
	var sorter = load("res://scripts/depth_sort.gd").new()
	sorter.name = "DepthSort"
	main.add_child(sorter)
	return sorter


# Regista um objeto alto. base_y = linha dos pés, em coordenadas locais do
# objeto; se ficar NAN, usa o fundo do desenho (polígonos e sprites filhos).
static func register(item: CanvasItem, base_y: float = NAN) -> void:
	if item == null:
		return
	if is_nan(base_y):
		base_y = visual_bottom(item)
	item.set_meta("depth_base_y", base_y)
	item.z_as_relative = false
	item.z_index = Z_BEHIND
	item.add_to_group(GROUP)


# Objeto de chão: sempre por baixo das personagens.
static func set_floor(item: CanvasItem) -> void:
	if item == null:
		return
	item.z_as_relative = false
	item.z_index = FLOOR_Z


# Texto por cima de tudo o que é ordenado.
static func set_label(item: CanvasItem) -> void:
	if item == null:
		return
	item.z_as_relative = false
	item.z_index = LABEL_Z


# Fundo (maior y local) do que o objeto desenha.
static func visual_bottom(item: Node) -> float:
	var bottom := -INF
	var stack: Array = [[item, Transform2D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var to_item: Transform2D = entry[1]
		if node is Polygon2D and node.visible:
			for point in node.polygon:
				bottom = maxf(bottom, (to_item * (point + node.offset)).y)
		elif node is Sprite2D and node.visible and node.texture != null:
			var rect: Rect2 = node.get_rect()
			for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
				bottom = maxf(bottom, (to_item * corner).y)
		for child in node.get_children():
			if child is Node2D and not child is Control:
				stack.append([child, to_item * child.transform])
	return 0.0 if bottom == -INF else bottom


# Linha dos pés de um objeto registado, no mundo.
static func base_of(item: CanvasItem) -> float:
	var base := float(item.get_meta("depth_base_y", 0.0))
	if item is Node2D:
		return (item.global_transform * Vector2(0.0, base)).y
	return base


static func feet_of(body: Node2D) -> float:
	return body.global_position.y + FEET_Y


# Camada de um objeto para as linhas dos pés das duas personagens.
static func layer_for(base: float, upper_feet: float, lower_feet: float) -> int:
	if base <= upper_feet:
		return Z_BEHIND
	if base <= lower_feet:
		return Z_BETWEEN
	return Z_FRONT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Depois do movimento das personagens.
	process_priority = 100
	var main := get_parent()
	for character_name in CHARACTERS:
		var body := main.get_node_or_null(character_name)
		if body is Node2D:
			body.z_as_relative = false
			characters.append(body)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var bodies := characters.filter(func(body): return is_instance_valid(body))
	if bodies.is_empty():
		return
	bodies.sort_custom(func(a, b): return feet_of(a) < feet_of(b))
	var upper: Node2D = bodies[0]
	var lower: Node2D = bodies[bodies.size() - 1]
	upper.z_index = Z_UPPER
	lower.z_index = Z_LOWER if lower != upper else Z_UPPER
	var upper_feet := feet_of(upper)
	var lower_feet := feet_of(lower)
	for item in get_tree().get_nodes_in_group(GROUP):
		if item is CanvasItem:
			item.z_index = layer_for(base_of(item), upper_feet, lower_feet)
