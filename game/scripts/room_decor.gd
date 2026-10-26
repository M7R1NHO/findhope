extends Node

# Decoração das salas, da superfície e das naves.
#
# Cada sala tem uma lista de objetos a condizer com o nome (armazém com
# caixas, laboratório com bancadas e tubos de amostras, santuário com
# esculturas...). Os objetos são desenhados por decor_props.gd; os sólidos
# têm colisão.
#
# Regra de segurança: antes de pôr um objeto, vê o que já lá está. Um
# objeto que ficaria por cima de um terminal, de um esconderijo, de uma
# porta, de uma zona de gatilho, da entrada de um corredor ou do Player/Atlas
# não é posto (fica registado em "skipped"). Assim a decoração nunca tapa
# nem bloqueia nada do jogo, mesmo que mais tarde mudes posições.
#
# Não muda lógica, posições nem colisões que já existiam (exceto acrescentar
# as colisões dos objetos novos).

const Props := preload("res://scripts/decor_props.gd")
const CreatureActor := preload("res://scripts/creature_actor.gd")
const ShipArt := preload("res://scripts/ship_art.gd")
const DepthSort := preload("res://scripts/depth_sort.gd")

const WALL_INSET := 26.0      # distância mínima às paredes
const CLEARANCE := 24.0       # folga à volta do que já existe
const DOOR_CLEARANCE := 40.0  # folga dos lados da entrada de um corredor
const DOOR_REACH := 130.0     # quanto a entrada fica livre para dentro da sala
# Zonas de gatilho muito grandes (a área onde a criatura é descoberta, o
# confronto, a entrada do Hangar) não impedem objetos encostados às paredes:
# o gatilho continua a disparar quando o Player lá entra.
const BIG_TRIGGER_AREA := 120000.0
# Se o sítio pedido estiver ocupado, experimenta deslizar ao longo da parede.
const SLIDES := [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 160.0, -160.0]
# Condutas da criatura: uma por sala, num destes sítios (fração do tamanho da
# sala, a partir do centro), o primeiro que estiver livre. As dos corredores
# são postas pelo alien_encounter_manager.gd.
const VENT_SIZE := Vector2(128, 76)
# A conduta é sólida (não se anda por cima dela): fica com a mesma folga dos
# outros objetos sólidos, para nunca fechar uma passagem.
const VENT_CLEARANCE := 16.0
# Em salas muito cheias aceita-se uma folga menor (nunca à entrada de um
# corredor), para todas as salas terem conduta.
const VENT_CLEARANCE_TIGHT := 8.0
const VENT_SPOTS := [
	Vector2(0.3, -0.28), Vector2(-0.3, 0.28), Vector2(-0.3, -0.28), Vector2(0.3, 0.28),
	Vector2(0.0, -0.3), Vector2(0.0, 0.3), Vector2(0.36, 0.0), Vector2(-0.36, 0.0),
	Vector2(0.15, 0.1), Vector2(-0.15, -0.1),
]

