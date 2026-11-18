extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	%CurrencyButton1.pressed.connect(func():
		PlayerData.update_currency(50, "paid")
		)
	%CurrencyButton2.pressed.connect(func():
		PlayerData.update_currency(200, "paid")
		)
	%CurrencyButton3.pressed.connect(func():
		PlayerData.update_currency(500, "paid")
		)
	%CurrencyButton4.pressed.connect(func():
		PlayerData.update_currency(1000, "paid")
		)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
