extends Control

const TEAM: Array[String] = ["tyler", "jason", "mihai", "riley"]
var click_count: int = 0

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "FINAL EXODUS — TEAM SYNC TEST"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var instructions := Label.new()
	instructions.text = "If you can see this screen, the shared GDScript project runs.\nEdit only your check-in file, then share your change through GitHub."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	for member in TEAM:
		var row := Label.new()
		var path := "res://team_checkins/%s.txt" % member
		row.text = "%s: %s" % [member.capitalize(), FileAccess.get_file_as_string(path).strip_edges()]
		column.add_child(row)
	var button := Button.new()
	button.text = "Test button — 0 clicks"
	button.pressed.connect(func() -> void:
		click_count += 1
		button.text = "Test button — %d clicks" % click_count
	)
	column.add_child(button)
	var note := Label.new()
	note.text = "Local button clicks reset when you restart. GitHub syncs files, not live game state.\nThis screen does not connect to the backend yet."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	var accounts := Button.new()
	accounts.text = "Open account creation test"
	accounts.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/registration_test.tscn"))
	column.add_child(accounts)
