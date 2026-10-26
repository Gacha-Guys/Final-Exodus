extends Control

var state: Dictionary = {}
var pending := false
var pending_action: Dictionary = {}
var start_id := ""
var enemy_bar: ProgressBar
var party_bars: Array[ProgressBar] = []
var enemy_label: Label
var turn_label: Label
var log_label: Label
var status_label: Label
var attack_buttons: Array[Button] = []
var unit_labels: Array[Label] = []
var retry_button: Button
var back_button: Button

func _ready() -> void:
	if GameSession.token.is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/titleScreenNew.tscn")
		return
	build_ui()
	await load_saved()

func label(text: String, font_size: int = 24) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

func build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	var title := label("THE GATE", 36)
	title.add_theme_font_override("font", load("res://assets/Cinzel-VariableFont_wght.ttf"))
	box.add_child(title)
	box.add_child(label("Basic encounter · three demo characters", 22))
	enemy_label = label("Loading sentinel…", 32)
	box.add_child(enemy_label)
	enemy_bar = health_bar(Color("be5e56"))
	box.add_child(enemy_bar)
	turn_label = label("", 24)
	box.add_child(turn_label)
	for index in range(3):
		var row := HBoxContainer.new()
		var unit := label("Loading…", 24)
		unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var unit_box := VBoxContainer.new()
		unit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_box.add_child(unit)
		var bar := health_bar(Color("65ab8b"))
		unit_box.add_child(bar)
		party_bars.append(bar)
		row.add_child(unit_box)
		unit_labels.append(unit)
		var button := Button.new()
		button.name = "Attack%d" % index
		button.text = "Attack"
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(150, 70)
		button.pressed.connect(func() -> void: attack(index))
		row.add_child(button)
		attack_buttons.append(button)
		box.add_child(row)
	log_label = label("", 23)
	log_label.custom_minimum_size.y = 260
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(log_label)
	status_label = label("Loading saved battle…", 22)
	status_label.custom_minimum_size.y = 60
	box.add_child(status_label)
	retry_button = Button.new()
	retry_button.text = "Reload saved battle"
	retry_button.add_theme_font_size_override("font_size", 24)
	retry_button.custom_minimum_size.y = 64
	retry_button.pressed.connect(retry)
	box.add_child(retry_button)
	back_button = Button.new()
	back_button.text = "Return to hub"
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.custom_minimum_size.y = 64
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	box.add_child(back_button)
	set_busy(true)

func set_busy(value: bool) -> void:
	pending = value
	for index in range(attack_buttons.size()):
		attack_buttons[index].disabled = value or state.get("status") != "active" or int(state.party[index].hp) <= 0
	retry_button.disabled = value
	back_button.disabled = value

func show_state(data: Variant) -> void:
	if not GameSession.valid_battle(data):
		status_label.text = "Unexpected battle response. Reload to retry."
		return
	state = data
	retry_button.text = "Reload saved battle"
	enemy_bar.value = float(state.enemy.hp)
	GameSession.battle = state.duplicate(true)
	enemy_label.text = "%s · HP %d/%d" % [state.enemy.name, int(state.enemy.hp), int(state.enemy.max_hp)]
	turn_label.text = "Turn %d · %s" % [int(state.turn), str(state.status).capitalize()]
	for index in range(3):
		var unit: Dictionary = state.party[index]
		party_bars[index].value = float(unit.hp)
		unit_labels[index].text = "%s\nHP %d/%d · ATK %d" % [unit.name, int(unit.hp), int(unit.max_hp), int(unit.attack)]
	log_label.text = "\n".join(state.log)
	status_label.text = "Saved to the server." if state.status == "active" else "Encounter saved. Return to the hub to view your progress."

func load_saved() -> void:
	set_busy(true)
	var result: Dictionary = await GameSession.request("/battles/current")
	if result.ok:
		if result.data is Dictionary and result.data.get("status") == "active":
			show_state(result.data)
		else:
			if start_id.is_empty():
				start_id = GameSession.uuid()
			result = await GameSession.request("/battles", HTTPClient.METHOD_POST, {"request_id": start_id})
			if result.ok:
				show_state(result.data)
	if not result.ok:
		status_label.text = result.error
	set_busy(false)

func attack(index: int) -> void:
	if pending or state.is_empty():
		return
	if pending_action.is_empty():
		pending_action = {"request_id": GameSession.uuid(), "actor": index, "version": int(state.version)}
	await send_action()

func send_action() -> void:
	set_busy(true)
	status_label.text = "Resolving attack…"
	var result: Dictionary = await GameSession.request("/battles/%s/actions" % state.id, HTTPClient.METHOD_POST, pending_action)
	if result.ok:
		pending_action = {}
		show_state(result.data)
	elif result.status == 409:
		pending_action = {}
		var latest: Dictionary = await GameSession.request("/battles/current")
		if latest.ok and latest.data is Dictionary:
			show_state(latest.data)
		status_label.text = result.error + " Try the action again."
	else:
		status_label.text = result.error + " Use retry to safely repeat this action."
	set_busy(false)
	if not pending_action.is_empty():
		for button in attack_buttons:
			button.disabled = true
		retry_button.text = "Retry pending attack"

func retry() -> void:
	if not pending_action.is_empty():
		await send_action()
	elif state.is_empty():
		await load_saved()
	else:
		set_busy(true)
		var result: Dictionary = await GameSession.request("/battles/current")
		if result.ok and result.data is Dictionary:
			show_state(result.data)
		else:
			status_label.text = result.get("error", "Saved battle unavailable.")
		set_busy(false)

func health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar
