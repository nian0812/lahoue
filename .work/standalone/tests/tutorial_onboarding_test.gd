extends Node

const tutorial_controller_script: Script = preload("res://scripts/tutorial/tutorial_controller.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_tutorial_test"):
		push_error("tutorial_onboarding_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	await get_tree().process_frame
	await get_tree().process_frame
	var controller: Node = world.get_node("tutorial_controller")
	var popup: Control = world.get_node("ui/tutorial_popup") as Control

	_expect(String(controller.get("current_tutorial")) == "new_game", "new game tutorial did not start")
	_expect(String((popup.get("title_label") as Label).text) == "Welcome to LaHoue", "new game tutorial title is wrong")

	_assert_level_queue(controller, 2, [], "Lv2 queued a redesigned feature early")
	_assert_level_queue(controller, 3, ["animal"], "Animal tutorial is not gated at Lv3")
	_assert_level_queue(controller, 5, ["cooking", "restaurant", "staff"], "Restaurant/Staff tutorials are not gated at Lv5")
	_assert_level_queue(controller, 10, ["aquaculture"], "Aquaculture tutorial is not gated at Lv10")
	_assert_level_queue(controller, 35, ["premium_market"], "Premium Market tutorial is not gated at Lv35")
	_assert_level_queue(controller, 55, ["level_10"], "LaHoue Empire tutorial is not gated at Lv55")
	_expect(String((popup.get("title_label") as Label).text) == "LaHoue Empire", "Lv55 tutorial title was not updated")
	_expect(String((popup.get("body_label") as Label).text).contains("Level 55"), "Lv55 tutorial body does not describe the terminal level")

	var valid_state: Dictionary = controller.call("get_save_state") as Dictionary
	_expect(bool((tutorial_controller_script.validate_save_state(valid_state) as Dictionary).get("ok", false)), "current tutorial state failed validation")
	var invalid_state: Dictionary = valid_state.duplicate(true)
	invalid_state["queue"] = ["premium_market", "premium_market"]
	_expect(not bool((tutorial_controller_script.validate_save_state(invalid_state) as Dictionary).get("ok", false)), "duplicate tutorial queue was accepted")

	game_manager.level = 54
	var completed_state: Dictionary = _tutorial_state_with_pending(controller, [])
	completed_state["state"] = "COMPLETED"
	var pre_max_save: Dictionary = save_manager.call("_build_save_state") as Dictionary
	pre_max_save["level"] = 54
	pre_max_save["exp"] = 0
	pre_max_save["tutorial"] = completed_state
	var reopened: Dictionary = save_manager.call("_validate_save_state", pre_max_save) as Dictionary
	_expect(bool(reopened.get("ok", false)), "pre-Lv55 completed tutorial save was rejected")
	if bool(reopened.get("ok", false)):
		var reopened_tutorial: Dictionary = (reopened.get("state", {}) as Dictionary).get("tutorial", {}) as Dictionary
		_expect(String(reopened_tutorial.get("state", "")) == "ACTIVE", "pre-Lv55 old completion was not reopened")
		_expect(not bool((reopened_tutorial.get("completed_features", {}) as Dictionary).get("level_10", true)), "pre-Lv55 migration left final tutorial completed")

	game_manager.level = 55
	var legacy_save: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_save.erase("tutorial")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_save) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy save without tutorial field was rejected")
	if bool(legacy_validation.get("ok", false)):
		save_manager.call("_apply_save_state", legacy_validation.get("state", {}) as Dictionary)
		_expect(String(controller.get("current_tutorial")) == "level_10", "legacy Lv55 save did not recover to LaHoue Empire tutorial")

	save_manager.create_new_game()
	game_manager.stop_gameplay()
	controller.call("skip_tutorial")
	var skip_money: int = game_manager.money
	var skip_items: Dictionary = inventory_manager.items.duplicate(true)
	_expect(String(controller.get("master_state")) == "SKIPPED", "Skip did not set SKIPPED")
	_expect(save_manager.save_game(), "skipped tutorial state could not be saved")
	controller.call("apply_save_state", {})
	_expect(save_manager.load_game(), "skipped tutorial state could not be loaded")
	_expect(String(controller.get("master_state")) == "SKIPPED" and not popup.visible, "Continue replayed a skipped tutorial")
	_expect(game_manager.money == skip_money and inventory_manager.items == skip_items, "Skip changed gameplay economy")

	_finish_tests()


func _assert_level_queue(controller: Node, level: int, pending: Array[String], message: String) -> void:
	game_manager.level = level
	controller.call("apply_save_state", _tutorial_state_with_pending(controller, pending))
	controller.call("_queue_unlocked_tutorials", level)
	var actual: Array[String] = []
	var current: String = String(controller.get("current_tutorial"))
	if not current.is_empty():
		actual.append(current)
	for queued_id: Variant in controller.get("tutorial_queue") as Array:
		actual.append(String(queued_id))
	_expect(actual == pending, "%s (got %s)" % [message, actual])


func _tutorial_state_with_pending(controller: Node, pending: Array[String]) -> Dictionary:
	var completed: Dictionary = {}
	for feature_id: String in controller.get("feature_ids") as Array[String]:
		completed[feature_id] = not pending.has(feature_id)
	var hints: Dictionary = {"helicopter_upgrade": false}
	var milestones: Dictionary = {}
	for milestone_id: String in controller.get("milestone_ids") as Array[String]:
		milestones[milestone_id] = false
	return {
		"state": "ACTIVE",
		"current_tutorial": "",
		"current_step": 0,
		"completed_features": completed,
		"one_time_hints": hints,
		"milestones": milestones,
		"queue": [],
	}


func _finish_tests() -> void:
	if failures == 0:
		print("tutorial_onboarding_test: PASS")
	else:
		push_error("tutorial_onboarding_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("tutorial_onboarding_test: %s" % message)


func _cleanup_save_files() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return
	user_directory.list_dir_begin()
	var file_name: String = user_directory.get_next()
	while not file_name.is_empty():
		if not user_directory.current_is_dir() and file_name.begins_with("savegame"):
			user_directory.remove(file_name)
		file_name = user_directory.get_next()
	user_directory.list_dir_end()
