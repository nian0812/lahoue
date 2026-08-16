extends Node

signal data_loaded
signal data_load_failed(path: String, reason: String)

const data_paths: Dictionary = {
	"items": "res://data/items.json",
	"crops": "res://data/crops.json",
	"animals": "res://data/animals.json",
	"aquaculture": "res://data/aquaculture.json",
	"recipes": "res://data/recipes.json",
	"progression": "res://data/progression.json"
}

var data: Dictionary = {}
var is_ready: bool = false


func _ready() -> void:
	load_all_data()


func load_all_data() -> bool:
	data.clear()

	for data_key in data_paths:
		var path: String = String(data_paths[data_key])
		var result: Dictionary = _load_json(path)
		var load_ok: bool = bool(result.get("ok", false))

		if not load_ok:
			is_ready = false
			var reason: String = String(result.get("error", "unknown error"))
			data_load_failed.emit(path, reason)
			push_error("data_manager: failed to load %s: %s" % [path, reason])
			return false

		var loaded_value: Variant = result.get("value")
		if typeof(loaded_value) != TYPE_DICTIONARY:
			is_ready = false
			var root_error: String = "root json value must be a dictionary"
			data_load_failed.emit(path, root_error)
			push_error("data_manager: failed to load %s: %s" % [path, root_error])
			return false

		data[String(data_key)] = loaded_value

	is_ready = true
	data_loaded.emit()
	return true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"value": null,
			"error": "file not found"
		}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"value": null,
			"error": "cannot open file"
		}

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)

	if error != OK:
		return {
			"ok": false,
			"value": null,
			"error": "json parse error at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message()
			]
		}

	return {
		"ok": true,
		"value": json.data,
		"error": ""
	}


func get_dataset(data_key: String) -> Dictionary:
	if not data.has(data_key):
		push_error("data_manager: unknown dataset '%s'" % data_key)
		return {}

	var dataset_value: Variant = data[data_key]
	if typeof(dataset_value) != TYPE_DICTIONARY:
		push_error("data_manager: dataset '%s' is not a dictionary" % data_key)
		return {}

	return dataset_value as Dictionary


func get_entry(data_key: String, entry_id: String) -> Variant:
	var dataset: Dictionary = get_dataset(data_key)
	if dataset.is_empty():
		return null

	var entries_value: Variant = dataset.get("entries", {})
	if typeof(entries_value) != TYPE_DICTIONARY:
		push_error("data_manager: dataset '%s' has no dictionary 'entries'" % data_key)
		return null

	var entries: Dictionary = entries_value as Dictionary
	return entries.get(entry_id)


func get_crop_id_for_seed(seed_item_id: String) -> String:
	var crops: Dictionary = get_dataset("crops")
	var entries_value: Variant = crops.get("entries", {})
	if typeof(entries_value) != TYPE_DICTIONARY:
		return ""

	var entries: Dictionary = entries_value as Dictionary
	for crop_id_value: Variant in entries:
		var crop_value: Variant = entries[crop_id_value]
		if typeof(crop_value) != TYPE_DICTIONARY:
			continue

		var crop_data: Dictionary = crop_value as Dictionary
		if String(crop_data.get("seed_item", "")) == seed_item_id:
			return String(crop_id_value)

	return ""


func get_crop_growth_time_seconds(crop_id: String) -> float:
	var crop_value: Variant = get_entry("crops", crop_id)
	if typeof(crop_value) != TYPE_DICTIONARY:
		return 0.0

	var growth_time_value: Variant = (crop_value as Dictionary).get("growth_time")
	if typeof(growth_time_value) != TYPE_INT and typeof(growth_time_value) != TYPE_FLOAT:
		return 0.0

	var growth_time: float = float(growth_time_value)
	return growth_time if is_finite(growth_time) and growth_time > 0.0 else 0.0


