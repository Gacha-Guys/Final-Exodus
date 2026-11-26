extends CanvasLayer

const SUCCESS = preload("res://scenes/shop/transaction_popup.tscn")
const FAILURE = preload('res://scenes/shop/transaction_failure.tscn')

func _ready() -> void:
	%Button.pressed.connect(_switch_shop)
	
	var paid_dict := {
		1: %PaidButton1,
		2: %PaidButton2,
		3: %PaidButton3,
		4: %PaidButton4,
		5: %PaidButton5,
	}
	
	var free_dict := {
		1: %FreeButton1,
		2: %FreeButton2,
		3: %FreeButton3,
		4: %FreeButton4,
		5: %FreeButton5,
	}
	
	for i in range(1,6):
		paid_dict[i].popup_transaction_success.connect(_pop_transaction_success)
		free_dict[i].popup_transaction_success.connect(_pop_transaction_success)
		paid_dict[i].popup_failure.connect(_pop_transaction_failure)
		free_dict[i].popup_failure.connect(_pop_transaction_failure)
		


func _switch_shop() -> void:
	%PaidShopMargin.visible = not %PaidShopMargin.visible
	%FreeShopMargin.visible = not %PaidShopMargin.visible
	
func _pop_transaction_success(type, msg, item_texture) -> void:
	var popup = SUCCESS.instantiate()
	popup.layer = 100
	add_child(popup)
	popup.update_msg(type, msg, item_texture)
	
	
func _pop_transaction_failure() -> void:
	var popup = FAILURE.instantiate()
	popup.layer = 100
	add_child(popup)
