extends Area2D


@export var part_id: String = "ship_part_01"
@export var display_name: String = "Peça da Nave 47"


var collected: bool = false
var parts_manager: Node = null


func _ready():
	add_to_group(
		"ship_part"
	)

	call_deferred(
		"resolve_parts_manager"
	)

	call_deferred(
		"sync_with_parts_manager"
	)


func resolve_parts_manager():
	var main = get_parent()

	if main == null:
		return

	parts_manager = main.get_node_or_null(
		"ShipPartsManager"
	)


func examine():
	if collected:
		return

	if parts_manager == null:
		resolve_parts_manager()

	if parts_manager == null:
		push_warning(
			"ShipPartsManager não encontrado."
		)

		return

	var success = parts_manager.collect_part(
		part_id,
		display_name
	)

	if not success:
		return

	mark_as_collected()


func sync_with_parts_manager():
	if parts_manager == null:
		resolve_parts_manager()

	if parts_manager == null:
		return

	if not parts_manager.has_method(
		"is_part_collected"
	):
		return

	var already_collected = (
		parts_manager.is_part_collected(
			part_id
		)
	)

	if already_collected:
		mark_as_collected()


func mark_as_collected():
	if collected:
		return

	collected = true

	set_deferred(
		"monitoring",
		false
	)

	set_deferred(
		"monitorable",
		false
	)

	var collision = get_node_or_null(
		"CollisionShape2D"
	)

	if collision != null:
		collision.set_deferred(
			"disabled",
			true
		)

	visible = false

	call_deferred(
		"queue_free"
	)
