extends "res://scripts/demo/hub_controller.gd"

func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	super._ready()
	# Keep all team offers visible. A purchase needs a verified provider receipt.
	for index in range(1, 7):
		var offer := get_node_or_null("GridContainer/CurrencyButton%d" % index)
		if offer != null:
			offer.custom_minimum_size.y = 130
			offer.pressed.connect(purchase_unavailable)
	# Six offers fit between account details and the existing bottom navigation.
	var offers: GridContainer = $GridContainer
	offers.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offers.position = Vector2(110, 270)
	offers.size = Vector2(500, 865)

func _on_currency_changed() -> void:
	%Currency.val = str(PlayerData.paid_currency)

func purchase_unavailable() -> void:
	status_label.text = "Purchases are not connected yet. No currency was charged or granted."
