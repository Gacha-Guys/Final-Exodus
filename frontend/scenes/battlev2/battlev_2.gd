extends Control

var battleEngine = BattleEngine.new()

#func _ready():
#    $AttackButton.pressed.connect(_on_move_pressed.bind(0))
#    $SpecialButton.pressed.connect(_on_move_pressed.bind(1))
#    $GuardButton.pressed.connect(_on_move_pressed.bind(2))

var t: int = 0

var u1: Array[Button]
var u2: Array[Button]
var u3: Array[Button]


var u1StartPos: Vector2
var u2StartPos: Vector2
var u3StartPos: Vector2
var eStartPos: Vector2

func disableGroup(b: Array[Button]):
	for but in b:
		but.disabled = true

func enableGroup(b: Array[Button]):
	for but in b:
		but.disabled = false

func _on_move_pressed(unit_index: int, move_type: int):
	print("Unit ", unit_index, " doing ", move_type)
	match unit_index:
		0:
			disableGroup(u1)
			if move_type != 2:
				$Unit1.play("attack")
				var tween = create_tween()
				tween.tween_property($Unit1, "position", u1StartPos + Vector2(32, 0), 0.3)
			else:
				$Unit1.statusPopup("GUARD")
		1:
			disableGroup(u2)
			if move_type != 2:
				$Unit2.play("attack")
				var tween = create_tween()
				tween.tween_property($Unit2, "position", u2StartPos + Vector2(32, 0), 0.3)
			else:
				$Unit2.statusPopup("GUARD")
		2:
			disableGroup(u3)
			if move_type != 2:
				$Unit3.play("attack")
				var tween = create_tween()
				tween.tween_property($Unit3, "position", u3StartPos + Vector2(32, 0), 0.3)
			else:
				$Unit3.statusPopup("GUARD")
	battleEngine.doMove(unit_index, move_type)
	t += 1
	if (t >= 3):
		t = 0
		var state = await battleEngine.finishTurn()
		if (state["delta"]["enemies"][0].move_type == 2):
			$Enemy.statusPopup("GUARD")
		var i = 0
		for unit in [$Unit1, $Unit2, $Unit3]:
			if state["delta"]["units"][i].move_type != 2:
				var tween = create_tween()
				tween.tween_property(unit, "position", eStartPos - Vector2(64, 0), 0.3)
				await tween.finished

				var return_tween = create_tween()
				if unit == $Unit1:
					print(state["delta"]["units"][0].dealt)
					$Enemy.statusPopup(str(state["delta"]["units"][0].dealt))
					return_tween.tween_property(unit, "position", u1StartPos, 0.3)
				if unit == $Unit2:
					print(state["delta"]["units"][1].dealt)
					$Enemy.statusPopup(str(state["delta"]["units"][1].dealt))
					return_tween.tween_property(unit, "position", u2StartPos, 0.3)
				if unit == $Unit3:
					print(state["delta"]["units"][2].dealt)
					$Enemy.statusPopup(str(state["delta"]["units"][2].dealt))
					return_tween.tween_property(unit, "position", u3StartPos, 0.3)
				await return_tween.finished
			i += 1
			unit.play("idle")
		
		if (state["delta"]["enemies"][0].move_type != 2):
			$Enemy.play("attack")
			var tween = create_tween()
			tween.tween_property($Enemy, "position", [u1StartPos, u2StartPos, u3StartPos][state["delta"]["enemies"][0].targetIndex] + Vector2(64, 0), 0.3)
			await tween.finished
			[$Unit1, $Unit2, $Unit3][state["delta"]["enemies"][0].targetIndex].statusPopup(str(state["delta"]["enemies"][0].dealt))
			tween = create_tween()
			tween.tween_property($Enemy, "position", eStartPos, 0.3)
			await tween.finished
			$Enemy.play("idle")
		
		await battleEngine.syncServer(state["state"])
		enableGroup(u1)
		enableGroup(u2)
		enableGroup(u3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	u1StartPos = $Unit1.position
	u2StartPos = $Unit2.position
	u3StartPos = $Unit3.position
	eStartPos = $Enemy.position
	$Enemy.flip_h = true

	
	$GridContainer/basic1.pressed.connect(_on_move_pressed.bind(0, 0))
	$GridContainer/basic2.pressed.connect(_on_move_pressed.bind(1, 0))
	$GridContainer/basic3.pressed.connect(_on_move_pressed.bind(2, 0))
	
	$GridContainer/special1.pressed.connect(_on_move_pressed.bind(0, 1))
	$GridContainer/special2.pressed.connect(_on_move_pressed.bind(1, 1))
	$GridContainer/special3.pressed.connect(_on_move_pressed.bind(2, 1))
	
	$GridContainer/guard1.pressed.connect(_on_move_pressed.bind(0, 2))
	$GridContainer/guard2.pressed.connect(_on_move_pressed.bind(1, 2))
	$GridContainer/guard3.pressed.connect(_on_move_pressed.bind(2, 2))
	
	u1 = [$GridContainer/basic1, $GridContainer/special1, $GridContainer/guard1]
	u2 = [$GridContainer/basic2, $GridContainer/special2, $GridContainer/guard2]
	u3 = [$GridContainer/basic3, $GridContainer/special3, $GridContainer/guard3]
	
	$Unit1.play("idle")
	$Unit2.play("idle")
	$Unit3.play("idle")
	$Enemy.play("idle")
	
	
	add_child(battleEngine)
	disableGroup(u1)
	disableGroup(u2)
	disableGroup(u3)
	await battleEngine.startBattle(1)
	print("Ready!")
	enableGroup(u1)
	enableGroup(u2)
	enableGroup(u3)
	
	
	"""
	var response = await GameSession.request("/battles/init", HTTPClient.METHOD_POST, {stage_id=1})
	print(response)
	
	var SEED = int(response["data"]["seed"])
	var turn = 0
	
	var units: Array[Unit] = []
	var enemies: Array[Unit] = []
	for u in response["data"]["state"]["units"]:
		units.append(Unit.new(u))
	units[0].move_type = 0
	units[1].move_type = 2
	units[2].move_type = 2
	
	for u in response["data"]["state"]["enemies"]:
		enemies.append(Unit.new(u))
	
	response = await send_state(units, enemies, SEED, turn)
	print("\nClient Calculated State:")
	print(response)
	
	print("\nServer Response:")
	var payload = {"units": response["units"], "enemies": response["enemies"]}
	response = await GameSession.request("/battles/submit_turn", HTTPClient.METHOD_POST, payload)
	print(response)
	"""
	
	
	"""
	var response = await GameSession.request("/battles/init", HTTPClient.METHOD_POST)
	print(response)
	response = await GameSession.request("/battles/query", HTTPClient.METHOD_POST, {index=0, unitid=1, move_type=0})
	print(response)
	response = await GameSession.request("/battles/query", HTTPClient.METHOD_POST, {index=0, unitid=1, move_type=0})
	print(response)
	response = await GameSession.request("/battles/end_query", HTTPClient.METHOD_POST, {turn=1})
	print(response)
	"""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
