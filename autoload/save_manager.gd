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
const animal_script: Script = preload("res://scripts/animals/animal.gd")
const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")
const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")


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

	var farming_error: String = _validate_farming_state(state, normalized_state)
	if not farming_error.is_empty():
		return _validation_error(farming_error)

	var animals_initialized_value: Variant = state.get("animals_initialized", false)
	if typeof(animals_initialized_value) != TYPE_BOOL:
		return _validation_error("field 'animals_initialized' must be a boolean")
	normalized_state["animals_initialized"] = bool(animals_initialized_value)

	var animal_error: String = _validate_animal_state(state, normalized_state)
	if not animal_error.is_empty():
		return _validation_error(animal_error)

	var aquaculture_error: String = _validate_aquaculture_state(state, normalized_state)
	if not aquaculture_error.is_empty():
		return _validation_error(aquaculture_error)

	var restaurant_error: String = _validate_restaurant_state(state, normalized_state)
	if not restaurant_error.is_empty():
		return _validation_error(restaurant_error)

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


func _validate_farming_state(state: Dictionary, normalized_state: Dictionary) -> String:
	var crops_value: Variant = state.get("crops")
	var growth_value: Variant = state.get("crop_growth")
	if typeof(crops_value) != TYPE_DICTIONARY:
		return "field 'crops' must be a dictionary"
	if typeof(growth_value) != TYPE_DICTIONARY:
		return "field 'crop_growth' must be a dictionary"

	var crops: Dictionary = crops_value as Dictionary
	var crop_growth: Dictionary = growth_value as Dictionary
	var normalized_crops: Dictionary = {}
	var normalized_growth: Dictionary = {}
	var current_scene: Node = get_tree().current_scene

	for tile_id_value: Variant in crops:
		if typeof(tile_id_value) != TYPE_STRING or String(tile_id_value).is_empty():
			return "farming tile ids must be non-empty strings"

		var tile_id: String = String(tile_id_value)
		if (
			current_scene != null
			and current_scene.has_method("has_farm_tile")
			and not bool(current_scene.call("has_farm_tile", tile_id))
		):
			return "farming state contains unknown tile '%s'" % tile_id

		var crop_id_value: Variant = crops[tile_id_value]
		if typeof(crop_id_value) != TYPE_STRING:
			return "crop id for tile '%s' must be a string" % tile_id

		var crop_id: String = String(crop_id_value)
		var crop_data_value: Variant = data_manager.get_entry("crops", crop_id)
		if typeof(crop_data_value) != TYPE_DICTIONARY:
			return "tile '%s' contains unknown crop '%s'" % [tile_id, crop_id]

		var crop_data: Dictionary = crop_data_value as Dictionary
		var seed_item_id: String = String(crop_data.get("seed_item", ""))
		var harvest_item_id: String = String(crop_data.get("harvest_item", ""))
		if data_manager.get_entry("items", seed_item_id) == null:
			return "crop '%s' references unknown seed item '%s'" % [crop_id, seed_item_id]
		if data_manager.get_entry("items", harvest_item_id) == null:
			return "crop '%s' references unknown harvest item '%s'" % [crop_id, harvest_item_id]

		var growth_time: float = data_manager.get_crop_growth_time_seconds(crop_id)
		if growth_time <= 0.0:
			return "crop '%s' has invalid growth_time" % crop_id

		var yield_result: Dictionary = _read_integer_value(
			crop_data.get("yield"),
			"yield for crop '%s'" % crop_id,
			1
		)
		if not bool(yield_result.get("ok", false)):
			return String(yield_result.get("error", "invalid crop yield"))

		if not crop_growth.has(tile_id):
			return "missing crop_growth for tile '%s'" % tile_id

		var elapsed_value: Variant = crop_growth[tile_id]
		if typeof(elapsed_value) != TYPE_INT and typeof(elapsed_value) != TYPE_FLOAT:
			return "crop_growth for tile '%s' must be a number" % tile_id

		var elapsed: float = float(elapsed_value)
		if not is_finite(elapsed) or elapsed < 0.0 or elapsed > growth_time:
			return "crop_growth for tile '%s' is outside the valid range" % tile_id

		normalized_crops[tile_id] = crop_id
		normalized_growth[tile_id] = elapsed

	for tile_id_value: Variant in crop_growth:
		if typeof(tile_id_value) != TYPE_STRING or not crops.has(String(tile_id_value)):
			return "crop_growth contains an orphan tile entry"

	normalized_state["crops"] = normalized_crops
	normalized_state["crop_growth"] = normalized_growth
	return ""


