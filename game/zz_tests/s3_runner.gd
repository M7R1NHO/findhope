extends Node
func _ready():
	var t = load("res://zz_tests/s3_tests.gd").new()
	t.name = "S3Tests"
	get_tree().root.add_child.call_deferred(t)
