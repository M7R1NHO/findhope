extends Node

# Conquistas (autoload "Achievements").
#
# A lista é a do documento "Find Hope: Conquistas" (16 conquistas). Cada uma
# está ligada a um acontecimento real do jogo:
#   - a maioria a valores da run que o jogo já grava (SaveManager emite
#     run_value_changed sempre que um muda): formulário, descobertas,
#     PROTOCOL DOOR, primeiro encontro, Laboratório, Phase 3, combates...;
#   - as conversas com o Atlas contam respostas reais do /chat
#     (main.gd chama register_chat);
#   - os minijogos contam cada minijogo diferente concluído na run
#     (hack_manager.gd chama register_minigame);
#   - os finais contam os 16 finais diferentes (A1..D4) vistos
#     (save_manager.finish_completed_run chama register_ending).
#
# Ficam no perfil global (SaveManager.profile): não dependem da run, o NOVO
# JOGO não as apaga e cada uma só desbloqueia uma vez. Ao desbloquear aparece
# um aviso no canto do ecrã.

signal unlocked(id: String)

const COMUM := "COMUM"
const INCOMUM := "INCOMUM"
const RARO := "RARO"
const LENDARIO := "LENDÁRIO"

const CHATS_SMART := 7
const CHATS_PYSSOA := 20
const FIGHTS_IN_RUN := 5
const MINIGAMES := 9
const ENDINGS := 16

const LIST := [
	{"id": "soldado_nave_47", "title": "SOLDADO DA NAVE 47", "description": "Preenche o formulário pela primeira vez.", "rarity": COMUM},
	{"id": "android_inteligente", "title": "ANDROID INTELIGENTE", "description": "Conversa com o Atlas 7 vezes.", "rarity": COMUM, "goal": CHATS_SMART},
	{"id": "o_que_e_isso", "title": "O QUE É ISSO?", "description": "Encontra as duas descobertas da superfície.", "rarity": COMUM},
	{"id": "quebra_de_protocolo", "title": "QUEBRA DE PROTOCOLO", "description": "Faz o Atlas abrir a porta.", "rarity": COMUM},
	{"id": "nao_estamos_sozinhos", "title": "NÃO ESTAMOS SOZINHOS", "description": "Sobrevive ao primeiro encontro com a criatura.", "rarity": COMUM},
	{"id": "humano", "title": "HUMANO?", "description": "Descobre que a criatura era humana.", "rarity": COMUM},
	{"id": "plot_twist", "title": "PLOT TWIST", "description": "Descobre que o androide pediu ajuda.", "rarity": COMUM},
	{"id": "de_volta_a_missao", "title": "DE VOLTA À MISSÃO", "description": "Recupera as 6 peças e foge do planeta.", "rarity": INCOMUM},
	{"id": "poder_sonoro", "title": "PODER SONORO", "description": "Equipa o equipamento sonoro no Atlas.", "rarity": INCOMUM},
	{"id": "contra_ataque", "title": "CONTRA-ATAQUE", "description": "Vence uma luta.", "rarity": INCOMUM},
	{"id": "pyssoa", "title": "PYSSOA", "description": "Conversa com o Atlas 20 vezes.", "rarity": INCOMUM, "goal": CHATS_PYSSOA},
	{"id": "obrigado_por_jogar", "title": "OBRIGADO POR JOGAR", "description": "Termina o jogo uma vez.", "rarity": INCOMUM},
	{"id": "preso_comigo", "title": "VOCÊ QUE ESTÁ PRESO COMIGO!", "description": "Vence 5 lutas numa run.", "rarity": RARO, "goal": FIGHTS_IN_RUN},
	{"id": "me_sinto_melhor", "title": "ME SINTO MELHOR", "description": "Cura-te na sala de reparação.", "rarity": RARO},
	{"id": "mestre_hacker", "title": "MESTRE HACKER", "description": "Faz todos os 9 minijogos numa run.", "rarity": RARO, "goal": MINIGAMES},
	{"id": "eu_achei_esperanca", "title": "EU ACHEI ESPERANÇA", "description": "Obtém todos os finais.", "rarity": LENDARIO, "goal": ENDINGS},
]

const RARITY_COLORS := {
	COMUM: Color(0.78, 0.8, 0.83),
	INCOMUM: Color(0.42, 0.85, 0.45),
	RARO: Color(0.35, 0.65, 1.0),
	LENDARIO: Color(1.0, 0.78, 0.25),
}

# Os 16 finais que contam (o final offline "X0" e a saída antecipada não).
const ENDING_PATTERN := "^[ABCD][1-4]$"

var toast_queue: Array = []
var toast_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.run_value_changed.connect(_on_run_value_changed)


static func definition(id: String) -> Dictionary:
	for item in LIST:
		if item["id"] == id:
			return item
	return {}


func is_unlocked(id: String) -> bool:
	var entry = SaveManager.profile.get("achievements", {}).get(id)
	return entry is Dictionary and bool(entry.get("unlocked", false))


func unlocked_count() -> int:
	var count := 0
	for item in LIST:
		if is_unlocked(item["id"]):
			count += 1
	return count


# Desbloqueia uma vez. Devolve true só quando desbloqueou agora.
func unlock(id: String) -> bool:
	if definition(id).is_empty() or is_unlocked(id):
		return false
	SaveManager.register_achievement(id)
	print("CONQUISTA DESBLOQUEADA: ", id)
	unlocked.emit(id)
	show_toast(definition(id))
	return true


