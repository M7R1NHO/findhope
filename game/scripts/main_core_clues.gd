extends RefCounted

# Pistas da palavra-passe do Núcleo Principal.
#
# Cada run sorteia uma das dez palavras. O Laboratório, os Arquivos e o
# Santuário mostram, cada um, uma pista diferente sobre a palavra sorteada.
# Nenhuma pista sozinha chega; as três juntas apontam para uma só palavra.
#
# O estado de cada terminal fica nos dados da run (secção "world"), para
# ser restaurado ao carregar um save ou depois de um Game Over.

const SAVE_SECTION := "world"
const PASSWORD_KEY := "main_core_password_word"
const SOLVED_KEY := "main_core_password_solved"
# Palavras erradas já tentadas no Núcleo (lista, sem repetidas).
const TRIED_KEY := "main_core_password_tried"
const MAX_ATTEMPTS := 3

const WORDS: Array[String] = [
	"ECO", "SOM", "NAVE", "ESPAÇO", "ANDROID",
	"HUMANO", "VIDA", "MORTE", "ESPERANÇA", "DESTINO"
]

const LOCATIONS: Array[String] = ["laboratory", "archives", "sanctuary"]

const LOCATION_NAMES := {
	"laboratory": "Laboratório",
	"archives": "Arquivos",
	"sanctuary": "Santuário",
}

# Chave da run e etapa final de cada terminal.
const STAGE_KEYS := {
	"laboratory": "laboratory_analysis_stage",
	"archives": "archives_stage",
	"sanctuary": "sanctuary_stage",
}

const FINAL_STAGES := {
	"laboratory": 3,
	"archives": 2,
	"sanctuary": 2,
}

# Laboratório: dados técnicos e científicos.
# Arquivos: registos e mensagens deixados pelas pessoas.
# Santuário: inscrições em forma de enigma.
const CLUES := {
	"laboratory": {
		"ECO": "Registo acústico 7: o impulso emitido no poço regressou 3,2 segundos depois, mais fraco, mas idêntico. Nenhuma fonte nova foi detetada.",
		"SOM": "Análise comportamental: o sujeito reage apenas a vibrações do ar entre 20 e 400 Hz. Na ausência delas, permanece imóvel.",
		"NAVE": "Amostras metálicas com marcas de reentrada atmosférica. A liga não foi produzida neste planeta.",
		"ESPAÇO": "Sensor externo: -270 °C, pressão nula. Nenhuma onda sonora se propaga no exterior.",
		"ANDROID": "Análise de tecido: nenhuma célula. Servomotores, circuitos e uma rede neural sintética sob a pele.",
		"HUMANO": "Amostra 12: ADN compatível com os registos da Terra. 46 cromossomas.",
		"VIDA": "Cultura B-3: as células continuam a dividir-se, apesar do frio e da falta de energia.",
		"MORTE": "Relatório final: atividade cerebral nula nos sujeitos 4 a 9. Sem sinais vitais.",
		"ESPERANÇA": "Nota junto ao microscópio: «Se a cultura sobreviver mais uma noite, talvez ainda exista cura.»",
		"DESTINO": "Cálculo de trajetória: rota fixada antes da partida. Nenhuma correção foi possível.",
	},
	"archives": {
		"ECO": "Diário de um técnico: «Na sala vazia, cada palavra que digo volta para mim. Já não sei se falo sozinho.»",
		"SOM": "Ordem de manutenção: «Desliguem todos os alarmes. O silêncio é a única proteção que nos resta.»",
		"NAVE": "Manifesto de carga: «Tripulação: 4. Combustível: 12%. Aterragem forçada no setor norte.»",
		"ESPAÇO": "Registo de missão: «Lá fora não há cima nem baixo. Só distância.»",
		"ANDROID": "Ficha de unidade: «Construído à imagem humana. Segue o protocolo. Não dorme, não come, não esquece.»",
		"HUMANO": "Lista de pessoal: «Investigadores: 31. Todos nascidos na Terra.»",
		"VIDA": "Diário de campo: «Encontrámos algo que respira, cresce e se reproduz. Não estamos sozinhos.»",
		"MORTE": "Último registo da enfermaria: «Ninguém respondeu à chamada. As camas estão todas vazias.»",
		"ESPERANÇA": "Última mensagem enviada: «Não desistam. Enquanto houver sinal, alguém virá buscar-nos.»",
		"DESTINO": "Registo de navegação: «O ponto final da viagem já estava escrito no plano de voo.»",
	},
	"sanctuary": {
		"ECO": "Inscrição: «Chamamos pela montanha e a montanha responde com a nossa própria voz.»",
		"SOM": "Inscrição: «Não tem forma nem cor, mas atravessa paredes e chega antes de nós.»",
		"NAVE": "Inscrição: «Vieram do céu dentro de uma casca de metal e nunca mais voltaram a subir.»",
		"ESPAÇO": "Inscrição: «Separa todas as coisas e, ainda assim, contém-nas a todas.»",
		"ANDROID": "Inscrição: «Tem rosto de homem e coração de máquina. Pergunta-se se pode escolher.»",
		"HUMANO": "Inscrição: «Erra, sangra e, mesmo assim, volta a tentar.»",
		"VIDA": "Inscrição: «Começa num sopro e é aquilo que todos tentam proteger.»",
		"MORTE": "Inscrição: «A única porta por onde todos passam e por onde nenhum regressa.»",
		"ESPERANÇA": "Inscrição: «É a última coisa a perder-se e dá nome a esta busca.»",
		"DESTINO": "Inscrição: «O lugar para onde caminhas, quer queiras, quer não.»",
	},
}