# [tipo, posição (píxeis a partir do centro da sala), tamanho, sólido, variante, (forçar)]
# A posição é ajustada para o objeto ficar dentro da sala; um objeto
# encostado a uma parede pode deslizar ao longo dela (ver SLIDES).
# "forçar" só serve para marcas no chão que ficam de propósito por baixo de
# outra coisa (o círculo de aterragem por baixo da nave).
# As posições foram escolhidas à volta do que já existe em cada sala
# (terminais, esconderijos, entradas dos corredores, zona da criatura).
const UNDERGROUND := {
	"Entrance": [
		["locker", Vector2(-220, -200), Vector2(150, 46), true, 0],
		["locker", Vector2(220, -200), Vector2(150, 46), true, 0],
		["bench", Vector2(-150, 200), Vector2(130, 34), true, 0],
		["plant", Vector2(-350, 200), Vector2(46, 60), true, 0],
		["plant", Vector2(350, 200), Vector2(46, 60), true, 1],
		["crates", Vector2(190, 200), Vector2(110, 80), true, 0],
	],
	"Hall": [
		["plant", Vector2(-500, -60), Vector2(50, 64), true, 0],
		["plant", Vector2(500, -60), Vector2(50, 64), true, 1],
		["plant", Vector2(-500, 300), Vector2(50, 64), true, 1],
		["plant", Vector2(500, 300), Vector2(50, 64), true, 0],
		["bench", Vector2(-300, 300), Vector2(150, 36), true, 0],
		["bench", Vector2(300, 300), Vector2(150, 36), true, 0],
		["carpet", Vector2(0, 160), Vector2(130, 220), false, 0],
	],
	"Storage": [
		["shelf", Vector2(234, -200), Vector2(160, 50), true, 0],
		["crates", Vector2(-250, 184), Vector2(130, 80), true, 0],
		["barrels", Vector2(-60, 190), Vector2(120, 64), true, 0],
		["crate", Vector2(60, 190), Vector2(70, 70), true, 0],
		["stain", Vector2(20, -40), Vector2(120, 70), false, 0],
	],
	"TechnicalRoom": [
		["pipes", Vector2(-240, -262), Vector2(230, 30), false, 0],
		["pipes", Vector2(240, -262), Vector2(230, 30), false, 0],
		["barrels", Vector2(-330, -224), Vector2(100, 50), true, 1],
		["tanks", Vector2(300, -215), Vector2(100, 64), true, 0],
		["generator", Vector2(-290, 200), Vector2(160, 90), true, 0],
		["cables", Vector2(0, 222), Vector2(300, 50), false, 0],
		["stripes", Vector2(-290, 140), Vector2(160, 18), false, 0],
	],
	"SupportRoom": [
		["bed", Vector2(230, -190), Vector2(170, 70), true, 0],
		["desk", Vector2(-75, 190), Vector2(150, 70), true, 0],
		["cabinet", Vector2(70, 185), Vector2(70, 84), true, 0],
		["papers", Vector2(-40, 60), Vector2(120, 70), false, 0],
	],
	"Security": [
		["cell", Vector2(-10, -120), Vector2(110, 110), true, 0],
		["cell", Vector2(-60, 150), Vector2(130, 130), true, 1],
		["monitors", Vector2(-250, 190), Vector2(140, 66), true, 0],
		["stain", Vector2(-60, 60), Vector2(90, 40), false, 1],
	],
	"Archives": [
		["shelf", Vector2(-260, -226), Vector2(200, 46), true, 0],
		["cabinet", Vector2(-346, 10), Vector2(56, 84), true, 2],
		["cabinet", Vector2(-330, 205), Vector2(80, 84), true, 0],
		["cabinet", Vector2(-230, 205), Vector2(80, 84), true, 1],
		["desk", Vector2(-250, 60), Vector2(150, 70), true, 0],
		["shelf", Vector2(270, 226), Vector2(200, 46), true, 1],
		["papers", Vector2(20, -10), Vector2(120, 70), false, 0],
	],
	"Laboratory": [
		["lab_bench", Vector2(260, -217), Vector2(210, 64), true, 0],
		["tube", Vector2(346, -90), Vector2(56, 110), true, 0],
		["tube", Vector2(346, 90), Vector2(56, 110), true, 1],
		["stain", Vector2(300, 226), Vector2(100, 40), false, 1],
		["lab_bench", Vector2(-260, 215), Vector2(200, 64), true, 1],
	],
	"Maintenance": [
		["toolbench", Vector2(230, -190), Vector2(170, 64), true, 0],
		["barrel", Vector2(305, 100), Vector2(40, 56), true, 2],
		["toolbench", Vector2(-230, 200), Vector2(170, 60), true, 1],
		["crates", Vector2(-250, 60), Vector2(130, 100), true, 1],
		["toolbox", Vector2(230, 210), Vector2(60, 30), true, 0],
		["stain", Vector2(0, 30), Vector2(150, 90), false, 0],
		["cables", Vector2(0, -50), Vector2(160, 40), false, 1],
	],
	"Sanctuary": [
		["carpet", Vector2(0, 0), Vector2(900, 80), false, 0],
		["statue", Vector2(-170, -234), Vector2(80, 130), true, 0],
		["lamp", Vector2(-70, -254), Vector2(52, 90), true, 0],
		["statue", Vector2(30, -234), Vector2(80, 130), true, 1],
		["lamp", Vector2(130, -254), Vector2(52, 90), true, 1],
		["statue", Vector2(230, -234), Vector2(80, 130), true, 2],
		["lamp", Vector2(330, -254), Vector2(52, 90), true, 2],
		["statue", Vector2(430, -234), Vector2(80, 130), true, 0],
		["statue", Vector2(-450, 234), Vector2(80, 130), true, 1],
		["lamp", Vector2(-350, 254), Vector2(52, 90), true, 0],
		["statue", Vector2(-250, 234), Vector2(80, 130), true, 2],
		["lamp", Vector2(-150, 254), Vector2(52, 90), true, 1],
		["statue", Vector2(-50, 234), Vector2(80, 130), true, 0],
		["lamp", Vector2(50, 254), Vector2(52, 90), true, 2],
		["statue", Vector2(150, 234), Vector2(80, 130), true, 1],
	],
	"MainCore": [
		["server", Vector2(-460, -245), Vector2(100, 110), true, 0],
		["server", Vector2(-150, -245), Vector2(100, 110), true, 1],
		["server", Vector2(-26, -245), Vector2(100, 110), true, 2],
		["server", Vector2(98, -245), Vector2(100, 110), true, 3],
		["server", Vector2(-330, 245), Vector2(100, 110), true, 4],
		["server", Vector2(-206, 245), Vector2(100, 110), true, 5],
		["server", Vector2(-82, 245), Vector2(100, 110), true, 6],
		["server", Vector2(42, 245), Vector2(100, 110), true, 7],
		["server", Vector2(166, 245), Vector2(100, 110), true, 8],
		["generator", Vector2(460, 259), Vector2(120, 76), true, 2],
		["tanks", Vector2(470, 50), Vector2(90, 80), true, 1],
		["cables", Vector2(-40, 30), Vector2(400, 60), false, 2],
	],
}

