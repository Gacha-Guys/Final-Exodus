extends Control

var pending := false
var message: AcceptDialog
const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	PlayerData.currency_fail.connect(_on_currency_failed)
	%CurrencyButton1.pressed.connect(_on_currency_offer_pressed)
	_on_currency_changed()
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)

func _on_currency_offer_pressed() -> void:
	if pending:
		return
	pending = true
	%CurrencyButton1.disabled = true
	await PlayerData.update_currency(50, "paid")
	%CurrencyButton1.disabled = false
	pending = false

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level) if not GameSession.account.is_empty() else "Rank\n—"

func _on_currency_failed(reason: String) -> void:
	if not is_instance_valid(message):
		message = AcceptDialog.new()
		message.title = "Currency update"
		add_child(message)
	message.dialog_text = reason
	message.popup_centered()
