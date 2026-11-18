extends Control

var latest_purchase = 0
var transaction_popup = preload("res://ui/transaction_popup.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	%CurrencyButton1.pressed.connect(func():
		PlayerData.update_currency(50, "paid")
		latest_purchase = 50
		)
	%CurrencyButton2.pressed.connect(func():
		PlayerData.update_currency(200, "paid")
		latest_purchase = 200
		)
	%CurrencyButton3.pressed.connect(func():
		PlayerData.update_currency(500, "paid")
		latest_purchase = 500
		)
	%CurrencyButton4.pressed.connect(func():
		PlayerData.update_currency(1000, "paid")
		latest_purchase = 1000
		)
	%CurrencyButton5.pressed.connect(func():
		PlayerData.update_gamepass(true)
		latest_purchase = "Gamepass"
		)
		
	PlayerData.currency_success.connect(_run_pop_up)
	PlayerData.gamepass_success.connect(_run_pop_up)
	
	pass # Replace with function body.


func _run_pop_up() -> void:
	# have a variavle store the .instantiate() of a preloaded scene
	var popup = transaction_popup.instantiate()
	# add it as a child
	add_child(popup)
	# call its method down to edit it [it will kill itself]
	popup.update_msg(latest_purchase)
	
	
	
	
	
	
