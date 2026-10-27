extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Currency.val = PlayerData.paid_currency
	PlayerData.currency_success.connect(_on_currency_changed)
	
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
		PlayerData.update_currency(999, "paid")
	)
	pass # Replace with function body.

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
