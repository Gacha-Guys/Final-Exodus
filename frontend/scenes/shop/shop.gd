extends CanvasLayer


func _ready() -> void:
	%Button.pressed.connect(_switch_shop)
	
	
func _switch_shop() -> void:
	%PaidShopMargin.visible = not %PaidShopMargin.visible
	%FreeShopMargin.visible = not %PaidShopMargin.visible
	
