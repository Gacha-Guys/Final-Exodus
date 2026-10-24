extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Title.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/login_screen.tscn"))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
