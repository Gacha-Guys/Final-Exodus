extends SceneTree

var checks := 0
var failures := 0
var session: Node
var test_email := ""
var test_username := ""
var saved_username := ""
var other_username := ""
var small := "--small" in OS.get_cmdline_user_args()

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func() -> void: push_error("UI test timed out"); quit(1))
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func settle(scene: Node) -> void:
	for step in range(100):
		await create_timer(0.05).timeout
		if not is_instance_valid(scene) or not scene.get("pending"):
			return
	expect(false, "UI request did not finish")

func wait_scene(suffix: String) -> Node:
	for step in range(100):
		await create_timer(0.02).timeout
		if is_instance_valid(current_scene) and current_scene.scene_file_path.ends_with(suffix):
			return current_scene
	expect(false, "Scene did not load: " + suffix)
	quit(1)
	return null

func artifact_path(name: String) -> String:
	var directory := OS.get_environment("FINAL_EXODUS_TEST_ARTIFACT_DIR")
	if directory.is_empty():
		directory = "res://../docs/review"
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(name)

func screenshot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(artifact_path(name + ("-small" if small else "") + ".png"))

func run() -> void:
	root.size = Vector2i(390, 744) if small else Vector2i(480, 854)
	session = root.get_node("GameSession")
	expect(session.valid_origin("http://127.0.0.1:8007"), "Loopback API allowed")
	for origin in ["http://example.com", "http://127.0.0.1.evil.com", "https://user:pass@example.com", "http://localhost:0", "https://example.com/path", "https://example.com#fragment"]:
		expect(not session.valid_origin(origin), "Unsafe origin rejected: " + origin)
	expect(not session.valid_account({"id": 1}), "Malformed account response rejected")
	expect(not session.valid_battle({"party": []}), "Malformed battle response rejected")
	var title: Node = load("res://scenes/demo_title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	# Closing the popup does not allow the Start control to bypass login.
	title.popup.queue_free()
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	title._start_input(click)
	await process_frame
	expect(current_scene == title and session.token.is_empty(), "Unauthenticated Start stays on title")
	var initial_login: Node = title.popup
	expect(initial_login.fields.get_global_rect().encloses(initial_login.get_node("%GoogleButton").get_global_rect()), "Google sign-in button fits the login popup")
	await screenshot("login")
	expect(initial_login.get_node("%GoogleButton").pressed.is_connected(Callable(initial_login, "google_sign_in")), "Google button is connected to the login controller")
	# Exercise either configured or unconfigured APIs without opening a real browser.
	initial_login.set_busy(true)
	var google: Node = load("res://tests/simulated_google_browser.gd").new()
	initial_login.add_child(google)
	google.finished.connect(func() -> void: initial_login.set_busy(false))
	google.begin()
	for step in range(100):
		await create_timer(0.02).timeout
		if google.status.text.contains("setup") or not google.flow.is_empty():
			break
	expect((google.status.text.contains("setup") or not google.flow.is_empty()) and session.token.is_empty(), "Google start reports missing setup or waits for consent without entering the hub")
	if google.flow.is_empty():
		await screenshot("google-setup")
	await google.cancel()
	expect(not initial_login.pending, "Cancelling Google sign-in restores username login")
	title._pop_signup()
	await process_frame
	var signup: Node = title.popup
	var suffix: String = session.uuid().left(8)
	test_email = "ui-%s@example.com" % suffix
	test_username = "UI" + suffix
	saved_username = "Saved" + suffix
	other_username = "Other" + suffix
	signup.get_node("%EmailInput").text = test_email
	signup.get_node("%UsernameInput").text = test_username
	signup.get_node("%PasswordInput").text = "LocalUiDemo!2026"
	signup.get_node("%PasswordConfirmation").text = "LocalUiDemo!2026"
	await signup.submit()
	await process_frame
	expect(title.popup != signup, "Successful registration opens login")
	var login: Node = title.popup
	login.fields.get_node("UsernameInput").text = test_username
	login.fields.get_node("PasswordInput").text = "incorrect-password"
	await login.submit()
	expect(session.token.is_empty() and login.message.text.contains("Incorrect"), "Wrong password cannot enter hub")
	login.fields.get_node("UsernameInput").text = test_email
	login.fields.get_node("PasswordInput").text = "LocalUiDemo!2026"
	await login.submit()
	expect(session.token.is_empty() and login.message.text.contains("Incorrect"), "Account email cannot be used as a username alias")
	login.fields.get_node("UsernameInput").text = test_username
	login.fields.get_node("PasswordInput").text = "LocalUiDemo!2026"
	await login.submit()
	await process_frame
	await process_frame
	var hub: Node = await wait_scene("demo_hub.tscn")
	await settle(hub)
	expect(hub.scene_file_path.ends_with("demo_hub.tscn"), "Valid login enters existing hub")
	expect(session.token.split(".").size() == 3, "Username login uses a signed JWT access token")
	expect(hub.player_label.text == test_username and hub.get_node("Currency").val == 0, "Hub displays actual profile and trigger-created balances")
	await screenshot("hub")
	hub.open_settings()
	hub.name_input.text = saved_username
	await hub.save_name()
	expect(hub.player_label.text == saved_username, "Settings updates persisted name")
	var profile_before: Dictionary = session.account.duplicate(true)
	var wrong_profile: Dictionary = profile_before.duplicate(true)
	wrong_profile.id = int(profile_before.id) + 1
	for invalid_profile in [null, {}, wrong_profile]:
		hub.apply_name_result({"ok": true, "data": invalid_profile})
		expect(session.account == profile_before and hub.player_label.text == saved_username and hub.settings_message.text.contains("Unexpected"), "Invalid settings response cannot replace the current account")
	hub.settings.hide()
	hub.open_battle()
	await process_frame
	await process_frame
	var battle: Node = await wait_scene("demo_battle.tscn")
	await settle(battle)
	if not session.valid_battle(battle.state):
		expect(false, "Encounter failed to load: " + battle.status_label.text)
		quit(1)
		return
	expect(battle.state.enemy.hp == 100 and battle.state.party.size() == 3, "Encounter loads three characters")
	for button in battle.attack_buttons + [battle.retry_button, battle.back_button]:
		expect(battle.get_rect().encloses(button.get_global_rect()), "Battle control stays inside viewport")
	for actor in range(3):
		await battle.attack(actor)
	expect(battle.state.enemy.hp == 52 and battle.state.version == 3, "All three attack buttons use authoritative server damage")
	await screenshot("battle")
	var saved_id: String = battle.state.id
	var saved: Dictionary = battle.state.duplicate(true)
	await change_scene_to_file("res://scenes/demo_hub.tscn")
	await process_frame
	hub = await wait_scene("demo_hub.tscn")
	await settle(hub)
	expect(session.battle.id == saved_id and session.battle.enemy.hp == 52, "Hub reloads saved encounter")
	await hub.logout()
	await process_frame
	await process_frame
	expect(session.token.is_empty() and session.account.is_empty() and session.battle.is_empty(), "Logout removes all private client state")
	title = await wait_scene("demo_title.tscn")
	login = title.popup
	login.fields.get_node("UsernameInput").text = test_username
	login.fields.get_node("PasswordInput").text = "LocalUiDemo!2026"
	await login.submit()
	expect(session.token.is_empty() and login.message.text.contains("Incorrect"), "Renaming the account stops the old username from logging in")
	var other_email := "ui-%s@example.com" % session.uuid().left(8)
	var other_registration: Dictionary = await session.request("/accounts", HTTPClient.METHOD_POST, {"email": other_email, "display_name": other_username, "password": "LocalUiDemo!2026", "dob": "2000-01-01"}, false)
	expect(other_registration.ok, "Second account created for account-switch check")
	login = title.popup
	login.fields.get_node("UsernameInput").text = other_username
	login.fields.get_node("PasswordInput").text = "LocalUiDemo!2026"
	await login.submit()
	await process_frame
	await process_frame
	hub = await wait_scene("demo_hub.tscn")
	await settle(hub)
	expect(hub.player_label.text == other_username and session.battle.is_empty(), "Account switch never displays the previous player's encounter")
	await hub.logout()
	await process_frame
	await process_frame
	title = await wait_scene("demo_title.tscn")
	login = title.popup
	login.fields.get_node("UsernameInput").text = saved_username
	login.fields.get_node("PasswordInput").text = "LocalUiDemo!2026"
	await login.submit()
	await process_frame
	await process_frame
	hub = await wait_scene("demo_hub.tscn")
	await settle(hub)
	expect(hub.player_label.text == saved_username and session.battle == saved, "Login reloads saved name and exact battle")
	hub.open_battle()
	await process_frame
	await process_frame
	battle = await wait_scene("demo_battle.tscn")
	await settle(battle)
	expect(battle.state == saved, "Re-entering active battle does not create a new encounter")
	while battle.state.status == "active":
		await battle.attack(int(battle.state.version) % 3)
	expect(battle.state.enemy.hp == 0 and battle.attack_buttons[0].disabled, "Victory disables further attacks")
	await screenshot("victory")
	await change_scene_to_file("res://scenes/demo_hub.tscn")
	await process_frame
	hub = await wait_scene("demo_hub.tscn")
	await settle(hub)
	expect(int(session.account.completed_battles) == 1 and int(session.account.free_currency) == 0, "Hub shows one persisted victory with no invented rewards")
	# A network failure must not replace known data with successful-looking zeroes.
	var origin: String = session.api_origin
	session.api_origin = "http://127.0.0.1:1"
	await hub.refresh()
	expect(hub.battle_button.disabled and hub.player_label.text == "Loading account…" and hub.status_label.text.contains("server"), "Unavailable API shows error and disables encounter entry")
	session.api_origin = origin
	await hub.refresh()
	expect(not hub.battle_button.disabled, "Refresh recovers after API returns")
	await change_scene_to_file("res://scenes/shop.tscn")
	await process_frame
	var shop: Node = await wait_scene("shop.tscn")
	await settle(shop)
	expect(shop.get_node("%Currency").val == int(session.account.paid_currency), "Team shop displays authenticated currency")
	await screenshot("shop")
	# Expiry/invalid-token handling clears the HUD instead of leaving private data visible.
	session.token = "invalid-session-token-for-ui-test"
	await session.refresh_account()
	await process_frame
	await process_frame
	await wait_scene("titleScreenNew.tscn")
	expect(current_scene.scene_file_path.ends_with("titleScreenNew.tscn") and session.account.is_empty(), "Invalid session returns to login and clears profile")
	var file := FileAccess.open(artifact_path("ui-small-result.json" if small else "ui-result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "synthetic_test_email": test_email, "synthetic_test_username": test_username, "renamed_username": saved_username}, "  "))
	file.close()
	print("Connected UI checks: %d passed, %d failed" % [checks - failures, failures])
	current_scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
