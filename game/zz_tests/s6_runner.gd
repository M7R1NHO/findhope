extends Node
func _ready():
	var t = load("res://zz_tests/s6_tests.gd").new()
	t.name = "S6Tests"
	get_tree().root.add_child.call_deferred(t)
