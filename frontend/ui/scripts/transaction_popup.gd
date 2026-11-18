extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%Placeholder.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_msg(latest_purchase) -> void:
	var msg := "You have purchased "
	var sbf : StyleBoxFlat = StyleBoxFlat.new()
	sbf.set_corner_radius_all(16)
	match typeof(latest_purchase):
		TYPE_INT:
			msg += str(latest_purchase) + " Gems!"
			%Gems.visible = true
			%Logo.visible = false
			sbf.bg_color = Color(0.0, 0.22, 0.26, .87)
			%Panel.add_theme_stylebox_override("panel", sbf)
		TYPE_STRING:
			msg += "a " + latest_purchase + "!"
			%Logo.visible = true
			%Gems.visible = false
			sbf.bg_color = Color(0.704, 0.49, 0.126, 0.87)
			%Panel.add_theme_stylebox_override("panel", sbf)
		
	%CustomMsg.text = msg
	
