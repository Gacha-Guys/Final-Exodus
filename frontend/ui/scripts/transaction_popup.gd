extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%Placeholder.visible = false
	


func update_msg(type, latest_purchase: String, item_texture: Texture2D) -> void:
	var msg := "You have purchased" + latest_purchase
	var sbf : StyleBoxFlat = StyleBoxFlat.new()
	sbf.set_corner_radius_all(16)
	match type:
		"Gem":
			%Gems.visible = true
			%LogoMargin.visible = false
			%Item.visible = false
			sbf.bg_color = Color(0.0, 0.22, 0.26, .87)
			%Panel.add_theme_stylebox_override("panel", sbf)
		"Logo":
			%LogoMargin.visible = true
			%Gems.visible = false
			%Item.visible = false
			sbf.bg_color = Color(0.704, 0.49, 0.126, 0.87)
			%Panel.add_theme_stylebox_override("panel", sbf)
		"Item":
			%Item.visible = true
			%LogoMargin.visible = false
			%Gems.visible = false
			sbf.bg_color = Color("#232834", 0.95)
			%Item.texture = item_texture
			
	%CustomMsg.text = msg
	%Panel.add_theme_stylebox_override("panel", sbf)
	
