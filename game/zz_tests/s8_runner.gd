extends Node
func _ready():
	var t = load("res://zz_tests/s8_tests.gd").new()
	t.name = "S8Tests"
	get_tree().root.add_child.call_deferred(t)
