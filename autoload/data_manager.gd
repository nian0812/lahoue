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
