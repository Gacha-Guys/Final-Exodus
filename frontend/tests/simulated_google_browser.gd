extends "res://scripts/demo/google_sign_in.gd"

# Keep the real controller and API requests; suppress only the external browser.
func open_browser(_url: String) -> Error:
	return OK
