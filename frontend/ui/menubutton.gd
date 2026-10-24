@tool
extends Control

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$Button.icon = icon_texture
			
@export var text: String = "Button":
	set(value):
		text = value
		if is_node_ready():
			$Button.text = text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.text = text
	$Button.icon = icon_texture


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