func _validate_animal_state(state: Dictionary, normalized_state: Dictionary) -> String:
	var animals_value: Variant = state.get("animals")
	var age_value: Variant = state.get("animal_age")
	if typeof(animals_value) != TYPE_DICTIONARY:
		return "field 'animals' must be a dictionary"
	if typeof(age_value) != TYPE_DICTIONARY:
		return "field 'animal_age' must be a dictionary"

	var animals: Dictionary = animals_value as Dictionary
	var animal_age: Dictionary = age_value as Dictionary
	var normalized_animals: Dictionary = {}
	var normalized_age: Dictionary = {}
	var saved_day: int = int(normalized_state.get("day", 1))

	for instance_id_value: Variant in animals:
		if typeof(instance_id_value) != TYPE_STRING:
			return "animal instance ids must be strings"

		var instance_id: String = String(instance_id_value)
		if (
			instance_id.is_empty()
			or instance_id != instance_id.to_lower()
			or not instance_id.is_valid_identifier()
		):
			return "animal instance id '%s' is invalid" % instance_id
		if not animal_age.has(instance_id):
			return "missing animal_age for '%s'" % instance_id

		var saved_animal_value: Variant = animals[instance_id_value]
		if typeof(saved_animal_value) != TYPE_DICTIONARY:
			return "animal state for '%s' must be a dictionary" % instance_id

		var saved_animal: Dictionary = saved_animal_value as Dictionary
		var animal_id_value: Variant = saved_animal.get("animal_id")
		if typeof(animal_id_value) != TYPE_STRING or String(animal_id_value).is_empty():
			return "animal_id for '%s' must be a non-empty string" % instance_id

		var animal_id: String = String(animal_id_value)
		var animal_data_value: Variant = data_manager.get_entry("animals", animal_id)
		if typeof(animal_data_value) != TYPE_DICTIONARY:
			return "animal '%s' references unknown animal_id '%s'" % [instance_id, animal_id]

		var animal_data: Dictionary = animal_data_value as Dictionary
		var definition_error: String = _validate_animal_definition(animal_id, animal_data)
		if not definition_error.is_empty():
			return definition_error

		var age_result: Dictionary = _read_integer_value(
			animal_age[instance_id],
			"age for animal '%s'" % instance_id,
			0
		)
		if not bool(age_result.get("ok", false)):
			return String(age_result.get("error", "invalid animal age"))
		var age_days: int = int(age_result.get("value", 0))

		var lifespan_days: int = 0
		var lifespan_value: Variant = animal_data.get("lifespan_days")
		if lifespan_value != null:
			lifespan_days = int(lifespan_value)
			if age_days > lifespan_days:
				return "age for animal '%s' exceeds its lifespan" % instance_id

		var position_value: Variant = saved_animal.get("position")
		if typeof(position_value) != TYPE_DICTIONARY:
			return "position for animal '%s' must be a dictionary" % instance_id
		var saved_position: Dictionary = position_value as Dictionary
		var position_result: Dictionary = _validate_animal_position(saved_position, instance_id)
		if not bool(position_result.get("ok", false)):
			return String(position_result.get("error", "invalid animal position"))

		var state_value: Variant = saved_animal.get("state")
		if typeof(state_value) != TYPE_STRING:
			return "state for animal '%s' must be a string" % instance_id
		var animal_state: String = String(state_value)
		if not animal_script.is_valid_state(animal_state):
			return "state for animal '%s' is invalid" % instance_id

		var timer_value: Variant = saved_animal.get("production_timer")
		if typeof(timer_value) != TYPE_INT and typeof(timer_value) != TYPE_FLOAT:
			return "production_timer for animal '%s' must be a number" % instance_id
		var production_timer: float = float(timer_value)
		if not is_finite(production_timer) or production_timer < 0.0:
			return "production_timer for animal '%s' is invalid" % instance_id

		var collected_value: Variant = saved_animal.get("product_collected")
		var end_created_value: Variant = saved_animal.get("end_product_created")
		if typeof(collected_value) != TYPE_BOOL:
			return "product_collected for animal '%s' must be a boolean" % instance_id
		if typeof(end_created_value) != TYPE_BOOL:
			return "end_product_created for animal '%s' must be a boolean" % instance_id

		var processed_result: Dictionary = _read_integer_value(
			saved_animal.get("last_processed_day"),
			"last_processed_day for animal '%s'" % instance_id,
			0
		)
		if not bool(processed_result.get("ok", false)):
			return String(processed_result.get("error", "invalid last_processed_day"))
		var last_processed_day: int = int(processed_result.get("value", 0))
		if last_processed_day > saved_day:
			return "last_processed_day for animal '%s' exceeds the saved day" % instance_id
		if age_days > last_processed_day:
			return "age for animal '%s' exceeds its processed-day count" % instance_id

		var daily_product_value: Variant = animal_data.get("daily_product")
		if typeof(daily_product_value) == TYPE_DICTIONARY:
			var interval_value: Variant = animal_data.get("production_interval_days")
			var production_interval: float = float(interval_value)
			if production_timer >= production_interval:
				return "production_timer for animal '%s' reached an unprocessed cycle" % instance_id
		elif not is_zero_approx(production_timer):
			return "animal '%s' has a production timer without a daily product" % instance_id

		var pending_value: Variant = saved_animal.get("pending_products")
		if typeof(pending_value) != TYPE_ARRAY:
			return "pending_products for animal '%s' must be an array" % instance_id
		var pending_products: Array = pending_value as Array
		if pending_products.size() > 2:
			return "animal '%s' has too many pending products" % instance_id

		var normalized_pending: Array = []
		var product_kinds_seen: Dictionary = {}
		for product_value: Variant in pending_products:
			var product_result: Dictionary = _validate_pending_animal_product(
				product_value,
				animal_data,
				instance_id,
				last_processed_day
			)
			if not bool(product_result.get("ok", false)):
				return String(product_result.get("error", "invalid pending animal product"))

			var normalized_product: Dictionary = product_result.get("value", {}) as Dictionary
			var product_kind: String = String(normalized_product.get("kind", ""))
			if product_kinds_seen.has(product_kind):
				return "animal '%s' has duplicate pending '%s' products" % [
					instance_id,
					product_kind
				]
			product_kinds_seen[product_kind] = true
			normalized_pending.append(normalized_product)

		var product_collected: bool = bool(collected_value)
		if product_collected != normalized_pending.is_empty():
			return "product_collected for animal '%s' does not match pending products" % instance_id

		var lifecycle_complete: bool = lifespan_days > 0 and age_days >= lifespan_days
		var end_product_created: bool = bool(end_created_value)
		if lifecycle_complete != end_product_created:
			return "end-of-life status for animal '%s' is inconsistent" % instance_id
		if product_kinds_seen.has(animal_script.product_kind_end_of_life) and not lifecycle_complete:
			return "animal '%s' has an end-of-life product before its lifecycle completed" % instance_id
		if (
			lifecycle_complete
			and product_kinds_seen.has(animal_script.product_kind_daily)
			and not product_kinds_seen.has(animal_script.product_kind_end_of_life)
		):
			return "animal '%s' lost its pending end-of-life product" % instance_id

		var expected_state: String = animal_script.state_active
		if lifecycle_complete:
			expected_state = (
				animal_script.state_completed
				if normalized_pending.is_empty()
				else animal_script.state_end_of_life
			)
		elif not normalized_pending.is_empty():
			expected_state = animal_script.state_product_ready
		if animal_state != expected_state:
			return "state for animal '%s' is inconsistent with its lifecycle" % instance_id

		normalized_animals[instance_id] = {
			"animal_id": animal_id,
			"position": position_result.get("value", {}),
			"state": animal_state,
			"production_timer": production_timer,
			"product_collected": product_collected,
			"last_processed_day": last_processed_day,
			"pending_products": normalized_pending,
			"end_product_created": end_product_created
		}
		normalized_age[instance_id] = age_days

	for instance_id_value: Variant in animal_age:
		if typeof(instance_id_value) != TYPE_STRING or not animals.has(String(instance_id_value)):
			return "animal_age contains an orphan entry"

	normalized_state["animals"] = normalized_animals
	normalized_state["animal_age"] = normalized_age
	return ""


func _validate_animal_definition(animal_id: String, animal_data: Dictionary) -> String:
	if String(animal_data.get("animal_id", "")) != animal_id:
		return "animal data for '%s' has a mismatched animal_id" % animal_id

	var level_result: Dictionary = _read_integer_value(
		animal_data.get("required_level"),
		"required_level for animal '%s'" % animal_id,
		1
	)
	if not bool(level_result.get("ok", false)):
		return String(level_result.get("error", "invalid animal required_level"))

	var price_result: Dictionary = _read_integer_value(
		animal_data.get("purchase_price"),
		"purchase_price for animal '%s'" % animal_id,
		0
	)
	if not bool(price_result.get("ok", false)):
		return String(price_result.get("error", "invalid animal purchase_price"))

	var lifespan_value: Variant = animal_data.get("lifespan_days")
	if lifespan_value != null:
		var lifespan_result: Dictionary = _read_integer_value(
			lifespan_value,
			"lifespan_days for animal '%s'" % animal_id,
			1
		)
		if not bool(lifespan_result.get("ok", false)):
			return String(lifespan_result.get("error", "invalid animal lifespan"))

	var daily_product_value: Variant = animal_data.get("daily_product")
	var end_product_value: Variant = animal_data.get("end_of_life_product")
	if daily_product_value != null:
		var daily_error: String = _validate_animal_product_definition(
			daily_product_value,
			"daily_product for animal '%s'" % animal_id
		)
		if not daily_error.is_empty():
			return daily_error

		var interval_value: Variant = animal_data.get("production_interval_days")
		if typeof(interval_value) != TYPE_INT and typeof(interval_value) != TYPE_FLOAT:
			return "production_interval_days for animal '%s' must be a number" % animal_id
		var production_interval: float = float(interval_value)
		if not is_finite(production_interval) or production_interval <= 0.0:
			return "production_interval_days for animal '%s' must be greater than zero" % animal_id

	if end_product_value != null:
		var end_error: String = _validate_animal_product_definition(
			end_product_value,
			"end_of_life_product for animal '%s'" % animal_id
		)
		if not end_error.is_empty():
			return end_error
	if lifespan_value != null and end_product_value == null:
		return "finite-lifespan animal '%s' has no end_of_life_product" % animal_id
	if daily_product_value == null and end_product_value == null:
		return "animal '%s' has no configured product" % animal_id

	return ""


func _validate_animal_product_definition(product_value: Variant, label: String) -> String:
	if typeof(product_value) != TYPE_DICTIONARY:
		return "%s must be a dictionary" % label

	var product: Dictionary = product_value as Dictionary
	var item_id_value: Variant = product.get("item_id")
	if typeof(item_id_value) != TYPE_STRING or String(item_id_value).is_empty():
		return "%s has an invalid item_id" % label
	if data_manager.get_entry("items", String(item_id_value)) == null:
		return "%s references an unknown item" % label

	var amount_result: Dictionary = _read_integer_value(
		product.get("amount"),
		"amount in %s" % label,
		1
	)
	if not bool(amount_result.get("ok", false)):
		return String(amount_result.get("error", "invalid animal product amount"))

	var exp_result: Dictionary = _read_integer_value(
		product.get("collect_exp"),
		"collect_exp in %s" % label,
		0
	)
	if not bool(exp_result.get("ok", false)):
		return String(exp_result.get("error", "invalid animal product EXP"))

	return ""


