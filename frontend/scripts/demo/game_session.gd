extends Node

signal account_changed(profile: Dictionary)

var token := ""
var account: Dictionary = {}
var battle: Dictionary = {}
var notice := ""
var generation := 0
var api_origin := "http://127.0.0.1:8007"

func _ready() -> void:
	var configured := OS.get_environment("FINAL_EXODUS_API_ORIGIN")
	if not configured.is_empty():
		api_origin = configured.trim_suffix("/")

func valid_origin(origin: String) -> bool:
	# Same origin-only policy as the registration screen in PR #6.
	var pattern := RegEx.new()
	pattern.compile("^(https://[A-Za-z0-9.-]+|http://(localhost|127\\.0\\.0\\.1))(:[0-9]{1,5})?$")
	if pattern.search(origin) == null:
		return false
	var authority := origin.split("://")[1]
	if authority.contains(":"):
		var port := int(authority.split(":")[1])
		return port >= 1 and port <= 65535
	return true

func clear() -> void:
	token = ""
	account = {}
	battle = {}
	generation += 1
	account_changed.emit(account)

func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20)]

func request(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, authenticated: bool = true) -> Dictionary:
	if not valid_origin(api_origin):
		return {"ok": false, "status": 0, "error": "Use a valid HTTPS or local API address."}
	var started_generation := generation
	var http := HTTPRequest.new()
	http.timeout = 6.0
	http.max_redirects = 0
	http.body_size_limit = 524288
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated and not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var err := http.request(api_origin + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": "Could not connect. Start the local API and retry."}
	var response: Array = await http.request_completed
	http.queue_free()
	if started_generation != generation:
		return {"ok": false, "status": 0, "error": "Account changed. Please retry."}
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "error": "Cannot reach the server. Check the connection and retry."}
	var code: int = response[1]
	if code == 204:
		return {"ok": true, "status": code, "data": {}}
	var parser := JSON.new()
	if parser.parse(response[3].get_string_from_utf8()) != OK:
		return {"ok": false, "status": code, "error": "Unexpected server response. Retry shortly."}
	var data: Variant = parser.data
	if code >= 200 and code < 300:
		if not data is Dictionary and data != null:
			return {"ok": false, "status": code, "error": "Unexpected server response."}
		return {"ok": true, "status": code, "data": data}
	var message := "Request failed. Please retry."
	if data is Dictionary and data.get("detail") is String:
		message = data.detail
	elif code == 422:
		message = "Check the fields. Use a valid email, birth date, and a 12–128 character password."
	if code == 401 and authenticated:
		clear()
		notice = "Session expired. Please log in again."
		get_tree().call_deferred("change_scene_to_file", "res://scenes/titleScreenNew.tscn")
	return {"ok": false, "status": code, "error": message}

func refresh_account() -> Dictionary:
	var result: Dictionary = await request("/me")
	if result.ok:
		var data: Variant = result.data
		if not valid_account(data):
			return {"ok": false, "status": 0, "error": "Unexpected account response."}
		account = data
		account_changed.emit(account)
	return result

func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func valid_account(data: Variant) -> bool:
	if not data is Dictionary or not data.get("display_name") is String or not data.get("email") is String:
		return false
	for key in ["id", "level", "experience", "free_currency", "paid_currency", "completed_battles"]:
		if not number(data.get(key)):
			return false
	return data.id > 0

func valid_battle(data: Variant) -> bool:
	if not data is Dictionary or not data.get("id") is String or not number(data.get("version")) or not number(data.get("turn")):
		return false
	if not data.get("status") in ["active", "won", "lost"] or not data.get("party") is Array or data.party.size() != 3:
		return false
	if not data.get("log") is Array or not data.get("enemy") is Dictionary:
		return false
	for entry in data.log:
		if not entry is String:
			return false
	var units: Array = data.party.duplicate()
	units.append(data.enemy)
	for unit in units:
		if not unit is Dictionary or not unit.get("name") is String:
			return false
		for key in ["hp", "max_hp", "attack"]:
			if not number(unit.get(key)):
				return false
	return true
