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
	# Invalid origin fails before transport, so these scene checks never access a server.
	var origin: String = session.api_origin
	session.api_origin = "invalid-for-offline-check"
	await legacy.update_currency(50, "paid")
	expect(currency_errors == 2 and legacy.paid_currency == 11, "Failed currency requests preserve the balance")
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	expect(not hub.has_method("open_battle") and hub.has_method("_on_currency_changed"), "Team hub has no injected combat controller")
	expect(hub.get_node("StoryButton").visible, "Team Story button stays visible")
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
	expect(not shop.has_method("open_battle"), "Team shop has no injected demo UI")
	expect(shop.get_node("GridContainer").get_child_count() == 5, "Riley's four gem offers and gamepass remain five offers")
	for index in range(1, 6):
		var offer: Button = shop.get_node("GridContainer/CurrencyButton%d" % index)
		expect(shop.get_rect().encloses(offer.get_global_rect()), "Offer %d stays inside the viewport" % index)
	expect(shop.get_node("GridContainer/CurrencyButton5/HBoxContainer2/Title").text.contains("Gamepass"), "Gamepass remains Riley's fifth offer")
	for index in range(4):
		expect(shop.get_node("%%CurrencyButton%d" % (index + 1)).pressed.is_connected(Callable(shop, "_on_currency_offer_pressed").bind([50, 200, 500, 999][index])), "Mihai's currency offer %d stays connected" % (index + 1))
	await shop._on_currency_offer_pressed()
	expect(shop.message.dialog_text.contains("valid") and legacy.paid_currency == 11, "Failed offer shows feedback and preserves balance")
	shop._on_currency_changed()
	expect(shop.get_node("%Currency").val == 11, "Team shop receives the paid-currency signal")
	session.clear()
	expect(legacy.user_id == 0 and legacy.paid_currency == 0 and legacy.free_currency == 0, "Logout clears team HUD adapter private state")
	expect(shop.get_node(shop.RANK_PATH).text == "Rank\n—", "Logout clears the previous account rank")
	shop.queue_free()
	session.api_origin = origin
	await process_frame
	print("Team integration checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
