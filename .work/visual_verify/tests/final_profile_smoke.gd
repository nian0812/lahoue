extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("lahoue_codex_profile_smoke") or OS.get_cmdline_user_args().size() != 1:
		get_tree().quit(1)
		return
	game_manager.stop_gameplay()
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	if not source is Dictionary:
		get_tree().quit(1)
		return
	var result: Dictionary = save_manager._validate_save_state(source)
	if not result.ok:
		push_error("final_profile_smoke: " + str(result.error))
		get_tree().quit(1)
		return
	save_manager._apply_save_state(result.state)
	game_manager.add_exp(1000)
	var ok: bool = save_manager.save_game() and save_manager.load_game()
	ok = ok and game_manager.level == mini(int(source.level),55) and game_manager.money == int(source.money)
	ok = ok and game_manager.current_exp == 0 and not game_manager.profile_level_override
	print("final_profile_smoke: %s; old Lv100 profile loads, earns rewards, saves and continues in isolation" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
