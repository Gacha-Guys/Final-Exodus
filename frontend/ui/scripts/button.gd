@tool
extends Control

@export var text: String = "Button":
	set(value):
		text = value
		if has_node("customButton"):
			$customButton.text = text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$customButton.text = text


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
