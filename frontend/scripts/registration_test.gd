extends Control

# Functional boilerplate for Riley: replace layout without changing the API contract.
var api_url: LineEdit
var email: LineEdit
var display_name: LineEdit
var password: LineEdit
var status: Label
var submit: Button
var health: Button
var http: HTTPRequest
var operation := ""

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "ACCOUNT CREATION — CONNECTION TEST"
	column.add_child(title)
	api_url = field(column, "API address", false)
	api_url.text = "http://127.0.0.1:8001"
	email = field(column, "Email", false)
	display_name = field(column, "Display name", false)
	password = field(column, "Password (12–128 characters)", true)
	health = Button.new()
	health.text = "Check API"
	health.pressed.connect(func() -> void: send("health"))
	column.add_child(health)
	submit = Button.new()
	submit.text = "Create test account"
	submit.pressed.connect(func() -> void: send("register"))
	column.add_child(submit)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Start the Python backend first. Registration writes a real account to the configured database."
	column.add_child(status)
	var back := Button.new()
	back.text = "Back to team sync test"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/sync_test.tscn"))
	column.add_child(back)
	http = HTTPRequest.new()
	http.timeout = 10.0
	http.request_completed.connect(completed)
	add_child(http)

func field(column: VBoxContainer, placeholder: String, secret: bool) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.secret = secret
	column.add_child(input)
	return input

func busy(value: bool) -> void:
	submit.disabled = value
	health.disabled = value
	api_url.editable = not value
	email.editable = not value
	display_name.editable = not value
	password.editable = not value

func send(action: String) -> void:
	var base := api_url.text.strip_edges().trim_suffix("/")
	# HTTP is only for this machine; shared API testing requires HTTPS.
	var host := base.trim_prefix("http://").split("/")[0].split(":")[0]
	if not base.begins_with("https://") and not (base.begins_with("http://") and host in ["localhost", "127.0.0.1"]):
		status.text = "Use HTTPS, or HTTP on localhost/127.0.0.1 for local development."
		return
	operation = action
	busy(true)
	status.text = "Connecting…"
	var error: Error
	if action == "health":
		error = http.request(base + "/health")
	else:
		var body := JSON.stringify({"email": email.text.strip_edges(), "display_name": display_name.text, "password": password.text})
		password.clear()
		error = http.request(base + "/accounts", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		busy(false)
		status.text = "Could not start the request. Check the API address and retry."

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy(false)
	if result != HTTPRequest.RESULT_SUCCESS:
		status.text = "Cannot reach the API. Check that the backend is running and retry."
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		status.text = "Unexpected API response. Check the API address."
		return
	if operation == "health" and code == 200:
		status.text = "API is running. This checks the API process, not the database."
	elif operation == "register" and code == 201 and parsed.has("id"):
		status.text = "Account created: %s (ID %s). Login comes in a separate change." % [str(parsed.get("display_name", "Player")), str(parsed.id)]
	elif code == 422:
		status.text = "Check email, display name, and password length (12–128 characters), then retry."
	elif code == 409:
		status.text = "That email is already registered."
	elif code == 429:
		status.text = "Too many attempts. Wait at least a minute before retrying."
	elif code == 503:
		status.text = "Account creation unavailable. Check the backend database connection, then retry."
	else:
		status.text = "Request failed (HTTP %d). Check the API and retry." % code
