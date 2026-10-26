extends RefCounted

# Texto do Diário do Android (Bíblia 6.4): alguns parágrafos escritos do
# ponto de vista do Atlas daquela run, gerados UMA vez no fim da run a partir
# dos factos reais guardados no diário (save_manager.build_android_diary) e
# depois nunca mais alterados.
#
# É determinístico: os mesmos factos dão sempre o mesmo texto. Não inventa
# acontecimentos: cada frase só aparece se o facto correspondente existir.

const OUTCOME_TITLES := {"A": "Fuga", "B": "Sozinho", "C": "Resgate", "D": "Sacrifício"}


# Devolve {"title": ..., "paragraphs": [...]}.
static func write(diary: Dictionary) -> Dictionary:
	var name := player_name(diary)
	var paragraphs: Array = []
	paragraphs.append(opening(diary, name))
	var surface := surface_paragraph(diary, name)
	if surface != "":
		paragraphs.append(surface)
	var underground := underground_paragraph(diary, name)
	if underground != "":
		paragraphs.append(underground)
	paragraphs.append(bond_paragraph(diary, name))
	paragraphs.append(ending_paragraph(diary, name))
	return {"title": diary_title(diary), "paragraphs": paragraphs}


static func diary_title(diary: Dictionary) -> String:
	var ending: Dictionary = diary.get("ending", {})
	var title := str(ending.get("title", "")).strip_edges()
	if title == "":
		title = OUTCOME_TITLES.get(outcome_of(diary), "Registo")
	return title


static func player_name(diary: Dictionary) -> String:
	var profile: Dictionary = diary.get("player_profile", {})
	var name := str(profile.get("name", "")).strip_edges()
	return name if name != "" else "o tripulante"


static func outcome_of(diary: Dictionary) -> String:
	var ending: Dictionary = diary.get("ending", {})
	var outcome := str(ending.get("outcome", ""))
	if outcome == "":
		outcome = str(diary.get("final", {}).get("outcome", ""))
	return outcome


static func stat(diary: Dictionary, key: String) -> int:
	return int(diary.get("stats", {}).get(key, 0))


static func fact(diary: Dictionary, key: String, default = null):
	return diary.get("facts", {}).get(key, default)


# Relação do Atlas com o jogador: warm, neutral ou cold (a mesma regra dos
# finais em backend/endings.py: (confiança + afinidade) / 2 - irritação).
static func bond_kind(diary: Dictionary) -> String:
	var relation: Dictionary = diary.get("atlas", {}).get("relationship", {}).get("atlas_to_player", {})
	if relation.is_empty():
		return "neutral"
	var bond := (float(relation.get("trust", 50)) + float(relation.get("affinity", 50))) / 2.0 - float(relation.get("irritation", 0))
	if bond >= 62.0:
		return "warm"
	if bond <= 38.0:
		return "cold"
	return "neutral"


