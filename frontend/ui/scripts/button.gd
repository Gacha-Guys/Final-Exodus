@tool
extends Control

signal pressed
var held := false

@export var text: String = "Button":
	set(value):
		text = value
		if has_node("buttonLabel"):
			$buttonLabel.text = text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$buttonLabel.text = text


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			held = true
			$NinePatchRect.modulate = Color(1.3, 1.3, 1.3, 1.0)
		if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if held and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			held = false
			$NinePatchRect.modulate = Color(1.0, 1.0, 1.0, 1.0)
