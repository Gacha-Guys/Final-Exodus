extends Control

const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	_on_currency_changed()
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level) if not GameSession.account.is_empty() else "Rank\n—"
