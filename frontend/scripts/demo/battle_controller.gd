extends Control

@export_file("*.tscn") var return_scene := "res://scenes/demo_hub.tscn"
@export_file("*.tscn") var login_scene := "res://scenes/demo_title.tscn"

const Battlefield := preload("res://scripts/demo/battlefield.gd")
const TAP_WINDOW_MS := 900

var battlefield: Battlefield
var round_bar: ProgressBar
var taps: Array[Dictionary] = []
var first_tap_ms := 0
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
		get_tree().call_deferred("change_scene_to_file", login_scene)
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
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := label("THE GATE", 36)
	title.add_theme_font_override("font", load("res://assets/Cinzel-VariableFont_wght.ttf"))
	box.add_child(title)
	enemy_label = label("Gate Sentinel", 30)
	box.add_child(enemy_label)
	enemy_bar = health_bar(Color("d47669"))
	box.add_child(enemy_bar)
	battlefield = Battlefield.new()
	battlefield.custom_minimum_size.y = 350
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(battlefield)
	battlefield.hit_shown.connect(show_hit)
	battlefield.counter_shown.connect(show_counter)
	turn_label = label("", 25)
	box.add_child(turn_label)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	box.add_child(cards)
	for index in range(3):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		var button := Button.new()
		button.name = "Attack%d" % index
		button.icon = battlefield.portrait(index)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size.y = 142
		button.add_theme_font_size_override("font_size", 25)
		button.pressed.connect(func() -> void: attack(index))
		card.add_child(button)
		attack_buttons.append(button)
		var bar := health_bar(Color("70b898"))
		card.add_child(bar)
		party_bars.append(bar)
		var unit := label("", 20)
		unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(unit)
		unit_labels.append(unit)
	round_bar = ProgressBar.new()
	round_bar.custom_minimum_size.y = 8
	round_bar.show_percentage = false
	box.add_child(round_bar)
	status_label = label("Loading saved battle…", 23)
	box.add_child(status_label)
	log_label = label("", 22)
	log_label.custom_minimum_size.y = 58
	box.add_child(log_label)
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
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(return_scene))
	box.add_child(back_button)
	set_busy(true)

func set_busy(value: bool) -> void:
	pending = value
	for index in range(attack_buttons.size()):
		attack_buttons[index].disabled = value or state.get("status") != "active" or int(state.party[index].hp) <= 0
	retry_button.disabled = value
	back_button.disabled = value

func show_hit(hit: Dictionary) -> void:
	enemy_bar.value = hit.hp
	enemy_label.text = "%s · HP %d/%d" % [state.enemy.name, int(hit.hp), int(state.enemy.max_hp)]

func show_counter(counter: Dictionary) -> void:
	var index := int(counter.actor)
	party_bars[index].value = counter.hp
	unit_labels[index].text = "HP %d/%d" % [int(counter.hp), int(state.party[index].max_hp)]

func show_state(data: Variant) -> void:
	if not GameSession.valid_battle(data):
		status_label.text = "Unexpected battle response. Reload to retry."
		return
	state = data
	retry_button.text = "Reload saved battle"
	battlefield.sync_units(state)
	enemy_bar.max_value = float(state.enemy.max_hp)
	enemy_bar.value = float(state.enemy.hp)
	GameSession.battle = state.duplicate(true)
	enemy_label.text = "%s · HP %d/%d" % [state.enemy.name, int(state.enemy.hp), int(state.enemy.max_hp)]
	turn_label.text = "Round %d" % int(state.turn) if state.status == "active" else ("Victory" if state.status == "won" else "Defeat")
	for index in range(3):
		var unit: Dictionary = state.party[index]
		party_bars[index].max_value = float(unit.max_hp)
		party_bars[index].value = float(unit.hp)
		attack_buttons[index].text = unit.name
		unit_labels[index].text = "HP %d/%d" % [int(unit.hp), int(unit.max_hp)]
	log_label.text = "\n".join(state.log.slice(-2))
	status_label.text = "Tap an ally to attack. Try Rowan, then Vale half a beat later." if state.status == "active" else "Encounter saved."

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
	if state.get("status") != "active" or int(state.party[index].hp) <= 0 or attack_buttons[index].disabled:
		return
	var first := taps.is_empty()
	if first:
		first_tap_ms = Time.get_ticks_msec()
		pending = true
		back_button.disabled = true
		retry_button.disabled = true
		round_bar.value = 100
		create_tween().tween_property(round_bar, "value", 0.0, TAP_WINDOW_MS / 1000.0)
	var elapsed := Time.get_ticks_msec() - first_tap_ms
	if elapsed > TAP_WINDOW_MS:
		return
	taps.append({"actor": index, "at_ms": 0 if first else elapsed})
	attack_buttons[index].disabled = true
	battlefield.cue(index)
	status_label.text = "Tap another ally before the bar empties." if taps.size() < 3 else "Squad ready."
	if not first:
		return
	await get_tree().create_timer(TAP_WINDOW_MS / 1000.0).timeout
	pending_action = {"request_id": GameSession.uuid(), "version": int(state.version), "taps": taps.duplicate()}
	taps.clear()
	await send_action()

func send_action() -> void:
	set_busy(true)
	status_label.text = "Resolving attack…"
	var result: Dictionary = await GameSession.request("/battles/%s/rounds" % state.id, HTTPClient.METHOD_POST, pending_action)
	if result.ok and GameSession.valid_battle(result.data):
		if battlefield.can_replay(result.data.get("last_round")):
			await battlefield.play_round(result.data.last_round)
		else:
			battlefield.arrange()
		pending_action = {}
		show_state(result.data)
	elif result.ok:
		status_label.text = "Unexpected round response. Retry the saved action."
	elif result.status == 409:
		pending_action = {}
		var latest: Dictionary = await GameSession.request("/battles/current")
		if latest.ok and latest.data is Dictionary:
			show_state(latest.data)
		status_label.text = result.error + " Try the action again."
	else:
		battlefield.arrange()
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
