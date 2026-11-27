@tool
extends Control

@export var status: String = "?":
	set(value):
		status = value
		if has_node("Label"):
			$Label.text = value + "!!"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
