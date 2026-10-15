extends Control

# Scene nodes are editable in Godot's 2D editor; this script handles API behavior.
@onready var api_url: LineEdit = %ApiUrl
@onready var email: LineEdit = %Email
@onready var display_name: LineEdit = %DisplayName
@onready var password: LineEdit = %Password
@onready var status: Label = %Status
@onready var submit: Button = %Submit
@onready var health: Button = %Health
@onready var http: HTTPRequest = $HTTPRequest
@onready var back: Button = %Back
var operation := ""

func _ready() -> void:
	health.pressed.connect(func() -> void: send("health"))
	submit.pressed.connect(func() -> void: send("register"))
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/sync_test.tscn"))
	%DeveloperToggle.toggled.connect(func(open: bool) -> void: %DeveloperPanel.visible = open)
	http.request_completed.connect(completed)

func busy(value: bool) -> void:
	submit.disabled = value
	back.disabled = value
	health.disabled = value
	api_url.editable = not value
	email.editable = not value
	display_name.editable = not value
	password.editable = not value

func valid_api_origin(base: String) -> bool:
	# Accept origins only. Userinfo, paths and fragments must not bypass loopback rules.
	var pattern := RegEx.new()
	pattern.compile("^(https://[A-Za-z0-9.-]+|http://(localhost|127\\.0\\.0\\.1))(:[0-9]{1,5})?$")
	if pattern.search(base) == null:
		return false
	var authority := base.split("://")[1]
	if authority.contains(":"):
		var port := int(authority.split(":")[1])
		return port >= 1 and port <= 65535
	return true

func send(action: String) -> void:
	var base := api_url.text.strip_edges().trim_suffix("/")
	if not valid_api_origin(base):
		status.text = "Use an HTTPS origin, or http://localhost:port / http://127.0.0.1:port. No paths or credentials."
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