func get_aquaculture_growth_time_seconds(aquaculture_id: String) -> float:
	var aquaculture_value: Variant = get_entry("aquaculture", aquaculture_id)
	if typeof(aquaculture_value) != TYPE_DICTIONARY:
		return 0.0

	var growth_time_value: Variant = (aquaculture_value as Dictionary).get("growth_time")
	if typeof(growth_time_value) != TYPE_INT and typeof(growth_time_value) != TYPE_FLOAT:
		return 0.0

	var growth_time: float = float(growth_time_value)
	return growth_time if is_finite(growth_time) and growth_time > 0.0 else 0.0


func get_item_buy_price(item_id: String) -> int:
	return _get_item_price(item_id, "buy_price")


func get_item_sell_price(item_id: String) -> int:
	return _get_item_price(item_id, "sell_price")


func get_item_required_level(item_id: String) -> int:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return 0

	var item_data: Dictionary = item_value as Dictionary
	var required_level_value: Variant = item_data.get("required_level")
	if required_level_value != null:
		return _read_positive_integer(required_level_value)

	if String(item_data.get("category", "")) == "seed":
		var crop_id: String = get_crop_id_for_seed(item_id)
		var crop_value: Variant = get_entry("crops", crop_id)
		if typeof(crop_value) != TYPE_DICTIONARY:
			return 0
		return _read_positive_integer((crop_value as Dictionary).get("required_level"))

	return 1


func get_level_exp(level: int) -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return 0

	var level_exp_value: Variant = progression.get("level_exp", {})
	if typeof(level_exp_value) != TYPE_DICTIONARY:
		push_error("data_manager: progression.level_exp is not a dictionary")
		return 0

	var level_exp: Dictionary = level_exp_value as Dictionary
	return int(level_exp.get(str(level), 0))


func get_warehouse_capacity(level: int) -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return 0

	var warehouse_value: Variant = progression.get("warehouse", {})
	if typeof(warehouse_value) != TYPE_DICTIONARY:
		push_error("data_manager: progression.warehouse is not a dictionary")
		return 0

	var warehouse: Dictionary = warehouse_value as Dictionary
	var levels_value: Variant = warehouse.get("levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		push_error("data_manager: progression.warehouse.levels is not a dictionary")
		return 0

	var levels: Dictionary = levels_value as Dictionary
	var level_data_value: Variant = levels.get(str(level), {})
	if typeof(level_data_value) != TYPE_DICTIONARY:
		return 0

	var level_data: Dictionary = level_data_value as Dictionary
	return int(level_data.get("capacity", 0))


func get_warehouse_upgrade_cost(target_level: int) -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return -1

	var warehouse_value: Variant = progression.get("warehouse", {})
	if typeof(warehouse_value) != TYPE_DICTIONARY:
		return -1
	var levels_value: Variant = (warehouse_value as Dictionary).get("levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		return -1
	var level_value: Variant = (levels_value as Dictionary).get(str(target_level))
	if typeof(level_value) != TYPE_DICTIONARY:
		return -1

	var upgrade_cost_value: Variant = (level_value as Dictionary).get("upgrade_cost")
	return _read_non_negative_integer(upgrade_cost_value)


func get_animal_housing_capacity(housing_id: String, level: int = 1) -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return 0

	var housing_value: Variant = progression.get(housing_id, {})
	if typeof(housing_value) != TYPE_DICTIONARY:
		return 0

	var levels_value: Variant = (housing_value as Dictionary).get("levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		return 0

	var level_value: Variant = (levels_value as Dictionary).get(str(level), {})
	if typeof(level_value) != TYPE_DICTIONARY:
		return 0

	return int((level_value as Dictionary).get("capacity", 0))


func _get_item_price(item_id: String, field: String) -> int:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return -1
	return _read_non_negative_integer((item_value as Dictionary).get(field))


func _read_non_negative_integer(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return -1
	var number: float = float(value)
	if not is_finite(number) or floor(number) != number or number < 0.0:
		return -1
	return int(number)


func _read_positive_integer(value: Variant) -> int:
	var integer_value: int = _read_non_negative_integer(value)
	return integer_value if integer_value > 0 else 0
