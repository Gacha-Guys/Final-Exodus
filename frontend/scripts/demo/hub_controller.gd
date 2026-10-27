extends Control

var player_label: Label
var status_label: Label
var battle_label: Label
var battle_button: Button
var retry_button: Button
var pending := false
var settings: ConfirmationDialog
var name_input: LineEdit
var settings_message: Label
var is_shop := false
const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"

func _ready() -> void:
	if GameSession.token.is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/titleScreenNew.tscn")
		return
	is_shop = scene_file_path.ends_with("shop.tscn")
	player_label = Label.new()
	player_label.name = "PlayerName"
	player_label.position = Vector2(36, 150 if is_shop else 204)
	player_label.size = Vector2(530, 42)
	player_label.add_theme_font_size_override("font_size", 24)
	add_child(player_label)
	status_label = Label.new()
	status_label.position = Vector2(40, 190 if is_shop else 900)
	status_label.size = Vector2(630, 60)
	status_label.add_theme_font_size_override("font_size", 18 if is_shop else 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	if not is_shop:
		build_encounter_panel()
		$SettingsButton.pressed.connect(open_settings)
		$StoryButton.hide()
	else:
		status_label.text = "Shop preview · purchases unavailable"
	for name in ["UnitsButton", "SummonButton"]:
		var nav := get_node(name)
		nav.target_scene = ""
		nav.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and not event.pressed:
				status_label.text = "This screen is not part of the connected demo yet."
		)
	await refresh()

func build_encounter_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 286)
	panel.size = Vector2(640, 570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152934")
	style.border_color = Color("9a8654")
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CHAPTER 1 · THE GATE"
	title.add_theme_font_override("font", load("res://assets/Cinzel-VariableFont_wght.ttf"))
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var description := Label.new()
	description.text = "Ember · Rowan · Vale\nThree fixed characters for the combat demo."
	description.add_theme_font_size_override("font_size", 22)
	box.add_child(description)
	battle_label = Label.new()
	battle_label.name = "SavedBattle"
	battle_label.add_theme_font_size_override("font_size", 22)
	battle_label.custom_minimum_size = Vector2(0, 120)
	battle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_label.text = "Loading saved encounter…"
	box.add_child(battle_label)
	battle_button = Button.new()
	battle_button.name = "ContinueBattle"
	battle_button.add_theme_font_size_override("font_size", 24)
	battle_button.text = "Enter battle"
	battle_button.custom_minimum_size.y = 60
	battle_button.pressed.connect(open_battle)
	box.add_child(battle_button)
	retry_button = Button.new()
	retry_button.name = "Refresh"
	retry_button.add_theme_font_size_override("font_size", 24)
	retry_button.text = "Refresh saved data"
	retry_button.custom_minimum_size.y = 52
	retry_button.pressed.connect(refresh)
	box.add_child(retry_button)
	var logout_button := Button.new()
	logout_button.name = "Logout"
	logout_button.add_theme_font_size_override("font_size", 24)
	logout_button.text = "Log out"
	logout_button.custom_minimum_size.y = 52
	logout_button.pressed.connect(logout)
	box.add_child(logout_button)

func refresh() -> void:
	if pending:
		return
	pending = true
	player_label.text = "Loading account…"
	$Currency.val = "…"
	get_node(RANK_PATH).text = "Rank\n…"
	if not is_shop:
		battle_button.disabled = true
		status_label.text = "Loading saved data…"
	var result: Dictionary = await GameSession.refresh_account()
	if not result.ok:
		status_label.text = result.error
		if not is_shop:
			battle_label.text = "Saved data unavailable. Refresh to retry."
		pending = false
		return
	player_label.text = GameSession.account.display_name
	$Currency.val = str(int(GameSession.account.paid_currency))
	get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level)
	if not is_shop:
		var saved: Dictionary = await GameSession.request("/battles/current")
		if not saved.ok:
			status_label.text = saved.error
			battle_label.text = "Saved encounter unavailable. Refresh to retry."
			pending = false
			return
		if saved.data != null and not GameSession.valid_battle(saved.data):
			status_label.text = "Unexpected saved battle response. Refresh to retry."
			pending = false
			return
		GameSession.battle = saved.data if saved.data is Dictionary else {}
		var wins := int(GameSession.account.completed_battles)
		battle_label.text = "Free gems: %d · Paid gems: %d\nExperience: %d · Victories: %d\n" % [int(GameSession.account.free_currency), int(GameSession.account.paid_currency), int(GameSession.account.experience), wins]
		if GameSession.battle.is_empty():
			battle_label.text += "No saved encounter. Start at the gate."
		elif GameSession.battle.status == "active":
			battle_label.text += "Saved battle · enemy HP %d/100" % int(GameSession.battle.enemy.hp)
		else:
			battle_label.text += "Last encounter: %s · saved in MySQL" % GameSession.battle.status
		battle_button.text = "Resume battle" if GameSession.battle.get("status") == "active" else "Enter battle"
		battle_button.disabled = false
		status_label.text = "Account and battle loaded from the server."
	pending = false

func open_battle() -> void:
	if pending or battle_button.disabled:
		return
	get_tree().change_scene_to_file("res://scenes/demo_battle.tscn")

func logout() -> void:
	if pending:
		return
	pending = true
	var result: Dictionary = await GameSession.request("/sessions/current", HTTPClient.METHOD_DELETE)
	if result.ok:
		GameSession.clear()
		get_tree().change_scene_to_file("res://scenes/titleScreenNew.tscn")
	else:
		status_label.text = result.error
		pending = false

func open_settings() -> void:
	if pending:
		return
	if not is_instance_valid(settings):
		settings = ConfirmationDialog.new()
		settings.title = "Account settings"
		settings.ok_button_text = "Save name"
		settings.dialog_hide_on_ok = false
		var box := VBoxContainer.new()
		name_input = LineEdit.new()
		name_input.placeholder_text = "Display name"
		name_input.max_length = 64
		box.add_child(name_input)
		settings_message = Label.new()
		settings_message.custom_minimum_size = Vector2(460, 70)
		settings_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(settings_message)
		settings.add_child(box)
		settings.confirmed.connect(save_name)
		add_child(settings)
	name_input.text = GameSession.account.display_name
	settings_message.text = "Change the name shown on your account."
	settings.popup_centered(Vector2i(520, 240))

func save_name() -> void:
	settings.get_ok_button().disabled = true
	settings_message.text = "Saving…"
	var result: Dictionary = await GameSession.request("/me", HTTPClient.METHOD_PATCH, {"display_name": name_input.text})
	apply_name_result(result)

func apply_name_result(result: Dictionary) -> void:
	settings.get_ok_button().disabled = false
	if result.ok:
		if not GameSession.valid_account(result.data) or int(result.data.id) != int(GameSession.account.id):
			settings_message.text = "Unexpected account response. Refresh and retry."
			return
		GameSession.account = result.data
		GameSession.account_changed.emit(GameSession.account)
		player_label.text = GameSession.account.display_name
		settings_message.text = "Name saved."
	else:
		settings_message.text = result.error
