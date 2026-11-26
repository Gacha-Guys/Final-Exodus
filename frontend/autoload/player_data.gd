extends Node

# Compatibility signals for the team's HUD and shop, backed by one JWT session.
signal login_succeeded
signal login_failed(message)
signal signup_succeeded
signal signup_failed(message)
signal currency_success
signal currency_fail(message)
signal gamepass_success
signal gamepass_fail(message)

var user_id := 0
var paid_currency := 0
var free_currency := 0
var has_gamepass := false

func _ready() -> void:
	GameSession.account_changed.connect(sync_account)
	sync_account(GameSession.account)

func sync_account(profile: Dictionary) -> void:
	user_id = int(profile.get("id", 0))
	paid_currency = int(profile.get("paid_currency", 0))
	free_currency = int(profile.get("free_currency", 0))
	has_gamepass  = bool(profile.get("gamepass", false))
	currency_success.emit()
	gamepass_success.emit()

func getCurrency(id: int) -> void:
	if GameSession.token.is_empty() or id != user_id:
		currency_fail.emit("Log in to view your own currency.")
		return
	var result: Dictionary = await GameSession.refresh_account()
	if not result.ok:
		currency_fail.emit(result.error)

# Older teammate scenes still call these account methods after merging frontend changes.
func login(name: String, password: String) -> void:
	var result: Dictionary = await GameSession.request("/login", HTTPClient.METHOD_POST, {"name": name, "password": password}, false)
	password = ""
	if not result.ok or not result.data is Dictionary or not result.data.get("access_token") is String:
		login_failed.emit(result.get("error", "Unexpected login response."))
		return
	GameSession.clear()
	GameSession.token = result.data.access_token
	var profile: Dictionary = await GameSession.refresh_account()
	if not profile.ok:
		GameSession.clear()
		login_failed.emit(profile.error)
		return
	login_succeeded.emit()

func signup(email: String, name: String, password: String, dob: String = "") -> void:
	var body := {"email": email, "name": name, "password": password}
	if not dob.is_empty():
		body["dob"] = dob
	var result: Dictionary = await GameSession.request("/signup", HTTPClient.METHOD_POST, body, false)
	password = ""
	if result.ok and result.status == 201:
		signup_succeeded.emit()
	else:
		signup_failed.emit(result.get("error", "Unexpected registration response."))
