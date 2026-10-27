@tool
extends Control

@export var val: int = 0:
	set(value):
		val = value
		if has_node("NinePatchRect/MarginContainer2/Value"):
			$NinePatchRect/MarginContainer2/Value.text = str(val)

@export var texture: Texture2D:
	set(value):
		texture = value
		if has_node("NinePatchRect/MarginContainer/TextureRect"):
			$NinePatchRect/MarginContainer/TextureRect.texture = texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$NinePatchRect/MarginContainer2/Value.text = str(val)
	$NinePatchRect/MarginContainer/TextureRect.texture = texture


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