func _validate_animal_position(position: Dictionary, instance_id: String) -> Dictionary:
	var normalized_position: Dictionary = {}
	for axis: String in ["x", "y"]:
		var axis_value: Variant = position.get(axis)
		if typeof(axis_value) != TYPE_INT and typeof(axis_value) != TYPE_FLOAT:
			return _value_error("position.%s for animal '%s' must be a number" % [axis, instance_id])
		var axis_number: float = float(axis_value)
		if not is_finite(axis_number):
			return _value_error("position.%s for animal '%s' must be finite" % [axis, instance_id])
		normalized_position[axis] = axis_number

	return {
		"ok": true,
		"value": normalized_position,
		"error": ""
	}


func _validate_pending_animal_product(
	product_value: Variant,
	animal_data: Dictionary,
	instance_id: String,
	last_processed_day: int
) -> Dictionary:
	if typeof(product_value) != TYPE_DICTIONARY:
		return _value_error("pending product for animal '%s' must be a dictionary" % instance_id)

	var product: Dictionary = product_value as Dictionary
	var kind_value: Variant = product.get("kind")
	if typeof(kind_value) != TYPE_STRING:
		return _value_error("pending product kind for animal '%s' must be a string" % instance_id)
	var kind: String = String(kind_value)
	if not animal_script.is_valid_product_kind(kind):
		return _value_error("pending product kind for animal '%s' is invalid" % instance_id)

	var definition_field: String = (
		"daily_product"
		if kind == animal_script.product_kind_daily
		else "end_of_life_product"
	)
	var definition_value: Variant = animal_data.get(definition_field)
	if typeof(definition_value) != TYPE_DICTIONARY:
		return _value_error("animal '%s' has no configured '%s' product" % [instance_id, kind])
	var definition: Dictionary = definition_value as Dictionary

	var item_id_value: Variant = product.get("item_id")
	if typeof(item_id_value) != TYPE_STRING or String(item_id_value) != String(definition.get("item_id", "")):
		return _value_error("pending product item for animal '%s' does not match data" % instance_id)

	var amount_result: Dictionary = _read_integer_value(
		product.get("amount"),
		"pending product amount for animal '%s'" % instance_id,
		1
	)
	if not bool(amount_result.get("ok", false)):
		return amount_result

	var exp_result: Dictionary = _read_integer_value(
		product.get("collect_exp"),
		"pending product EXP for animal '%s'" % instance_id,
		0
	)
	if not bool(exp_result.get("ok", false)):
		return exp_result

	var produced_result: Dictionary = _read_integer_value(
		product.get("produced_day"),
		"produced_day for animal '%s'" % instance_id,
		1
	)
	if not bool(produced_result.get("ok", false)):
		return produced_result
	var produced_day: int = int(produced_result.get("value", 0))
	if produced_day > last_processed_day:
		return _value_error("pending product for animal '%s' was produced after its processed day" % instance_id)

	return {
		"ok": true,
		"value": {
			"item_id": String(item_id_value),
			"amount": int(amount_result.get("value", 0)),
			"collect_exp": int(exp_result.get("value", 0)),
			"kind": kind,
			"produced_day": produced_day
		},
		"error": ""
	}


func _validate_aquaculture_state(state: Dictionary, normalized_state: Dictionary) -> String:
	var aquaculture_value: Variant = state.get("aquaculture")
	if typeof(aquaculture_value) != TYPE_DICTIONARY:
		return "field 'aquaculture' must be a dictionary"

	var aquaculture: Dictionary = aquaculture_value as Dictionary
	var normalized_aquaculture: Dictionary = {}
	var current_scene: Node = get_tree().current_scene

	for container_id_value: Variant in aquaculture:
		if typeof(container_id_value) != TYPE_STRING:
			return "aquaculture container ids must be strings"
		var container_id: String = String(container_id_value)
		if container_id.is_empty() or container_id != container_id.to_lower() or not container_id.is_valid_identifier():
			return "aquaculture container id '%s' is invalid" % container_id
		if current_scene != null and current_scene.has_method("has_aquaculture_container") and not bool(current_scene.call("has_aquaculture_container", container_id)):
			return "aquaculture state contains unknown container '%s'" % container_id

		var saved_container_value: Variant = aquaculture[container_id_value]
		if typeof(saved_container_value) != TYPE_DICTIONARY:
			return "aquaculture state for '%s' must be a dictionary" % container_id
		var saved_container: Dictionary = saved_container_value as Dictionary

		var aquaculture_id_value: Variant = saved_container.get("aquaculture_id")
		if typeof(aquaculture_id_value) != TYPE_STRING or String(aquaculture_id_value).is_empty():
			return "aquaculture_id for '%s' must be a non-empty string" % container_id
		var aquaculture_id: String = String(aquaculture_id_value)
		if current_scene != null and current_scene.has_method("is_valid_aquaculture_assignment") and not bool(current_scene.call("is_valid_aquaculture_assignment", container_id, aquaculture_id)):
			return "aquaculture_id '%s' does not belong to container '%s'" % [aquaculture_id, container_id]
		var aquaculture_data_value: Variant = data_manager.get_entry("aquaculture", aquaculture_id)
		if typeof(aquaculture_data_value) != TYPE_DICTIONARY:
			return "container '%s' references unknown aquaculture_id '%s'" % [container_id, aquaculture_id]
		var aquaculture_data: Dictionary = aquaculture_data_value as Dictionary
		var definition_error: String = _validate_aquaculture_definition(aquaculture_id, aquaculture_data)
		if not definition_error.is_empty():
			return definition_error

		var position_value: Variant = saved_container.get("position")
		if typeof(position_value) != TYPE_DICTIONARY:
			return "position for aquaculture container '%s' must be a dictionary" % container_id
		var position_result: Dictionary = _validate_aquaculture_position(position_value as Dictionary, container_id)
		if not bool(position_result.get("ok", false)):
			return String(position_result.get("error", "invalid aquaculture position"))

		var state_value: Variant = saved_container.get("state")
		if typeof(state_value) != TYPE_STRING:
			return "state for aquaculture container '%s' must be a string" % container_id
		var container_state: String = String(state_value)
		if not aquaculture_container_script.is_valid_state(container_state):
			return "state for aquaculture container '%s' is invalid" % container_id

		var timer_value: Variant = saved_container.get("growth_timer")
		if typeof(timer_value) != TYPE_INT and typeof(timer_value) != TYPE_FLOAT:
			return "growth_timer for aquaculture container '%s' must be a number" % container_id
		var growth_timer: float = float(timer_value)
		var growth_time: float = data_manager.get_aquaculture_growth_time_seconds(aquaculture_id)
		if not is_finite(growth_timer) or growth_timer < 0.0 or growth_timer > growth_time:
			return "growth_timer for aquaculture container '%s' is outside the valid range" % container_id

		var collected_value: Variant = saved_container.get("product_collected")
		if typeof(collected_value) != TYPE_BOOL:
			return "product_collected for aquaculture container '%s' must be a boolean" % container_id
		var product_collected: bool = bool(collected_value)
		var pending_value: Variant = saved_container.get("pending_product")
		if typeof(pending_value) != TYPE_DICTIONARY:
			return "pending_product for aquaculture container '%s' must be a dictionary" % container_id
		var pending_product: Dictionary = pending_value as Dictionary
		var normalized_pending: Dictionary = {}

		match container_state:
			aquaculture_container_script.state_empty:
				if not is_zero_approx(growth_timer) or not pending_product.is_empty() or not product_collected:
					return "empty aquaculture container '%s' has inconsistent cycle data" % container_id
			aquaculture_container_script.state_growing:
				if growth_timer >= growth_time or not pending_product.is_empty() or product_collected:
					return "growing aquaculture container '%s' has inconsistent cycle data" % container_id
			aquaculture_container_script.state_ready:
				if not is_equal_approx(growth_timer, growth_time) or pending_product.is_empty() or product_collected:
					return "ready aquaculture container '%s' has inconsistent cycle data" % container_id
				var product_result: Dictionary = _validate_pending_aquaculture_product(pending_product, aquaculture_data, container_id)
				if not bool(product_result.get("ok", false)):
					return String(product_result.get("error", "invalid pending aquaculture product"))
				normalized_pending = product_result.get("value", {}) as Dictionary

		normalized_aquaculture[container_id] = {
			"aquaculture_id": aquaculture_id,
			"position": position_result.get("value", {}),
			"state": container_state,
			"growth_timer": growth_timer,
			"pending_product": normalized_pending,
			"product_collected": product_collected,
		}

	normalized_state["aquaculture"] = normalized_aquaculture
	return ""


