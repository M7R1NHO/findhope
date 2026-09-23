extends Area2D


@export var interaction_distance: float = 90.0

var already_examined: bool = false


func can_interact(player_position: Vector2) -> bool:
	return global_position.distance_to(
		player_position
	) <= interaction_distance


func examine():
	if already_examined:
		return

	already_examined = true

	var main = get_parent()

	if main.has_method(
		"on_protocol_door_examined"
	):
		main.on_protocol_door_examined()
