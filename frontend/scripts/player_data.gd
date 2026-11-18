extends Node

signal login_succeeded
signal login_failed(message)

signal signup_succeeded
signal signup_failed(message)

signal currency_success
signal currency_fail(message)

signal gamepass_success
signal gamepass_fail(message)

signal level_success
signal level_fail(message)

var user_id = 0
var url = "http://127.0.0.1:8000"

var paid_currency = 0;
var free_currency = 0;

var gamepass = false;
var level = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func _on_request_completed(results, response_code, headers, body, current_request, http):
	print(results)
	print(response_code)
	print(body.get_string_from_utf8())
	http.queue_free()

	if results != HTTPRequest.RESULT_SUCCESS:
		match current_request:
			"login":
				login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")
			"signup":
				signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")
			"currency":
				currency_fail.emit("Currency Retrieval Failed, our knights are giving chase to the thieving goblins as we speak")
			"gamepass":
				gamepass_fail.emit("Gamepass Retrieval Failed, it appears your subscription at the local tavern could not be found")
			"update_currency":
				currency_fail.emit("Currency Update Failed, our dwarven bankers could not process your currency change")
			"update_gamepass":
				gamepass_fail.emit("Gamepass Update Failed, we are searching for where your invitation to the Nice Knight's club went")
			_:
				print("Whatever you're doing isn't implemented yet because time crunch is real")
		
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 or response_code == 201:
		print(response_code)
		match current_request:
			"login":
				user_id = int(json["id"])
				login_succeeded.emit()
			"signup":
				signup_succeeded.emit()
			"currency":
				paid_currency = int(json["paid"])
				free_currency = int(json["free"])
				currency_success.emit()
			"gamepass":
				gamepass = bool(json["gamepass"])
				gamepass_success.emit()
			"level":
				level = int(json["level"])
				level_success.emit()
			"update_currency":
				if json["type"] == "paid":
					paid_currency = int(json["count"])
				elif json["type"] == "free":
					free_currency = int(json["count"])
				currency_success.emit()
			"update_gamepass":
				gamepass = bool(json["gamepass"])
				gamepass_success.emit()
			_:
				print("How'd you succeed with an unimplemented query?")

	else:
		match current_request:
			"login":
				match response_code:
					401:
						login_failed.emit("Login Failed, incorrect credentials")
					_:
						login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")
			"signup":
				match response_code:
					409:
						signup_failed.emit("Signup Failed, account already exists")
					422:
						signup_failed.emit("Signup Failed, email address is invalid")
					_:
						signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")
			"currency":
				if response_code == 401:
					currency_fail.emit("Currency retrieval failed, invalid user id")
				else:
					currency_fail.emit("Currency Retrieval Failed, Our knights are giving chase to the thieving goblins as we speak")
			"gamepass":
				if response_code == 401:
					gamepass_fail.emit("Gamepass retrieval failed, invalid user id")
				else:
					gamepass_fail.emit("Gamepass Retrieval Failed, it appears your subscription at the local tavern could not be found")
			"update_currency":
				if response_code == 453:
					currency_fail.emit("Not enough currency")
				else:
					currency_fail.emit("Currency update failed")
			"update_gamepass":
				gamepass_fail.emit("Gamepass update failed")
			_:
				print("How'd you succeed with an unimplemented query?")


func signup(email, name, password):
	print("sign up called")
	var body = JSON.stringify({"name": name, "password": password, "email": email})
	var headers = ["Content-Type: application/json"]

	url = "http://127.0.0.1:8000/signup"

	var result = _send(url, headers, HTTPClient.METHOD_POST, body, "signup")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")


func get_currency():
	print("Currency getter called")
	
	url = "http://127.0.0.1:8000/currency?u_id=" + str(user_id)
	
	var result = _send(url, [], HTTPClient.METHOD_GET, "", "currency")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		currency_fail.emit("Currency Retrieval Failed, Our knights are giving chase to the thieving goblins as we speak")

func get_gamepass():
	print("Gamepass getter called")
	
	url = "http://127.0.0.1:8000/gamepass?u_id=" + str(user_id)
	
	var result = _send(url, [], HTTPClient.METHOD_GET, "", "gamepass")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		gamepass_fail.emit("Gamepass Retrieval Failed, it appears your subscription at the local tavern could not be found")

func get_level():
	print("Level getter getting called")
	
	url = "http://127.0.0.1:8000/level?u_id=" + str(user_id)
	
	var result = _send(url, [], HTTPClient.METHOD_GET, "", "level")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		level_fail.emit("Level Retrieval Faild, your powerlevel is too obscure for even our scanners")
	

func login(name, password):
	print("log in called")
	var body = JSON.stringify({"name": name, "password": password})
	var headers = ["Content-Type: application/json"]
	
	url = "http://127.0.0.1:8000/login"
	
	var result = _send(url, headers, HTTPClient.METHOD_POST, body, "login")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")


func update_currency(amt, type):
	print("currency update called")
	var body = JSON.stringify({"u_id": user_id, "amount": amt, "type": type})
	var headers = ["Content-Type: application/json"]
	
	url = "http://127.0.0.1:8000/currency/update"
	
	var result = _send(url, headers, HTTPClient.METHOD_POST, body, "update_currency")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		currency_fail.emit("Currency update failed")
		
func update_gamepass(has_pass):
	
	if has_pass == gamepass:
		print("You already have this value silly")
		return
	
	print("buying gamepass")
	var body = JSON.stringify({"u_id" : user_id, "gamepass": has_pass})
	var headers = ["Content-Type: application/json"]
	
	url = "http://127.0.0.1:8000/gamepass/update"
	
	var result = _send(url, headers, HTTPClient.METHOD_POST, body, "update_gamepass")
	if result == 0:
		print("Initial connection status: ", result)
	else:
		gamepass_fail.emit("Gamepass update failed")


func _send(s_url, headers, method, body, request_type) -> int:
	print("database query")
	
	# make a whole new http node because they can only do 1 request at a time
	var http = HTTPRequest.new()
	add_child(http)
	
	# bind that jawn so it can accept values in here
	http.request_completed.connect(_on_request_completed.bind(request_type, http))
	
	# send the request, if it blows up kill http, regardless, return it
	var result = http.request(s_url, headers, method, body)
	if result == 0:
		return result
	http.queue_free()
	return result
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
