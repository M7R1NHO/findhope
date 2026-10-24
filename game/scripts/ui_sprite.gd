extends TextureRect

# Sprite animado para ecrãs de interface (encontro, fuga, luta, Game Over).
# Usa as mesmas frames do mundo (character_frames.gd).

const CharacterFrames := preload("res://scripts/character_frames.gd")

var frames: SpriteFrames = null
var animation: String = ""
var frame_index: int = 0
var frame_time: float = 0.0


static func make(character: String, animation_name: String, height: float, flip: bool = false) -> TextureRect:
	var sprite_frames := CharacterFrames.frames_for(character)
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return null
	var rect = load("res://scripts/ui_sprite.gd").new()
	rect.name = character.capitalize() + "Sprite"
	rect.frames = sprite_frames
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.flip_h = flip
	rect.process_mode = Node.PROCESS_MODE_ALWAYS
	var first := sprite_frames.get_frame_texture(animation_name, 0)
	rect.custom_minimum_size = Vector2(height * first.get_width() / first.get_height(), height)
	rect.play(animation_name)
	return rect


func play(animation_name: String) -> void:
	if frames == null or not frames.has_animation(animation_name) or animation == animation_name:
		return
	animation = animation_name
	frame_index = 0
	frame_time = 0.0
	texture = frames.get_frame_texture(animation, 0)


func _process(delta: float) -> void:
	if frames == null or animation.is_empty():
		return
	var count := frames.get_frame_count(animation)
	if count <= 1:
		return
	frame_time += delta
	var step := 1.0 / frames.get_animation_speed(animation)
	if frame_time >= step:
		frame_time -= step
		frame_index += 1
		if frame_index >= count:
			frame_index = 0 if frames.get_animation_loop(animation) else count - 1
		texture = frames.get_frame_texture(animation, frame_index)
