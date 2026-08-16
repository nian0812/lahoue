extends Node

signal game_saved(path)
signal game_loaded(path)
signal corrupt_save_preserved(original_path, preserved_path)
signal save_failed(reason)
signal load_failed(reason)

const save_path: String = "user://savegame.json"
const backup_path: String = "user://savegame.backup.json"
const temporary_save_path: String = "user://savegame.tmp.json"
const save_version: int = 1
const max_safe_json_integer: int = 9007199254740991


func has_save() -> bool:
	for candidate_path: String in _get_load_candidates():
		if FileAccess.file_exists(candidate_path):
			return true

	return false


func save_game() -> bool:
	var validation: Dictionary = _validate_save_state(_build_save_state())
	if not bool(validation.get("ok", false)):
		return _fail_save("refusing to save invalid state: %s" % validation.get("error", "unknown error"))

	var state: Dictionary = validation.get("state", {}) as Dictionary
	var json_text: String = JSON.stringify(state, "\t")
	var cleanup_error: Error = _remove_file_if_exists(temporary_save_path)
	if cleanup_error != OK:
		return _fail_save(
			"cannot remove stale temporary save: %s" % error_string(cleanup_error)
		)

	var file: FileAccess = FileAccess.open(temporary_save_path, FileAccess.WRITE)
	if file == null:
		return _fail_save("cannot open temporary save file for writing")

	file.store_string(json_text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		_remove_file_if_exists(temporary_save_path)
		return _fail_save("cannot write temporary save: %s" % error_string(write_error))

	var written_result: Dictionary = _read_json_file(temporary_save_path)
	if not bool(written_result.get("ok", false)):
		_remove_file_if_exists(temporary_save_path)
		return _fail_save(
			"temporary save verification failed: %s" % written_result.get("error", "unknown error")
		)

	var written_state: Dictionary = written_result.get("state", {}) as Dictionary
	var written_validation: Dictionary = _validate_save_state(written_state)
	if not bool(written_validation.get("ok", false)):
		_remove_file_if_exists(temporary_save_path)
		return _fail_save(
			"temporary save contains invalid state: %s" % written_validation.get("error", "unknown error")
		)

	if not _replace_save_with_temporary():
		return false

	game_saved.emit(save_path)
	return true


func load_game() -> bool:
	var failure_reasons: Array[String] = []

	for candidate_path: String in _get_load_candidates():
		if not FileAccess.file_exists(candidate_path):
			continue

		var read_result: Dictionary = _read_json_file(candidate_path)
		if not bool(read_result.get("ok", false)):
			failure_reasons.append(
				"%s: %s" % [candidate_path, read_result.get("error", "unknown read error")]
			)
			_preserve_invalid_save(candidate_path)
			continue

		var state: Dictionary = read_result.get("state", {}) as Dictionary
		var validation: Dictionary = _validate_save_state(state)
		if not bool(validation.get("ok", false)):
			failure_reasons.append(
				"%s: %s" % [candidate_path, validation.get("error", "unknown validation error")]
			)
			_preserve_invalid_save(candidate_path)
			continue

		_apply_save_state(validation.get("state", {}) as Dictionary)
		game_loaded.emit(candidate_path)
		return true

	if failure_reasons.is_empty():
		return _fail_load("save file not found")

	return _fail_load(
		"no valid save found; " + "; ".join(PackedStringArray(failure_reasons))
	)


func _get_load_candidates() -> Array[String]:
	return [save_path, backup_path, temporary_save_path]


func _read_json_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _read_error("cannot open file")

	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()

	if read_error != OK:
		return _read_error("cannot read file: %s" % error_string(read_error))

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return _read_error(
			"json parse error at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message()
			]
		)

	var parsed_data: Variant = json.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return _read_error("save root must be a dictionary")

	return {
		"ok": true,
		"state": (parsed_data as Dictionary).duplicate(true),
		"error": ""
	}


