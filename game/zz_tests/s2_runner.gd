extends Node
func _ready():
	var t = load("res://zz_tests/s2_tests.gd").new()
	t.name = "S2Tests"
	get_tree().root.add_child.call_deferred(t)
