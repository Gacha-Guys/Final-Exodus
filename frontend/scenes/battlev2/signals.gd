extends Node

const DAMAGE_NUMBER = preload("res://scenes/battlev2/status.tscn")

func statusPopup(status: String):
	var label = DAMAGE_NUMBER.instantiate()
	add_child(label)
	label.status = status
	label.position = Vector2(0, -20)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.tween_property(label, "modulate:a", 0, 0.8)
	await tween.finished
	label.queue_free()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
