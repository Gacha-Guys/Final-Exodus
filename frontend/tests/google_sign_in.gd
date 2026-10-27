extends SceneTree

var checks := 0
var failures := 0
var session: Node
var login: Node
var title: Node
var test_username := ""

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func() -> void: push_error("Google UI test timed out"); quit(1))
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func artifact_path(name: String) -> String:
	var directory := OS.get_environment("FINAL_EXODUS_TEST_ARTIFACT_DIR")
	if directory.is_empty():
		directory = "res://../docs/review"
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(name)

func start_google() -> Node:
	login = title.popup
	login.set_busy(true)
	var google: Node = load("res://tests/simulated_google_browser.gd").new()
	login.add_child(google)
	google.session_ready.connect(login.accept_session)
	google.finished.connect(func() -> void: login.set_busy(false))
	google.begin()
	for step in range(100):
		await create_timer(0.02).timeout
		if not google.flow.is_empty():
			return google
	expect(false, "Google flow started")
	return google

func callback(google: Node) -> void:
	var http := HTTPRequest.new()
	root.add_child(http)
	http.timeout = 5
	http.max_redirects = 0
	http.request(session.api_origin + "/auth/google/callback?state=" + google.flow.flow_id + "&code=simulated-google-code")
	var response: Array = await http.request_completed
	expect(response[1] == 200, "Simulated browser callback accepted")
	http.queue_free()

func wait_hub() -> Node:
	for step in range(200):
		await create_timer(0.02).timeout
		if is_instance_valid(current_scene) and current_scene.scene_file_path.ends_with("hub.tscn") and not current_scene.pending:
			return current_scene
	expect(false, "Google login enters the hub")
	quit(1)
	return null

func run() -> void:
	session = root.get_node("GameSession")
	title = load("res://scenes/titleScreenNew.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	var google: Node = await start_google()
	await callback(google)
	for step in range(200):
		await create_timer(0.02).timeout
		if google.registration_ready:
			break
	expect(google.registration_ready and google.dob_input.visible, "New Google user is asked for real DOB")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(artifact_path("google-registration-simulated.png"))
	test_username = "Google" + session.uuid().left(8)
	google.name_input.text = test_username
	google.dob_input.text = "2999-01-01"
	await google.complete_registration()
	expect(google.status.text.contains("Check") and session.token.is_empty(), "Invalid DOB cannot finish Google registration")
	google.dob_input.text = "2000-01-01"
	await google.complete_registration()
	var hub: Node = await wait_hub()
	var account_id: int = int(session.account.id)
	expect(hub.player_label.text == test_username and session.token.split(".").size() == 3, "Google registration issues JWT and loads the real profile")
	var started: Dictionary = await session.request("/battles", HTTPClient.METHOD_POST, {"request_id":session.uuid()})
	expect(started.ok, "Google account can start an owned battle")
	var battle_id: String = started.data.id
	await hub.logout()
	await create_timer(0.1).timeout
	title = current_scene
	google = await start_google()
	await callback(google)
	hub = await wait_hub()
	expect(int(session.account.id) == account_id and session.battle.id == battle_id, "Returning Google user resumes the same account and battle")
	await hub.logout()
	await create_timer(0.1).timeout
	expect(session.token.is_empty() and session.account.is_empty(), "Google logout clears the client")
	var report := FileAccess.open(artifact_path("google-ui-simulated-result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"provider": "simulated", "checks": checks, "failures": failures}, "  "))
	report.close()
	print("Simulated Google UI checks: %d passed, %d failed" % [checks-failures,failures])
	current_scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
