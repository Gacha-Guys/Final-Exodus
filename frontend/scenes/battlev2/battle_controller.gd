class_name BattleEngine
extends Node

var TURN: int = 0
var SEED: String = ""
var units: Array[Unit]
var enemies: Array[Unit]

var unitFinished: int = 0	# number of units that already selected their move

func send_state(units: Array[Unit], enemies: Array[Unit], seed: int, turn: int):
	var http := HTTPRequest.new()
	http.timeout = 6.0
	http.max_redirects = 0
	http.body_size_limit = 524288
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload = {
		"body": {
			"units": [],
			"enemies": []
		},
		"data": {
			"seed": seed,
			"turn": turn
		}
	}
	for u in units:
		payload["body"]["units"].append(u.toDict())
	for e in enemies:
		payload["body"]["enemies"].append(e.toDict())
	var err := http.request("http://127.0.0.1:22567/calculate", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	var response = await http.request_completed
	http.queue_free()
	
	return JSON.parse_string(response[3].get_string_from_utf8())

func startBattle(stage_id: int):
	# Tell server we want to initialize a battle and get the stage/party information.
	var response = await GameSession.request("/battles/init", HTTPClient.METHOD_POST, {stage_id=stage_id})
	SEED = response["data"]["seed"]
	TURN = 0

	for u in response["data"]["state"]["units"]:
		units.append(Unit.new(u))
	for u in response["data"]["state"]["enemies"]:
		enemies.append(Unit.new(u))

# 1: Basic
# 2: Special
# 3: Guard/Pass
func doMove(unit_index: int, move_type: int):
	for u in units:
		if u.index == unit_index:
			u.move_type = move_type
			unitFinished += 1
			return
	push_error("Unable to find unit of index ", unit_index)

func finishTurn() -> Dictionary:
	if (unitFinished != len(units)):
		push_error("Number of units finished does not equal the number of units in party!")
	
	# send local state to server and validate
	var response = await send_state(units, enemies, int(SEED), TURN)
	# set new values
	var result = {
		"state": response,
		"delta": 
			{
				"units": [],
				"enemies":[]
			}
		}
	var i = 0;
	for u in response["units"]:
		result["delta"]["units"].append(null)
	for u in response["enemies"]:
		result["delta"]["enemies"].append(null)
	for u in response["units"]:
		print(u.name + "'s HP: " + str(u.health) + " / " + str(response["units"][i].health - units[0].health) + "HP!")
		result["delta"]["units"][u.index] = Action.new(u.move_type, 0, units[0].health - response["units"][i].health, u.dealt)
		if u.move_type == 2: print(u.name + " guarded!")
		units.pop_front()
		units.append(Unit.new(u))
		i+=1
	i = 0
	for u in response["enemies"]:
		print(u.name + "'s HP: " + str(u.health) + " / " + str(response["enemies"][i].health - enemies[0].health) + "HP!")
		result["delta"]["enemies"][u.index] = Action.new(u.move_type, u.target, enemies[0].health - response["enemies"][i].health, u.dealt)
		if u.move_type == 2: print(u.name + " guarded!")
		enemies.pop_front()
		enemies.append(Unit.new(u))
		i+=1
	
	
	#print(response)
	return result

func syncServer(clientState: Dictionary):
	var payload = {"units": clientState["units"], "enemies": clientState["enemies"]}
	var response = await GameSession.request("/battles/submit_turn", HTTPClient.METHOD_POST, payload)
	# set the values to sync up with the server, yes it pretty invalidates the previous thing
	# but thats only for response time.
	units.clear()
	enemies.clear()
	for u in response["data"]["state"]["units"]:
		units.append(Unit.new(u))
	for u in response["data"]["state"]["enemies"]:
		enemies.append(Unit.new(u))
	print(response)
	TURN += 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
