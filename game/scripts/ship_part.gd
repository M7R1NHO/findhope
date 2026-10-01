extends Area2D


@export var part_id: String = "ship_part_01"
@export var display_name: String = "Peça da Nave 47"


var collected: bool = false


func examine():
	if collected:
		return

	var manager = (
		get_parent()
		.get_node_or_null(
			"ShipPartsManager"
		)
	)

	if manager == null:
		push_warning(
			"ShipPartsManager não encontrado."
		)

		return

	var success = manager.collect_part(
		part_id,
		display_name
	)

	if not success:
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
