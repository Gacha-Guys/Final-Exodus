@tool
extends Control

signal pressed;

var held := false

@export var item_name: String = "ItemName":
	set(value):
		item_name = value
		if has_node("itemLabel"):
			$itemLabel.text = item_name + " x" + str(item_count)

@export var item_count: int = 0:
	set(value):
		item_count = value
		if has_node("itemLabel"):
			$itemLabel.text = item_name + " x" + str(item_count)

@export var texture: Texture2D = null:
	set(value):
		texture = value
		if has_node("NinePatchRect/MarginContainer/TextureRect"):
			$NinePatchRect/MarginContainer/TextureRect.texture = texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$itemLabel.text = item_name + " x" + str(item_count)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			held = true
			$NinePatchRect.modulate = Color(1.1, 1.1, 1.1, 1.0)
		if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if held and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			held = false
			$NinePatchRect.modulate = Color(1.0, 1.0, 1.0, 1.0)
