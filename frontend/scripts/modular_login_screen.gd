extends CanvasLayer

signal signup_signal


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CloseButton.pressed.connect(queue_free)
	%SignUpButton.pressed.connect(func():
		queue_free()
		signup_signal.emit()
	)
	
	%LoginButton.pressed.connect(func():
			var name = %UsernameInput.text
			var password = %PasswordInput.text
			print("LOGIN BUTTON PRESSED")
			PlayerData.login(name, password)
			)
	PlayerData.login_succeeded.connect(success)
	PlayerData.login_failed.connect(fail)
	
	pass # Replace with function body.

func success() -> void:
	print("success")
	PlayerData.getCurrency(PlayerData.user_id)
	queue_free()
	
func fail(message: String) -> void:
	print("Login failed: ", message)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
