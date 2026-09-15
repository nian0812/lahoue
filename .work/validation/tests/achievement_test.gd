extends Node

var failures: int = 0
var original_dataset: Dictionary = {}

@onready var world: Node = get_parent()
@onready var tracker: Node = world.get_node("achievement_tracker")


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_achievement_test"):
		push_error("achievement_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	original_dataset = data_manager.get_dataset("achievements").duplicate(true)
	var production_result: Dictionary = data_manager.validate_achievement_definitions(original_dataset)
	_expect(bool(production_result.get("ok", false)), "production achievement definitions are invalid")
	_expect((production_result.get("definitions", {}) as Dictionary).size() == 18, "production achievement count is wrong")

	var test_dataset: Dictionary = _make_test_dataset()
	var definition_result: Dictionary = data_manager.validate_achievement_definitions(test_dataset)
	_expect(bool(definition_result.get("ok", false)), "valid achievement definitions were rejected")
	_expect((definition_result.get("definitions", {}) as Dictionary).size() == 4, "achievement definitions did not load")
	_test_invalid_definitions(test_dataset)

	data_manager.data["achievements"] = test_dataset.duplicate(true)
	_expect(bool(tracker.call("reload_definitions")), "tracker could not load definitions")
	_expect((tracker.call("get_definitions") as Dictionary).size() == 4, "tracker definition count is wrong")

	var tile: Node = world.get_node("farm/tile_01")
	tile.emit_signal("crop_harvested", "farm_01", "rice", "rice", 1)
	var harvest_state: Dictionary = tracker.call("get_achievement_state", "harvest_steps") as Dictionary
	_expect(int(harvest_state.get("progress", 0)) == 1, "integrated farming event did not update progress")
	_expect(not bool(harvest_state.get("unlocked", false)), "achievement unlocked before its target")
	tile.emit_signal("crop_harvested", "farm_01", "rice", "rice", 1)
	harvest_state = tracker.call("get_achievement_state", "harvest_steps") as Dictionary
	_expect(bool(harvest_state.get("unlocked", false)), "achievement did not unlock at its target")
	_expect(bool(harvest_state.get("reward_claimed", false)), "empty reward did not close atomically")
	_expect(not bool(tracker.call("record_increment", "crops_harvested", 1)), "completed achievement accepted duplicate progress")
	_expect((tracker.call("get_achievement_state", "harvest_steps") as Dictionary) == harvest_state, "duplicate progress changed achievement state")

	game_manager.money = 0
	_expect(bool(tracker.call("record_maximum", "player_level", 2)), "maximum condition was not evaluated")
	_expect(game_manager.money == 0, "achievement reward was granted before Claim")
	_expect(bool(tracker.call("claim_reward", "level_reward")), "completed achievement reward could not be claimed")
	_expect(game_manager.money == 7, "claimed achievement money reward was not granted")
	_expect(not bool(tracker.call("record_maximum", "player_level", 3)), "maximum achievement unlocked twice")
	_expect(game_manager.money == 7, "achievement reward was duplicated")

	game_manager.money = game_manager.max_wallet_balance
	_expect(bool(tracker.call("record_increment", "items_sold", 1)), "reward-failure achievement did not unlock")
	var blocked_state: Dictionary = tracker.call("get_achievement_state", "blocked_reward") as Dictionary
	_expect(bool(blocked_state.get("unlocked", false)), "reward-failure achievement is not unlocked")
	_expect(not bool(blocked_state.get("reward_claimed", false)), "failed reward was marked claimed")
	game_manager.money = 0
	_expect(bool(tracker.call("claim_reward", "blocked_reward")), "retained reward could not be retried")
	_expect(game_manager.money == 5, "retried reward amount is wrong")
	_expect(not bool(tracker.call("claim_reward", "blocked_reward")), "reward could be claimed twice")
	_expect(game_manager.money == 5, "duplicate reward claim changed wallet")

	_expect(bool(tracker.call("record_increment", "upgrades_purchased", 2)), "partial progress was rejected")
	var partial_state: Dictionary = tracker.call("get_achievement_state", "upgrade_progress") as Dictionary
	_expect(int(partial_state.get("progress", 0)) == 2 and not bool(partial_state.get("unlocked", false)), "partial progress is inaccurate")

	game_manager.money = 123
	_expect(save_manager.save_game(), "achievement state could not be saved")
	tracker.call("reset_state")
	game_manager.money = 0
	_expect(save_manager.load_game(), "achievement state could not be loaded")
	_expect((tracker.call("get_achievement_state", "harvest_steps") as Dictionary) == harvest_state, "unlocked achievement did not restore")
	_expect((tracker.call("get_achievement_state", "upgrade_progress") as Dictionary) == partial_state, "achievement progress did not restore")
	_expect(bool((tracker.call("get_achievement_state", "blocked_reward") as Dictionary).get("reward_claimed", false)), "claimed reward state did not restore")
	_expect(game_manager.money == 123, "wallet regression during achievement load")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("achievements")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy v1 save without achievement state is incompatible")
	_expect((legacy_validation.get("state", {}) as Dictionary).get("achievements", []) == [], "legacy achievement state did not migrate to empty")
	_test_invalid_save_states()
	_finish_tests()


func _make_test_dataset() -> Dictionary:
	return {
		"schema_version": 1,
		"entries": {
			"harvest_steps": {"condition": {"metric": "crops_harvested", "mode": "increment", "target": 2}, "reward": null},
			"level_reward": {"condition": {"metric": "player_level", "mode": "maximum", "target": 2}, "reward": {"type": "money", "amount": 7}},
			"blocked_reward": {"condition": {"metric": "items_sold", "mode": "increment", "target": 1}, "reward": {"type": "money", "amount": 5}},
			"upgrade_progress": {"condition": {"metric": "upgrades_purchased", "mode": "increment", "target": 5}, "reward": null},
		},
	}


func _test_invalid_definitions(valid_dataset: Dictionary) -> void:
	var unknown_metric: Dictionary = valid_dataset.duplicate(true)
	unknown_metric["entries"]["harvest_steps"]["condition"]["metric"] = "unknown_metric"
	_expect(not bool(data_manager.validate_achievement_definitions(unknown_metric).get("ok", false)), "unknown achievement metric was accepted")
	var invalid_id: Dictionary = valid_dataset.duplicate(true)
	invalid_id["entries"]["Bad Id"] = invalid_id["entries"]["harvest_steps"]
	_expect(not bool(data_manager.validate_achievement_definitions(invalid_id).get("ok", false)), "invalid achievement id was accepted")
	var unknown_item: Dictionary = valid_dataset.duplicate(true)
	unknown_item["entries"]["harvest_steps"]["reward"] = {"type": "item", "item_id": "missing", "amount": 1}
	_expect(not bool(data_manager.validate_achievement_definitions(unknown_item).get("ok", false)), "unknown reward item was accepted")
	var definitions_before: Dictionary = tracker.call("get_definitions") as Dictionary
	_expect(not bool(tracker.call("configure_definitions", unknown_metric)), "tracker accepted invalid definitions")
	_expect((tracker.call("get_definitions") as Dictionary) == definitions_before, "invalid definitions partially mutated tracker")


func _test_invalid_save_states() -> void:
	var unknown: Dictionary = save_manager.call("_build_save_state") as Dictionary
	unknown["achievements"] = [{"achievement_id": "missing", "progress": 1, "unlocked": false, "reward_claimed": false}]
	_expect(not bool((save_manager.call("_validate_save_state", unknown) as Dictionary).get("ok", false)), "save accepted unknown achievement")
	var overflow: Dictionary = save_manager.call("_build_save_state") as Dictionary
	overflow["achievements"] = [{"achievement_id": "harvest_steps", "progress": 3, "unlocked": true, "reward_claimed": true}]
	_expect(not bool((save_manager.call("_validate_save_state", overflow) as Dictionary).get("ok", false)), "save accepted progress above target")
	var duplicate: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var entry: Dictionary = {"achievement_id": "upgrade_progress", "progress": 2, "unlocked": false, "reward_claimed": false}
	duplicate["achievements"] = [entry, entry.duplicate(true)]
	_expect(not bool((save_manager.call("_validate_save_state", duplicate) as Dictionary).get("ok", false)), "save accepted duplicate achievement state")
	var early_reward: Dictionary = save_manager.call("_build_save_state") as Dictionary
	early_reward["achievements"] = [{"achievement_id": "upgrade_progress", "progress": 1, "unlocked": false, "reward_claimed": true}]
	_expect(not bool((save_manager.call("_validate_save_state", early_reward) as Dictionary).get("ok", false)), "save accepted reward before unlock")


func _finish_tests() -> void:
	if failures == 0:
		print("achievement_test: PASS")
	else:
		push_error("achievement_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	data_manager.data["achievements"] = original_dataset
	tracker.call("reload_definitions")
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("achievement_test: %s" % message)


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
