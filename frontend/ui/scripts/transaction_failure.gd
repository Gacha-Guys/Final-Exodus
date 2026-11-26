extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.1, .1 ,.1, 0.9)
	%Panel.add_theme_stylebox_override("panel", style)
	
