extends Node

signal game_saved(path)
signal game_loaded(path)
signal save_failed(reason)
signal load_failed(reason)

const save_path: String = "user://savegame.json"
const save_version: int = 1


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var state: Dictionary = _build_save_state()
	var json_text: String = JSON.stringify(state, "\t")

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("cannot open save file for writing")
		return false

	file.store_string(json_text)
	file.close()

	game_saved.emit(save_path)
	return true


func load_game() -> bool:
	if not has_save():
		load_failed.emit("save file not found")
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_failed.emit("cannot open save file")
		return false

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(text)

	if error != OK:
		load_failed.emit(
			"json parse error at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return false

	var parsed_data: Variant = json.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		load_failed.emit("save root must be a dictionary")
		return false

	_apply_save_state(parsed_data as Dictionary)
	game_loaded.emit(save_path)
	return true


func _build_save_state() -> Dictionary:
	var state: Dictionary = game_manager.get_save_state()
	state.merge(inventory_manager.get_save_state(), true)

	# These fields are reserved now so later systems can be added
	# without changing the agreed top-level save structure.
	state["save_version"] = save_version
	state["crops"] = {}
	state["crop_growth"] = {}
	state["animals"] = {}
	state["animal_age"] = {}
	state["aquaculture"] = {}
	state["coop_level"] = 1
	state["cow_barn_level"] = 1
	state["restaurant_level"] = 0
	state["kitchen_level"] = 0
	state["beverage_counter"] = 0
	state["staff"] = {}
	state["unlocked_recipes"] = []
	state["unlocked_items"] = []
	state["achievements"] = []

	return state


func _apply_save_state(state: Dictionary) -> void:
	game_manager.apply_save_state(state)
	inventory_manager.apply_save_state(state)


func create_new_game() -> void:
	game_manager.apply_save_state({
		"day": 1,
		"day_timer": 0.0,
		"money": 0,
		"exp": 0,
		"level": 1,
		"reputation": 1.0
	})

	inventory_manager.clear()