# Phase 3: as três salas (1000 x 600), pela ordem em que aparecem. A Sala de
# Controlo (a segunda) não leva decoração daqui: é desenhada igual à planta do
# confronto por control_room_art.gd.
const PHASE3 := [
	[
		["radio", Vector2(-360, -300), Vector2(130, 76), true, 0],
		["radio", Vector2(360, -300), Vector2(130, 76), true, 1],
		["desk", Vector2(-300, 300), Vector2(160, 72), true, 0],
		["locker", Vector2(320, 300), Vector2(140, 46), true, 0],
		["papers", Vector2(-50, 60), Vector2(140, 80), false, 1],
		["cables", Vector2(0, -150), Vector2(400, 60), false, 0],
		["stain", Vector2(300, 180), Vector2(90, 50), false, 0],
	],
	[],
	[
		["landing", Vector2(250, 0), Vector2(480, 480), false, 0, true],
		["fuel", Vector2(-350, -300), Vector2(200, 72), true, 0],
		["crates", Vector2(-340, 300), Vector2(130, 100), true, 0],
		["barrels", Vector2(-120, 300), Vector2(120, 64), true, 0],
		["tanks", Vector2(-170, -300), Vector2(110, 84), true, 0],
		["stripes", Vector2(-420, 0), Vector2(18, 200), false, 0],
	],
]

var root: Node = null
var placed: Array = []
var skipped: Array = []


func _ready() -> void:
	name = "RoomDecor"
	root = get_parent()
	# Esperar que terminais, esconderijos e salas da Phase 3 estejam criados.
	for i in 3:
		await get_tree().process_frame
	decorate_all()


