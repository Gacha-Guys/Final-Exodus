extends Control

const LOGIN_SCREEN = preload("res://scenes/account/login_screen.tscn")
const SIGNUP_SCREEN = preload("res://scenes/account/signup_screen.tscn")
var popup: CanvasLayer

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		$AudioStreamPlayer2D.play()
	$Start.gui_input.connect(_start_input)
	$Account.pressed.connect(_on_account_pressed)
	_pop_login()

func replace_popup(scene: PackedScene) -> CanvasLayer:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = scene.instantiate()
	add_child(popup)
	return popup

func _on_account_pressed() -> void:
	if not is_instance_valid(popup) or not popup.pending:
		_pop_login()

func _pop_login() -> void:
	var login_popup := replace_popup(LOGIN_SCREEN)
	login_popup.signup_signal.connect(_pop_signup)

func _pop_signup() -> void:
	var signup_popup := replace_popup(SIGNUP_SCREEN)
	signup_popup.login_signal.connect(_pop_login)

func _start_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(popup) and popup.pending:
			return
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _exit_tree() -> void:
	$AudioStreamPlayer2D.stop()
	$AudioStreamPlayer2D.stream = null
