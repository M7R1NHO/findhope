extends Node

# Banda sonora e volume (autoload "Music").
#
# Há uma única música (audio/music/find_hope_theme.ogg, original, gerada por
# ferramentas_ultimas/2_banda_sonora.py) em ciclo contínuo. Toca neste
# autoload, que não muda com as cenas: menu, jogo e finais ouvem sempre a
# mesma instância, sem recomeçar nem duplicar.
#
# Buses (default_bus_layout.tres): Master > Music (a banda sonora) e
# Master > SFX (para efeitos sonoros). O volume geral e o da música ficam
# no perfil (profile.options) e voltam ao abrir o jogo. São configuração
# técnica: o APAGAR PROGRESSO não os apaga.

const TRACK := "res://audio/music/find_hope_theme.ogg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
# Volume por omissão (0..1) de cada controlo.
const DEFAULTS := {"master": 0.8, "music": 0.5}
const BUS_FOR := {"master": "Master", "music": MUSIC_BUS}

var player: AudioStreamPlayer = null
var missing_track: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for kind in DEFAULTS:
		apply_volume(kind, get_volume(kind))
	player = AudioStreamPlayer.new()
	player.name = "Soundtrack"
	player.bus = MUSIC_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	var stream = load(TRACK) if ResourceLoader.exists(TRACK) else null
	if stream == null:
		missing_track = true
		push_warning("Banda sonora em falta: " + TRACK)
		return
	if "loop" in stream:
		stream.loop = true
	player.stream = stream
	player.play()


# Se o default_bus_layout.tres faltar, cria os buses aqui.
func ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func is_playing() -> bool:
	return player != null and player.playing


func get_volume(kind: String) -> float:
	var options = SaveManager.profile.get("options", {})
	if not options is Dictionary:
		options = {}
	return clampf(float(options.get("volume_" + kind, DEFAULTS.get(kind, 1.0))), 0.0, 1.0)


func apply_volume(kind: String, value: float) -> void:
	var index := AudioServer.get_bus_index(BUS_FOR.get(kind, "Master"))
	if index == -1:
		return
	value = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(max(value, 0.0001)))


# Muda o volume já (enquanto se arrasta o controlo). save = gravar no perfil.
func set_volume(kind: String, value: float, save: bool = true) -> void:
	apply_volume(kind, value)
	var options = SaveManager.profile.get("options", {})
	if not options is Dictionary:
		options = {}
	options["volume_" + kind] = clampf(value, 0.0, 1.0)
	SaveManager.profile["options"] = options
	if save:
		SaveManager.save_profile()
