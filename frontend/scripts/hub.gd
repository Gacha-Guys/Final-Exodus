extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Currency.val = PlayerData.paid_currency
	PlayerData.currency_success.connect(_on_currency_changed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