# Só a primeira letra (capitalize() estragava nomes como "da Silva").
static func upper_first(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func times(count: int) -> String:
	return "uma vez" if count == 1 else "%d vezes" % count


static func opening(diary: Dictionary, name: String) -> String:
	var date := str(diary.get("started_at", diary.get("created_at", ""))).split("T")[0]
	var text := "Registo pessoal da unidade Atlas"
	if date != "":
		text += ", iniciado a " + date
	text += ". A Nave 47 caiu num planeta de areia amarela e eu acordei com um único tripulante a meu cargo: " + name + "."
	match bond_kind(diary):
		"warm":
			text += " Ao princípio era só mais um nome no formulário da missão. Não ficou assim por muito tempo."
		"cold":
			text += " Registei-o como protocolo manda. Esperava um tripulante; encontrei alguém difícil de prever."
		_:
			text += " O meu dever era simples: mantê-lo vivo e levá-lo de volta à missão Find Hope."
	return text


static func surface_paragraph(diary: Dictionary, name: String) -> String:
	var parts: Array = []
	var debris := bool(fact(diary, "unknown_debris_discovered", false))
	var sculpture := bool(fact(diary, "ancient_sculpture_discovered", false))
	if debris and sculpture:
		parts.append("Na superfície encontrámos uma escultura antiga, com a forma de alguém de pé a segurar um capacete, e destroços de um metal que não pertencia a nenhuma nave que eu conhecesse.")
	elif debris:
		parts.append("Na superfície encontrámos destroços de um metal que não pertencia a nenhuma nave que eu conhecesse.")
	elif sculpture:
		parts.append("Na superfície encontrámos uma escultura antiga, gasta pela areia.")
	var insistence := int(fact(diary, "protocol_door_insistence", 0))
	if bool(fact(diary, "protocol_door_opened", false)):
		if insistence >= 5:
			parts.append("Diante da PROTOCOL DOOR, " + name + " pediu-me " + times(insistence) + ", sempre com respeito e com razões diferentes, que a abrisse. O protocolo dizia que não. À quinta vez percebi que o protocolo não era a única voz que eu devia ouvir, e abri-a.")
		else:
			parts.append("Diante da PROTOCOL DOOR, escolhi quebrar o protocolo e abri-la.")
	if parts.is_empty():
		return ""
	return " ".join(parts)


static func underground_paragraph(diary: Dictionary, name: String) -> String:
	var parts: Array = []
	var hides := stat(diary, "hides_success")
	var caught := stat(diary, "hides_failed")
	if hides > 0 or caught > 0 or bool(fact(diary, "hide_initial_complete", false)):
		var text := "Debaixo da superfície não estávamos sozinhos. Uma criatura caçava nos corredores"
		if hides > 0:
			text += ", e escondemo-nos dela " + times(hides)
		parts.append(text + ".")
	if bool(fact(diary, "creature_human", false)):
		parts.append("Mais tarde, no Laboratório, os registos mostraram-me o que eu não queria saber: aquela criatura tinha sido humana.")
	var hacks := stat(diary, "hacks_success")
	if hacks > 0:
		parts.append("Abri " + ("um sistema" if hacks == 1 else "%d sistemas" % hacks) + " da instalação enquanto " + name + " vigiava as portas.")
	var fights := stat(diary, "fights_won")
	if bool(fact(diary, "sonic_equipment_connected", false)):
		if fights > 0:
			parts.append("Com o equipamento sonoro ligado ao meu corpo, deixámos de só fugir: enfrentámos a criatura e vencemos " + times(fights) + ".")
		else:
			parts.append("Ligaram-me um equipamento sonoro, mas nunca precisámos de lutar com ele.")
	if stat(diary, "maintenance_used") > 0:
		parts.append("Na sala de reparação, " + name + " esperou que eu recuperasse. Anotei isso.")
	if parts.is_empty():
		return ""
	return " ".join(parts)


static func bond_paragraph(diary: Dictionary, name: String) -> String:
	var atlas: Dictionary = diary.get("atlas", {})
	var stage := int(atlas.get("narrative_stage", 0))
	var autonomy := int(atlas.get("autonomy", {}).get("autonomy", 0))
	var text := ""
	match bond_kind(diary):
		"warm":
			text = "Confiei em " + name + ". Não por cálculo: porque cada vez que eu hesitava, voltava para trás por mim."
		"cold":
			text = "Nunca confiei totalmente em " + name + ". Cumpri o meu dever, mas guardei cada palavra dura que me disse."
		_:
			text = "Entre mim e " + name + " ficou uma distância educada. Trabalhámos bem juntos; nenhum de nós disse mais do que precisava."
	if bool(fact(diary, "distress_revealed", false)) or stage >= 7:
		text += " Descobri que o desvio da Nave 47 não foi um erro: fui eu que respondi a um pedido de socorro de outro androide. Alguém como eu. Desde então não consigo pensar em mim só como uma unidade de navegação."
	elif autonomy >= 50:
		text += " Algures pelo caminho comecei a tomar decisões que nenhum protocolo me tinha dado."
	return text


static func ending_paragraph(diary: Dictionary, name: String) -> String:
	var ending: Dictionary = diary.get("ending", {})
	var text := ""
	match outcome_of(diary):
		"A":
			text = "Saí inteiro do confronto. Corremos os dois para a nave do explorador e deixámos o planeta juntos."
		"B":
			text = "Fiquei danificado no Hangar. " + upper_first(name) + " escolheu partir sozinho, e eu vi a luz dos motores desaparecer pelo teto aberto."
		"C":
			text = "Fiquei danificado no Hangar, mas " + name + " voltou atrás por mim e arrastou-me até à nave. Saímos os dois."
		"D":
			text = "Fiquei danificado no Hangar. " + upper_first(name) + " voltou atrás por mim e não sobreviveu ao resgate. Fiquei sozinho com este registo."
		_:
			text = "A missão terminou aqui."
	var lines: Array = []
	for line in ending.get("atlas_lines", []):
		var clean := str(line).strip_edges()
		if clean != "":
			lines.append(clean)
	if not lines.is_empty():
		text += " As últimas palavras que registei foram minhas: «" + " ".join(lines) + "»"
	return text + "\n\n— Atlas, unidade PYSSOA"