func _validate_aquaculture_definition(aquaculture_id: String, aquaculture_data: Dictionary) -> String:
	var required_level_result: Dictionary = _read_integer_value(aquaculture_data.get("required_level"), "required_level for aquaculture '%s'" % aquaculture_id, 1)
	if not bool(required_level_result.get("ok", false)):
		return String(required_level_result.get("error", "invalid aquaculture required_level"))
	if data_manager.get_aquaculture_growth_time_seconds(aquaculture_id) <= 0.0:
		return "growth_time for aquaculture '%s' must be greater than zero" % aquaculture_id
	var yield_result: Dictionary = _read_integer_value(aquaculture_data.get("yield"), "yield for aquaculture '%s'" % aquaculture_id, 1)
	if not bool(yield_result.get("ok", false)):
		return String(yield_result.get("error", "invalid aquaculture yield"))
	var exp_result: Dictionary = _read_integer_value(aquaculture_data.get("exp"), "EXP for aquaculture '%s'" % aquaculture_id, 0)
	if not bool(exp_result.get("ok", false)):
		return String(exp_result.get("error", "invalid aquaculture EXP"))

	var item_id_value: Variant = aquaculture_data.get("item_id")
	if typeof(item_id_value) != TYPE_STRING or String(item_id_value).is_empty():
		return "item_id for aquaculture '%s' must be a non-empty string" % aquaculture_id
	var item_value: Variant = data_manager.get_entry("items", String(item_id_value))
	if typeof(item_value) != TYPE_DICTIONARY:
		return "aquaculture '%s' references unknown item '%s'" % [aquaculture_id, item_id_value]
	if String((item_value as Dictionary).get("category", "")) != "seafood":
		return "aquaculture '%s' product must be a seafood item" % aquaculture_id
	return ""


func _validate_aquaculture_position(position: Dictionary, container_id: String) -> Dictionary:
	var normalized_position: Dictionary = {}
	for axis: String in ["x", "y"]:
		var axis_value: Variant = position.get(axis)
		if typeof(axis_value) != TYPE_INT and typeof(axis_value) != TYPE_FLOAT:
			return _value_error("position.%s for aquaculture container '%s' must be a number" % [axis, container_id])
		var axis_number: float = float(axis_value)
		if not is_finite(axis_number):
			return _value_error("position.%s for aquaculture container '%s' must be finite" % [axis, container_id])
		normalized_position[axis] = axis_number
	return {"ok": true, "value": normalized_position, "error": ""}


func _validate_pending_aquaculture_product(product: Dictionary, aquaculture_data: Dictionary, container_id: String) -> Dictionary:
	var item_id_value: Variant = product.get("item_id")
	if typeof(item_id_value) != TYPE_STRING or String(item_id_value) != String(aquaculture_data.get("item_id", "")):
		return _value_error("pending product item for aquaculture container '%s' does not match data" % container_id)
	var amount_result: Dictionary = _read_integer_value(product.get("amount"), "pending product amount for aquaculture container '%s'" % container_id, 1)
	if not bool(amount_result.get("ok", false)):
		return amount_result
	var exp_result: Dictionary = _read_integer_value(product.get("exp"), "pending product EXP for aquaculture container '%s'" % container_id, 0)
	if not bool(exp_result.get("ok", false)):
		return exp_result
	return {
		"ok": true,
		"value": {
			"item_id": String(item_id_value),
			"amount": int(amount_result.get("value", 0)),
			"exp": int(exp_result.get("value", 0)),
		},
		"error": "",
	}


func _validate_restaurant_state(state: Dictionary, normalized_state: Dictionary) -> String:
	var restaurant_level: int = int(normalized_state.get("restaurant_level", 0))
	var kitchen_level: int = int(normalized_state.get("kitchen_level", 0))
	var player_level: int = int(normalized_state.get("level", 1))
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	if unlock_level <= 0:
		return "restaurant unlock level is not defined in progression data"
	if restaurant_level > 0 and data_manager.get_restaurant_table_capacity(restaurant_level) <= 0:
		return "field 'restaurant_level' is not defined in progression data"
	if restaurant_level > 0 and player_level < unlock_level:
		return "restaurant cannot be active below its unlock level"
	if kitchen_level > 0 and data_manager.get_kitchen_cooking_slots(kitchen_level) <= 0:
		return "field 'kitchen_level' is not defined in progression data"
	if kitchen_level > 0 and restaurant_level == 0:
		# Phase 7 saves did not own kitchen state. Normalize their inactive restaurant
		# fixture back to an inactive kitchen instead of rejecting save version 1.
		kitchen_level = 0
		normalized_state["kitchen_level"] = 0

	var tables_value: Variant = state.get("restaurant_tables", {})
	if typeof(tables_value) != TYPE_DICTIONARY:
		return "field 'restaurant_tables' must be a dictionary"
	var saved_tables: Dictionary = tables_value as Dictionary
	var normalized_tables: Dictionary = {}
	var current_scene: Node = get_tree().current_scene
	var maximum_tables: int = data_manager.get_restaurant_table_capacity(maxi(restaurant_level, 1))
	if saved_tables.size() > maximum_tables:
		return "restaurant table state exceeds configured capacity"

	for table_id_value: Variant in saved_tables:
		if typeof(table_id_value) != TYPE_STRING:
			return "restaurant table ids must be strings"
		var table_id: String = String(table_id_value)
		if table_id.is_empty() or table_id != table_id.to_lower() or not table_id.is_valid_identifier():
			return "restaurant table id '%s' is invalid" % table_id
		if current_scene != null and current_scene.has_method("has_restaurant_table") and not bool(current_scene.call("has_restaurant_table", table_id)):
			return "restaurant state contains unknown table '%s'" % table_id

		var table_state_value: Variant = saved_tables[table_id_value]
		if typeof(table_state_value) != TYPE_DICTIONARY:
			return "restaurant table state for '%s' must be a dictionary" % table_id
		var table_state: Dictionary = table_state_value as Dictionary
		var state_value: Variant = table_state.get("state")
		var occupant_value: Variant = table_state.get("occupant_id")
		if typeof(state_value) != TYPE_STRING or typeof(occupant_value) != TYPE_STRING:
			return "restaurant table '%s' has invalid state data" % table_id
		var saved_state: String = String(state_value)
		var occupant_id: String = String(occupant_value)
		if not restaurant_table_script.is_valid_state_data(saved_state, occupant_id):
			return "restaurant table '%s' has inconsistent state data" % table_id
		if restaurant_level == 0 and saved_state != restaurant_table_script.state_available:
			return "locked restaurant contains an active table '%s'" % table_id
		normalized_tables[table_id] = {
			"state": saved_state,
			"occupant_id": occupant_id,
		}

	normalized_state["restaurant_tables"] = normalized_tables

	var sequence_result: Dictionary = _read_integer_value(
		state.get("restaurant_customer_sequence", 0),
		"field 'restaurant_customer_sequence'",
		0
	)
	if not bool(sequence_result.get("ok", false)):
		return String(sequence_result.get("error", "invalid restaurant customer sequence"))
	normalized_state["restaurant_customer_sequence"] = int(sequence_result.get("value", 0))

	var settings: Dictionary = data_manager.get_customer_settings()
	if settings.is_empty():
		return "customer settings are invalid"
	var spawn_elapsed_value: Variant = state.get("restaurant_spawn_elapsed", 0.0)
	if typeof(spawn_elapsed_value) != TYPE_INT and typeof(spawn_elapsed_value) != TYPE_FLOAT:
		return "field 'restaurant_spawn_elapsed' must be a number"
	var spawn_elapsed: float = float(spawn_elapsed_value)
	var spawn_interval: float = float(settings.get("spawn_interval_seconds", 0.0))
	if not is_finite(spawn_elapsed) or spawn_elapsed < 0.0 or spawn_elapsed > spawn_interval:
		return "field 'restaurant_spawn_elapsed' is outside the configured interval"
	normalized_state["restaurant_spawn_elapsed"] = spawn_elapsed

	var customers_value: Variant = state.get("restaurant_customers", {})
	if typeof(customers_value) != TYPE_DICTIONARY:
		return "field 'restaurant_customers' must be a dictionary"
	var saved_customers: Dictionary = customers_value as Dictionary
	if restaurant_level == 0 and not saved_customers.is_empty():
		return "locked restaurant contains customers"
	if saved_customers.size() > maximum_tables:
		return "restaurant customer state exceeds configured table capacity"

	var normalized_customers: Dictionary = {}
	var claimed_tables: Dictionary = {}
	for customer_id_value: Variant in saved_customers:
		if typeof(customer_id_value) != TYPE_STRING:
			return "restaurant customer ids must be strings"
		var customer_id: String = String(customer_id_value)
		if not customer_script.is_valid_customer_id(customer_id):
			return "restaurant customer id '%s' is invalid" % customer_id
		var customer_state_value: Variant = saved_customers[customer_id_value]
		if typeof(customer_state_value) != TYPE_DICTIONARY:
			return "restaurant customer state for '%s' must be a dictionary" % customer_id
		var customer_result: Dictionary = _validate_restaurant_customer(
			customer_id,
			customer_state_value as Dictionary,
			player_level,
			normalized_tables,
			claimed_tables
		)
		if not bool(customer_result.get("ok", false)):
			return String(customer_result.get("error", "invalid restaurant customer"))
		normalized_customers[customer_id] = customer_result.get("value", {})
	normalized_state["restaurant_customers"] = normalized_customers

	var cooking_value: Variant = state.get("restaurant_cooking", {})
	if typeof(cooking_value) != TYPE_DICTIONARY:
		return "field 'restaurant_cooking' must be a dictionary"
	var saved_cooking: Dictionary = cooking_value as Dictionary
	if kitchen_level == 0 and not saved_cooking.is_empty():
		return "inactive kitchen contains cooking jobs"
	var cooking_slots: int = data_manager.get_kitchen_cooking_slots(kitchen_level)
	var active_cooking_count: int = 0
	var normalized_cooking: Dictionary = {}
	for customer_id_value: Variant in saved_cooking:
		if typeof(customer_id_value) != TYPE_STRING:
			return "cooking job customer ids must be strings"
		var customer_id: String = String(customer_id_value)
		if not normalized_customers.has(customer_id):
			return "cooking job references unknown customer '%s'" % customer_id
		var job_value: Variant = saved_cooking[customer_id_value]
		if typeof(job_value) != TYPE_DICTIONARY:
			return "cooking job for '%s' must be a dictionary" % customer_id
		var job_result: Dictionary = _validate_restaurant_cooking_job(
			customer_id,
			job_value as Dictionary,
			normalized_customers[customer_id] as Dictionary,
			player_level
		)
		if not bool(job_result.get("ok", false)):
			return String(job_result.get("error", "invalid cooking job"))
		var normalized_job: Dictionary = job_result.get("value", {}) as Dictionary
		if String(normalized_job.get("state", "")) == restaurant_script.cooking_state_cooking:
			active_cooking_count += 1
		normalized_cooking[customer_id] = normalized_job
	if active_cooking_count > cooking_slots:
		return "active cooking jobs exceed kitchen capacity"
	normalized_state["restaurant_cooking"] = normalized_cooking
	var staff_error: String = _validate_restaurant_staff(
		state,
		normalized_state,
		normalized_tables,
		normalized_customers,
		normalized_cooking
	)
	if not staff_error.is_empty():
		return staff_error
	return ""


