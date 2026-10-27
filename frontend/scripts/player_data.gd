extends Node

signal login_succeeded
signal login_failed(message)

signal signup_succeeded
signal signup_failed(message)

signal currency_success
signal currency_fail(message)

var user_id = 0
var http = HTTPRequest.new()
var url = "http://127.0.0.1:8000"
var current_request = ""

var paid_currency = 0;
var free_currency = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(http)
	http.request_completed.connect(_on_request_completed)



func _on_request_completed(results, response_code, headers, body):
	print(results)
	print(response_code)
	print(body.get_string_from_utf8())

	if results != HTTPRequest.RESULT_SUCCESS:
		match current_request:
			"login":
				login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")
			"signup":
				signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")
			"currency":
				currency_fail.emit("Currency Retrieval Failed, Our knights are giving chase to the thieving goblins as we speak")
			_:
				print("Whatever you're doing isn't implemented yet because time crunch is real")
		current_request = ""
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 or response_code == 201:
		print(response_code)
		match current_request:
			"login":
				current_request = ""
				user_id = int(json["id"])
				login_succeeded.emit()
			"signup":
				current_request = ""
				signup_succeeded.emit()
			"currency":
				current_request = ""
				paid_currency = int(json["paid"])
				free_currency = int(json["free"])
				currency_success.emit()
			"update_currency":
				current_request = ""
				if json["type"] == "paid":
					paid_currency = int(json["count"])
				elif json["type"] == "free":
					free_currency = int(json["count"])
				currency_success.emit()
			_:
				print("How'd you succeed with an unimplemented query?")

	else:
		match current_request:
			"login":
				current_request = ""
				match response_code:
					401:
						login_failed.emit("Login Failed, incorrect credentials")
					_:
						login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")
			"signup":
				current_request = ""
				match response_code:
					409:
						signup_failed.emit("Signup Failed, account already exists")
					422:
						signup_failed.emit("Signup Failed, email address is invalid")
					_:
						signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")
			"currency":
				current_request = ""
				if response_code == 401:
					currency_fail.emit("Currency retrieval failed, invalid user id")
				else:
					currency_fail.emit("Currency Retrieval Failed, Our knights are giving chase to the thieving goblins as we speak")
			"update_currency":
				current_request = ""
				if response_code == 453:
					currency_fail.emit("Not enough currency")
				else:
					currency_fail.emit("Currency update failed")
			_:
				print("How'd you succeed with an unimplemented query?")


func signup(email, name, password):
	print("sign up called")
	var body = JSON.stringify({"name": name, "password": password, "email": email})
	var headers = ["Content-Type: application/json"]

	url = "http://127.0.0.1:8000/signup"
	current_request = "signup"

	print("database query")
	var result = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if result == 0:
		print("Initial connection status: ", result)
	else:
		login_failed.emit("Login Failed, summoners are attempting to summon an entity who may know what has gone wrong")


func getCurrency(id):
	print("Currency getter called")
	
	url = "http://127.0.0.1:8000/currency?u_id=" + str(id)
	current_request = "currency"
	
	print("databae query")
	var result = http.request(url, [], HTTPClient.METHOD_GET)
	if result == 0:
		print("Initial connection status: ", result)
	else:
		currency_fail.emit("Currency Retrieval Failed, Our knights are giving chase to the thieving goblins as we speak")


func login(name, password):
	print("log in called")
	var body = JSON.stringify({"name": name, "password": password})
	var headers = ["Content-Type: application/json"]
	
	url = "http://127.0.0.1:8000/login"
	current_request = "login"
	
	print("database query")
	var result = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if result == 0:
		print("Initial connection status: ", result)
	else:
		signup_failed.emit("Signup Failed, unkown reason that not even our wisest wizards could discern")


func update_currency(amt, type):
	print("currency update called")
	var body = JSON.stringify({"u_id": user_id, "amount": amt, "type": type})
	var headers = ["Content-Type: application/json"]
	
	url = "http://127.0.0.1:8000/currency/update"
	
	print("database query")
	var result = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if result == 0:
		current_request = "update_currency"
		print("Initial connection status: ", result)
	else:
		signup_failed.emit("Currency update failed")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
