extends CanvasLayer

signal signup_signal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%SignUpButton.pressed.connect(func():
		queue_free()
		signup_signal.emit()
	)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