func decorate_all() -> void:
	if root == null or not is_instance_valid(root):
		return
	var layout := root.get_node_or_null("UndergroundRoot/GeneratedLayout")
	if layout != null and "rooms" in layout:
		decorate_underground(layout)
	var endgame := root.get_node_or_null("Endgame")
	if endgame != null and "room_size" in endgame:
		decorate_phase3(endgame)
	decorate_surface()


# ---------------------------------------------------------------------------
# Salas
# ---------------------------------------------------------------------------

var debug_occupied: Array = []
# [{room, rect, node}] das condutas postas nas salas.
var vents: Array = []
# Objetos de chão tirados para dar lugar a uma conduta (salas cheias).
var replaced_by_vents: Array = []


func decorate_underground(layout: Node2D) -> void:
	var container := new_container(layout, "Decor")
	var occupied := collect_occupied(root.get_node("UndergroundRoot"), container)
	debug_occupied = occupied.duplicate()
	for room_id in UNDERGROUND:
		if not layout.rooms.has(room_id):
			continue
		var data: Dictionary = layout.rooms[room_id]
		var center: Vector2 = layout.to_global(data["position"])
		place_room(container, room_id, center, data["size"], UNDERGROUND[room_id], occupied)
	# As condutas vêm depois da decoração, nos sítios que ficaram livres.
	var encounters := root.get_node_or_null("UndergroundRoot/AlienEncounterManager")
	for room_id in layout.rooms:
		var data: Dictionary = layout.rooms[room_id]
		var vent_position = place_vent(container, room_id, layout.to_global(data["position"]), data["size"], occupied)
		if vent_position != null and encounters != null and encounters.has_method("register_room_vent"):
			encounters.register_room_vent(room_id, vent_position)


func decorate_phase3(endgame: Node2D) -> void:
	var container := new_container(endgame, "Decor")
	var occupied := collect_occupied(endgame, container)
	var step: float = endgame.room_size.x + endgame.corridor_length
	for i in PHASE3.size():
		var center: Vector2 = endgame.to_global(Vector2(step * i, 0.0))
		var size: Vector2 = endgame.control_room_size() if i == 1 and endgame.has_method("control_room_size") else endgame.room_size
		place_room(container, "Phase3_%d" % (i + 1), center, size, PHASE3[i], occupied)
	dress_explorer_ship(endgame)


func place_room(container: Node2D, room_id: String, center: Vector2, room_size: Vector2, specs: Array, occupied: Array) -> void:
	var inner := Rect2(center - room_size / 2.0, room_size).grow(-WALL_INSET)
	for spec in specs:
		var kind: String = spec[0]
		var prop_size: Vector2 = spec[2]
		var solid: bool = spec[3]
		var offset: Vector2 = spec[1]
		var forced: bool = spec.size() > 5 and spec[5]
		# Encostado a uma parede de cima/baixo desliza em x; às dos lados, em y.
		var touches_side: bool = abs(offset.x) + prop_size.x / 2.0 >= room_size.x / 2.0 - WALL_INSET - 1.0
		var touches_top: bool = abs(offset.y) + prop_size.y / 2.0 >= room_size.y / 2.0 - WALL_INSET - 1.0
		var axis := Vector2(0, 1) if touches_side and not touches_top else Vector2(1, 0)
		var rect := Rect2()
		var blocker := ""
		for slide in SLIDES:
			var pos: Vector2 = center + offset + axis * slide
			pos.x = clamp(pos.x, inner.position.x + prop_size.x / 2.0, inner.end.x - prop_size.x / 2.0)
			pos.y = clamp(pos.y, inner.position.y + prop_size.y / 2.0, inner.end.y - prop_size.y / 2.0)
			rect = Rect2(pos - prop_size / 2.0, prop_size)
			blocker = "" if forced else find_blocker(rect, solid, occupied)
			if blocker == "":
				break
		if blocker != "":
			skipped.append({"room": room_id, "kind": kind, "rect": rect, "because": blocker})
			continue
		var pos := rect.get_center()
		var prop := Props.make(kind, prop_size, solid, spec[4])
		set_prop_depth(prop, kind, prop_size)
		container.add_child(prop)
		prop.global_position = pos
		placed.append({"room": room_id, "kind": kind, "rect": rect, "solid": solid, "node": prop})
		if solid:
			occupied.append({"rect": rect, "important": false, "door": false, "what": "decor " + kind})


