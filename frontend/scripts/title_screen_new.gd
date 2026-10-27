extends Control

const LOGIN_SCREEN = preload("res://scenes/login_screen.tscn")
const SIGNUP_SCREEN = preload("res://scenes/signup_screen.tscn")
@export var demo_mode := false
var popup: CanvasLayer

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		$AudioStreamPlayer2D.play()
	$Start.gui_input.connect(_start_input)
	$Account.pressed.connect(_pop_login)
	_pop_login()

func replace_popup(scene: PackedScene) -> CanvasLayer:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = scene.instantiate()
	if scene == LOGIN_SCREEN:
		popup.enable_google = demo_mode
	add_child(popup)
	return popup

func _pop_login() -> void:
	var login_popup := replace_popup(LOGIN_SCREEN)
	login_popup.signup_signal.connect(_pop_signup)
	if demo_mode:
		login_popup.logged_in.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/demo_hub.tscn"))

func _pop_signup() -> void:
	var signup_popup := replace_popup(SIGNUP_SCREEN)
	signup_popup.login_signal.connect(_pop_login)

func _start_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if demo_mode and GameSession.token.is_empty():
			_pop_login()
		else:
			get_tree().change_scene_to_file("res://scenes/demo_hub.tscn" if demo_mode else "res://scenes/hub.tscn")

func _exit_tree() -> void:
	$AudioStreamPlayer2D.stop()
	$AudioStreamPlayer2D.stream = null
