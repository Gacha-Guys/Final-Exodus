extends Control

const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

var account_dialog: ConfirmationDialog

func _ready() -> void:
	PlayerData.currency_success.connect(_on_currency_changed)
	_on_currency_changed()
	$SettingsButton.pressed.connect(open_account_settings)
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)

func open_account_settings() -> void:
	if GameSession.token.is_empty():
		get_tree().change_scene_to_file("res://scenes/titleScreenNew.tscn")
		return
	if not is_instance_valid(account_dialog):
		account_dialog = ConfirmationDialog.new()
		account_dialog.title = "Account"
		account_dialog.ok_button_text = "Sign out"
		account_dialog.dialog_hide_on_ok = false
		account_dialog.confirmed.connect(sign_out)
		add_child(account_dialog)
	account_dialog.dialog_text = "Signed in as %s" % GameSession.account.get("display_name", "")
	account_dialog.popup_centered()

func sign_out() -> void:
	if account_dialog.get_ok_button().disabled:
		return
	account_dialog.get_ok_button().disabled = true
	var result: Dictionary = await GameSession.request("/sessions/current", HTTPClient.METHOD_DELETE)
	if result.ok:
		GameSession.clear()
		get_tree().change_scene_to_file("res://scenes/titleScreenNew.tscn")
	else:
		account_dialog.dialog_text = result.error
		account_dialog.get_ok_button().disabled = false

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level) if not GameSession.account.is_empty() else "Rank\n—"