# Profundidade (depth_sort.gd): o que fica no chão está sempre por baixo do
# Player e do Atlas; o resto é ordenado pela base (o fundo do retângulo), para
# as personagens passarem por trás e pela frente dos objetos.
func set_prop_depth(prop: Node2D, kind: String, prop_size: Vector2) -> void:
	if Props.is_floor_kind(kind):
		DepthSort.set_floor(prop)
	else:
		DepthSort.register(prop, prop_size.y / 2.0)


# Conduta da criatura na sala: fica no chão, longe de terminais, esconderijos
# e entradas, e os objetos postos depois afastam-se dela. Devolve a posição
# global (ou null se não houver sítio livre).
func place_vent(container: Node2D, room_id: String, center: Vector2, room_size: Vector2, occupied: Array):
	var inner := Rect2(center - room_size / 2.0, room_size).grow(-WALL_INSET)
	# De preferência também fica fora dos objetos de chão (manchas, cabos...).
	var floor_items: Array = []
	for item in placed:
		if item["room"] == room_id and Props.is_floor_kind(item["kind"]):
			floor_items.append(item)
	var strict := occupied.duplicate()
	for item in floor_items:
		strict.append({"rect": item["rect"], "important": true, "door": false, "what": "decor " + item["kind"]})
	# Primeiro os sítios preferidos; se estiverem todos ocupados, uma grelha
	# pela sala, do mais perto do primeiro sítio para o mais longe.
	var candidates: Array = []
	for spot in VENT_SPOTS:
		candidates.append(center + spot * room_size)
	var grid: Array = []
	# Passo fino: em salas cheias o único sítio livre pode ser estreito.
	var step := 8.0
	var x := inner.position.x + VENT_SIZE.x / 2.0
	while x <= inner.end.x - VENT_SIZE.x / 2.0:
		var y := inner.position.y + VENT_SIZE.y / 2.0
		while y <= inner.end.y - VENT_SIZE.y / 2.0:
			grid.append(Vector2(x, y))
			y += step
		x += step
	var first: Vector2 = candidates[0]
	grid.sort_custom(func(a, b): return a.distance_to(first) < b.distance_to(first))
	candidates.append_array(grid)
	# Se só houver sítio por cima de objetos de chão, esses saem. Nunca fica à
	# entrada de um corredor: é sólida e fecharia a passagem.
	var found := false
	var rect := Rect2()
	for attempt in [[strict, VENT_CLEARANCE], [occupied, VENT_CLEARANCE], [occupied, VENT_CLEARANCE_TIGHT]]:
		var taken: Array = attempt[0]
		for candidate in candidates:
			var pos: Vector2 = candidate
			pos.x = clamp(pos.x, inner.position.x + VENT_SIZE.x / 2.0, inner.end.x - VENT_SIZE.x / 2.0)
			pos.y = clamp(pos.y, inner.position.y + VENT_SIZE.y / 2.0, inner.end.y - VENT_SIZE.y / 2.0)
			rect = Rect2(pos - VENT_SIZE / 2.0, VENT_SIZE)
			if vent_blocker(rect, taken, attempt[1]) == "":
				found = true
				break
		if found:
			break
	if found:
		for item in floor_items:
			if rect.grow(VENT_CLEARANCE).intersects(item["rect"]):
				placed.erase(item)
				replaced_by_vents.append({"room": room_id, "kind": item["kind"]})
				item["node"].queue_free()
		var pos := rect.get_center()
		var vent := CreatureActor.make_vent()
		vent.name = "Vent_" + room_id
		container.add_child(vent)
		vent.global_position = pos
		vents.append({"room": room_id, "rect": rect, "node": vent})
		occupied.append({"rect": rect, "important": true, "door": false, "what": "conduta"})
		return pos
	skipped.append({"room": room_id, "kind": "vent_creature", "rect": Rect2(), "because": "sem sítio livre"})
	return null


