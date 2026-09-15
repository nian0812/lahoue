extends Node

signal data_loaded
signal data_load_failed(path: String, reason: String)

const progression_effect_fields: Dictionary = {
	"warehouse": "capacity",
	"coop": "capacity",
	"pig_pen": "capacity",
	"cow_barn": "capacity",
	"aquaculture": "areas",
	"restaurant": "tables",
	"kitchen": "cooking_slots",
	"truck": "delivery_time",
	"resort": "rooms",
}

const data_paths: Dictionary = {
	"items": "res://data/items.json",
	"crops": "res://data/crops.json",
	"animals": "res://data/animals.json",
	"aquaculture": "res://data/aquaculture.json",
	"recipes": "res://data/recipes.json",
	"customers": "res://data/customers.json",
	"staff": "res://data/staff.json",
	"progression": "res://data/progression.json",
	"achievements": "res://data/achievements.json"
}

const achievement_metric_modes: Dictionary = {
	"crops_harvested": "increment",
	"animal_products_collected": "increment",
	"aquaculture_products_collected": "increment",
	"cooking_orders_completed": "increment",
	"customer_orders_served": "increment",
	"restaurant_orders_paid": "increment",
	"items_sold": "increment",
	"money_earned": "increment",
	"truck_shipments_completed": "increment",
	"import_shipments_completed": "increment",
	"staff_roles_owned": "maximum",
	"upgrades_purchased": "increment",
	"player_level": "maximum",
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


func validate_achievement_definitions(dataset: Dictionary) -> Dictionary:
	if int(dataset.get("schema_version", 0)) != 1:
		return {"ok": false, "definitions": {}, "error": "schema_version must be 1"}
	var entries_value: Variant = dataset.get("entries")
	if typeof(entries_value) != TYPE_DICTIONARY:
		return {"ok": false, "definitions": {}, "error": "entries must be a dictionary"}

	var normalized: Dictionary = {}
	for achievement_id_value: Variant in entries_value as Dictionary:
		if typeof(achievement_id_value) != TYPE_STRING:
			return {"ok": false, "definitions": {}, "error": "achievement ids must be strings"}
		var achievement_id: String = String(achievement_id_value)
		if (
			achievement_id.is_empty()
			or achievement_id != achievement_id.to_lower()
			or not achievement_id.is_valid_identifier()
		):
			return {"ok": false, "definitions": {}, "error": "invalid achievement id '%s'" % achievement_id}
		var definition_value: Variant = (entries_value as Dictionary)[achievement_id_value]
		if typeof(definition_value) != TYPE_DICTIONARY:
			return {"ok": false, "definitions": {}, "error": "achievement '%s' must be a dictionary" % achievement_id}
		var definition: Dictionary = definition_value as Dictionary
		var condition_value: Variant = definition.get("condition")
		if typeof(condition_value) != TYPE_DICTIONARY:
			return {"ok": false, "definitions": {}, "error": "achievement '%s' needs a condition" % achievement_id}
		var condition: Dictionary = condition_value as Dictionary
		var metric: String = String(condition.get("metric", ""))
		var mode: String = String(condition.get("mode", ""))
		var target: int = _read_positive_integer(condition.get("target"))
		if not achievement_metric_modes.has(metric) or mode != String(achievement_metric_modes[metric]) or target <= 0:
			return {"ok": false, "definitions": {}, "error": "achievement '%s' has an invalid condition" % achievement_id}

		var reward_value: Variant = definition.get("reward", null)
		var reward: Variant = null
		if reward_value != null:
			if typeof(reward_value) != TYPE_DICTIONARY:
				return {"ok": false, "definitions": {}, "error": "achievement '%s' has an invalid reward" % achievement_id}
			var reward_data: Dictionary = reward_value as Dictionary
			var reward_type: String = String(reward_data.get("type", ""))
			var reward_amount: int = _read_positive_integer(reward_data.get("amount"))
			if not ["money", "exp", "item"].has(reward_type) or reward_amount <= 0:
				return {"ok": false, "definitions": {}, "error": "achievement '%s' has an invalid reward" % achievement_id}
			reward = {"type": reward_type, "amount": reward_amount}
			if reward_type == "item":
				var item_id: String = String(reward_data.get("item_id", ""))
				if item_id.is_empty() or get_entry("items", item_id) == null:
					return {"ok": false, "definitions": {}, "error": "achievement '%s' has an unknown reward item" % achievement_id}
				(reward as Dictionary)["item_id"] = item_id

		normalized[achievement_id] = {
			"achievement_id": achievement_id,
			"name": String(definition.get("name", achievement_id)),
			"description": String(definition.get("description", "")),
			"progress_label": String(definition.get("progress_label", "Progress")),
			"condition": {"metric": metric, "mode": mode, "target": target},
			"reward": reward,
		}

	return {"ok": true, "definitions": normalized, "error": ""}


func get_achievement_definitions() -> Dictionary:
	var result: Dictionary = validate_achievement_definitions(get_dataset("achievements"))
	if not bool(result.get("ok", false)):
		push_error("data_manager: invalid achievement data: %s" % String(result.get("error", "unknown error")))
		return {}
	return (result.get("definitions", {}) as Dictionary).duplicate(true)


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


func get_crop_required_level(crop_id: String) -> int:
	var crop_value: Variant = get_entry("crops", crop_id)
	if typeof(crop_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((crop_value as Dictionary).get("required_level"))


func get_aquaculture_growth_time_seconds(aquaculture_id: String) -> float:
	var aquaculture_value: Variant = get_entry("aquaculture", aquaculture_id)
	if typeof(aquaculture_value) != TYPE_DICTIONARY:
		return 0.0

	var growth_time_value: Variant = (aquaculture_value as Dictionary).get("growth_time")
	if typeof(growth_time_value) != TYPE_INT and typeof(growth_time_value) != TYPE_FLOAT:
		return 0.0

	var growth_time: float = float(growth_time_value)
	return growth_time if is_finite(growth_time) and growth_time > 0.0 else 0.0


func get_aquaculture_required_level(aquaculture_id: String) -> int:
	var aquaculture_value: Variant = get_entry("aquaculture", aquaculture_id)
	if typeof(aquaculture_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((aquaculture_value as Dictionary).get("required_level"))


func get_animal_required_level(animal_id: String) -> int:
	var animal_value: Variant = get_entry("animals", animal_id)
	if typeof(animal_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((animal_value as Dictionary).get("required_level"))


func get_item_buy_price(item_id: String) -> int:
	return _get_item_price(item_id, "buy_price")


func get_item_sell_price(item_id: String) -> int:
	return _get_item_price(item_id, "sell_price")

func get_item_source_level(item_id: String) -> int:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return 1
	var lvl: int = _read_positive_integer((item_value as Dictionary).get("required_level"))
	if lvl > 0:
		return lvl
	var crops: Dictionary = get_dataset("crops").get("entries", {})
	for cid: String in crops:
		if String(crops[cid].get("harvest_item", "")) == item_id:
			return _read_positive_integer(crops[cid].get("required_level"))
	var animals: Dictionary = get_dataset("animals").get("entries", {})
	for aid: String in animals:
		var d: Variant = animals[aid].get("daily_product")
		if typeof(d) == TYPE_DICTIONARY and String((d as Dictionary).get("item_id", "")) == item_id:
			return _read_positive_integer(animals[aid].get("required_level"))
		var e: Variant = animals[aid].get("end_of_life_product")
		if typeof(e) == TYPE_DICTIONARY and String((e as Dictionary).get("item_id", "")) == item_id:
			return _read_positive_integer(animals[aid].get("required_level"))
		var p: String = String(animals[aid].get("primary_product", ""))
		if p == item_id:
			return _read_positive_integer(animals[aid].get("required_level"))
	var aqua: Dictionary = get_dataset("aquaculture").get("entries", {})
	for aid: String in aqua:
		if String(aqua[aid].get("item_id", "")) == item_id:
			return _read_positive_integer(aqua[aid].get("required_level"))
	return 1

func get_item_required_level(item_id: String) -> int:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return 0

	var item_data: Dictionary = item_value as Dictionary
	var required_level_value: Variant = item_data.get("required_level")
	if required_level_value != null:
		return _read_positive_integer(required_level_value)

	var crop_id: String = get_crop_id_for_seed(item_id)
	if not crop_id.is_empty():
		var crop_value: Variant = get_entry("crops", crop_id)
		if typeof(crop_value) != TYPE_DICTIONARY:
			return 0
		return get_crop_required_level(crop_id)

	return 1


func get_restaurant_unlock_level() -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return 0
	var restaurant_value: Variant = progression.get("restaurant")
	if typeof(restaurant_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((restaurant_value as Dictionary).get("unlock_level"))


func get_restaurant_table_capacity(restaurant_level: int) -> int:
	return get_progression_effect("restaurant", restaurant_level)


func get_restaurant_menu(player_level: int) -> Dictionary:
	var unlock_level: int = get_restaurant_unlock_level()
	if unlock_level <= 0 or player_level < unlock_level:
		return {}

	var recipes: Dictionary = get_dataset("recipes")
	var entries_value: Variant = recipes.get("entries", {})
	if typeof(entries_value) != TYPE_DICTIONARY:
		return {}

	var menu: Dictionary = {}
	for recipe_id_value: Variant in entries_value as Dictionary:
		var recipe_id: String = String(recipe_id_value)
		var normalized_entry: Dictionary = _normalize_restaurant_recipe(recipe_id, player_level)
		if not normalized_entry.is_empty():
			menu[recipe_id] = normalized_entry
	return menu


func get_restaurant_menu_entry(recipe_id: String, player_level: int) -> Dictionary:
	if player_level < get_restaurant_unlock_level():
		return {}
	return _normalize_restaurant_recipe(recipe_id, player_level)


func get_kitchen_cooking_slots(kitchen_level: int) -> int:
	var level_data: Dictionary = _get_progression_level_data("kitchen", kitchen_level)
	return _read_positive_integer(level_data.get("cooking_slots"))


func get_kitchen_speed_percent(kitchen_level: int) -> int:
	var level_data: Dictionary = _get_progression_level_data("kitchen", kitchen_level)
	return _read_positive_integer(level_data.get("speed_percent"))


func get_customer_settings() -> Dictionary:
	var customers: Dictionary = get_dataset("customers")
	var settings_value: Variant = customers.get("settings", {})
	if typeof(settings_value) != TYPE_DICTIONARY:
		return {}
	var settings: Dictionary = settings_value as Dictionary
	var spawn_interval: float = _read_positive_number(settings.get("spawn_interval_seconds"))
	var default_type: String = String(settings.get("default_customer_type", ""))
	if spawn_interval <= 0.0 or get_customer_type(default_type).is_empty():
		return {}
	return {
		"spawn_interval_seconds": spawn_interval,
		"default_customer_type": default_type,
	}


func get_customer_type(customer_type_id: String) -> Dictionary:
	var customer_value: Variant = get_entry("customers", customer_type_id)
	if typeof(customer_value) != TYPE_DICTIONARY:
		return {}
	var customer_data: Dictionary = customer_value as Dictionary
	var patience: float = _read_positive_number(customer_data.get("patience_seconds"))
	var leaving_duration: float = _read_positive_number(customer_data.get("leaving_duration_seconds"))
	var order_quantity: int = _read_positive_integer(customer_data.get("order_quantity"))
	var reputation_value: Variant = customer_data.get("timeout_reputation_change")
	if typeof(reputation_value) != TYPE_INT and typeof(reputation_value) != TYPE_FLOAT:
		return {}
	var reputation_change: float = float(reputation_value)
	if not is_finite(reputation_change) or reputation_change >= 0.0:
		return {}
	if patience <= 0.0 or leaving_duration <= 0.0 or order_quantity <= 0:
		return {}
	return {
		"customer_type_id": customer_type_id,
		"patience_seconds": patience,
		"leaving_duration_seconds": leaving_duration,
		"order_quantity": order_quantity,
		"timeout_reputation_change": reputation_change,
	}


func get_staff_settings() -> Dictionary:
	var staff: Dictionary = get_dataset("staff")
	var settings_value: Variant = staff.get("settings", {})
	if typeof(settings_value) != TYPE_DICTIONARY:
		return {}
	var default_staff_type: String = String((settings_value as Dictionary).get("default_staff_type", ""))
	if get_staff_type(default_staff_type).is_empty():
		return {}
	return {"default_staff_type": default_staff_type}


func get_staff_type(staff_type_id: String) -> Dictionary:
	var staff_value: Variant = get_entry("staff", staff_type_id)
	if typeof(staff_value) != TYPE_DICTIONARY:
		return {}
	var staff_data: Dictionary = staff_value as Dictionary
	var unlock_level: int = _read_positive_integer(staff_data.get("unlock_level"))
	var movement_speed: float = _read_positive_number(staff_data.get("movement_speed"))
	var cleaning_time: float = _read_positive_number(staff_data.get("cleaning_time_seconds"))
	var max_count: int = _read_positive_integer(staff_data.get("max_count"))
	var jobs_value: Variant = staff_data.get("allowed_jobs")
	var hire_cost: int = get_staff_hire_cost(staff_type_id)
	var daily_salary: int = get_staff_daily_salary(staff_type_id)
	if unlock_level <= 0 or movement_speed <= 0.0 or cleaning_time <= 0.0 or max_count <= 0 or hire_cost <= 0 or daily_salary <= 0:
		return {}
	if typeof(jobs_value) != TYPE_ARRAY or (jobs_value as Array).is_empty():
		return {}
	var allowed_jobs: Array[String] = []
	for job_value: Variant in jobs_value as Array:
		if typeof(job_value) != TYPE_STRING:
			return {}
		var job_type: String = String(job_value)
		if not [
			"cook",
			"serve",
			"payment",
			"clean",
			"harvest",
			"collect_animal",
			"collect_aquaculture",
		].has(job_type) or allowed_jobs.has(job_type):
			return {}
		allowed_jobs.append(job_type)
	return {
		"staff_type_id": staff_type_id,
		"unlock_level": unlock_level,
		"movement_speed": movement_speed,
		"cleaning_time_seconds": cleaning_time,
		"max_count": max_count,
		"allowed_jobs": allowed_jobs,
		"hire_cost": hire_cost,
		"daily_salary": daily_salary,
	}


func get_staff_hire_cost(staff_type_id: String) -> int:
	var progression: Dictionary = get_dataset("progression")
	var costs_value: Variant = progression.get("staff_hire_costs", {})
	if typeof(costs_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((costs_value as Dictionary).get(staff_type_id))


func get_staff_daily_salary(staff_type_id: String) -> int:
	var progression: Dictionary = get_dataset("progression")
	var salaries_value: Variant = progression.get("staff_daily_salaries", {})
	if typeof(salaries_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((salaries_value as Dictionary).get(staff_type_id))


func get_premium_market_unlock_level() -> int:
	var progression: Dictionary = get_dataset("progression")
	var market_value: Variant = progression.get("premium_market", {})
	if typeof(market_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((market_value as Dictionary).get("unlock_level"))


func get_helicopter_level_data(level: int) -> Dictionary:
	if level <= 0:
		return {}
	var progression: Dictionary = get_dataset("progression")
	var market_value: Variant = progression.get("premium_market", {})
	if typeof(market_value) != TYPE_DICTIONARY:
		return {}
	var levels_value: Variant = (market_value as Dictionary).get("helicopter_levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		return {}
	var level_value: Variant = (levels_value as Dictionary).get(str(level), {})
	if typeof(level_value) != TYPE_DICTIONARY:
		return {}
	var level_data: Dictionary = level_value as Dictionary
	if (
		_read_positive_number(level_data.get("shipping_time")) <= 0.0
		or _read_positive_integer(level_data.get("capacity")) <= 0
		or _read_positive_number(level_data.get("visual_speed")) <= 0.0
	):
		return {}
	return level_data.duplicate(true)


func get_max_helicopter_level() -> int:
	var maximum: int = 0
	while not get_helicopter_level_data(maximum + 1).is_empty():
		maximum += 1
	return maximum


func get_premium_import_item_ids() -> Array[String]:
	var result: Array[String] = []
	var entries: Dictionary = get_dataset("items").get("entries", {}) as Dictionary
	for item_id_value: Variant in entries:
		var item_id: String = String(item_id_value)
		var item_data: Dictionary = entries[item_id_value] as Dictionary
		if (
			String(item_data.get("category", "")) == "import"
			and _read_positive_integer(item_data.get("required_level")) == get_premium_market_unlock_level()
			and get_item_buy_price(item_id) > 0
		):
			result.append(item_id)
	result.sort()
	return result


func get_item_display_name(item_id: String) -> String:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return ""
	var configured_name: String = String((item_value as Dictionary).get("display_name", ""))
	return configured_name if not configured_name.is_empty() else item_id.replace("_", " ").capitalize()


func get_level_exp(level: int) -> int:
	var progression: Dictionary = get_dataset("progression")
	if progression.is_empty():
		return 0

	var level_exp_value: Variant = progression.get("level_exp", {})
	if typeof(level_exp_value) != TYPE_DICTIONARY:
		push_error("data_manager: progression.level_exp is not a dictionary")
		return 0

	var level_exp: Dictionary = level_exp_value as Dictionary
	return _read_positive_integer(level_exp.get(str(level)))


func get_max_player_level() -> int:
	var progression: Dictionary = get_dataset("progression")
	var level_exp_value: Variant = progression.get("level_exp", {})
	if typeof(level_exp_value) != TYPE_DICTIONARY:
		return 0
	var maximum: int = 0
	for level_value: Variant in level_exp_value as Dictionary:
		var level_string: String = String(level_value)
		if not level_string.is_valid_int():
			return 0
		var level: int = int(level_string)
		if level <= 0 or _read_positive_integer((level_exp_value as Dictionary)[level_value]) <= 0:
			return 0
		maximum = maxi(maximum, level)
	for level: int in range(1, maximum + 1):
		if not (level_exp_value as Dictionary).has(str(level)):
			return 0
	return maximum


func get_warehouse_capacity(level: int) -> int:
	return get_progression_effect("warehouse", level)


func get_warehouse_upgrade_cost(target_level: int) -> int:
	return get_progression_upgrade_cost("warehouse", target_level)


func get_animal_housing_capacity(housing_id: String, level: int = 1) -> int:
	if not ["coop", "pig_pen", "cow_barn"].has(housing_id):
		return 0
	return get_progression_effect(housing_id, level)


func get_system_unlock_level(system_id: String) -> int:
	var progression: Dictionary = get_dataset("progression")
	var system_value: Variant = progression.get(system_id, {})
	if typeof(system_value) != TYPE_DICTIONARY:
		return 0
	return _read_positive_integer((system_value as Dictionary).get("unlock_level", 1))


func get_system_required_player_level(system_id: String, target_level: int) -> int:
	var level_data: Dictionary = get_progression_level_data(system_id, target_level)
	if level_data.is_empty():
		return 0
	return _read_positive_integer(level_data.get("required_player_level", get_system_unlock_level(system_id)))


func get_farm_plot_maximum() -> int:
	var settings: Dictionary = get_dataset("progression").get("farm_plots", {}) as Dictionary
	return _read_positive_integer(settings.get("maximum"))


func get_farm_plot_purchase_cost() -> int:
	var settings: Dictionary = get_dataset("progression").get("farm_plots", {}) as Dictionary
	return _read_positive_integer(settings.get("purchase_cost"))


func get_farm_plot_limit(player_level: int) -> int:
	var settings: Dictionary = get_dataset("progression").get("farm_plots", {}) as Dictionary
	var limits_value: Variant = settings.get("level_limits", {})
	if typeof(limits_value) != TYPE_DICTIONARY:
		return 0
	var allowed: int = 0
	for level_value: Variant in limits_value as Dictionary:
		var level_string: String = String(level_value)
		if not level_string.is_valid_int():
			return 0
		var required_level: int = int(level_string)
		var limit: int = _read_positive_integer((limits_value as Dictionary)[level_value])
		if required_level <= 0 or limit <= 0:
			return 0
		if player_level >= required_level:
			allowed = maxi(allowed, limit)
	return mini(allowed, get_farm_plot_maximum())


func get_next_farm_plot_limit_level(player_level: int, owned_count: int) -> int:
	var settings: Dictionary = get_dataset("progression").get("farm_plots", {}) as Dictionary
	var limits_value: Variant = settings.get("level_limits", {})
	if typeof(limits_value) != TYPE_DICTIONARY:
		return 0
	var next_level: int = 0
	for level_value: Variant in limits_value as Dictionary:
		var level_string: String = String(level_value)
		if not level_string.is_valid_int():
			continue
		var required_level: int = int(level_string)
		var limit: int = _read_positive_integer((limits_value as Dictionary)[level_value])
		if required_level > player_level and limit > owned_count and (next_level == 0 or required_level < next_level):
			next_level = required_level
	return next_level


func get_pond_unlock_level(aquaculture_id: String) -> int:
	var ponds: Dictionary = get_dataset("progression").get("ponds", {}) as Dictionary
	var pond: Dictionary = ponds.get(aquaculture_id, {}) as Dictionary
	return _read_positive_integer(pond.get("unlock_level"))


func get_pond_purchase_cost(aquaculture_id: String) -> int:
	var ponds: Dictionary = get_dataset("progression").get("ponds", {}) as Dictionary
	var pond: Dictionary = ponds.get(aquaculture_id, {}) as Dictionary
	return _read_positive_integer(pond.get("purchase_cost"))


func get_pond_level_data(aquaculture_id: String, pond_level: int) -> Dictionary:
	if pond_level <= 0:
		return {}
	var ponds: Dictionary = get_dataset("progression").get("ponds", {}) as Dictionary
	var pond: Dictionary = ponds.get(aquaculture_id, {}) as Dictionary
	var levels: Dictionary = pond.get("levels", {}) as Dictionary
	var value: Variant = levels.get(str(pond_level), {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func get_pond_max_level(aquaculture_id: String) -> int:
	var maximum: int = 0
	while not get_pond_level_data(aquaculture_id, maximum + 1).is_empty():
		maximum += 1
	return maximum


func get_pond_upgrade_cost(aquaculture_id: String, target_level: int) -> int:
	var data_value: Dictionary = get_pond_level_data(aquaculture_id, target_level)
	if data_value.is_empty():
		return -1
	return _read_non_negative_integer(data_value.get("upgrade_cost"))


func get_pond_cycle_time(aquaculture_id: String, pond_level: int) -> float:
	var base_time: float = get_aquaculture_growth_time_seconds(aquaculture_id)
	var speed_percent: int = _read_positive_integer(get_pond_level_data(aquaculture_id, pond_level).get("speed_percent"))
	return base_time * float(speed_percent) / 100.0 if base_time > 0.0 and speed_percent > 0 else 0.0


func get_building_purchase_data(building_id: String) -> Dictionary:
	var purchases: Dictionary = get_dataset("progression").get("building_purchases", {}) as Dictionary
	var value: Variant = purchases.get(building_id, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func get_building_unlock_level(building_id: String) -> int:
	return _read_positive_integer(get_building_purchase_data(building_id).get("unlock_level"))


func get_building_purchase_cost(building_id: String) -> int:
	return _read_positive_integer(get_building_purchase_data(building_id).get("cost"))


func get_vip_payout_multiplier() -> float:
	var market: Dictionary = get_dataset("progression").get("premium_market", {}) as Dictionary
	var value: Variant = market.get("vip_multiplier", 1.0)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 1.0
	return maxf(float(value), 1.0)


func get_aquaculture_area_capacity(level: int) -> int:
	return get_progression_effect("aquaculture", level)


func get_progression_level_data(system_id: String, level: int) -> Dictionary:
	if not progression_effect_fields.has(system_id) or level <= 0:
		return {}
	return _get_progression_level_data(system_id, level)


func get_progression_effect(system_id: String, level: int) -> int:
	var level_data: Dictionary = get_progression_level_data(system_id, level)
	var effect_field: String = String(progression_effect_fields.get(system_id, ""))
	return _read_positive_integer(level_data.get(effect_field))


func get_progression_upgrade_cost(system_id: String, target_level: int) -> int:
	var level_data: Dictionary = get_progression_level_data(system_id, target_level)
	if level_data.is_empty():
		return -1
	return _read_non_negative_integer(level_data.get("upgrade_cost"))


func get_progression_max_level(system_id: String) -> int:
	if not progression_effect_fields.has(system_id):
		return 0
	var progression: Dictionary = get_dataset("progression")
	var system_value: Variant = progression.get(system_id, {})
	if typeof(system_value) != TYPE_DICTIONARY:
		return 0
	var levels_value: Variant = (system_value as Dictionary).get("levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		return 0
	var maximum: int = 0
	for level_value: Variant in levels_value as Dictionary:
		var level_string: String = String(level_value)
		if not level_string.is_valid_int():
			return 0
		var level: int = int(level_string)
		if level <= 0 or get_progression_effect(system_id, level) <= 0:
			return 0
		maximum = maxi(maximum, level)
	for level: int in range(1, maximum + 1):
		if not (levels_value as Dictionary).has(str(level)):
			return 0
	return maximum


func _get_progression_level_data(system_id: String, level: int) -> Dictionary:
	var progression: Dictionary = get_dataset("progression")
	var system_value: Variant = progression.get(system_id, {})
	if typeof(system_value) != TYPE_DICTIONARY:
		return {}
	var levels_value: Variant = (system_value as Dictionary).get("levels", {})
	if typeof(levels_value) != TYPE_DICTIONARY:
		return {}
	var level_value: Variant = (levels_value as Dictionary).get(str(level), {})
	if typeof(level_value) != TYPE_DICTIONARY:
		return {}
	return (level_value as Dictionary).duplicate(true)


func _get_item_price(item_id: String, field: String) -> int:
	var item_value: Variant = get_entry("items", item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return -1
	return _read_non_negative_integer((item_value as Dictionary).get(field))


func _normalize_restaurant_recipe(recipe_id: String, player_level: int) -> Dictionary:
	var recipe_value: Variant = get_entry("recipes", recipe_id)
	if typeof(recipe_value) != TYPE_DICTIONARY:
		return {}
	var recipe: Dictionary = recipe_value as Dictionary
	var unlock_level: int = get_restaurant_unlock_level()
	var recipe_level: int = unlock_level
	var required_level_value: Variant = recipe.get("required_level")
	if required_level_value != null:
		recipe_level = _read_positive_integer(required_level_value)
		if recipe_level <= 0:
			return {}
	var selling_price: int = _read_positive_integer(recipe.get("selling_price"))
	var cooking_time: float = _read_positive_number(recipe.get("cooking_time"))
	var ingredients_value: Variant = recipe.get("ingredients")
	if selling_price <= 0 or cooking_time <= 0.0 or typeof(ingredients_value) != TYPE_DICTIONARY:
		return {}
	var ingredients: Dictionary = ingredients_value as Dictionary
	if ingredients.is_empty():
		return {}

	var normalized_ingredients: Dictionary = {}
	for item_id_value: Variant in ingredients:
		if typeof(item_id_value) != TYPE_STRING:
			return {}
		var item_id: String = String(item_id_value)
		var amount: int = _read_positive_integer(ingredients[item_id_value])
		if item_id.is_empty() or amount <= 0 or get_entry("items", item_id) == null:
			return {}
		recipe_level = maxi(recipe_level, get_item_source_level(item_id))
		normalized_ingredients[item_id] = amount

	if player_level < recipe_level:
		return {}

	return {
		"recipe_id": recipe_id,
		"name": String(recipe.get("name", recipe_id)),
		"category": String(recipe.get("category", "")),
		"required_level": recipe_level,
		"ingredients": normalized_ingredients,
		"cooking_time_seconds": cooking_time,
		"selling_price": selling_price,
		"icon": String(recipe.get("icon", "")),
	}


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


func _read_positive_number(value: Variant) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0.0
	var number: float = float(value)
	return number if is_finite(number) and number > 0.0 else 0.0
