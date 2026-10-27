extends SceneTree

var checks := 0
var failures := 0
var currency_errors := 0

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func() -> void: push_error("Team integration checks timed out"); quit(1))
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var session := root.get_node("GameSession")
	var legacy := root.get_node("PlayerData")
	var profile := {"id": 42, "display_name": "Adapter Test", "email": "adapter@example.invalid", "level": 1, "experience": 0, "free_currency": 7, "paid_currency": 11, "completed_battles": 0}
	session.account = profile
	session.token = "isolated-client-test"
	session.account_changed.emit(profile)
	expect(legacy.user_id == 42 and legacy.paid_currency == 11 and legacy.free_currency == 7, "Team HUD adapter uses the authenticated profile")
	legacy.currency_fail.connect(func(_message: String) -> void: currency_errors += 1)
	legacy.getCurrency(43)
	expect(currency_errors == 1 and legacy.user_id == 42, "Legacy getter rejects another player's account")
	legacy.update_currency(50, "paid")
	expect(currency_errors == 2 and legacy.paid_currency == 11, "A client purchase cannot mint paid currency")
	# Invalid origin fails before transport, so these scene checks never access a server.
	var origin: String = session.api_origin
	session.api_origin = "invalid-for-offline-check"
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	expect(hub.has_method("open_battle") and hub.has_method("_on_currency_changed"), "Team hub and saved-battle controller remain connected")
	expect(hub.get_node("ShopButton") != null and hub.get_node("SummonButton") != null, "Team hub navigation is retained")
	hub._on_currency_changed()
	hub.get_node("%Currency").set_loading(true)
	expect(hub.get_node("%Currency").val == 11 and hub.get_node("%Currency/NinePatchRect/MarginContainer2/Value").text == "…", "Loading preserves numeric balance while showing pending state")
	hub._on_currency_changed()
	expect(not hub.get_node("%Currency").loading and hub.get_node("%Currency/NinePatchRect/MarginContainer2/Value").text == "11", "New balance ends loading and formats the numeric value")
	expect(hub.get_node("%Currency").val == 11, "Team hub keeps the numeric currency contract")
	hub.queue_free()
	await process_frame
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	expect(shop.has_method("refresh") and shop.has_method("purchase_unavailable"), "Team shop uses the same authenticated controller")
	for index in range(1, 7):
		var offer: Button = shop.get_node("GridContainer/CurrencyButton%d" % index)
		expect(shop.get_rect().encloses(offer.get_global_rect()), "Offer %d stays inside the viewport" % index)
		expect(offer.pressed.is_connected(Callable(shop, "purchase_unavailable")), "Offer %d remains visible and has safe purchase handling" % index)
	expect(shop.get_node("GridContainer/CurrencyButton1").get_global_rect().position.y >= shop.status_label.get_global_rect().end.y, "Offers do not overlap account status")
	expect(shop.get_node("GridContainer/CurrencyButton6").get_global_rect().end.y <= shop.get_node("UnitsButton").get_global_rect().position.y, "Gamepass stays above bottom navigation")
	shop.get_node("GridContainer/CurrencyButton1").pressed.emit()
	expect(shop.status_label.text.contains("No currency") and legacy.paid_currency == 11, "Offer click reports unavailable payment without changing balances")
	shop._on_currency_changed()
	expect(shop.get_node("%Currency").val == 11, "Team shop receives the paid-currency signal")
	session.clear()
	expect(legacy.user_id == 0 and legacy.paid_currency == 0 and legacy.free_currency == 0, "Logout clears team HUD adapter private state")
	shop.queue_free()
	session.api_origin = origin
	await process_frame
	print("Team integration checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
