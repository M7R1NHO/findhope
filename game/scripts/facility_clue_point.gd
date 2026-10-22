
extends Area2D

@export_enum("laboratory", "archives", "sanctuary")
var clue_id: String = "laboratory"

@export var interaction_distance: float = 120.0

var player: Node2D = null
var atlas: Node = null
var analyzed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	player = current_scene.get_node_or_null("Player")
	atlas = current_scene.get_node_or_null("Atlas")


func _process(_delta: float) -> void:
	if player == null or atlas == null:
		return

	if analyzed:
		return

	if global_position.distance_to(player.global_position) > interaction_distance:
		return

	if Input.is_action_just_pressed("interact"):
		analyze_clue()


func analyze_clue() -> void:
	if analyzed or atlas == null:
		return

	if not atlas.has_method("register_facility_clue_analyzed"):
		push_warning("Atlas não suporta o registo de pistas.")
		return

	var success: bool = atlas.register_facility_clue_analyzed(clue_id)

	if not success:
		return

	analyzed = true
	print("PISTA ANALISADA: ", clue_id)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
