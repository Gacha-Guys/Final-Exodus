extends "res://scripts/registration_test.gd"

var requests: Array[Dictionary] = []
var request_error: Error = OK

func perform_request(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: String) -> Error:
	requests.append({"url": url, "headers": headers, "method": method, "body": body})
	return request_error
