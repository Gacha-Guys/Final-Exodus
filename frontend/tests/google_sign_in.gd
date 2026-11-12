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
		directory = "user://google-ui-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
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
		if is_instance_valid(current_scene) and current_scene.scene_file_path.ends_with("demo_hub.tscn") and not current_scene.pending:
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
	for step in range(100):
		if title.popup.get_node("%GoogleButton").visible:
			break
		await create_timer(0.02).timeout
	var button: Button = title.popup.get_node("%GoogleButton")
	expect(button.visible and button.pressed.is_connected(Callable(title.popup, "google_sign_in")), "F5 offers the configured provider")
	var google: Node = await start_google()
	title._on_account_pressed()
	var blocked_click := InputEventMouseButton.new()
	blocked_click.button_index = MOUSE_BUTTON_LEFT
	blocked_click.pressed = true
	title._start_input(blocked_click)
	expect(current_scene == title and title.popup == login, "Pending browser login cannot be replaced by Account or Start")
	await google.cancel()
	expect(not login.pending and session.token.is_empty(), "Cancelling Google restores password input")
	google = await start_google()
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
	for step in range(100):
		if not is_instance_valid(login):
			break
		await create_timer(0.02).timeout
	expect(current_scene == title and not is_instance_valid(login), "F5 Google login closes the popup and waits for Start")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	title._start_input(click)
	await scene_changed
	var hub: Node = current_scene
	expect(hub.scene_file_path == "res://scenes/hub.tscn", "Start opens the team hub")
	var account_id: int = int(session.account.id)
	expect(session.account.display_name == test_username and root.get_node("PlayerData").user_id == account_id, "Team HUD receives the signed-in account")
	var started: Dictionary = await session.request("/battles", HTTPClient.METHOD_POST, {"request_id":session.uuid()})
	expect(started.ok, "Google account can start an owned battle")
	var battle_id: String = started.data.id
	var settings: Control = hub.get_node("SettingsButton")
	click.position = settings.get_global_transform_with_canvas() * (settings.size / 2)
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	root.push_input(motion, true)
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	expect(is_instance_valid(hub.account_dialog) and hub.account_dialog.visible, "Clicking Settings opens the account dialog")
	if not is_instance_valid(hub.account_dialog):
		quit(1)
		return
	hub.account_dialog.confirmed.emit()
	await scene_changed
	expect(current_scene.scene_file_path.ends_with("/titleScreenNew.tscn") and session.token.is_empty(), "Team sign-out returns to team login")
	change_scene_to_file("res://scenes/demo_title.tscn")
	await scene_changed
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