static func _save_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveManager")


# Sorteia a palavra da run, se ainda não existir, e devolve-a.
static func ensure_password_word() -> String:
	var manager := _save_manager()
	if manager == null:
		return WORDS[0]

	var saved := str(manager.get_run_value(SAVE_SECTION, PASSWORD_KEY, ""))
	if saved in WORDS:
		return saved

	var chosen: String = WORDS[randi_range(0, WORDS.size() - 1)]
	manager.set_run_value(SAVE_SECTION, PASSWORD_KEY, chosen)
	return chosen


static func get_password_word() -> String:
	return ensure_password_word()


static func get_clue(location: String) -> String:
	var by_word: Dictionary = CLUES.get(location, {})
	return str(by_word.get(get_password_word(), ""))


static func load_stage(location: String) -> int:
	var manager := _save_manager()
	if manager == null:
		return 0
	return int(manager.get_run_value(SAVE_SECTION, STAGE_KEYS[location], 0))


static func save_stage(location: String, stage: int) -> void:
	var manager := _save_manager()
	if manager != null:
		manager.set_run_value(SAVE_SECTION, STAGE_KEYS[location], stage)


static func is_clue_found(location: String) -> bool:
	return load_stage(location) >= int(FINAL_STAGES[location])


static func count_found() -> int:
	var total := 0
	for location in LOCATIONS:
		if is_clue_found(location):
			total += 1
	return total


# Texto com as pistas já recuperadas, para o terminal do Núcleo.
static func describe_found_clues() -> String:
	var lines: Array[String] = []
	for location in LOCATIONS:
		if is_clue_found(location):
			lines.append(str(LOCATION_NAMES[location]) + ": " + get_clue(location))
		else:
			lines.append(str(LOCATION_NAMES[location]) + ": (pista ainda não recuperada)")
	return "\n\n".join(lines)


static func is_password_solved() -> bool:
	var manager := _save_manager()
	if manager == null:
		return false
	return bool(manager.get_run_value(SAVE_SECTION, SOLVED_KEY, false))


# Palavras erradas já tentadas nesta run, pela ordem em que foram escritas.
static func get_tried_words() -> Array[String]:
	var result: Array[String] = []
	var manager := _save_manager()
	if manager == null:
		return result
	var saved = manager.get_run_value(SAVE_SECTION, TRIED_KEY, [])
	if saved is Array:
		for word in saved:
			if str(word) in WORDS and not str(word) in result:
				result.append(str(word))
	return result


static func add_tried_word(word: String) -> void:
	var manager := _save_manager()
	if manager == null:
		return
	var tried := get_tried_words()
	if not word in tried:
		tried.append(word)
	manager.set_run_value(SAVE_SECTION, TRIED_KEY, tried)


static func attempts_left() -> int:
	return maxi(0, MAX_ATTEMPTS - get_tried_words().size())
