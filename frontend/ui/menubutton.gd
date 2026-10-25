@tool
extends Control

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$TextureRect.texture = icon_texture
			
@export var text: String = "Button":
	set(value):
		text = value
		if is_node_ready():
			$Label.text = text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = text
	$TextureRect.texture = icon_texture


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			$NinePatchRect.modulate = Color(1.3, 1.3, 1.3, 1.0)
		if event.is_released():
			$NinePatchRect.modulate = Color(1.0, 1.0, 1.0, 1.0)
