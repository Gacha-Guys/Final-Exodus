extends SceneTree

func _initialize() -> void:
	create_timer(10).timeout.connect(func() -> void:
		push_error("Battle conflict check timed out")
		quit(1)
	)
	call_deferred("run")

func run() -> void:
	root.get_node("GameSession").token = "synthetic-test"
	change_scene_to_file("res://scenes/battle/team_battle.tscn")
	await scene_changed
	var battle := current_scene
	while battle.pending:
		await create_timer(0.02).timeout
	assert(battle.state.version == 0 and not battle.attack_buttons[0].disabled,
		"Initial battle must permit an attack")
	await battle.attack(0)
	assert(battle.state.version == 0, "A failed refresh must leave the last displayed version intact")
	assert(battle.attack_buttons.all(func(button: Button) -> bool: return button.disabled),
		"Attacks must remain disabled after a conflict and a failed reload")
	assert(not battle.retry_button.disabled, "The player must be able to retry the reload")
	await battle.retry()
	assert(battle.state.version == 1 and not battle.attack_buttons[0].disabled,
		"Attacks must resume once a newer battle version has loaded")
	print("PASS: conflict plus failed reload blocks attacks until retry loads fresh state")
	quit()