func _validate_restaurant_staff(
	state: Dictionary,
	normalized_state: Dictionary,
	normalized_tables: Dictionary,
	normalized_customers: Dictionary,
	normalized_cooking: Dictionary
) -> String:
	var staff_value: Variant = state.get("staff", {})
	if typeof(staff_value) != TYPE_DICTIONARY:
		return "field 'staff' must be a dictionary"
	var saved_staff: Dictionary = staff_value as Dictionary
	if int(normalized_state.get("restaurant_level", 0)) == 0 and not saved_staff.is_empty():
		return "locked restaurant contains staff"
	var player_level: int = int(normalized_state.get("level", 1))
	var normalized_staff: Dictionary = {}
	var claimed_jobs: Dictionary = {}
	for staff_id_value: Variant in saved_staff:
		if typeof(staff_id_value) != TYPE_STRING:
			return "staff ids must be strings"
		var staff_id: String = String(staff_id_value)
		if not staff_script.is_valid_staff_id(staff_id):
			return "staff id '%s' is invalid" % staff_id
		var saved_staff_value: Variant = saved_staff[staff_id_value]
		if typeof(saved_staff_value) != TYPE_DICTIONARY:
			return "staff state for '%s' must be a dictionary" % staff_id
		var saved_entry: Dictionary = saved_staff_value as Dictionary
		var staff_type_value: Variant = saved_entry.get("staff_type_id")
		var state_value: Variant = saved_entry.get("state")
		if typeof(staff_type_value) != TYPE_STRING or typeof(state_value) != TYPE_STRING:
			return "staff '%s' has invalid identity or state" % staff_id
		var staff_type_id: String = String(staff_type_value)
		var staff_data: Dictionary = data_manager.get_staff_type(staff_type_id)
		if staff_data.is_empty():
			return "staff '%s' has unknown type '%s'" % [staff_id, staff_type_id]
		if player_level < int(staff_data.get("unlock_level", 0)):
			return "staff '%s' is locked at the saved player level" % staff_id
		var staff_state: String = String(state_value)
		if not staff_script.is_valid_state(staff_state):
			return "staff '%s' has invalid state '%s'" % [staff_id, staff_state]
		var position_result: Dictionary = _validate_staff_position(saved_entry.get("position"), staff_id)
		if not bool(position_result.get("ok", false)):
			return String(position_result.get("error", "invalid staff position"))
		var active_job_value: Variant = saved_entry.get("active_job", {})
		if typeof(active_job_value) != TYPE_DICTIONARY:
			return "staff '%s' active_job must be a dictionary" % staff_id
		var active_job: Dictionary = active_job_value as Dictionary
		if staff_state == staff_script.state_idle or staff_state == staff_script.state_returning:
			if not active_job.is_empty():
				return "staff '%s' has a job while idle or returning" % staff_id
		else:
			var job_result: Dictionary = _validate_staff_job(
				staff_id,
				staff_state,
				active_job,
				staff_data,
				normalized_tables,
				normalized_customers,
				normalized_cooking,
				claimed_jobs
			)
			if not bool(job_result.get("ok", false)):
				return String(job_result.get("error", "invalid staff job"))
			active_job = job_result.get("value", {}) as Dictionary
		normalized_staff[staff_id] = {
			"staff_type_id": staff_type_id,
			"position": position_result.get("value", {}),
			"state": staff_state,
			"active_job": active_job.duplicate(true),
		}
	normalized_state["staff"] = normalized_staff
	return ""


