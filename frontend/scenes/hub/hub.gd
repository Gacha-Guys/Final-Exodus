extends Control

const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

var account_dialog: ConfirmationDialog

func _ready() -> void:
	$BattleButton.show()
	$BattleButton.pressed.connect(enter_battle)
	PlayerData.currency_success.connect(_on_currency_changed)
	_on_currency_changed()
	$SettingsButton.pressed.connect(open_account_settings)
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)

func open_account_settings() -> void:
	if GameSession.token.is_empty():
		get_tree().change_scene_to_file("res://scenes/account/title_screen.tscn")
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
	var session_generation := GameSession.generation
	var result: Dictionary = await GameSession.request("/sessions/current", HTTPClient.METHOD_DELETE)
	# A 401 already clears and redirects. Leave any replacement session alone.
	if session_generation != GameSession.generation:
		return
	GameSession.clear()
	if not result.ok:
		GameSession.notice = "Signed out on this device. Server sign-out could not be confirmed."
	get_tree().change_scene_to_file("res://scenes/account/title_screen.tscn")

func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level) if not GameSession.account.is_empty() else "Rank\n—"

func enter_battle() -> void:
	if GameSession.token.is_empty():
		GameSession.notice = "Log in to start or resume a battle."
		get_tree().change_scene_to_file("res://scenes/account/title_screen.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/battle/team_battle.tscn")
