extends Node

signal session_ready(data: Dictionary)
signal finished

const SignInDialog := preload("res://scenes/account/google_sign_in_dialog.tscn")

var flow: Dictionary = {}
var running := false
var registration_ready := false
var dialog: ConfirmationDialog
var status: Label
var name_input: LineEdit
var dob_input: LineEdit

func _ready() -> void:
	dialog = SignInDialog.instantiate()
	add_child(dialog)
	status = dialog.get_node("Content/Status")
	name_input = dialog.get_node("Content/Username")
	dob_input = dialog.get_node("Content/BirthDate")
	dialog.canceled.connect(cancel)
	dialog.confirmed.connect(complete_registration)

func begin() -> void:
	running = true
	registration_ready = false
	name_input.hide()
	dob_input.hide()
	dialog.get_ok_button().hide()
	status.text = "Opening Google sign-in in your browser…"
	dialog.popup_centered(Vector2i(320, 220))
	if await start_browser_sign_in():
		await poll_for_result()

func start_browser_sign_in() -> bool:
	var result: Dictionary = await GameSession.request("/auth/google/start", HTTPClient.METHOD_POST, {}, false)
	if not running:
		if result.ok and valid_start(result.data):
			await GameSession.request("/auth/google/cancel", HTTPClient.METHOD_POST, key_for(result.data), false)
		return false
	if not result.ok or not valid_start(result.data):
		show_error(result.get("error", "Unexpected Google sign-in response."))
		return false
	flow = key_for(result.data)
	if open_browser(result.data.authorization_url) != OK:
		show_error("Could not open the browser. Cancel and try again.")
		return false
	status.text = "Finish signing in with Google in your browser."
	return true

func poll_for_result() -> void:
	var started := Time.get_ticks_msec()
	while running and Time.get_ticks_msec() - started < 300000:
		await get_tree().create_timer(1.0).timeout
		if not running:
			return
		var poll: Dictionary = await GameSession.request("/auth/google/poll", HTTPClient.METHOD_POST, flow, false)
		if not running:
			return
		if not poll.ok:
			show_error(poll.error)
			return
		if not poll.data is Dictionary:
			show_error("Unexpected Google sign-in response.")
			return
		match poll.data.get("status"):
			"authenticated":
				accept_session(poll.data)
				return
			"registration_required":
				show_registration_form(str(poll.data.get("display_name", "Player")))
				return
			"pending":
				pass
			_:
				show_error("Unexpected Google sign-in response.")
				return
	if running:
		show_error("Google sign-in expired. Cancel and try again.")

func show_registration_form(display_name: String) -> void:
	registration_ready = true
	status.text = "Google verified your identity. Enter your details to create your game account."
	name_input.text = display_name
	name_input.show()
	dob_input.show()
	dialog.get_ok_button().show()

func open_browser(url: String) -> Error:
	return OS.shell_open(url)

func valid_start(data: Variant) -> bool:
	return data is Dictionary and data.get("authorization_url") is String \
		and data.authorization_url.begins_with("https://accounts.google.com/o/oauth2/v2/auth?") \
		and data.get("flow_id") is String and data.flow_id.length() >= 40 \
		and data.get("poll_secret") is String and data.poll_secret.length() >= 40

func key_for(data: Dictionary) -> Dictionary:
	return {"flow_id": data.flow_id, "poll_secret": data.poll_secret}

func complete_registration() -> void:
	if not running or not registration_ready or dialog.get_ok_button().disabled:
		return
	dialog.get_ok_button().disabled = true
	var body := flow.duplicate()
	body["display_name"] = name_input.text.strip_edges()
	var birth_date := dob_input.text.strip_edges()
	if not birth_date.is_empty():
		body["dob"] = birth_date
	var result: Dictionary = await GameSession.request("/auth/google/register", HTTPClient.METHOD_POST, body, false)
	if not running:
		return
	dialog.get_ok_button().disabled = false
	if result.ok and result.data is Dictionary and result.data.get("status") == "authenticated":
		accept_session(result.data)
	else:
		status.text = result.get("error", "Unexpected Google sign-in response.")

func accept_session(data: Dictionary) -> void:
	if not data.get("access_token") is String or data.access_token.is_empty():
		show_error("Unexpected Google sign-in response.")
		return
	running = false
	flow = {}
	dialog.hide()
	session_ready.emit(data)
	queue_free()

func show_error(text: String) -> void:
	status.text = text
	dialog.get_ok_button().hide()

func cancel() -> void:
	running = false
	dialog.hide()
	if not flow.is_empty():
		await GameSession.request("/auth/google/cancel", HTTPClient.METHOD_POST, flow, false)
	flow = {}
	finished.emit()
	queue_free()
