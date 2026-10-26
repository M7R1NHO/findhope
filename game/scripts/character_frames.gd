extends RefCounted

# Animações do Player, do Atlas e da criatura, montadas a partir dos PNG em
# res://sprites/characters/<personagem>/<linha>_<n>.png.
#
# As imagens foram recortadas das folhas de sprites do projeto (uma pasta por
# personagem, frame 0 = IDLE, frames 1 a 4 = WALK; "side" olha para a
# direita). As vistas que faltavam nas folhas (Player de lado, Atlas de
# costas e de lado) foram feitas no mesmo estilo pela ferramenta
# 3_vistas_em_falta.py. O Player de costas (back_0..4) vem do sprite enviado
# pelo utilizador em 25/10/2026 (ferramentas_ultimas/1_player_costas.py),
# com as passadas feitas como as de frente. Para trocar um sprite,
# basta substituir o PNG com o mesmo nome; o código não muda.
#
# Se uma pasta não existir, frames_for() devolve null e quem a usa mantém o
# visual antigo (o quadrado de cor).

const ROOT := "res://sprites/characters/"

# animação -> [ficheiros, fps, repetir]
const ANIMATIONS := {
	"player": {
		"idle_front": [["front_0"], 1.0, true],
		"walk_front": [["front_1", "front_2", "front_3", "front_4"], 8.0, true],
		"idle_back": [["back_0"], 1.0, true],
		"walk_back": [["back_1", "back_2", "back_3", "back_4"], 8.0, true],
		"idle_side": [["side_0"], 1.0, true],
		"walk_side": [["side_1", "side_2", "side_3", "side_4"], 8.0, true],
	},
	"atlas": {
		"idle_front": [["front_0"], 1.0, true],
		"walk_front": [["front_1", "front_2", "front_3", "front_4"], 8.0, true],
		"idle_back": [["back_0"], 1.0, true],
		"walk_back": [["back_1", "back_2", "back_3", "back_4"], 8.0, true],
		# De lado, o Atlas usa a mesma animação de andar para baixo (pedido
		# do utilizador, 25/10/2026); o character_sprite.gd vira-o para o lado
		# para onde anda e inclina-o um pouco nessa direção.
		"idle_side": [["front_0"], 1.0, true],
		"walk_side": [["front_1", "front_2", "front_3", "front_4"], 8.0, true],
	},
	"monster": {
		"idle_front": [["front_0"], 1.0, true],
		"walk_front": [["front_1", "front_2", "front_3", "front_4"], 7.0, true],
		"idle_back": [["back_0"], 1.0, true],
		"walk_back": [["back_1", "back_2", "back_3", "back_4"], 7.0, true],
		"walk_side": [["side_0", "side_1", "side_2", "side_1"], 7.0, true],
		"attack": [["side_3", "alert_0", "alert_1", "alert_0"], 8.0, true],
		"hurt": [["alert_2"], 1.0, false],
		"roar": [["alert_3", "alert_4"], 4.0, true],
	},
}

# Personagens cuja vista de lado reutiliza as frames de frente: inclinam-se
# para o lado do movimento (character_sprite.gd SIDE_LEAN).
const SIDE_FROM_FRONT := ["atlas"]

static var _cache: Dictionary = {}


static func frames_for(character: String) -> SpriteFrames:
	if _cache.has(character):
		return _cache[character]
	if not ANIMATIONS.has(character):
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ANIMATIONS[character]:
		var info: Array = ANIMATIONS[character][animation]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, info[1])
		frames.set_animation_loop(animation, info[2])
		for file_name in info[0]:
			var texture := texture_for(character, file_name)
			if texture == null:
				_cache[character] = null
				return null
			frames.add_frame(animation, texture)
	_cache[character] = frames
	return frames


static func texture_for(character: String, file_name: String) -> Texture2D:
	var path := ROOT + character + "/" + file_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("Sprite em falta: " + path)
		return null
	return load(path)


# Primeiro frame de uma animação (para desenhar com draw_texture).
static func first_texture(character: String, animation: String) -> Texture2D:
	var frames := frames_for(character)
	if frames == null or not frames.has_animation(animation):
		return null
	return frames.get_frame_texture(animation, 0)
