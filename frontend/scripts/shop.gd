extends Control

var pending := false
var message: AcceptDialog
const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	PlayerData.currency_fail.connect(_on_currency_failed)
	for index in range(4):
		get_node("%%CurrencyButton%d" % (index + 1)).pressed.connect(_on_currency_offer_pressed.bind([50, 200, 500, 999][index]))
	_on_currency_changed()
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)

func _on_currency_offer_pressed(amount: int = 50) -> void:
	if pending:
		return
	pending = true
	for index in range(1, 5):
		get_node("%%CurrencyButton%d" % index).disabled = true
	await PlayerData.update_currency(amount, "paid")
	for index in range(1, 5):
		get_node("%%CurrencyButton%d" % index).disabled = false
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
