extends Control

const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

const AccountSettingsDialog := preload("res://scenes/hub/account_settings_dialog.tscn")

var account_dialog: ConfirmationDialog
var username_input: LineEdit
var account_status: Label
var sign_out_button: Button
var account_request_pending := false

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
		account_dialog = AccountSettingsDialog.instantiate()
		username_input = account_dialog.get_node("Content/Username")
		account_status = account_dialog.get_node("Content/Status")
		sign_out_button = account_dialog.add_button("Sign out", true, "sign_out")
		account_dialog.custom_action.connect(_on_account_action)
		account_dialog.confirmed.connect(save_username)
		add_child(account_dialog)
	if account_request_pending:
		return
	username_input.text = GameSession.account.get("display_name", "")
	account_status.text = "Use your new username the next time you sign in with a password."
	account_dialog.popup_centered()

func _on_account_action(action: StringName) -> void:
	if action == &"sign_out":
		await sign_out()

func set_account_request_pending(pending: bool) -> void:
	account_request_pending = pending
	username_input.editable = not pending
	account_dialog.get_ok_button().disabled = pending
	sign_out_button.disabled = pending

func save_username() -> void:
	if account_request_pending or GameSession.token.is_empty():
		return
	var requested_name := username_input.text.strip_edges()
	if requested_name.is_empty():
		account_status.text = "Enter a username."
		return
	set_account_request_pending(true)
	account_status.text = "Saving username…"
	var session_generation := GameSession.generation
	var account_id := int(GameSession.account.get("id", 0))
	var result: Dictionary = await GameSession.request("/me", HTTPClient.METHOD_PATCH, {"display_name": requested_name})
	set_account_request_pending(false)
	if session_generation != GameSession.generation:
		return
	if not result.ok:
		account_status.text = result.error
		return
	if not GameSession.valid_account(result.data) or int(result.data.id) != account_id:
		account_status.text = "Unexpected account response. Try again."
		return
	GameSession.account = result.data
	GameSession.account_changed.emit(GameSession.account)
	username_input.text = GameSession.account.display_name
	account_status.text = "Username saved."

func sign_out() -> void:
	if account_request_pending:
		return
	set_account_request_pending(true)
	var session_generation := GameSession.generation
	var result: Dictionary = await GameSession.request("/sessions/current", HTTPClient.METHOD_DELETE)
	set_account_request_pending(false)
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
