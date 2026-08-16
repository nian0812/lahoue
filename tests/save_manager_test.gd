extends Node

var failures: int = 0


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_save_test"):
		push_error("save_manager_test: refusing to run outside the isolated test user directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()

	save_manager.create_new_game()
	game_manager.day = 3
	game_manager.money = 1200
	_expect(inventory_manager.add_item("rice_seed", 2), "test inventory setup failed")
	_expect(save_manager.save_game(), "first valid save failed")
	_expect(FileAccess.file_exists(save_manager.save_path), "primary save was not created")

	game_manager.day = 4
	game_manager.money = 2400
	_expect(save_manager.save_game(), "second valid save failed")
	_expect(FileAccess.file_exists(save_manager.backup_path), "backup save was not created")

	_expect(_write_text(save_manager.save_path, "{corrupt"), "could not write corrupt fixture")
	save_manager.create_new_game()
	_expect(save_manager.load_game(), "load did not recover from the valid backup")
	_expect(game_manager.day == 3, "backup day state was not restored")
	_expect(game_manager.money == 1200, "backup money state was not restored")
	_expect(inventory_manager.get_amount("rice_seed") == 2, "backup inventory was not restored")

	var valid_state: Dictionary = _read_dictionary(save_manager.backup_path)
	_expect(not valid_state.is_empty(), "could not read the valid backup fixture")
	_expect(_remove_file(save_manager.backup_path), "could not remove backup fixture")
	_expect(_remove_file(save_manager.temporary_save_path), "could not remove temporary fixture")
	valid_state["day"] = 0
	_expect(
		_write_text(save_manager.save_path, JSON.stringify(valid_state)),
		"could not write invalid-state fixture"
	)

	game_manager.day = 7
	_expect(not save_manager.load_game(), "semantically invalid save was accepted")
	_expect(game_manager.day == 7, "failed load partially applied invalid state")

	_expect(save_manager.save_game(), "valid state could not be saved after load failure")
	var last_good_save: String = _read_text(save_manager.save_path)
	game_manager.day = 0
	_expect(not save_manager.save_game(), "invalid runtime state was written")
	_expect(
		_read_text(save_manager.save_path) == last_good_save,
		"failed save replaced the last known-good primary save"
	)

	if failures == 0:
		print("save_manager_test: PASS")
	else:
		push_error("save_manager_test: %d failure(s)" % failures)

	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("save_manager_test: %s" % message)


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


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var text: String = file.get_as_text()
	file.close()
	return text


func _read_dictionary(path: String) -> Dictionary:
	var parsed_value: Variant = JSON.parse_string(_read_text(path))
	if typeof(parsed_value) != TYPE_DICTIONARY:
		return {}

	return (parsed_value as Dictionary).duplicate(true)


func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
