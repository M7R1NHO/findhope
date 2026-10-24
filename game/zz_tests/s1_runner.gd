extends Node
func _ready():
	var t = load("res://zz_tests/s1_tests.gd").new()
	t.name = "S1Tests"
	get_tree().root.add_child.call_deferred(t)
