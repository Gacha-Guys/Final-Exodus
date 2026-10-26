extends CanvasLayer

signal login_signal
var pending := false

func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%LoginButton.pressed.connect(func() -> void:
		login_signal.emit()
		queue_free()
	)
	%SignUpButton.pressed.connect(submit)

func set_busy(value: bool) -> void:
	pending = value
	for name in ["SignUpButton", "LoginButton", "CloseButton"]:
		get_node("%" + name).disabled = value
	for name in ["EmailInput", "UsernameInput", "PasswordInput", "PasswordConfirmation", "DoBInput"]:
		get_node("%" + name).editable = not value

func submit() -> void:
	if pending:
		return
	if %PasswordInput.text != %PasswordConfirmation.text:
		%ErrorMessage.text = "Passwords do not match."
		return
	if %EmailInput.text.strip_edges().is_empty() or %UsernameInput.text.strip_edges().is_empty() or %DoBInput.text.strip_edges().is_empty():
		%ErrorMessage.text = "Enter your email, username, and birth date."
		return
	if %PasswordInput.text.length() < 12 or %PasswordInput.text.length() > 128:
		%ErrorMessage.text = "Use a password with 12–128 characters."
		return
	var body := {"email": %EmailInput.text.strip_edges(), "display_name": %UsernameInput.text, "password": %PasswordInput.text, "dob": %DoBInput.text.strip_edges()}
	%PasswordInput.clear()
	%PasswordConfirmation.clear()
	set_busy(true)
	%ErrorMessage.text = "Creating account…"
	var result: Dictionary = await GameSession.request("/accounts", HTTPClient.METHOD_POST, body, false)
	body.clear()
	set_busy(false)
	if result.ok and result.status == 201 and result.data is Dictionary and result.data.has("id"):
		GameSession.notice = "Account created. Log in with your email."
		login_signal.emit()
		queue_free()
	else:
		%ErrorMessage.text = result.get("error", "Unexpected registration response.")