func _validate_save_state(state: Dictionary) -> Dictionary:
	if not data_manager.is_ready:
		return _validation_error("game data is not ready")

	var normalized_state: Dictionary = state.duplicate(true)
	var integer_minimums: Dictionary = {
		"save_version": 1,
		"day": 1,
		"money": 0,
		"exp": 0,
		"level": 1,
		"warehouse_level": 1,
		"coop_level": 1,
		"cow_barn_level": 1,
		"restaurant_level": 0,
		"kitchen_level": 0,
		"beverage_counter": 0
	}

	for field: String in integer_minimums:
		var integer_result: Dictionary = _read_integer_field(
			state,
			field,
			int(integer_minimums[field])
		)
		if not bool(integer_result.get("ok", false)):
			return _validation_error(String(integer_result.get("error", "invalid integer")))

		normalized_state[field] = int(integer_result.get("value", 0))

	if int(normalized_state["save_version"]) != save_version:
		return _validation_error(
			"unsupported save version %d (expected %d)" % [
				int(normalized_state["save_version"]),
				save_version
			]
		)

	var day_timer_result: Dictionary = _read_number_field(state, "day_timer", 0.0)
	if not bool(day_timer_result.get("ok", false)):
		return _validation_error(String(day_timer_result.get("error", "invalid day_timer")))

	var day_timer: float = float(day_timer_result.get("value", 0.0))
	if game_manager.day_duration <= 0.0:
		return _validation_error("day duration must be greater than zero")
	if day_timer > game_manager.day_duration:
		return _validation_error("day_timer exceeds the configured day duration")
	normalized_state["day_timer"] = day_timer

	var reputation_result: Dictionary = _read_number_field(state, "reputation", 1.0)
	if not bool(reputation_result.get("ok", false)):
		return _validation_error(String(reputation_result.get("error", "invalid reputation")))

	var reputation: float = float(reputation_result.get("value", 1.0))
	if reputation > 5.0:
		return _validation_error("field 'reputation' must not be greater than 5")
	normalized_state["reputation"] = reputation

	var level: int = int(normalized_state["level"])
	if data_manager.get_level_exp(level) <= 0:
		return _validation_error("field 'level' is not defined in progression data")

	var warehouse_level: int = int(normalized_state["warehouse_level"])
	var warehouse_capacity: int = data_manager.get_warehouse_capacity(warehouse_level)
	if warehouse_capacity <= 0:
		return _validation_error("field 'warehouse_level' is not defined in progression data")

	var inventory_value: Variant = state.get("inventory")
	if typeof(inventory_value) != TYPE_DICTIONARY:
		return _validation_error("field 'inventory' must be a dictionary")

	var normalized_inventory: Dictionary = {}
	var inventory_count: int = 0
	var saved_inventory: Dictionary = inventory_value as Dictionary
	for item_id_value: Variant in saved_inventory:
		if typeof(item_id_value) != TYPE_STRING:
			return _validation_error("inventory item ids must be strings")

		var item_id: String = String(item_id_value)
		if data_manager.get_entry("items", item_id) == null:
			return _validation_error("inventory contains unknown item '%s'" % item_id)

		var amount_value: Variant = saved_inventory[item_id_value]
		var amount_result: Dictionary = _read_integer_value(
			amount_value,
			"inventory amount for '%s'" % item_id,
			1
		)
		if not bool(amount_result.get("ok", false)):
			return _validation_error(
				String(amount_result.get("error", "invalid inventory amount"))
			)

		var amount: int = int(amount_result.get("value", 0))
		if amount > warehouse_capacity - inventory_count:
			return _validation_error("inventory exceeds warehouse capacity")

		inventory_count += amount
		normalized_inventory[item_id] = amount

	normalized_state["inventory"] = normalized_inventory

	var dictionary_fields: Array[String] = [
		"crops",
		"crop_growth",
		"animals",
		"animal_age",
		"aquaculture",
		"staff"
	]
	for field: String in dictionary_fields:
		if typeof(state.get(field)) != TYPE_DICTIONARY:
			return _validation_error("field '%s' must be a dictionary" % field)

	var array_fields: Array[String] = [
		"unlocked_recipes",
		"unlocked_items",
		"achievements"
	]
	for field: String in array_fields:
		if typeof(state.get(field)) != TYPE_ARRAY:
			return _validation_error("field '%s' must be an array" % field)

	return {
		"ok": true,
		"state": normalized_state,
		"error": ""
	}


func _read_integer_field(state: Dictionary, field: String, minimum: int) -> Dictionary:
	if not state.has(field):
		return _value_error("missing required field '%s'" % field)

	return _read_integer_value(state[field], "field '%s'" % field, minimum)


