# Run: Godot --headless --path frontend --script res://tests/registration_safety.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var screen = load("res://scenes/registration_test.tscn").instantiate()
	root.add_child(screen)
	for address in ["http://localhost:8001", "http://127.0.0.1", "https://api.example.com:443"]:
		if not screen.valid_api_origin(address):
			push_error("Rejected valid origin: " + address)
			quit(1)
			return
	for address in ["http://remote.example.com", "http://localhost:80@remote.example.com", "http://127.0.0.1:80@remote.example.com", "https://", "https://api.example.com/path", "https://api.example.com#fragment", "http://localhost:65536", "http://localhost:0"]:
		if screen.valid_api_origin(address):
			push_error("Accepted unsafe origin: " + address)
			quit(1)
			return
	if screen.http.max_redirects != 0:
		push_error("Registration must not follow redirects")
		quit(1)
		return
	root.size = Vector2i(480, 854)
	var sync = load("res://scenes/sync_test.tscn").instantiate()
	root.add_child(sync)
	await process_frame
	await process_frame
	var margin = sync.get_child(0)
	if margin.get_combined_minimum_size().x > 480 or margin.get_combined_minimum_size().y > 854:
		push_error("Sync screen overflows portrait viewport")
		quit(1)
		return
	print("PASS: API origin validation and redirect policy")
	quit()
