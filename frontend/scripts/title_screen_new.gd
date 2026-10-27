extends Node

const LOGIN_SCREEN = preload("res://scenes/login_screen.tscn")
const SIGNUP_SCREEN = preload("res://scenes/signup_screen.tscn")

func _pop_login() -> void:
	var login_popup = LOGIN_SCREEN.instantiate()
	login_popup.signup_signal.connect(_pop_signup)
	add_child(login_popup)
	
func _pop_signup() -> void:
	var signup_popup = SIGNUP_SCREEN.instantiate()
	signup_popup.login_signal.connect(_pop_login)
	add_child(signup_popup)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_pop_login()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
