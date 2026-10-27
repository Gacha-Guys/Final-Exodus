extends CanvasLayer

signal login_signal

func _process_sign_up(error_message: Control) -> bool:
	if $%EmailInput.text.is_empty():
		error_message.text = "Please enter an Email"
		return false
	if $%UsernameInput.text.is_empty():
		error_message.text = "Please enter a Username"
		return false
	if $%PasswordInput.text.is_empty():
		error_message.text = "Please enter a Password"
		return false
	if  $%PasswordInput.text != $%PasswordConfirmation.text:
		error_message.text = "Passwords do not match"
		return false
	
	PlayerData.signup($%EmailInput.text, $%UsernameInput.text, $%PasswordInput.text)
	return true
	#more logic on passing the stuff to the backend
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)

	%SignUpButton.pressed.connect(func():
		if _process_sign_up(%ErrorMessage):
			queue_free()
			login_signal.emit()
	)
	
	%LoginButton.pressed.connect(func():
		login_signal.emit()
		queue_free()
	)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