func _read_integer_value(value: Variant, label: String, minimum: int) -> Dictionary:
	var integer_value: int = 0
	if typeof(value) == TYPE_INT:
		integer_value = int(value)
	elif typeof(value) == TYPE_FLOAT:
		var number_value: float = float(value)
		if (
			not is_finite(number_value)
			or floor(number_value) != number_value
			or number_value > max_safe_json_integer
		):
			return _value_error("%s must be an integer" % label)
		integer_value = int(number_value)
	else:
		return _value_error("%s must be an integer" % label)

	if integer_value > max_safe_json_integer:
		return _value_error("%s exceeds the safe JSON integer range" % label)
	if integer_value < minimum:
		return _value_error("%s must be at least %d" % [label, minimum])

	return {
		"ok": true,
		"value": integer_value,
		"error": ""
	}


func _read_number_field(state: Dictionary, field: String, minimum: float) -> Dictionary:
	if not state.has(field):
		return _value_error("missing required field '%s'" % field)

	var value: Variant = state[field]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return _value_error("field '%s' must be a number" % field)

	var number_value: float = float(value)
	if not is_finite(number_value):
		return _value_error("field '%s' must be finite" % field)
	if number_value < minimum:
		return _value_error("field '%s' must be at least %s" % [field, minimum])

	return {
		"ok": true,
		"value": number_value,
		"error": ""
	}


func _replace_save_with_temporary() -> bool:
	var absolute_save_path: String = ProjectSettings.globalize_path(save_path)
	var absolute_backup_path: String = ProjectSettings.globalize_path(backup_path)
	var absolute_temporary_path: String = ProjectSettings.globalize_path(temporary_save_path)
	var had_primary_save: bool = FileAccess.file_exists(save_path)

	if had_primary_save:
		var cleanup_error: Error = _remove_file_if_exists(backup_path)
		if cleanup_error != OK:
			return _fail_save(
				"cannot replace previous backup: %s" % error_string(cleanup_error)
			)

		var backup_error: Error = DirAccess.rename_absolute(
			absolute_save_path,
			absolute_backup_path
		)
		if backup_error != OK:
			return _fail_save(
				"cannot back up current save: %s" % error_string(backup_error)
			)

	var replace_error: Error = DirAccess.rename_absolute(
		absolute_temporary_path,
		absolute_save_path
	)
	if replace_error == OK:
		return true

	if had_primary_save and FileAccess.file_exists(backup_path):
		var restore_error: Error = DirAccess.rename_absolute(
			absolute_backup_path,
			absolute_save_path
		)
		if restore_error != OK:
			push_error(
				"save_manager: failed to restore previous save: %s" % error_string(restore_error)
			)

	return _fail_save("cannot activate temporary save: %s" % error_string(replace_error))


func _preserve_invalid_save(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var timestamp: int = int(Time.get_unix_time_from_system())
	var path_without_extension: String = path.trim_suffix(".json")
	var preserved_path: String = "%s.corrupt.%d.json" % [path_without_extension, timestamp]
	var suffix: int = 1
	while FileAccess.file_exists(preserved_path):
		preserved_path = "%s.corrupt.%d.%d.json" % [
			path_without_extension,
			timestamp,
			suffix
		]
		suffix += 1

	var preserve_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(preserved_path)
	)
	if preserve_error != OK:
		push_warning(
			"save_manager: cannot preserve invalid save '%s': %s" % [
				path,
				error_string(preserve_error)
			]
		)
		return ""

	corrupt_save_preserved.emit(path, preserved_path)
	push_warning("save_manager: invalid save moved to %s" % preserved_path)
	return preserved_path


func _remove_file_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _fail_save(reason: String) -> bool:
	save_failed.emit(reason)
	push_error("save_manager: %s" % reason)
	return false


func _fail_load(reason: String) -> bool:
	load_failed.emit(reason)
	push_error("save_manager: %s" % reason)
	return false


func _read_error(reason: String) -> Dictionary:
	return {
		"ok": false,
		"state": {},
		"error": reason
	}


func _validation_error(reason: String) -> Dictionary:
	return {
		"ok": false,
		"state": {},
		"error": reason
	}


func _value_error(reason: String) -> Dictionary:
	return {
		"ok": false,
		"value": null,
		"error": reason
	}
