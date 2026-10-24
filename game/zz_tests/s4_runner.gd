extends Node
func _ready():
	var t = load("res://zz_tests/s4_tests.gd").new()
	t.name = "S4Tests"
	get_tree().root.add_child.call_deferred(t)
