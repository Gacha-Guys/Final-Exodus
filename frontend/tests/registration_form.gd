# No backend or database needed. Simulates transport, tests the real scene and handlers.
extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var screen = load("res://scenes/registration_test.tscn").instantiate()
	screen.set_script(load("res://tests/fake_registration.gd"))
	root.add_child(screen)
	screen.api_url.text = "http://127.0.0.1:8001"
	screen.email.text = "player@example.com"
	screen.display_name.text = "Player"
	screen.password.text = "a long demo password"
	screen.send("register")
	check(screen.password.text == "", "Password cleared after submission")
	check(screen.submit.disabled and screen.health.disabled and screen.back.disabled, "Controls disabled while pending")
	check(not screen.email.editable, "Form frozen while pending")
	check(screen.requests.size() == 1, "One request sent")
	check(screen.requests[0].url == "http://127.0.0.1:8001/accounts", "Registration URL")
	check(screen.requests[0].method == HTTPClient.METHOD_POST and "Content-Type: application/json" in screen.requests[0].headers, "JSON POST request")
	var payload: Dictionary = JSON.parse_string(screen.requests[0].body)
	check(payload.email == "player@example.com" and payload.password == "a long demo password", "Registration payload intact")
	screen.send("register")
	check(screen.requests.size() == 1, "Repeated submission ignored while pending")
	screen.completed(HTTPRequest.RESULT_SUCCESS, 201, [], '{"id":42,"email":"player@example.com","display_name":"Player"}'.to_utf8_buffer())
	check(screen.status.text.begins_with("Account created:"), "Success displayed")
	check(not screen.submit.disabled and screen.email.editable, "Form restored on completion")
	for item in [[409, "already registered"], [422, "Check email"], [429, "Too many attempts"], [503, "unavailable"]]:
		screen.busy(true)
		screen.completed(HTTPRequest.RESULT_SUCCESS, item[0], [], '{"detail":"error"}'.to_utf8_buffer())
		check(screen.status.text.contains(item[1]), "Expected error state for " + str(item[0]))
		check(not screen.submit.disabled, "Can retry after HTTP error")
	screen.busy(true)
	screen.completed(HTTPRequest.RESULT_TIMEOUT, 0, [], PackedByteArray())
	check(screen.status.text.begins_with("Cannot reach"), "Timeout is not success")
	check(not screen.submit.disabled, "Can retry after timeout")
	for body in ['not json', '[]', 'null', '{}', '{"id":null}', '{"id":-1,"email":"x","display_name":"x"}', '{"id":1.5,"email":"x","display_name":"x"}', '{"id":1,"email":"x","display_name":null}']:
		screen.completed(HTTPRequest.RESULT_SUCCESS, 201, [], body.to_utf8_buffer())
		check(screen.status.text.begins_with("Unexpected API"), "Malformed response is not success")
	var long_password := "x".repeat(129)
	screen.password.text = long_password
	screen.send("register")
	var long_payload: Dictionary = JSON.parse_string(screen.requests[-1].body)
	check(long_payload.password == long_password, "Overlong passwords reach validation without silent truncation")
	screen.completed(HTTPRequest.RESULT_SUCCESS, 422, [], '{"detail":[]}'.to_utf8_buffer())
	screen.send("health")
	check(screen.requests[-1].url.ends_with("/health") and screen.requests[-1].method == HTTPClient.METHOD_GET, "Health uses GET")
	screen.completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"status":"running"}'.to_utf8_buffer())
	check(screen.status.text.begins_with("API is running"), "Health success displayed")
	screen.request_error = ERR_INVALID_PARAMETER
	screen.password.text = "a long demo password"
	screen.send("register")
	check(not screen.submit.disabled and not screen.request_pending, "Immediate transport failure restores controls")
	check(screen.status.text.begins_with("Could not start"), "Immediate transport failure visible")
	screen.api_url.text = "http://remote.example.com"
	var count: int = screen.requests.size()
	screen.send("register")
	check(screen.requests.size() == count, "Unsafe origin never reaches transport")
	print("Registration form: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
