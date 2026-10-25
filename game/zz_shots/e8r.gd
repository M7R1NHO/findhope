extends Node
func _ready():
	var t = load("res://zz_shots/e8.gd").new()
	get_tree().root.add_child.call_deferred(t)
