extends SceneTree

var checks := 0
var failures := 0
var session: Node
var small := "--small" in OS.get_cmdline_user_args()
var username := ""
var email := ""
const PASSWORD := "Team!42"

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func() -> void: push_error("Restored team flow timed out"); quit(1))
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func wait_scene(suffix: String) -> Node:
	for step in range(200):
		await create_timer(0.02).timeout
		if is_instance_valid(current_scene) and current_scene.scene_file_path.ends_with(suffix):
			return current_scene
	push_error("Scene not loaded: " + suffix)
	quit(1)
	return null

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var directory := OS.get_environment("FINAL_EXODUS_TEST_ARTIFACT_DIR")
	if directory.is_empty():
		directory = "user://team-restoration"
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ("-small" if small else "") + ".png"))

func start_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click

func run() -> void:
	root.size = Vector2i(390, 744) if small else Vector2i(480, 854)
	session = root.get_node("GameSession")
	var legacy: Node = root.get_node("PlayerData")
	var title: Node = load("res://scenes/titleScreenNew.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	expect(not title.demo_mode, "Default title is the team's flow")
	expect(not title.popup.get_node("%GoogleButton").visible, "Optional Google demo does not change the default team login")
	title.popup.queue_free()
	await process_frame
	title._start_input(start_click())
	var hub: Node = await wait_scene("hub.tscn")
	expect(session.token.is_empty() and legacy.user_id == 0, "Team Start still permits a guest preview without an account")
	expect(hub.get_node("StoryButton").visible and not hub.has_method("build_encounter_panel"), "Guest hub retains Story without injected combat")
	await change_scene_to_file("res://scenes/titleScreenNew.tscn")
	title = await wait_scene("titleScreenNew.tscn")
	title._pop_signup()
	await process_frame
	var signup: Node = title.popup
	expect(not signup.get_node("SignupScreen/Container/Panel/Margin/VBox/DoBInput").visible, "DOB remains hidden in Riley's signup")
	username = "Team" + session.uuid().left(8)
	email = "restore-%s@example.com" % session.uuid().left(8)
	signup.get_node("%EmailInput").text = email
	signup.get_node("%UsernameInput").text = username
	signup.get_node("%PasswordInput").text = PASSWORD
	signup.get_node("%PasswordConfirmation").text = "different"
	await signup.submit()
	expect(signup.get_node("%ErrorMessage").text.contains("match"), "Password confirmation remains enforced")
	signup.get_node("%PasswordConfirmation").text = PASSWORD
	await signup.submit()
	await process_frame
	expect(is_instance_valid(title.popup) and title.popup != signup, "Three-field signup accepts the team's password without a new length policy")
	var duplicate: Dictionary = await session.request("/signup", HTTPClient.METHOD_POST, {"name": username, "email": "duplicate-%s@example.com" % session.uuid().left(8), "password": PASSWORD}, false)
	expect(duplicate.status == 409, "Mihai's duplicate username rejection is restored")
	var login: Node = title.popup
	login.fields.get_node("UsernameInput").text = email
	login.fields.get_node("PasswordInput").text = PASSWORD
	await login.submit()
	expect(session.token.is_empty(), "Email cannot act as a username alias")
	login.fields.get_node("UsernameInput").text = username
	login.fields.get_node("PasswordInput").text = "wrong"
	await login.submit()
	expect(login.message.text.contains("Incorrect") and session.token.is_empty(), "Wrong password stays on login")
	await screenshot("team-login")
	login.fields.get_node("UsernameInput").text = username
	login.fields.get_node("PasswordInput").text = PASSWORD
	await login.submit()
	await process_frame
	expect(current_scene == title and not session.token.is_empty(), "Successful login closes popup and keeps the team's Start flow")
	expect(legacy.user_id == int(session.account.id) and legacy.paid_currency == 0, "PlayerData signals carry the actual account and balances")
	title._start_input(start_click())
	hub = await wait_scene("hub.tscn")
	await create_timer(0.2).timeout
	expect(hub.get_node("StoryButton").visible and not hub.has_method("open_battle"), "Authenticated hub keeps team controls and no demo overlay")
	expect(hub.get_node(hub.RANK_PATH).text == "Rank\n1", "Hub rank uses the saved account instead of the layout placeholder")
	for name in ["UnitsButton", "SummonButton"]:
		expect(not hub.get_node(name).target_scene.is_empty(), "Team %s destination is retained" % name)
	await screenshot("team-hub")
	# Use Riley's actual menu event, not a direct scene switch.
	var release := start_click()
	release.pressed = false
	hub.get_node("ShopButton")._gui_input(release)
	var shop: Node = await wait_scene("shop.tscn")
	expect(shop.get_node("GridContainer").get_child_count() == 5, "Shop has Riley's original five offers")
	expect(shop.get_node("GridContainer/CurrencyButton5/HBoxContainer/MidSeparate/Title").text.contains("Gamepass"), "Fifth offer remains gamepass")
	expect(shop.get_node(shop.RANK_PATH).text == "Rank\n1", "Shop rank agrees with the saved account")
	await shop._on_currency_offer_pressed()
	expect(legacy.paid_currency == 50 and shop.get_node("%Currency").val == 50, "Mihai's +50 local prototype persists and updates the HUD")
	var forbidden: Dictionary = await session.request("/currency/update", HTTPClient.METHOD_POST, {"u_id": legacy.user_id + 1, "amount": 50, "type": "paid"})
	expect(forbidden.status == 403, "Prototype cannot change another player's currency")
	await legacy.update_currency(-20, "paid")
	expect(legacy.paid_currency == 30, "Team's currency subtraction remains functional")
	await legacy.update_currency(-31, "paid")
	expect(legacy.paid_currency == 30 and is_instance_valid(shop.message), "Insufficient currency preserves balance and reports failure")
	shop.message.hide()
	await screenshot("team-shop")
	shop.get_node("HomeButton")._gui_input(release)
	hub = await wait_scene("hub.tscn")
	expect(hub.get_node("%Currency").val == 30, "Home navigation retains the saved balance")
	# Reload through the API, proving the display is not only a local counter.
	var fetched: Dictionary = await session.refresh_account()
	expect(fetched.ok and int(fetched.data.paid_currency) == 30, "Currency balance is saved on the server")
	var result: Dictionary = await session.request("/sessions/current", HTTPClient.METHOD_DELETE)
	expect(result.ok, "Authenticated logout revokes the session")
	session.clear()
	expect(legacy.user_id == 0 and legacy.paid_currency == 0, "Account clearing removes private HUD data")
	print("Team restoration checks: %d passed, %d failed; test account: %s" % [checks - failures, failures, email])
	current_scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
