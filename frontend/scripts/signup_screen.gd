extends Node



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
	return true
	#more logic on passing the stuff to the backend
	
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%LoginButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/login_screen.tscn")
	)

	%SignUpButton.pressed.connect(func():
		if _process_sign_up(%ErrorMessage):
			get_tree().change_scene_to_file("res://scenes/login_screen.tscn")
	)
		
	pass# Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
