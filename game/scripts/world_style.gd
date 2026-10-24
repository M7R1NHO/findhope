extends Node

# Estilo visual do mundo, a condizer com as folhas de sprites: contorno
# preto grosso, cinzentos frios, amarelo-torrado e ciano como destaques.
#
# Não mexe em posições, colisões nem lógica. Percorre a cena e:
#   - chãos das salas e corredores: cor nova + painéis metálicos com rebites;
#   - bordas das salas e paredes: cinzento-metal com contorno preto;
#   - restantes polígonos (terminais, portas, peças, destroços...): contorno
#     preto à volta, como nos sprites;
#   - nomes das salas: letra com contorno preto.
# Objetos criados mais tarde (Phase 3, terminais, portas) são apanhados pelo
# sinal node_added da árvore.

const OUTLINE := Color(0.07, 0.07, 0.09)
const FLOOR := Color(0.21, 0.23, 0.27)
const FLOOR_IMPORTANT := Color(0.24, 0.26, 0.3)
const CORRIDOR := Color(0.16, 0.17, 0.2)
const SEAM := Color(0.12, 0.13, 0.15)
const HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.05)
const RIVET := Color(0.4, 0.43, 0.48)
const WALL := Color(0.45, 0.48, 0.53)
const ACCENT := Color(0.88, 0.64, 0.17)

const OUTLINE_WIDTH := 4.0
const PANEL := 64.0

var root: Node = null


func _ready() -> void:
	name = "WorldStyle"
	root = get_parent()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("style_tree", root)


func _on_node_added(node: Node) -> void:
	if root != null and is_instance_valid(root) and root.is_ancestor_of(node):
		# Esperar que quem criou o nó lhe dê forma e cor.
		call_deferred("style_node", node)


func style_tree(node: Node) -> void:
	style_node(node)
	for child in node.get_children():
		style_tree(child)


func style_node(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.has_meta("world_style"):
		return
	if node is Polygon2D:
		style_polygon(node)
	elif node is Line2D:
		style_line(node)


func should_skip(node: CanvasItem) -> bool:
	if not node.is_inside_tree():
		return true
	var parent := node.get_parent()
	# Sprites (sombras), Player/Atlas (quadrado antigo), elementos de interface.
	if parent is AnimatedSprite2D or parent is Sprite2D or parent is CharacterBody2D:
		return true
	if node.name == "Shadow" or node.name.begins_with("Outline"):
		return true
	return false


func style_polygon(poly: Polygon2D) -> void:
	if should_skip(poly) or poly.polygon.size() < 3:
		return
	poly.set_meta("world_style", true)
	if poly.texture != null:
		return
	var parent_name := String(poly.get_parent().name)
	if poly.name == "Floor":
		var important := poly.color.is_equal_approx(Color(0.22, 0.27, 0.31, 1.0))
		poly.color = FLOOR_IMPORTANT if important else FLOOR
		add_panels(poly, PANEL)
		return
	if parent_name.begins_with("Corridor_"):
		poly.color = CORRIDOR
		add_panels(poly, PANEL / 2.0)
		return
	if poly.name == "Border":
		poly.color = WALL
		add_outline(poly, OUTLINE_WIDTH + 2.0)
		return
	# Superfície: a nave e os destroços passam aos cinzentos dos sprites e
	# as peças a recolher ao amarelo do fato do Player.
	if parent_name == "Ship":
		poly.color = Color(0.4, 0.43, 0.48)
	elif parent_name.begins_with("Debris"):
		poly.color = Color(0.3, 0.31, 0.35)
	elif parent_name.begins_with("ShipPart"):
		poly.color = ACCENT
		# Só contorna o que é sólido; zonas translúcidas (gatilhos, esconderijos,
	# brilhos) ficam como estão.
	if poly.color.a < 0.85 or not poly.visible:
		return
	if is_machine(poly):
		dress_machine(poly)
	add_outline(poly, OUTLINE_WIDTH)


# Terminais e estações: painel grande e retangular dentro de um nó cujo nome
# diz o que é. Ganham moldura, ecrã ciano e botões, como uma consola.
func is_machine(poly: Polygon2D) -> bool:
	var owner_name := String(poly.get_parent().name)
	var machine := false
	for word in ["Terminal", "Station", "Estacao", "Energy", "Equipment", "Map", "Console"]:
		if owner_name.contains(word):
			machine = true
	if not machine:
		return false
	var bounds := polygon_bounds(poly.polygon)
	return bounds.size.x >= 80.0 and bounds.size.y >= 50.0


func dress_machine(poly: Polygon2D) -> void:
	# A cor original passa a ser só um tom na moldura (cada terminal mantém a
	# sua identidade de cor).
	var tone := poly.color
	poly.color = Color(0.28, 0.3, 0.34).lerp(tone, 0.35)
	var decor := MachineDecor.new()
	decor.name = "OutlineMachine"
	decor.bounds = polygon_bounds(poly.polygon)
	decor.tone = tone
	decor.set_meta("world_style", true)
	poly.add_child(decor)


func style_line(line: Line2D) -> void:
	if should_skip(line):
		return
	line.set_meta("world_style", true)
	if String(line.get_parent().name) != "WallVisuals":
		return
	line.default_color = WALL
	# Contorno preto por trás da parede.
	var outline := Line2D.new()
	outline.name = "OutlineWall"
	outline.points = line.points
	outline.width = line.width + OUTLINE_WIDTH * 2.0
	outline.default_color = OUTLINE
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.show_behind_parent = true
	outline.set_meta("world_style", true)
	line.add_child(outline)


func add_outline(poly: Polygon2D, width: float) -> void:
	var outline := Line2D.new()
	outline.name = "Outline"
	var points := poly.polygon.duplicate()
	outline.points = points
	outline.closed = true
	outline.width = width
	outline.default_color = OUTLINE
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.position = poly.offset
	outline.set_meta("world_style", true)
	poly.add_child(outline)


func add_panels(poly: Polygon2D, step: float) -> void:
	var panels := FloorPanels.new()
	panels.name = "OutlinePanels"
	panels.bounds = polygon_bounds(poly.polygon)
	panels.step = step
	panels.set_meta("world_style", true)
	poly.add_child(panels)


static func polygon_bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


# Painéis de metal desenhados por cima do chão (juntas, brilho e rebites).
class FloorPanels extends Node2D:
	var bounds: Rect2
	var step: float = 64.0

	func _draw() -> void:
		var x := bounds.position.x
		while x <= bounds.end.x + 0.1:
			draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), SEAM, 2.0)
			x += step
		var y := bounds.position.y
		while y <= bounds.end.y + 0.1:
			draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), SEAM, 2.0)
			draw_line(Vector2(bounds.position.x, y + 2.0), Vector2(bounds.end.x, y + 2.0), HIGHLIGHT, 1.0)
			y += step
		if step < 48.0:
			return
		x = bounds.position.x
		while x < bounds.end.x:
			y = bounds.position.y
			while y < bounds.end.y:
				for corner in [Vector2(6, 6), Vector2(step - 6, 6), Vector2(6, step - 6), Vector2(step - 6, step - 6)]:
					var p: Vector2 = Vector2(x, y) + corner
					if bounds.has_point(p):
						draw_circle(p, 1.8, RIVET)
				y += step
			x += step