func _validate_staff_job(
	staff_id: String,
	staff_state: String,
	active_job: Dictionary,
	staff_data: Dictionary,
	tables: Dictionary,
	customers: Dictionary,
	cooking: Dictionary,
	claimed_jobs: Dictionary
) -> Dictionary:
	var job_type_value: Variant = active_job.get("job_type")
	var target_id_value: Variant = active_job.get("target_id")
	if typeof(job_type_value) != TYPE_STRING or typeof(target_id_value) != TYPE_STRING:
		return _value_error("staff '%s' job identity is invalid" % staff_id)
	var job_type: String = String(job_type_value)
	var target_id: String = String(target_id_value)
	if not staff_script.is_valid_job_type(job_type) or not (staff_data.get("allowed_jobs", []) as Array).has(job_type):
		return _value_error("staff '%s' cannot perform job '%s'" % [staff_id, job_type])
	if target_id.is_empty():
		return _value_error("staff '%s' job target is empty" % staff_id)
	var elapsed_value: Variant = active_job.get("elapsed", 0.0)
	if typeof(elapsed_value) != TYPE_INT and typeof(elapsed_value) != TYPE_FLOAT:
		return _value_error("staff '%s' job timer must be a number" % staff_id)
	var elapsed: float = float(elapsed_value)
	if not is_finite(elapsed) or elapsed < 0.0:
		return _value_error("staff '%s' job timer is invalid" % staff_id)
	if job_type == staff_script.job_clean:
		if elapsed > float(staff_data.get("cleaning_time_seconds", 0.0)):
			return _value_error("staff '%s' cleaning timer exceeds its duration" % staff_id)
		if staff_state != staff_script.state_moving and staff_state != staff_script.state_cleaning_table:
			return _value_error("staff '%s' cleaning job has an inconsistent state" % staff_id)
		var table: Dictionary = tables.get(target_id, {}) as Dictionary
		if String(table.get("state", "")) != restaurant_table_script.state_needs_cleanup:
			return _value_error("staff '%s' cleaning job references a clean table" % staff_id)
	else:
		if elapsed != 0.0:
			return _value_error("staff '%s' non-cleaning job has an invalid timer" % staff_id)
		var customer: Dictionary = customers.get(target_id, {}) as Dictionary
		if customer.is_empty():
			return _value_error("staff '%s' job references unknown customer '%s'" % [staff_id, target_id])
		var customer_state: String = String(customer.get("state", ""))
		var order: Dictionary = customer.get("order", {}) as Dictionary
		var cooking_job: Dictionary = cooking.get(target_id, {}) as Dictionary
		if job_type == staff_script.job_cook:
			if staff_state != staff_script.state_moving and staff_state != staff_script.state_handling_order:
				return _value_error("staff '%s' cook job has an inconsistent state" % staff_id)
			if customer_state != customer_script.state_waiting_food or String(order.get("state", "")) != customer_script.order_state_pending or not cooking_job.is_empty():
				return _value_error("staff '%s' cook job target is not waiting for cooking" % staff_id)
		elif job_type == staff_script.job_serve:
			if staff_state != staff_script.state_moving and staff_state != staff_script.state_delivering_food:
				return _value_error("staff '%s' serve job has an inconsistent state" % staff_id)
			if String(cooking_job.get("state", "")) != restaurant_script.cooking_state_ready:
				return _value_error("staff '%s' serve job target has no ready food" % staff_id)
		elif job_type == staff_script.job_payment:
			if staff_state != staff_script.state_moving and staff_state != staff_script.state_handling_order:
				return _value_error("staff '%s' payment job has an inconsistent state" % staff_id)
			if customer_state != customer_script.state_eating or String(cooking_job.get("state", "")) != restaurant_script.cooking_state_served or bool(cooking_job.get("payment_collected", false)):
				return _value_error("staff '%s' payment job target is not awaiting payment" % staff_id)
	var job_key: String = "%s:%s" % [job_type, target_id]
	if claimed_jobs.has(job_key):
		return _value_error("staff job '%s' is claimed more than once" % job_key)
	claimed_jobs[job_key] = staff_id
	return {"ok": true, "value": {"job_type": job_type, "target_id": target_id, "elapsed": elapsed}, "error": ""}


func _validate_staff_position(position_value: Variant, staff_id: String) -> Dictionary:
	if typeof(position_value) != TYPE_DICTIONARY:
		return _value_error("staff '%s' position must be a dictionary" % staff_id)
	var position: Dictionary = position_value as Dictionary
	if not position.has("x") or not position.has("y"):
		return _value_error("staff '%s' position is incomplete" % staff_id)
	var x_value: Variant = position.get("x")
	var y_value: Variant = position.get("y")
	if (typeof(x_value) != TYPE_INT and typeof(x_value) != TYPE_FLOAT) or (typeof(y_value) != TYPE_INT and typeof(y_value) != TYPE_FLOAT):
		return _value_error("staff '%s' position must contain numbers" % staff_id)
	var x: float = float(x_value)
	var y: float = float(y_value)
	if not is_finite(x) or not is_finite(y):
		return _value_error("staff '%s' position must be finite" % staff_id)
	return {"ok": true, "value": {"x": x, "y": y}, "error": ""}


func _validate_restaurant_cooking_job(
	customer_id: String,
	saved_job: Dictionary,
	saved_customer: Dictionary,
	player_level: int
) -> Dictionary:
	var recipe_value: Variant = saved_job.get("recipe_id")
	var state_value: Variant = saved_job.get("state")
	var payment_value: Variant = saved_job.get("payment_collected")
	if typeof(recipe_value) != TYPE_STRING or typeof(state_value) != TYPE_STRING or typeof(payment_value) != TYPE_BOOL:
		return _value_error("cooking job for '%s' has invalid identifiers" % customer_id)
	var recipe_id: String = String(recipe_value)
	var cooking_state: String = String(state_value)
	if not restaurant_script.is_valid_cooking_state(cooking_state):
		return _value_error("cooking job for '%s' has an invalid state" % customer_id)
	if data_manager.get_restaurant_menu_entry(recipe_id, player_level).is_empty():
		return _value_error("cooking job for '%s' references an unavailable recipe" % customer_id)
	var quantity_result: Dictionary = _read_integer_value(
		saved_job.get("quantity"),
		"cooking quantity for customer '%s'" % customer_id,
		1
	)
	if not bool(quantity_result.get("ok", false)):
		return quantity_result
	var elapsed_value: Variant = saved_job.get("cooking_elapsed")
	var duration_value: Variant = saved_job.get("cooking_duration")
	if (typeof(elapsed_value) != TYPE_INT and typeof(elapsed_value) != TYPE_FLOAT) or (typeof(duration_value) != TYPE_INT and typeof(duration_value) != TYPE_FLOAT):
		return _value_error("cooking timer for customer '%s' must be numeric" % customer_id)
	var elapsed: float = float(elapsed_value)
	var duration: float = float(duration_value)
	if not is_finite(elapsed) or not is_finite(duration) or elapsed < 0.0 or duration <= 0.0 or elapsed > duration:
		return _value_error("cooking timer for customer '%s' is inconsistent" % customer_id)
	if cooking_state == restaurant_script.cooking_state_cooking and elapsed >= duration:
		return _value_error("active cooking job for '%s' has already reached its duration" % customer_id)
	if cooking_state != restaurant_script.cooking_state_cooking and not is_equal_approx(elapsed, duration):
		return _value_error("completed cooking job for '%s' has an incomplete timer" % customer_id)

	var order: Dictionary = saved_customer.get("order", {}) as Dictionary
	if recipe_id != String(order.get("recipe_id", "")) or int(quantity_result.get("value", 0)) != int(order.get("quantity", 0)):
		return _value_error("cooking job for '%s' does not match its order" % customer_id)
	var customer_state: String = String(saved_customer.get("state", ""))
	var order_state: String = String(order.get("state", ""))
	match cooking_state:
		restaurant_script.cooking_state_cooking, restaurant_script.cooking_state_ready:
			if customer_state != customer_script.state_waiting_food or order_state != customer_script.order_state_pending:
				return _value_error("unserved cooking job for '%s' has an invalid customer state" % customer_id)
		restaurant_script.cooking_state_served:
			if customer_state != customer_script.state_eating or order_state != customer_script.order_state_served:
				return _value_error("served cooking job for '%s' has an invalid customer state" % customer_id)
		restaurant_script.cooking_state_paid:
			if customer_state != customer_script.state_leaving or order_state != customer_script.order_state_served:
				return _value_error("paid cooking job for '%s' has an invalid customer state" % customer_id)
	var payment_collected: bool = bool(payment_value)
	if payment_collected != (cooking_state == restaurant_script.cooking_state_paid):
		return _value_error("payment state for cooking job '%s' is inconsistent" % customer_id)
	return {
		"ok": true,
		"value": {
			"recipe_id": recipe_id,
			"quantity": int(quantity_result.get("value", 0)),
			"state": cooking_state,
			"cooking_elapsed": elapsed,
			"cooking_duration": duration,
			"payment_collected": payment_collected,
		},
		"error": "",
	}


