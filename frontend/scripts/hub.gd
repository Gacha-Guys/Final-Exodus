extends "res://scripts/demo/hub_controller.gd"

# Keep the team hub scene and currency signal on the shared authenticated session.
func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	super._ready()

func _on_currency_changed() -> void:
	%Currency.val = str(PlayerData.paid_currency)