func vent_blocker(rect: Rect2, taken: Array, clearance: float = VENT_CLEARANCE) -> String:
	for item in taken:
		if rect.grow(clearance).intersects(item["rect"]):
			return item["what"]
	return ""


func new_container(parent: Node, container_name: String) -> Node2D:
	var container := Node2D.new()
	container.name = container_name
	parent.add_child(container)
	return container


# O que impede um objeto de ficar ali ("" = nada).
# Objetos de chão só se afastam do que é importante (terminais, gatilhos,
# esconderijos, personagens); os sólidos afastam-se de tudo.
func find_blocker(rect: Rect2, solid: bool, occupied: Array) -> String:
	for item in occupied:
		if not solid and not item["important"]:
			continue
		if rect.grow(CLEARANCE).intersects(item["rect"]):
			return item["what"]
	return ""


# Tudo o que já existe numa zona: retângulos globais.
func collect_occupied(area: Node, skip: Node) -> Array:
	var out: Array = []
	for body in get_tree().get_nodes_in_group("character_sprite_body"):
		if body is Node2D:
			out.append({"rect": Rect2(body.global_position - Vector2(40, 60), Vector2(80, 90)), "important": true, "door": false, "what": String(body.name)})
	walk(area, skip, out)
	return out


func walk(node: Node, skip: Node, out: Array) -> void:
	if node == skip or node is CharacterBody2D or node is CanvasLayer:
		return
	var node_name := String(node.name)
	if node_name == "GeneratedWalls" or node_name == "WallCollision" or node_name.begins_with("Limite_"):
		return
	# Zonas que só dizem em que sala o Player está ocupam a sala inteira.
	if node_name.begins_with("RoomTrigger_"):
		return
	if node is CollisionShape2D and node.shape != null and not node.disabled:
		var owner_body := node.get_parent()
		var important: bool = owner_body is Area2D
		var rect := shape_rect(node)
		# As zonas "[E]" das portas são grandes; a passagem em si fica livre
		# pela regra dos corredores (em baixo) e pela colisão da porta.
		var door_zone: bool = important and String(owner_body.name).begins_with("Door_")
		if not door_zone and not (important and rect.get_area() > BIG_TRIGGER_AREA):
			out.append({"rect": rect, "important": important, "door": false, "what": String(owner_body.name)})
	elif node is Polygon2D and node.polygon.size() >= 3:
		var parent_name := String(node.get_parent().name)
		if parent_name.begins_with("Corridor_") or parent_name.begins_with("Corredor_"):
			# A entrada do corredor fica livre até DOOR_REACH píxeis para dentro
			# da sala, com folga dos lados.
			var corridor := global_bounds(node)
			if corridor.size.y > corridor.size.x:
				corridor = corridor.grow_individual(DOOR_CLEARANCE, DOOR_REACH, DOOR_CLEARANCE, DOOR_REACH)
			else:
				corridor = corridor.grow_individual(DOOR_REACH, DOOR_CLEARANCE, DOOR_REACH, DOOR_CLEARANCE)
			out.append({"rect": corridor, "important": false, "door": true, "what": "corredor " + parent_name})
		elif not node_name in ["Floor", "Border", "Ground"] and node.color.a > 0.05:
			out.append({"rect": global_bounds(node), "important": true, "door": false, "what": parent_name})
	elif node is Sprite2D or node is AnimatedSprite2D:
		var size: Vector2 = Vector2(80, 80)
		if node is Sprite2D and node.texture != null:
			size = node.texture.get_size() * node.global_scale.abs()
		out.append({"rect": Rect2(node.global_position - size / 2.0, size), "important": true, "door": false, "what": String(node.get_parent().name)})
	for child in node.get_children():
		walk(child, skip, out)


static func shape_rect(collision: CollisionShape2D) -> Rect2:
	var local: Rect2 = collision.shape.get_rect()
	var xf := collision.global_transform
	var rect := Rect2(xf * local.position, Vector2.ZERO)
	for corner in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		rect = rect.expand(xf * corner)
	return rect