# Ecrã, luzes e botões de uma consola.
class MachineDecor extends Node2D:
	var bounds: Rect2
	var tone: Color
	var clock: float = 0.0

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		var inset := 12.0
		var screen := Rect2(bounds.position + Vector2(inset, inset), Vector2(bounds.size.x - inset * 2.0, bounds.size.y * 0.62))
		draw_rect(screen, Color(0.04, 0.12, 0.14))
		# Linhas do ecrã e um brilho que desce devagar.
		var y := screen.position.y + 4.0
		while y < screen.end.y:
			draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0.25, 0.85, 0.85, 0.08), 1.0)
			y += 6.0
		var sweep := screen.position.y + fmod(clock * 30.0, screen.size.y)
		draw_rect(Rect2(screen.position.x, sweep, screen.size.x, 6.0), Color(0.25, 0.85, 0.85, 0.12))
		draw_rect(screen, OUTLINE, false, 3.0)
		# Botões por baixo do ecrã.
		var row_y := screen.end.y + (bounds.end.y - screen.end.y) / 2.0
		var colors := [ACCENT, Color(0.25, 0.85, 0.85), Color(0.85, 0.3, 0.25)]
		for i in 3:
			var center := Vector2(bounds.position.x + inset + 10.0 + i * 22.0, row_y)
			var lit := fmod(clock + i * 0.7, 2.0) < 1.4
			draw_circle(center, 6.0, OUTLINE)
			draw_circle(center, 4.5, colors[i] if lit else colors[i].darkened(0.6))
		# Grelha de ventilação à direita.
		for i in 4:
			var x := bounds.end.x - inset - 8.0 - i * 9.0
			draw_line(Vector2(x, row_y - 7.0), Vector2(x, row_y + 7.0), OUTLINE, 3.0)
		# Faixa de cor do terminal.
		draw_rect(Rect2(bounds.position.x, bounds.end.y - 6.0, bounds.size.x, 6.0), tone)