func _validate_restaurant_customer(
	customer_id: String,
	saved_customer: Dictionary,
	player_level: int,
	tables: Dictionary,
	claimed_tables: Dictionary
) -> Dictionary:
	var customer_type_value: Variant = saved_customer.get("customer_type_id")
	if typeof(customer_type_value) != TYPE_STRING:
		return _value_error("customer '%s' has an invalid type id" % customer_id)
	var customer_type_id: String = String(customer_type_value)
	if data_manager.get_customer_type(customer_type_id).is_empty():
		return _value_error("customer '%s' has an unknown type" % customer_id)

	var position_value: Variant = saved_customer.get("position")
	if typeof(position_value) != TYPE_DICTIONARY:
		return _value_error("position for customer '%s' must be a dictionary" % customer_id)
	var normalized_position: Dictionary = {}
	for axis: String in ["x", "y"]:
		var axis_value: Variant = (position_value as Dictionary).get(axis)
		if typeof(axis_value) != TYPE_INT and typeof(axis_value) != TYPE_FLOAT:
			return _value_error("position.%s for customer '%s' must be a number" % [axis, customer_id])
		var axis_number: float = float(axis_value)
		if not is_finite(axis_number):
			return _value_error("position.%s for customer '%s' must be finite" % [axis, customer_id])
		normalized_position[axis] = axis_number

	var state_value: Variant = saved_customer.get("state")
	var table_id_value: Variant = saved_customer.get("table_id")
	var requested_recipe_value: Variant = saved_customer.get("requested_recipe_id", "")
	if typeof(state_value) != TYPE_STRING or typeof(table_id_value) != TYPE_STRING or typeof(requested_recipe_value) != TYPE_STRING:
		return _value_error("customer '%s' has invalid lifecycle identifiers" % customer_id)
	var customer_state: String = String(state_value)
	var table_id: String = String(table_id_value)
	var requested_recipe_id: String = String(requested_recipe_value)
	if not customer_script.is_valid_state(customer_state):
		return _value_error("customer '%s' has an invalid state" % customer_id)
	if not requested_recipe_id.is_empty() and data_manager.get_restaurant_menu_entry(requested_recipe_id, player_level).is_empty():
		return _value_error("customer '%s' requested an unavailable recipe" % customer_id)

	var active_at_table: bool = customer_state in [
		customer_script.state_seated,
		customer_script.state_ordering,
		customer_script.state_waiting_food,
		customer_script.state_eating,
	]
	if active_at_table:
		if not customer_script.is_valid_table_id(table_id) or not tables.has(table_id):
			return _value_error("customer '%s' references an invalid table" % customer_id)
		if claimed_tables.has(table_id):
			return _value_error("table '%s' is assigned to multiple customers" % table_id)
		var table_state: Dictionary = tables[table_id] as Dictionary
		if String(table_state.get("occupant_id", "")) != customer_id:
			return _value_error("customer '%s' does not match table occupant" % customer_id)
		var saved_table_state: String = String(table_state.get("state", ""))
		if customer_state == customer_script.state_seated:
			if saved_table_state != restaurant_table_script.state_reserved and saved_table_state != restaurant_table_script.state_occupied:
				return _value_error("seated customer '%s' has an invalid table state" % customer_id)
		elif saved_table_state != restaurant_table_script.state_occupied:
			return _value_error("customer '%s' does not have an occupied table" % customer_id)
		claimed_tables[table_id] = customer_id
	elif not table_id.is_empty():
		return _value_error("customer '%s' has a table outside an active table state" % customer_id)

	var patience_result: Dictionary = _validate_customer_number_pair(saved_customer, "patience_elapsed", "patience_limit", customer_id)
	if not bool(patience_result.get("ok", false)):
		return patience_result
	var leaving_result: Dictionary = _validate_customer_number_pair(saved_customer, "leaving_elapsed", "leaving_duration", customer_id)
	if not bool(leaving_result.get("ok", false)):
		return leaving_result

	var reputation_value: Variant = saved_customer.get("timeout_reputation_change")
	if typeof(reputation_value) != TYPE_INT and typeof(reputation_value) != TYPE_FLOAT:
		return _value_error("timeout reputation change for customer '%s' must be a number" % customer_id)
	var reputation_change: float = float(reputation_value)
	if not is_finite(reputation_change) or reputation_change >= 0.0:
		return _value_error("timeout reputation change for customer '%s' must be negative" % customer_id)
	var impact_value: Variant = saved_customer.get("timeout_impact_applied")
	if typeof(impact_value) != TYPE_BOOL:
		return _value_error("timeout impact flag for customer '%s' must be a boolean" % customer_id)

	var order_value: Variant = saved_customer.get("order")
	if typeof(order_value) != TYPE_DICTIONARY:
		return _value_error("order for customer '%s' must be a dictionary" % customer_id)
	var order_result: Dictionary = _validate_restaurant_order(customer_id, order_value as Dictionary, customer_state, player_level)
	if not bool(order_result.get("ok", false)):
		return order_result
	var normalized_order: Dictionary = order_result.get("value", {}) as Dictionary
	if customer_state in [customer_script.state_enter, customer_script.state_seated, customer_script.state_ordering] and not normalized_order.is_empty():
		return _value_error("customer '%s' has an order before WAITING_FOOD" % customer_id)
	if customer_state == customer_script.state_leaving and String(normalized_order.get("state", "")) == customer_script.order_state_pending:
		return _value_error("leaving customer '%s' still has a pending order" % customer_id)
	if String(normalized_order.get("state", "")) == customer_script.order_state_failed and not bool(impact_value):
		return _value_error("failed order for customer '%s' has no applied reputation impact" % customer_id)

	return {
		"ok": true,
		"value": {
			"customer_type_id": customer_type_id,
			"position": normalized_position,
			"state": customer_state,
			"table_id": table_id,
			"requested_recipe_id": requested_recipe_id,
			"order": normalized_order,
			"patience_elapsed": float(patience_result.get("elapsed", 0.0)),
			"patience_limit": float(patience_result.get("limit", 0.0)),
			"leaving_elapsed": float(leaving_result.get("elapsed", 0.0)),
			"leaving_duration": float(leaving_result.get("limit", 0.0)),
			"timeout_reputation_change": reputation_change,
			"timeout_impact_applied": bool(impact_value),
		},
		"error": "",
	}


func _validate_customer_number_pair(saved_customer: Dictionary, elapsed_field: String, limit_field: String, customer_id: String) -> Dictionary:
	var elapsed_value: Variant = saved_customer.get(elapsed_field)
	var limit_value: Variant = saved_customer.get(limit_field)
	if (typeof(elapsed_value) != TYPE_INT and typeof(elapsed_value) != TYPE_FLOAT) or (typeof(limit_value) != TYPE_INT and typeof(limit_value) != TYPE_FLOAT):
		return _value_error("customer '%s' has invalid %s data" % [customer_id, elapsed_field])
	var elapsed: float = float(elapsed_value)
	var limit: float = float(limit_value)
	if not is_finite(elapsed) or not is_finite(limit) or elapsed < 0.0 or limit <= 0.0 or elapsed > limit:
		return _value_error("customer '%s' has inconsistent %s data" % [customer_id, elapsed_field])
	return {"ok": true, "elapsed": elapsed, "limit": limit, "error": ""}