static func global_bounds(poly: Polygon2D) -> Rect2:
	var xf := poly.global_transform
	var rect := Rect2(xf * (poly.polygon[0] + poly.offset), Vector2.ZERO)
	for p in poly.polygon:
		rect = rect.expand(xf * (p + poly.offset))
	return rect


# ---------------------------------------------------------------------------
# Naves
# ---------------------------------------------------------------------------

func dress_explorer_ship(endgame: Node2D) -> void:
	var ship := endgame.get_node_or_null("Nave_Explorador")
	if ship == null or ship.get_node_or_null("ShipArt") != null:
		return
	var hull := ship.get_node_or_null("PlaceholderVisual")
	if hull is CanvasItem:
		hull.visible = false
	var art := ShipArt.make("explorador", Vector2(380.0, 150.0))
	# Sem z próprio: a nave (Nave_Explorador) é ordenada pelo depth_sort.gd.
	ship.add_child(art)
	# Agora a nave é sólida: o Player e o Atlas já não passam por cima.
	var body := StaticBody2D.new()
	body.name = "Solid"
	var collision := CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([Vector2(-170, -60), Vector2(60, -75), Vector2(190, 0), Vector2(60, 75), Vector2(-170, 60)])
	body.add_child(collision)
	ship.add_child(body)


func dress_nave47(ship_body: Node2D) -> void:
	var hull := ship_body.get_node_or_null("Ship")
	if not hull is Polygon2D or ship_body.get_node_or_null("ShipArt") != null:
		return
	var bounds := global_bounds(hull)
	hull.visible = false
	var art := ShipArt.make("nave47", bounds.size)
	ship_body.add_child(art)
	art.global_position = bounds.get_center()


# ---------------------------------------------------------------------------
# Superfície
# ---------------------------------------------------------------------------

const SURFACE_AREA := Rect2(-3000.0, -1700.0, 4600.0, 3300.0)
# Na superfície tudo é sólido (pedido do utilizador, 25/10): rochas,
# pedregulhos, cristais, pedrinhas e chapas da nave. Só o rasto do despiste,
# que é uma marca no chão por trás da nave, se pode pisar.
const SURFACE_ITEMS := [["rock", 22, Vector2(40, 30), Vector2(80, 60), true], ["boulder", 9, Vector2(110, 80), Vector2(170, 120), true], ["crystal", 10, Vector2(50, 60), Vector2(80, 100), true], ["pebbles", 16, Vector2(60, 40), Vector2(110, 70), true]]


func decorate_surface() -> void:
	var ground := root.get_node_or_null("Ground")
	if not ground is Polygon2D:
		return
	dress_discoveries()
	var container := Node2D.new()
	container.name = "SurfaceDecor"
	root.add_child(container)
	# Logo a seguir ao chão: tudo o resto (nave, peças, porta) fica por cima.
	root.move_child(container, ground.get_index() + 1)
	var ground_points := PackedVector2Array()
	for p in ground.polygon:
		ground_points.append(ground.global_transform * p)
	var occupied: Array = []
	for child in root.get_children():
		if child == container or child == ground or child.name in ["UndergroundRoot", "Endgame", "UI"]:
			continue
		walk(child, container, occupied)
	for body in get_tree().get_nodes_in_group("character_sprite_body"):
		occupied.append({"rect": Rect2(body.global_position - Vector2(120, 120), Vector2(240, 240)), "important": true, "door": false, "what": String(body.name)})

	var ship := root.get_node_or_null("Ship")
	if ship is Node2D:
		var hull := ship.get_node_or_null("Ship")
		if hull is Polygon2D:
			var bounds := global_bounds(hull)
			# Rasto do despiste atrás da nave e chapas soltas à volta.
			add_surface_prop(container, "skid", Rect2(bounds.position.x - 760.0, bounds.get_center().y - 120.0, 780.0, 240.0), false, 0, occupied, ground_points, true)
			var plates := [Vector2(-1.3, 0.7), Vector2(-1.25, -0.8), Vector2(1.25, 1.0), Vector2(-0.3, 1.6), Vector2(0.4, -1.6)]
			for i in plates.size():
				var center: Vector2 = bounds.get_center() + plates[i] * bounds.size / 2.0
				add_surface_prop(container, "plate", Rect2(center - Vector2(36, 24), Vector2(72, 48)), true, i, occupied, ground_points)
		dress_nave47(ship)

	var random := RandomNumberGenerator.new()
	random.seed = 47
	for item in SURFACE_ITEMS:
		var count: int = item[1]
		var made := 0
		var tries := 0
		while made < count and tries < count * 12:
			tries += 1
			var size := Vector2(random.randf_range(item[2].x, item[3].x), random.randf_range(item[2].y, item[3].y))
			var pos := Vector2(random.randf_range(SURFACE_AREA.position.x, SURFACE_AREA.end.x), random.randf_range(SURFACE_AREA.position.y, SURFACE_AREA.end.y))
			if add_surface_prop(container, item[0], Rect2(pos - size / 2.0, size), item[4], made, occupied, ground_points):
				made += 1


