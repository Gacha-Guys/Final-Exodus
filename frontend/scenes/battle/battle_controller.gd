extends Control

@export_file("*.tscn") var return_scene := "res://scenes/hub/hub.tscn"
@export_file("*.tscn") var login_scene := "res://scenes/account/title_screen.tscn"

const Battlefield := preload("res://scenes/battle/battlefield.gd")
const TAP_WINDOW_MS := 900

enum Phase { LOADING, READY, COLLECTING_TAPS, SUBMITTING_ROUND, RETRY_ROUND, RELOAD_REQUIRED }

var phase := Phase.LOADING
var pending: bool:
	get:
		return phase in [Phase.LOADING, Phase.COLLECTING_TAPS, Phase.SUBMITTING_ROUND]
var taps: Array[Dictionary] = []
var first_tap_ms := 0
var state: Dictionary = {}
var pending_round: Dictionary = {}
var start_request_id := ""

@onready var battlefield: Battlefield = %Battlefield
@onready var round_bar: ProgressBar = %RoundTimer
@onready var enemy_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_label: Label = %EnemyName
@onready var turn_label: Label = %TurnLabel
@onready var log_label: Label = %BattleLog
@onready var status_label: Label = %BattleStatus
@onready var retry_button: Button = %RetryButton
@onready var back_button: Button = %BackButton
@onready var attack_buttons: Array[Button] = [%Attack0, %Attack1, %Attack2]
@onready var party_bars: Array[ProgressBar] = [%AllyHealth0, %AllyHealth1, %AllyHealth2]
@onready var unit_labels: Array[Label] = [%AllyLabel0, %AllyLabel1, %AllyLabel2]

func _ready() -> void:
	if GameSession.token.is_empty():
		get_tree().call_deferred("change_scene_to_file", login_scene)
		return
	for index in range(attack_buttons.size()):
		attack_buttons[index].icon = battlefield.portrait(index)
		attack_buttons[index].pressed.connect(attack.bind(index))
	battlefield.hit_shown.connect(show_hit)
	battlefield.counter_shown.connect(show_counter)
	retry_button.pressed.connect(retry)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(return_scene))
	await load_battle(true)

func set_phase(next_phase: Phase) -> void:
	phase = next_phase
	var can_attack: bool = phase in [Phase.READY, Phase.COLLECTING_TAPS] and state.get("status") == "active"
	for index in range(attack_buttons.size()):
		attack_buttons[index].disabled = not can_attack or int(state.party[index].hp) <= 0 \
			or taps.any(func(tap: Dictionary) -> bool: return tap.actor == index)
	retry_button.disabled = pending
	back_button.disabled = pending
	retry_button.text = "Retry pending attack" if phase == Phase.RETRY_ROUND else "Reload saved battle"

func show_hit(hit: Dictionary) -> void:
	enemy_bar.value = hit.hp
	enemy_label.text = "%s · HP %d/%d" % [state.enemy.name, int(hit.hp), int(state.enemy.max_hp)]

func show_counter(counter: Dictionary) -> void:
	var index := int(counter.actor)
	party_bars[index].value = counter.hp
	unit_labels[index].text = "HP %d/%d" % [int(counter.hp), int(state.party[index].max_hp)]

func display_battle(data: Dictionary) -> void:
	state = data
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

func load_battle(start_if_needed: bool) -> void:
	set_phase(Phase.LOADING)
	var result: Dictionary = await GameSession.request("/battles/current")
	if result.ok and start_if_needed and (result.data == null or (valid_battle(result.data) and result.data.status != "active")):
		if start_request_id.is_empty():
			start_request_id = GameSession.uuid()
		result = await GameSession.request("/battles", HTTPClient.METHOD_POST, {"request_id": start_request_id})
	if result.ok and valid_battle(result.data):
		display_battle(result.data)
		set_phase(Phase.READY)
	else:
		status_label.text = result.get("error", "Unexpected battle response. Reload to retry.")
		set_phase(Phase.RELOAD_REQUIRED)

func attack(index: int) -> void:
	if attack_buttons[index].disabled:
		return
	var starts_round := phase == Phase.READY
	if starts_round:
		first_tap_ms = Time.get_ticks_msec()
		round_bar.value = 100
		create_tween().tween_property(round_bar, "value", 0.0, TAP_WINDOW_MS / 1000.0)
	var elapsed := Time.get_ticks_msec() - first_tap_ms
	if elapsed > TAP_WINDOW_MS:
		return
	taps.append({"actor": index, "at_ms": 0 if starts_round else elapsed})
	set_phase(Phase.COLLECTING_TAPS)
	battlefield.cue(index)
	status_label.text = "Tap another ally before the bar empties." if taps.size() < 3 else "Squad ready."
	if not starts_round:
		return
	await get_tree().create_timer(TAP_WINDOW_MS / 1000.0).timeout
	pending_round = {"request_id": GameSession.uuid(), "version": int(state.version), "taps": taps.duplicate()}
	taps.clear()
	await submit_round()

func submit_round() -> void:
	set_phase(Phase.SUBMITTING_ROUND)
	status_label.text = "Resolving attack…"
	var result: Dictionary = await GameSession.request("/battles/%s/rounds" % state.id, HTTPClient.METHOD_POST, pending_round)
	if result.ok and valid_battle(result.data):
		if battlefield.can_replay(result.data.get("last_round")):
			await battlefield.play_round(result.data.last_round)
		pending_round = {}
		display_battle(result.data)
		set_phase(Phase.READY)
	elif result.status == 409:
		# The local version is stale. Keep attacks disabled until a reload supplies fresh state.
		pending_round = {}
		await load_battle(false)
	else:
		battlefield.arrange()
		status_label.text = result.get("error", "Unexpected round response.") + " Retry the saved attack."
		# The server may already have applied this round. Retry with the same request ID and taps.
		set_phase(Phase.RETRY_ROUND)

func retry() -> void:
	if phase == Phase.RETRY_ROUND:
		await submit_round()
	else:
		await load_battle(state.is_empty())

func valid_battle(data: Variant) -> bool:
	if not data is Dictionary or not data.get("id") is String or not GameSession.number(data.get("version")) or not GameSession.number(data.get("turn")):
		return false
	if not data.get("status") in ["active", "won", "lost"] or not data.get("party") is Array or data.party.size() != 3:
		return false
	if not data.get("log") is Array or not data.get("enemy") is Dictionary:
		return false
	for entry in data.log:
		if not entry is String:
			return false
	var units: Array = data.party.duplicate()
	units.append(data.enemy)
	for unit in units:
		if not unit is Dictionary or not unit.get("name") is String:
			return false
		for key in ["hp", "max_hp", "attack"]:
			if not GameSession.number(unit.get(key)):
				return false
	return true
