extends SceneTree

var server := TCPServer.new()
var client: StreamPeerTCP
var incoming := PackedByteArray()
var requests: Array[String] = []

func serve_fixture() -> void:
	if client == null:
		if not server.is_connection_available():
			return
		client = server.take_connection()
		incoming.clear()
	client.poll()
	var available := client.get_available_bytes()
	if available == 0:
		return
	var read := client.get_data(available)
	if read[0] != OK:
		return
	incoming.append_array(read[1])
	var request := incoming.get_string_from_utf8()
	if not request.contains("\r\n\r\n"):
		return
	var request_line := request.get_slice("\r\n", 0)
	var status := "200 OK"
	var response := {}
	if request_line.begins_with("POST /battles/fixture-battle/rounds "):
		requests.append("round")
		status = "409 Conflict"
		response = {"detail": "Battle changed"}
	elif request_line.begins_with("GET /battles/current "):
		requests.append("reload")
		if requests == ["reload", "round", "reload"]:
			status = "503 Service Unavailable"
			response = {"detail": "Temporary reload failure"}
		else:
			response = battle_state(int(requests.has("round")))
	else:
		status = "404 Not Found"
		response = {"detail": "Unexpected test request"}
	var body := JSON.stringify(response)
	var headers := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, body.to_utf8_buffer().size()]
	client.put_data((headers + body).to_utf8_buffer())
	client.disconnect_from_host()
	client = null

func battle_state(version: int) -> Dictionary:
	var ally := {"name": "Ally", "hp": 100, "max_hp": 100, "attack": 18}
	var enemy := ally.duplicate()
	enemy.hp = 100 - 18 * version
	return {
		"id": "fixture-battle", "version": version, "status": "active", "turn": version + 1,
		"party": [ally, ally, ally], "enemy": enemy, "log": [],
	}

func _initialize() -> void:
	create_timer(10).timeout.connect(func() -> void:
		push_error("Battle conflict check timed out")
		quit(1)
	)
	call_deferred("run")

func run() -> void:
	assert(server.listen(0, "127.0.0.1") == OK, "Could not start the loopback fixture")
	process_frame.connect(serve_fixture)
	var session := root.get_node("GameSession")
	session.api_origin = "http://127.0.0.1:%d" % server.get_local_port()
	session.token = "synthetic-test"
	change_scene_to_file("res://scenes/battle/team_battle.tscn")
	await scene_changed
	var battle := current_scene
	while battle.pending:
		await create_timer(0.02).timeout
	assert(battle.state.version == 0 and not battle.attack_buttons[0].disabled,
		"Initial battle must permit an attack")
	await battle.attack(0)
	assert(battle.state.version == 0, "A failed refresh must leave the last displayed version intact")
	assert(battle.attack_buttons.all(func(button: Button) -> bool: return button.disabled),
		"Attacks must remain disabled after a conflict and a failed reload")
	assert(not battle.retry_button.disabled, "The player must be able to retry the reload")
	await battle.retry()
	assert(battle.state.version == 1 and not battle.attack_buttons[0].disabled,
		"Attacks must resume once a newer battle version has loaded")
	assert(requests == ["reload", "round", "reload", "reload"], "Unexpected battle request sequence")
	server.stop()
	print("PASS: conflict plus failed reload blocks attacks until retry loads fresh state")
	quit()