# ---------------------------------------------------------------------------
# Contadores
# ---------------------------------------------------------------------------

func profile_stats() -> Dictionary:
	var stats = SaveManager.profile.get("achievement_stats")
	if not stats is Dictionary:
		stats = {}
		SaveManager.profile["achievement_stats"] = stats
	return stats


func chat_count() -> int:
	return int(profile_stats().get("chat_messages", 0))


func endings_seen() -> Array:
	var seen = profile_stats().get("endings_seen", [])
	return seen if seen is Array else []


func minigames_done() -> Array:
	var done = SaveManager.get_run_value("stats", "minigames_done", []) if not SaveManager.active_run_data.is_empty() else []
	return done if done is Array else []


# Progresso [atual, objetivo] das conquistas com contador.
func progress(id: String) -> Array:
	var goal := int(definition(id).get("goal", 0))
	match id:
		"android_inteligente", "pyssoa":
			return [min(chat_count(), goal), goal]
		"eu_achei_esperanca":
			return [min(endings_seen().size(), goal), goal]
		"preso_comigo":
			var fights := 0 if SaveManager.active_run_data.is_empty() else int(SaveManager.get_run_value("stats", "fights_won", 0))
			return [min(fights, goal), goal]
		"mestre_hacker":
			return [min(minigames_done().size(), goal), goal]
	return [0, 0]


# Uma resposta real do Atlas no chat (main.gd, depois de um /chat com êxito).
func register_chat() -> void:
	var stats := profile_stats()
	stats["chat_messages"] = chat_count() + 1
	SaveManager.save_profile()
	if chat_count() >= CHATS_SMART:
		unlock("android_inteligente")
	if chat_count() >= CHATS_PYSSOA:
		unlock("pyssoa")


# Um minijogo concluído (hack_manager.finish_success). Conta tipos diferentes.
func register_minigame(hack_id: int) -> void:
	if hack_id < 1 or SaveManager.active_run_data.is_empty():
		return
	var done := minigames_done().duplicate()
	if not hack_id in done:
		done.append(hack_id)
		SaveManager.set_run_value("stats", "minigames_done", done)
	if done.size() >= MINIGAMES:
		unlock("mestre_hacker")


# Um final completo (save_manager.finish_completed_run).
func register_ending(ending_id: String) -> void:
	unlock("obrigado_por_jogar")
	var regex := RegEx.create_from_string(ENDING_PATTERN)
	if regex.search(ending_id) == null:
		return
	var seen := endings_seen().duplicate()
	if not ending_id in seen:
		seen.append(ending_id)
		profile_stats()["endings_seen"] = seen
		SaveManager.save_profile()
	if seen.size() >= ENDINGS:
		unlock("eu_achei_esperanca")


func _on_run_value_changed(section: String, key: String, value) -> void:
	var on: bool = value is bool and value
	match section + "." + key:
		"story.application_form_completed":
			if on: unlock("soldado_nave_47")
		"story.unknown_debris_discovered", "story.ancient_sculpture_discovered":
			if bool(SaveManager.get_run_value("story", "unknown_debris_discovered", false)) and bool(SaveManager.get_run_value("story", "ancient_sculpture_discovered", false)):
				unlock("o_que_e_isso")
		"story.protocol_door_opened":
			if on: unlock("quebra_de_protocolo")
		"story.hide_initial_complete":
			if on: unlock("nao_estamos_sozinhos")
		"story.creature_human_origin_discovered":
			if on: unlock("humano")
		"world.phase3_twist_stage":
			if int(value) >= 3: unlock("plot_twist")
		"story.early_exit_ending":
			if on: unlock("de_volta_a_missao")
		"story.sonic_equipment_connected":
			if on: unlock("poder_sonoro")
		"stats.fights_won":
			if int(value) >= 1: unlock("contra_ataque")
			if int(value) >= FIGHTS_IN_RUN: unlock("preso_comigo")
		"stats.maintenance_used":
			if int(value) >= 1: unlock("me_sinto_melhor")


# ---------------------------------------------------------------------------
# Aviso no ecrã
# ---------------------------------------------------------------------------

func show_toast(item: Dictionary) -> void:
	toast_queue.append(item)
	if toast_queue.size() == 1:
		_show_next_toast()


func _show_next_toast() -> void:
	if toast_queue.is_empty():
		return
	var item: Dictionary = toast_queue[0]
	if toast_layer == null or not is_instance_valid(toast_layer):
		toast_layer = CanvasLayer.new()
		toast_layer.name = "AchievementToast"
		toast_layer.layer = 1500
		toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(toast_layer)
	var color: Color = RARITY_COLORS.get(item["rarity"], Color.WHITE)
	var panel := PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.96)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := Label.new()
	head.text = "CONQUISTA DESBLOQUEADA · " + str(item["rarity"])
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", color)
	box.add_child(head)
	var title := Label.new()
	title.text = str(item["title"])
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var description := Label.new()
	description.text = str(item["description"])
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.62, 0.68, 0.74))
	box.add_child(description)
	toast_layer.add_child(panel)
	panel.custom_minimum_size = Vector2(340, 0)
	var width := 340.0
	var view := get_viewport().get_visible_rect().size
	panel.position = Vector2(view.x + 10.0, 20.0)
	var tween := panel.create_tween()
	tween.tween_property(panel, "position:x", view.x - width - 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.2)
	tween.tween_property(panel, "position:x", view.x + 10.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		panel.queue_free()
		toast_queue.pop_front()
		_show_next_toast())