func _validate_restaurant_order(customer_id: String, saved_order: Dictionary, customer_state: String, player_level: int) -> Dictionary:
	if saved_order.is_empty():
		if customer_state == customer_script.state_waiting_food or customer_state == customer_script.state_eating:
			return _value_error("customer '%s' is missing an active order" % customer_id)
		return {"ok": true, "value": {}, "error": ""}
	var recipe_value: Variant = saved_order.get("recipe_id")
	var state_value: Variant = saved_order.get("state")
	var failure_value: Variant = saved_order.get("failure_reason")
	if typeof(recipe_value) != TYPE_STRING or typeof(state_value) != TYPE_STRING or typeof(failure_value) != TYPE_STRING:
		return _value_error("customer '%s' has invalid order identifiers" % customer_id)
	var recipe_id: String = String(recipe_value)
	var order_state: String = String(state_value)
	var failure_reason: String = String(failure_value)
	if data_manager.get_restaurant_menu_entry(recipe_id, player_level).is_empty():
		return _value_error("customer '%s' order references an unavailable recipe" % customer_id)
	if not customer_script.is_valid_order_state(order_state):
		return _value_error("customer '%s' order has an invalid state" % customer_id)
	var quantity_result: Dictionary = _read_integer_value(saved_order.get("quantity"), "order quantity for customer '%s'" % customer_id, 1)
	if not bool(quantity_result.get("ok", false)):
		return quantity_result
	if customer_state == customer_script.state_waiting_food and order_state != customer_script.order_state_pending:
		return _value_error("waiting customer '%s' does not have a pending order" % customer_id)
	if customer_state == customer_script.state_eating and order_state != customer_script.order_state_served:
		return _value_error("eating customer '%s' does not have a served order" % customer_id)
	if order_state == customer_script.order_state_failed and failure_reason.is_empty():
		return _value_error("failed order for customer '%s' has no reason" % customer_id)
	if order_state != customer_script.order_state_failed and not failure_reason.is_empty():
		return _value_error("active order for customer '%s' has a failure reason" % customer_id)
	return {
		"ok": true,
		"value": {
			"recipe_id": recipe_id,
			"quantity": int(quantity_result.get("value", 0)),
			"state": order_state,
			"failure_reason": failure_reason,
		},
		"error": "",
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
	var farming_state: Dictionary = _get_farming_save_state()
	var crops_value: Variant = farming_state.get("crops", {})
	var growth_value: Variant = farming_state.get("crop_growth", {})
	state["crops"] = (
		(crops_value as Dictionary).duplicate(true)
		if typeof(crops_value) == TYPE_DICTIONARY
		else crops_value
	)
	state["crop_growth"] = (
		(growth_value as Dictionary).duplicate(true)
		if typeof(growth_value) == TYPE_DICTIONARY
		else growth_value
	)
	var animal_state: Dictionary = _get_animal_save_state()
	var animals_value: Variant = animal_state.get("animals", {})
	var animal_age_value: Variant = animal_state.get("animal_age", {})
	state["animals"] = (
		(animals_value as Dictionary).duplicate(true)
		if typeof(animals_value) == TYPE_DICTIONARY
		else animals_value
	)
	state["animal_age"] = (
		(animal_age_value as Dictionary).duplicate(true)
		if typeof(animal_age_value) == TYPE_DICTIONARY
		else animal_age_value
	)
	state["animals_initialized"] = true
	var aquaculture_state: Dictionary = _get_aquaculture_save_state()
	var aquaculture_value: Variant = aquaculture_state.get("aquaculture", {})
	state["aquaculture"] = (
		(aquaculture_value as Dictionary).duplicate(true)
		if typeof(aquaculture_value) == TYPE_DICTIONARY
		else aquaculture_value
	)
	var restaurant_state: Dictionary = _get_restaurant_save_state()
	var restaurant_level_value: Variant = restaurant_state.get("restaurant_level", 0)
	var restaurant_tables_value: Variant = restaurant_state.get("restaurant_tables", {})
	var restaurant_customers_value: Variant = restaurant_state.get("restaurant_customers", {})
	var restaurant_cooking_value: Variant = restaurant_state.get("restaurant_cooking", {})
	var staff_value: Variant = restaurant_state.get("staff", {})
	state["restaurant_level"] = restaurant_level_value
	state["kitchen_level"] = restaurant_state.get("kitchen_level", 0)
	state["restaurant_tables"] = (
		(restaurant_tables_value as Dictionary).duplicate(true)
		if typeof(restaurant_tables_value) == TYPE_DICTIONARY
		else restaurant_tables_value
	)
	state["restaurant_customers"] = (
		(restaurant_customers_value as Dictionary).duplicate(true)
		if typeof(restaurant_customers_value) == TYPE_DICTIONARY
		else restaurant_customers_value
	)
	state["restaurant_customer_sequence"] = restaurant_state.get("restaurant_customer_sequence", 0)
	state["restaurant_spawn_elapsed"] = restaurant_state.get("restaurant_spawn_elapsed", 0.0)
	state["restaurant_cooking"] = (
		(restaurant_cooking_value as Dictionary).duplicate(true)
		if typeof(restaurant_cooking_value) == TYPE_DICTIONARY
		else restaurant_cooking_value
	)
	state["staff"] = (
		(staff_value as Dictionary).duplicate(true)
		if typeof(staff_value) == TYPE_DICTIONARY
		else staff_value
	)
	state["coop_level"] = 1
	state["cow_barn_level"] = 1
	state["beverage_counter"] = 0
	state["unlocked_recipes"] = []
	state["unlocked_items"] = []
	state["achievements"] = []

	return state


func _apply_save_state(state: Dictionary) -> void:
	game_manager.apply_save_state(state)
	inventory_manager.apply_save_state(state)
	_apply_farming_save_state(state)
	_apply_animal_save_state(state)
	_apply_aquaculture_save_state(state)
	_apply_restaurant_save_state(state)


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
	_apply_farming_save_state({
		"crops": {},
		"crop_growth": {}
	})
	_apply_animal_save_state({
		"animals": {},
		"animal_age": {},
		"animals_initialized": false
	})
	_apply_aquaculture_save_state({"aquaculture": {}})
	_apply_restaurant_save_state({
		"restaurant_level": 0,
		"kitchen_level": 0,
		"restaurant_tables": {},
		"restaurant_customers": {},
		"restaurant_customer_sequence": 0,
		"restaurant_spawn_elapsed": 0.0,
		"restaurant_cooking": {},
		"staff": {},
	})


func _get_farming_save_state() -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null or not current_scene.has_method("get_farming_save_state"):
		return {
			"crops": {},
			"crop_growth": {}
		}

	var farming_state_value: Variant = current_scene.call("get_farming_save_state")
	if typeof(farming_state_value) != TYPE_DICTIONARY:
		return {
			"crops": {},
			"crop_growth": {}
		}

	return farming_state_value as Dictionary


func _apply_farming_save_state(state: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("apply_farming_save_state"):
		current_scene.call("apply_farming_save_state", state)


func _get_animal_save_state() -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null or not current_scene.has_method("get_animal_save_state"):
		return {
			"animals": {},
			"animal_age": {}
		}

	var animal_state_value: Variant = current_scene.call("get_animal_save_state")
	if typeof(animal_state_value) != TYPE_DICTIONARY:
		return {
			"animals": {},
			"animal_age": {}
		}

	return animal_state_value as Dictionary


func _apply_animal_save_state(state: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("apply_animal_save_state"):
		current_scene.call("apply_animal_save_state", state)


func _get_aquaculture_save_state() -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null or not current_scene.has_method("get_aquaculture_save_state"):
		return {"aquaculture": {}}

	var aquaculture_state_value: Variant = current_scene.call("get_aquaculture_save_state")
	if typeof(aquaculture_state_value) != TYPE_DICTIONARY:
		push_error("save_manager: current scene returned an invalid aquaculture save state")
		return {"aquaculture": aquaculture_state_value}
	return aquaculture_state_value as Dictionary


func _apply_aquaculture_save_state(state: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("apply_aquaculture_save_state"):
		current_scene.call("apply_aquaculture_save_state", state)


func _get_restaurant_save_state() -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null or not current_scene.has_method("get_restaurant_save_state"):
		return {
			"restaurant_level": 0,
			"kitchen_level": 0,
			"restaurant_tables": {},
			"restaurant_customers": {},
			"restaurant_customer_sequence": 0,
			"restaurant_spawn_elapsed": 0.0,
			"restaurant_cooking": {},
			"staff": {},
		}
	var restaurant_state_value: Variant = current_scene.call("get_restaurant_save_state")
	if typeof(restaurant_state_value) != TYPE_DICTIONARY:
		push_error("save_manager: current scene returned an invalid restaurant save state")
		return {
			"restaurant_level": restaurant_state_value,
			"kitchen_level": 0,
			"restaurant_tables": {},
			"restaurant_customers": {},
			"restaurant_customer_sequence": 0,
			"restaurant_spawn_elapsed": 0.0,
			"restaurant_cooking": {},
			"staff": {},
		}
	return restaurant_state_value as Dictionary


func _apply_restaurant_save_state(state: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("apply_restaurant_save_state"):
		current_scene.call("apply_restaurant_save_state", state)


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
