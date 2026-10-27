extends Node

# Compatibility signals for the team's HUD and shop, backed by one JWT session.
signal login_succeeded
signal login_failed(message)
signal signup_succeeded
signal signup_failed(message)
signal currency_success
signal currency_fail(message)

var user_id := 0
var paid_currency := 0
var free_currency := 0

func _ready() -> void:
	GameSession.account_changed.connect(sync_account)
	sync_account(GameSession.account)

func sync_account(profile: Dictionary) -> void:
	user_id = int(profile.get("id", 0))
	paid_currency = int(profile.get("paid_currency", 0))
	free_currency = int(profile.get("free_currency", 0))
	currency_success.emit()

func getCurrency(id: int) -> void:
	if GameSession.token.is_empty() or id != user_id:
		currency_fail.emit("Log in to view your own currency.")
		return
	var result: Dictionary = await GameSession.refresh_account()
	if not result.ok:
		currency_fail.emit(result.error)

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
	if dob.is_empty():
		signup_failed.emit("Enter your birth date in the account form.")
		return
	var result: Dictionary = await GameSession.request("/accounts", HTTPClient.METHOD_POST, {"email": email, "display_name": name, "password": password, "dob": dob}, false)
	password = ""
	if result.ok and result.status == 201:
		signup_succeeded.emit()
	else:
		signup_failed.emit(result.get("error", "Unexpected registration response."))

func update_currency(_amount: int, _type: String) -> void:
	# Currency changes come from server-verified gameplay or payment operations.
	currency_fail.emit("Currency requires a verified reward or purchase.")
