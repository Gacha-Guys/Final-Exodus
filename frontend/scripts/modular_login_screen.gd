extends CanvasLayer

signal signup_signal
signal logged_in
var pending := false
const GOOGLE_SIGN_IN = preload("res://scripts/demo/google_sign_in.gd")
@onready var fields: VBoxContainer = $LoginScreen/Container/Panel/Margin/VBox
@onready var message: Label = %ErrorMessage

func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%SignUpButton.pressed.connect(func() -> void:
		signup_signal.emit()
		queue_free()
	)
	%LoginButton.pressed.connect(submit)
	%GoogleButton.pressed.connect(google_sign_in)
	fields.get_node("PasswordInput").text_submitted.connect(func(_text: String) -> void: submit())
	message.text = GameSession.notice
	GameSession.notice = ""

func set_busy(value: bool) -> void:
	pending = value
	for name in ["LoginButton", "GoogleButton", "SignUpButton", "CloseButton"]:
		get_node("%" + name).disabled = value
	fields.get_node("UsernameInput").editable = not value
	fields.get_node("PasswordInput").editable = not value

func submit() -> void:
	if pending:
		return
	var email: String = fields.get_node("UsernameInput").text.strip_edges()
	var password: String = fields.get_node("PasswordInput").text
	fields.get_node("PasswordInput").clear()
	if email.is_empty() or password.is_empty():
		message.text = "Enter your email and password."
		return
	set_busy(true)
	message.text = "Signing in…"
	var result: Dictionary = await GameSession.request("/sessions", HTTPClient.METHOD_POST, {"email": email, "password": password}, false)
	password = ""
	if result.ok and result.data is Dictionary and result.data.get("access_token") is String:
		await accept_session(result.data)
		return
	else:
		message.text = result.get("error", "Unexpected login response.")
	set_busy(false)

func accept_session(data: Dictionary) -> void:
	GameSession.clear()
	GameSession.token = data.access_token
	var profile: Dictionary = await GameSession.refresh_account()
	if profile.ok:
		logged_in.emit()
		queue_free()
		return
	GameSession.clear()
	message.text = profile.error
	set_busy(false)

func google_sign_in() -> void:
	if pending:
		return
	set_busy(true)
	var google := GOOGLE_SIGN_IN.new()
	google.name = "GoogleSignIn"
	add_child(google)
	google.session_ready.connect(accept_session)
	google.finished.connect(func() -> void: set_busy(false))
	google.begin()