func add_surface_prop(container: Node2D, kind: String, rect: Rect2, solid: bool, variant: int, occupied: Array, ground_points: PackedVector2Array, force: bool = false) -> bool:
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if not Geometry2D.is_point_in_polygon(corner, ground_points):
			return false
	if not force:
		var blocker := find_blocker(rect.grow(solid_margin(solid)), true, occupied)
		if blocker != "":
			skipped.append({"room": "Surface", "kind": kind, "rect": rect, "because": blocker})
			return false
	var prop := Props.make(kind, rect.size, solid, variant)
	set_prop_depth(prop, kind, rect.size)
	container.add_child(prop)
	prop.global_position = rect.get_center()
	placed.append({"room": "Surface", "kind": kind, "rect": rect, "solid": solid, "node": prop})
	if solid or not Props.is_floor_kind(kind):
		occupied.append({"rect": rect, "important": false, "door": false, "what": "decor " + kind})
	return true


# As duas descobertas da superfície (AncientSculpture e UnknownDebris)
# eram polígonos de 7 a 20 píxeis. Ganham um desenho a condizer com o resto
# (decor_props.gd), ordenado pelos pés e com uma colisão só na base: o
# Player e o Atlas passam por trás e pela frente, mas não por cima. O nó e a
# posição não mudam (o scan do Atlas continua a encontrá-los pelo nome).
const DISCOVERY_ART := {"AncientSculpture": ["sculpture", Vector2(52, 76)], "UnknownDebris": ["debris", Vector2(100, 60)]}


func dress_discoveries() -> void:
	for node_name in DISCOVERY_ART:
		var discovery := root.get_node_or_null(node_name)
		if not discovery is Node2D or discovery.get_node_or_null("Art") != null:
			continue
		var kind: String = DISCOVERY_ART[node_name][0]
		var art_size: Vector2 = DISCOVERY_ART[node_name][1]
		var old := discovery.get_node_or_null("Polygon2D")
		if old is CanvasItem:
			old.visible = false
		var art := Props.make(kind, art_size, false)
		art.name = "Art"
		# Os pés do desenho (8 a 12% acima do fundo) ficam na posição do nó.
		var foot := art_size.y * (0.42 if kind == "sculpture" else 0.38)
		art.position = Vector2(0.0, -foot)
		discovery.add_child(art)
		DepthSort.register(art, foot)
		var body := StaticBody2D.new()
		body.name = "Solid"
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(art_size.x * 0.75, art_size.y * 0.22)
		collision.shape = shape
		collision.position = Vector2(0.0, -shape.size.y / 2.0 + 4.0)
		body.add_child(collision)
		discovery.add_child(body)


# Na superfície as rochas grandes ficam mais afastadas de tudo, para nunca
# fecharem um caminho.
func solid_margin(solid: bool) -> float:
	return 60.0 if solid else 0.0
