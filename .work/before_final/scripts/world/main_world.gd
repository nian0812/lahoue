extends Node2D

signal upgrade_purchased(system_id: String, level: int, cost: int, effect: int)
signal tutorial_crop_planted(tile_id: String, crop_id: String)
signal tutorial_crop_harvested(tile_id: String, crop_id: String, item_id: String, amount: int)
signal tutorial_animal_product_collected(instance_id: String, item_id: String, amount: int)
signal tutorial_aquaculture_product_collected(container_id: String, item_id: String, amount: int)
signal farm_plot_purchased(tile_id: String, cost: int)
signal building_purchased(building_id: String, cost: int)
signal pond_upgraded(container_id: String, level: int, cost: int)
signal resort_booking_completed(income: int, tourist_spawned: bool)

const farm_tile_script: Script = preload("res://scripts/farming/farm_tile.gd")
const animal_script: Script = preload("res://scripts/animals/animal.gd")
const animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")
const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")
const achievement_staff_roles: Array[String] = [
	"waiter",
	"chef",
	"farm_worker",
	"animal_worker",
	"aquaculture_worker",
]

var farm_tiles_by_id: Dictionary = {}
var animals_by_id: Dictionary = {}
var default_animal_templates: Dictionary = {}
var aquaculture_containers_by_id: Dictionary = {}
var default_aquaculture_templates: Dictionary = {}
var coop_level: int = 0
var pig_pen_level: int = 0
var cow_barn_level: int = 0
var aquaculture_level: int = 1
var resort_level: int = 0
var purchased_farm_plots: Array[String] = ["farm_01"]
var building_ownership: Dictionary = {
	"warehouse": true,
	"coop": false,
	"pig_pen": false,
	"cow_barn": false,
	"restaurant": false,
	"vip_area": false,
	"international_license": false,
	"helipad": false,
	"resort": false,
}
var pond_levels: Dictionary = {
	"aquaculture_fish": 0,
	"aquaculture_shrimp": 0,
	"aquaculture_crab": 0,
	"aquaculture_squid": 0,
	"aquaculture_octopus": 0,
}
var resort_booking_elapsed: float = 0.0
var resort_total_bookings: int = 0
var resort_tourist_traffic: int = 0

@onready var achievement_tracker: Node = $achievement_tracker


func _ready() -> void:
	_ensure_farm_plot_nodes()
	_cache_farm_tiles()
	_cache_animals()
	_cache_aquaculture_containers()
	_sync_legacy_staff_markers()
	_connect_achievement_signals()

	if not data_manager.is_ready:
		push_error("main_world: cannot start gameplay because required game data failed to load")
		return

	var state_loaded: bool = false
	if save_manager.is_new_game_requested():
		save_manager.create_new_game()
		save_manager.clear_new_game_request()
		state_loaded = true
	else:
		if save_manager.has_save():
			state_loaded = save_manager.load_game()

	if not state_loaded:
		save_manager.create_new_game()

	achievement_tracker.call("record_maximum", "player_level", game_manager.level)
	game_manager.start_gameplay()


func _process(delta: float) -> void:
	if not game_manager.gameplay_active or get_tree().paused or resort_level <= 0:
		return
	advance_resort(delta)


func get_zone(zone_id: String) -> Node2D:
	for zone_value: Variant in get_tree().get_nodes_in_group("world_zones"):
		var zone: Node2D = zone_value as Node2D
		if zone != null and is_ancestor_of(zone) and String(zone.get("zone_id")) == zone_id:
			return zone
	return null


func get_world_bounds() -> Rect2:
	var controller: Node = get_node_or_null("world_bounds_controller")
	if controller == null:
		return Rect2()
	return controller.get("current_bounds") as Rect2


func refresh_world_bounds() -> Rect2:
	var controller: Node = get_node_or_null("world_bounds_controller")
	if controller == null or not controller.has_method("refresh_bounds"):
		return Rect2()
	return controller.call("refresh_bounds") as Rect2


func get_expansion_anchor(zone_id: String, anchor_id: String) -> Marker2D:
	var zone: Node2D = get_zone(zone_id)
	if zone == null or not zone.has_method("get_expansion_anchor"):
		return null
	return zone.call("get_expansion_anchor", anchor_id) as Marker2D


func attach_zone_to_expansion_anchor(
	zone: Node2D,
	source_zone_id: String,
	source_anchor_id: String,
	target_anchor_id: String = "West"
) -> bool:
	if zone == null or zone.get_parent() != null:
		return false
	var source_anchor: Marker2D = get_expansion_anchor(source_zone_id, source_anchor_id)
	if source_anchor == null:
		return false
	var target_local_position: Vector2 = Vector2.ZERO
	var target_anchor: Marker2D = zone.get_node_or_null(
		"ExpansionAnchors/%s" % target_anchor_id
	) as Marker2D
	if target_anchor != null:
		target_local_position = target_anchor.position
	add_child(zone)
	zone.global_position = source_anchor.global_position - target_local_position
	refresh_world_bounds.call_deferred()
	return true


func get_staff_home_global_position(staff_type_id: String, role_index: int) -> Vector2:
	var zone_id: String = ""
	var marker_prefix: String = ""
	match staff_type_id:
		"waiter":
			zone_id = "restaurant"
			marker_prefix = "WaiterHome"
		"chef":
			zone_id = "restaurant"
			marker_prefix = "ChefHome"
		"farm_worker":
			zone_id = "farm"
			marker_prefix = "FarmWorkerHome"
		"animal_worker":
			zone_id = "animal"
			marker_prefix = "AnimalWorkerHome"
		"aquaculture_worker":
			zone_id = "aquaculture"
			marker_prefix = "AquacultureWorkerHome"
	var zone: Node2D = get_zone(zone_id)
	if zone != null and zone.has_method("get_npc_marker"):
		var marker: Marker2D = zone.call(
			"get_npc_marker",
			"%s%02d" % [marker_prefix, role_index + 1]
		) as Marker2D
		if marker != null:
			return marker.global_position
	var fallback: Node2D = get_node_or_null("farm_worker_home_marker") as Node2D
	return fallback.global_position if fallback != null else global_position


func _sync_legacy_staff_markers() -> void:
	var marker_roles: Dictionary = {
		"farm_worker_home_marker": "farm_worker",
		"animal_worker_home_marker": "animal_worker",
		"aquaculture_worker_home_marker": "aquaculture_worker",
	}
	for marker_name: String in marker_roles:
		var legacy_marker: Node2D = get_node_or_null(marker_name) as Node2D
		if legacy_marker != null:
			legacy_marker.global_position = get_staff_home_global_position(
				String(marker_roles[marker_name]),
				0
			)


func get_achievement_save_state() -> Array:
	return achievement_tracker.call("get_save_state") as Array


func apply_achievement_save_state(state: Array) -> void:
	achievement_tracker.call("apply_save_state", state)
	_record_achievement_staff_roles()


func get_tutorial_save_state() -> Dictionary:
	var controller: Node = get_node_or_null("tutorial_controller")
	if controller == null or not controller.has_method("get_save_state"):
		return {}
	return controller.call("get_save_state") as Dictionary


func apply_tutorial_save_state(state: Dictionary) -> void:
	var controller: Node = get_node_or_null("tutorial_controller")
	if controller != null and controller.has_method("apply_save_state"):
		controller.call("apply_save_state", state)


func get_farming_save_state() -> Dictionary:
	var crops: Dictionary = {}
	var crop_growth: Dictionary = {}

	for tile_id_value: Variant in farm_tiles_by_id:
		var tile_id: String = String(tile_id_value)
		var tile: Variant = farm_tiles_by_id[tile_id]
		if bool(tile.call("is_empty")):
			continue

		crops[tile_id] = String(tile.get("crop_id"))
		crop_growth[tile_id] = float(tile.get("growth_elapsed"))

	return {
		"crops": crops,
		"crop_growth": crop_growth
	}


func apply_farming_save_state(state: Dictionary) -> void:
	for tile_value: Variant in farm_tiles_by_id.values():
		tile_value.call("clear_tile")

	var crops_value: Variant = state.get("crops", {})
	var growth_value: Variant = state.get("crop_growth", {})
	if typeof(crops_value) != TYPE_DICTIONARY or typeof(growth_value) != TYPE_DICTIONARY:
		return

	var crops: Dictionary = crops_value as Dictionary
	var crop_growth: Dictionary = growth_value as Dictionary
	for tile_id_value: Variant in crops:
		var tile_id: String = String(tile_id_value)
		if not farm_tiles_by_id.has(tile_id) or not is_farm_plot_purchased(tile_id):
			continue

		var saved_crop_id: String = String(crops[tile_id_value])
		var saved_growth: float = float(crop_growth.get(tile_id, 0.0))
		var tile: Variant = farm_tiles_by_id[tile_id]
		if not bool(tile.call("apply_saved_crop", saved_crop_id, saved_growth)):
			push_error("main_world: failed to restore farming state for tile '%s'" % tile_id)


func has_farm_tile(tile_id: String) -> bool:
	return farm_tiles_by_id.has(tile_id)


func get_aquaculture_save_state() -> Dictionary:
	var aquaculture: Dictionary = {}
	for container_id_value: Variant in aquaculture_containers_by_id:
		var container_id: String = String(container_id_value)
		var container: Variant = aquaculture_containers_by_id[container_id]
		aquaculture[container_id] = container.call("get_save_state")
	return {"aquaculture": aquaculture}


func apply_aquaculture_save_state(state: Dictionary) -> void:
	for container_id_value: Variant in aquaculture_containers_by_id:
		var container_id: String = String(container_id_value)
		var container: Variant = aquaculture_containers_by_id[container_id]
		var template: Dictionary = default_aquaculture_templates.get(container_id, {}) as Dictionary
		container.set("aquaculture_id", String(template.get("aquaculture_id", "")))
		container.set("position", template.get("position", Vector2.ZERO))
		container.call("reset_container")

	var aquaculture_value: Variant = state.get("aquaculture", {})
	if typeof(aquaculture_value) != TYPE_DICTIONARY:
		return

	var aquaculture: Dictionary = aquaculture_value as Dictionary
	for container_id_value: Variant in aquaculture:
		var container_id: String = String(container_id_value)
		if not aquaculture_containers_by_id.has(container_id):
			continue
		var saved_state_value: Variant = aquaculture[container_id_value]
		if typeof(saved_state_value) != TYPE_DICTIONARY:
			continue
		aquaculture_containers_by_id[container_id].call("apply_save_state", saved_state_value as Dictionary)


func has_aquaculture_container(container_id: String) -> bool:
	return aquaculture_containers_by_id.has(container_id)


func get_progression_save_state() -> Dictionary:
	return {
		"coop_level": coop_level,
		"pig_pen_level": pig_pen_level,
		"cow_barn_level": cow_barn_level,
		"aquaculture_level": aquaculture_level,
		"resort_level": resort_level,
		"purchased_farm_plots": purchased_farm_plots.duplicate(),
		"building_ownership": building_ownership.duplicate(true),
		"pond_levels": pond_levels.duplicate(true),
		"resort_state": {
			"booking_elapsed": resort_booking_elapsed,
			"total_bookings": resort_total_bookings,
			"tourist_traffic": resort_tourist_traffic,
		},
	}


func apply_progression_save_state(state: Dictionary) -> void:
	coop_level = int(state.get("coop_level", 0))
	pig_pen_level = int(state.get("pig_pen_level", 0))
	cow_barn_level = int(state.get("cow_barn_level", 0))
	aquaculture_level = int(state.get("aquaculture_level", 1))
	resort_level = int(state.get("resort_level", 0))
	purchased_farm_plots.clear()
	for tile_id_value: Variant in state.get("purchased_farm_plots", ["farm_01"]) as Array:
		var tile_id: String = String(tile_id_value)
		if farm_tiles_by_id.has(tile_id) and not purchased_farm_plots.has(tile_id):
			purchased_farm_plots.append(tile_id)
	if purchased_farm_plots.is_empty():
		purchased_farm_plots.append("farm_01")
	var saved_ownership: Dictionary = state.get("building_ownership", {}) as Dictionary
	for building_id: String in building_ownership:
		building_ownership[building_id] = bool(saved_ownership.get(building_id, building_id == "warehouse"))
	building_ownership["warehouse"] = true
	var saved_pond_levels: Dictionary = state.get("pond_levels", {}) as Dictionary
	for container_id: String in pond_levels:
		pond_levels[container_id] = int(saved_pond_levels.get(container_id, 0))
	var saved_resort: Dictionary = state.get("resort_state", {}) as Dictionary
	resort_booking_elapsed = float(saved_resort.get("booking_elapsed", 0.0))
	resort_total_bookings = int(saved_resort.get("total_bookings", 0))
	resort_tourist_traffic = int(saved_resort.get("tourist_traffic", 0))
	_refresh_economy_world_state()


func get_upgrade_level(system_id: String) -> int:
	match system_id:
		"warehouse":
			return inventory_manager.warehouse_level
		"coop":
			return coop_level
		"pig_pen":
			return pig_pen_level
		"cow_barn":
			return cow_barn_level
		"aquaculture":
			return aquaculture_level
		"restaurant", "kitchen":
			return int($restaurant.call("get_upgrade_level", system_id))
		"resort":
			return resort_level
	return 0


func get_upgrade_effect(system_id: String) -> int:
	return data_manager.get_progression_effect(system_id, get_upgrade_level(system_id))


func can_upgrade_system(system_id: String) -> bool:
	var current_level: int = get_upgrade_level(system_id)
	var target_level: int = current_level + 1
	var required_player_level: int = data_manager.get_system_required_player_level(system_id, target_level)
	if required_player_level <= 0 or game_manager.level < required_player_level:
		return false
	match system_id:
		"warehouse":
			return inventory_manager.can_upgrade_warehouse()
		"restaurant":
			if current_level == 0:
				return _can_purchase_levelled_system("restaurant", target_level)
			return bool($restaurant.call("can_upgrade_system", system_id))
		"kitchen":
			return false
		"coop", "pig_pen", "cow_barn", "resort":
			var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
			return (
				data_manager.get_progression_effect(system_id, target_level) > 0
				and cost > 0
				and game_manager.can_afford(cost)
			)
	return false


func upgrade_system(system_id: String) -> bool:
	if not can_upgrade_system(system_id):
		return false
	if system_id == "warehouse":
		return inventory_manager.upgrade_warehouse()
	if system_id == "restaurant" and get_upgrade_level("restaurant") == 0:
		return _purchase_levelled_system("restaurant")
	if system_id == "restaurant":
		return bool($restaurant.call("upgrade_system", system_id))
	if system_id == "kitchen":
		return false
	var target_level: int = get_upgrade_level(system_id) + 1
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	if not game_manager.spend_money(cost):
		return false
	match system_id:
		"coop":
			coop_level = target_level
			building_ownership["coop"] = true
		"pig_pen":
			pig_pen_level = target_level
			building_ownership["pig_pen"] = true
		"cow_barn":
			cow_barn_level = target_level
			building_ownership["cow_barn"] = true
		"aquaculture":
			aquaculture_level = target_level
		"resort":
			resort_level = target_level
			building_ownership["resort"] = true
		_:
			game_manager.add_money(cost)
			return false
	upgrade_purchased.emit(system_id, target_level, cost, get_upgrade_effect(system_id))
	_refresh_economy_world_state()
	return true


func is_building_owned(building_id: String) -> bool:
	return bool(building_ownership.get(building_id, false))


func can_purchase_building(building_id: String) -> bool:
	if is_building_owned(building_id):
		return false
	var unlock_level: int = data_manager.get_building_unlock_level(building_id)
	var cost: int = data_manager.get_building_purchase_cost(building_id)
	return unlock_level > 0 and game_manager.level >= unlock_level and cost > 0 and game_manager.can_afford(cost)


func purchase_building(building_id: String) -> bool:
	if not can_purchase_building(building_id):
		return false
	var cost: int = data_manager.get_building_purchase_cost(building_id)
	if not game_manager.spend_money(cost):
		return false
	building_ownership[building_id] = true
	building_purchased.emit(building_id, cost)
	_refresh_economy_world_state()
	return true


func _can_purchase_levelled_system(system_id: String, target_level: int = 1) -> bool:
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	return get_upgrade_level(system_id) == 0 and cost > 0 and game_manager.can_afford(cost)


func _purchase_levelled_system(system_id: String) -> bool:
	if not _can_purchase_levelled_system(system_id):
		return false
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, 1)
	if not game_manager.spend_money(cost):
		return false
	building_ownership[system_id] = true
	if system_id == "restaurant":
		$restaurant.set("restaurant_level", 1)
		$restaurant.set("kitchen_level", 1)
		$restaurant.call("refresh_availability")
	upgrade_purchased.emit(system_id, 1, cost, get_upgrade_effect(system_id))
	building_purchased.emit(system_id, cost)
	_refresh_economy_world_state()
	return true


func get_next_farm_plot_id() -> String:
	for plot_number: int in range(1, data_manager.get_farm_plot_maximum() + 1):
		var tile_id: String = "farm_%02d" % plot_number
		if not purchased_farm_plots.has(tile_id):
			return tile_id
	return ""


func get_current_farm_plot_limit() -> int:
	return data_manager.get_farm_plot_limit(game_manager.level)


func get_next_farm_plot_expansion_level() -> int:
	return data_manager.get_next_farm_plot_limit_level(game_manager.level, purchased_farm_plots.size())


func can_purchase_farm_plot() -> bool:
	return (
		purchased_farm_plots.size() < get_current_farm_plot_limit()
		and not get_next_farm_plot_id().is_empty()
		and game_manager.can_afford(data_manager.get_farm_plot_purchase_cost())
	)


func purchase_next_farm_plot() -> bool:
	var tile_id: String = get_next_farm_plot_id()
	var cost: int = data_manager.get_farm_plot_purchase_cost()
	if purchased_farm_plots.size() >= get_current_farm_plot_limit() or tile_id.is_empty() or cost <= 0:
		return false
	if not game_manager.spend_money(cost):
		return false
	purchased_farm_plots.append(tile_id)
	_refresh_farm_plot_visibility()
	farm_plot_purchased.emit(tile_id, cost)
	return true


func is_farm_plot_purchased(tile_id: String) -> bool:
	return purchased_farm_plots.has(tile_id)


func get_pond_level(container_id: String) -> int:
	return int(pond_levels.get(container_id, 0))


func can_upgrade_pond(container_id: String) -> bool:
	var container: Node = aquaculture_containers_by_id.get(container_id) as Node
	if container == null:
		return false
	var aquaculture_id: String = String(container.get("aquaculture_id"))
	var current_level: int = get_pond_level(container_id)
	if current_level == 0:
		return game_manager.level >= data_manager.get_pond_unlock_level(aquaculture_id) and game_manager.can_afford(data_manager.get_pond_purchase_cost(aquaculture_id))
	var cost: int = data_manager.get_pond_upgrade_cost(aquaculture_id, current_level + 1)
	return current_level < data_manager.get_pond_max_level(aquaculture_id) and cost > 0 and game_manager.can_afford(cost)


func upgrade_pond(container_id: String) -> bool:
	if not can_upgrade_pond(container_id):
		return false
	var container: Node = aquaculture_containers_by_id.get(container_id) as Node
	var aquaculture_id: String = String(container.get("aquaculture_id"))
	var current_level: int = get_pond_level(container_id)
	var target_level: int = current_level + 1
	var cost: int = data_manager.get_pond_purchase_cost(aquaculture_id) if current_level == 0 else data_manager.get_pond_upgrade_cost(aquaculture_id, target_level)
	if not game_manager.spend_money(cost):
		return false
	pond_levels[container_id] = target_level
	container.call("set_pond_level", target_level)
	pond_upgraded.emit(container_id, target_level, cost)
	return true


func get_recipe_payout_multiplier(recipe_id: String) -> float:
	var recipe_value: Variant = data_manager.get_entry("recipes", recipe_id)
	if typeof(recipe_value) != TYPE_DICTIONARY or String((recipe_value as Dictionary).get("category", "")) != "premium":
		return 1.0
	return data_manager.get_vip_payout_multiplier() if is_building_owned("vip_area") else 1.0


func advance_resort(delta: float) -> bool:
	if resort_level <= 0 or not is_finite(delta) or delta <= 0.0:
		return false
	var level_data: Dictionary = data_manager.get_progression_level_data("resort", resort_level)
	var interval: float = float(level_data.get("booking_interval", 0.0))
	var income: int = int(level_data.get("booking_income", 0))
	if interval <= 0.0 or income <= 0:
		return false
	resort_booking_elapsed += delta
	var advanced: bool = false
	while resort_booking_elapsed >= interval:
		resort_booking_elapsed -= interval
		if not game_manager.add_money(income):
			break
		game_manager.grant_sales_exp(income)
		resort_total_bookings += 1
		var tourist_spawned: bool = _spawn_resort_tourist()
		if tourist_spawned:
			resort_tourist_traffic += 1
		if achievement_tracker != null:
			achievement_tracker.call("record_increment", "money_earned", income)
		resort_booking_completed.emit(income, tourist_spawned)
		advanced = true
	return advanced


func _spawn_resort_tourist() -> bool:
	if not bool($restaurant.call("is_available")):
		return false
	var menu: Dictionary = $restaurant.call("get_menu_entries") as Dictionary
	var preferred_recipe: String = ""
	if resort_level >= 3:
		for recipe_id_value: Variant in menu:
			var recipe_id: String = String(recipe_id_value)
			if String((menu[recipe_id_value] as Dictionary).get("category", "")) == "premium":
				preferred_recipe = recipe_id
				break
	return $restaurant.call("spawn_customer", "", preferred_recipe) != null


func is_valid_aquaculture_assignment(container_id: String, aquaculture_id: String) -> bool:
	if not default_aquaculture_templates.has(container_id):
		return false
	var template: Dictionary = default_aquaculture_templates[container_id] as Dictionary
	return String(template.get("aquaculture_id", "")) == aquaculture_id


func get_restaurant_save_state() -> Dictionary:
	return $restaurant.call("get_save_state") as Dictionary


func apply_restaurant_save_state(state: Dictionary) -> void:
	$restaurant.call("apply_save_state", state)


func has_restaurant_table(table_id: String) -> bool:
	return bool($restaurant.call("has_table", table_id))


func has_restaurant_customer(customer_id: String) -> bool:
	return bool($restaurant.call("has_customer", customer_id))


func get_animal_save_state() -> Dictionary:
	var animals: Dictionary = {}
	var animal_age: Dictionary = {}

	for instance_id_value: Variant in animals_by_id:
		var instance_id: String = String(instance_id_value)
		var animal: Variant = animals_by_id[instance_id]
		animals[instance_id] = animal.call("get_save_state")
		animal_age[instance_id] = int(animal.get("age_days"))

	return {
		"animals": animals,
		"animal_age": animal_age
	}


func apply_animal_save_state(state: Dictionary) -> void:
	var animals_value: Variant = state.get("animals", {})
	var age_value: Variant = state.get("animal_age", {})
	if typeof(animals_value) != TYPE_DICTIONARY or typeof(age_value) != TYPE_DICTIONARY:
		return

	var saved_animals: Dictionary = animals_value as Dictionary
	var saved_age: Dictionary = age_value as Dictionary
	if saved_animals.is_empty() and saved_age.is_empty():
		if bool(state.get("animals_initialized", false)):
			for instance_id_value: Variant in animals_by_id.keys():
				_remove_animal(String(instance_id_value))
		else:
			_restore_default_animals()
		return

	for instance_id_value: Variant in animals_by_id.keys():
		var current_instance_id: String = String(instance_id_value)
		if not saved_animals.has(current_instance_id):
			_remove_animal(current_instance_id)

	for instance_id_value: Variant in saved_animals:
		var instance_id: String = String(instance_id_value)
		var saved_state_value: Variant = saved_animals[instance_id_value]
		if typeof(saved_state_value) != TYPE_DICTIONARY:
			continue

		var saved_state: Dictionary = saved_state_value as Dictionary
		var saved_animal_id: String = String(saved_state.get("animal_id", ""))
		var animal: Node = animals_by_id.get(instance_id) as Node
		if animal != null and String(animal.get("animal_id")) != saved_animal_id:
			_remove_animal(instance_id)
			animal = null

		if animal == null:
			animal = _create_animal(instance_id, saved_animal_id, Vector2.ZERO, false)
		if animal == null:
			push_error("main_world: failed to create saved animal '%s'" % instance_id)
			continue

		if not bool(animal.call("apply_save_state", saved_state, int(saved_age.get(instance_id, 0)))):
			push_error("main_world: failed to restore animal state for '%s'" % instance_id)
		elif String(animal.get("current_state")) == animal_script.state_completed:
			call_deferred("_remove_completed_animal", instance_id)


func has_animal(instance_id: String) -> bool:
	return animals_by_id.has(instance_id)


func purchase_animal(instance_id: String, new_animal_id: String, spawn_position: Vector2) -> Node:
	if not can_purchase_animal(instance_id, new_animal_id):
		return null

	var animal_data: Dictionary = data_manager.get_entry("animals", new_animal_id) as Dictionary
	var purchase_price: int = int(animal_data.get("purchase_price", 0))
	if not game_manager.spend_money(purchase_price):
		return null

	var housing_id: String = String(animal_data.get("housing", ""))
	var building: Node = $animals.get_node_or_null(housing_id)
	var target_pos: Vector2 = spawn_position
	
	if building != null:
		var spawn_anchor: Node2D = building.get_node_or_null("SpawnAnchor") as Node2D
		var housing_origin: Vector2 = (
			spawn_anchor.global_position
			if spawn_anchor != null
			else (building as Node2D).global_position
		)
		# Gather used global positions for this housing type
		var used_positions: Array[Vector2] = []
		for animal_value: Variant in animals_by_id.values():
			if String(animal_value.get("current_state")) == animal_script.state_completed:
				continue
			var a_id: String = String(animal_value.get("animal_id"))
			var a_data: Variant = data_manager.get_entry("animals", a_id)
			if typeof(a_data) == TYPE_DICTIONARY and String((a_data as Dictionary).get("housing", "")) == housing_id:
				if animal_value is Node2D:
					used_positions.append(animal_value.global_position)
		
		# Find an unused grid slot
		var cap: int = 50
		var cols: int = 10
		var spacing: float = 16.0
		if housing_id == "cow_barn":
			cap = 20
			cols = 5
			spacing = 24.0
		for i in range(cap):
			var col: int = i % cols
			var row: int = int(i / cols)
			var offset_x: float = (col - cols/2.0) * spacing
			var offset_y: float = (row - float(cap/cols)/2.0) * spacing
			var slot_global: Vector2 = housing_origin + Vector2(offset_x, offset_y)
			var is_used: bool = false
			for pos in used_positions:
				if pos.distance_to(slot_global) < 5.0:
					is_used = true
					break
			if not is_used:
				target_pos = $animals.to_local(slot_global)
				break
	
	var animal: Node = _create_animal(instance_id, new_animal_id, target_pos, true)
	if animal == null:
		game_manager.add_money(purchase_price)
	return animal


func can_purchase_animal(instance_id: String, new_animal_id: String) -> bool:
	if not _is_valid_animal_instance_id(instance_id) or animals_by_id.has(instance_id):
		return false

	var animal_data_value: Variant = data_manager.get_entry("animals", new_animal_id)
	if typeof(animal_data_value) != TYPE_DICTIONARY:
		return false

	var animal_data: Dictionary = animal_data_value as Dictionary
	var required_level: int = data_manager.get_animal_required_level(new_animal_id)
	if required_level <= 0 or required_level > game_manager.level:
		return false

	var purchase_price: int = int(animal_data.get("purchase_price", -1))
	if purchase_price < 0 or game_manager.money < purchase_price:
		return false

	var housing_id: String = String(animal_data.get("housing", ""))
	var housing_capacity: int = data_manager.get_animal_housing_capacity(housing_id, get_upgrade_level(housing_id))
	if housing_id.is_empty() or housing_capacity <= 0:
		return false

	return _get_animal_housing_count(housing_id) < housing_capacity


func _create_animal(
	instance_id: String,
	new_animal_id: String,
	spawn_position: Vector2,
	enforce_unlock: bool = true
) -> Node:
	if not _is_valid_animal_instance_id(instance_id) or animals_by_id.has(instance_id):
		return null

	var animal_data_value: Variant = data_manager.get_entry("animals", new_animal_id)
	if typeof(animal_data_value) != TYPE_DICTIONARY:
		return null

	var animal_data: Dictionary = animal_data_value as Dictionary
	if enforce_unlock:
		var required_level: int = data_manager.get_animal_required_level(new_animal_id)
		if required_level <= 0 or required_level > game_manager.level:
			return null

	var animal: Node = animal_scene.instantiate()
	animal.name = instance_id
	animal.set("animal_instance_id", instance_id)
	animal.set("animal_id", new_animal_id)
	animal.set("position", spawn_position)
	$animals.add_child(animal)

	if not bool(animal.get("is_configured")):
		animal.free()
		return null

	animals_by_id[instance_id] = animal
	_connect_animal_signals(animal)
	return animal


func _ensure_farm_plot_nodes() -> void:
	var maximum: int = data_manager.get_farm_plot_maximum()
	if maximum <= 0:
		maximum = 40
	for plot_number: int in range(1, maximum + 1):
		var tile_name: String = "tile_%02d" % plot_number
		var tile: Node2D = $farm.get_node_or_null(tile_name) as Node2D
		if tile == null:
			push_error(
				"main_world: Farm Zone is missing fixed plot node '%s'" % tile_name
			)


func _refresh_farm_plot_visibility() -> void:
	for tile_id_value: Variant in farm_tiles_by_id:
		var tile_id: String = String(tile_id_value)
		var tile: Node = farm_tiles_by_id[tile_id] as Node
		var purchased: bool = purchased_farm_plots.has(tile_id)
		if tile.has_method("set_purchased"):
			tile.call("set_purchased", purchased)
		else:
			tile.visible = purchased


func _refresh_economy_world_state() -> void:
	_refresh_farm_plot_visibility()
	for container_id: String in pond_levels:
		var container: Node = aquaculture_containers_by_id.get(container_id) as Node
		if container != null and container.has_method("set_pond_level"):
			container.call("set_pond_level", int(pond_levels[container_id]))
	var housing_levels: Dictionary = {
		"coop": coop_level,
		"pig_pen": pig_pen_level,
		"cow_barn": cow_barn_level,
	}
	for housing_id: String in housing_levels:
		var housing: CanvasItem = $animals.get_node_or_null(housing_id) as CanvasItem
		if housing != null:
			housing.visible = int(housing_levels[housing_id]) > 0
	if has_node("restaurant"):
		$restaurant.call("refresh_availability")
	var premium_market: Node = get_node_or_null("hub/premium_market")
	if premium_market != null and premium_market.has_method("_refresh_visual"):
		premium_market.call("_refresh_visual")


func _cache_farm_tiles() -> void:
	farm_tiles_by_id.clear()
	for child: Node in $farm.get_children():
		if child.get_script() != farm_tile_script:
			continue

		var tile_id: String = String(child.get("tile_id"))
		if tile_id.is_empty():
			push_error("main_world: farm tile '%s' has no tile_id" % child.name)
			continue
		if farm_tiles_by_id.has(tile_id):
			push_error("main_world: duplicate farm tile id '%s'" % tile_id)
			continue

		farm_tiles_by_id[tile_id] = child
		_connect_signal_once(child, "crop_harvested", _on_crop_harvested)

		# Add VFX hooks
		if not child.is_connected("crop_planted", _on_crop_planted_vfx):
			child.connect("crop_planted", _on_crop_planted_vfx.bind(child))
		if not child.is_connected("crop_harvested", _on_crop_harvested_vfx):
			child.connect("crop_harvested", _on_crop_harvested_vfx.bind(child))
	_refresh_farm_plot_visibility()

func _on_crop_planted_vfx(tile_id: String, crop_id: String, tile: Node) -> void:
	tutorial_crop_planted.emit(tile_id, crop_id)
	if tile is Node2D:
		_spawn_vfx(tile.global_position)

func _on_crop_harvested_vfx(_t_id: String, _c_id: String, _i_id: String, _amt: int, tile: Node) -> void:
	if tile is Node2D:
		_spawn_vfx(tile.global_position)

var vfx_scene: PackedScene = preload("res://scenes/world/vfx_particles.tscn")
func _spawn_vfx(pos: Vector2) -> void:
	var vfx: CPUParticles2D = vfx_scene.instantiate() as CPUParticles2D
	vfx.global_position = pos
	add_child(vfx)

func _cache_animals() -> void:
	animals_by_id.clear()
	default_animal_templates.clear()
	for child: Node in $animals.get_children():
		if child.get_script() != animal_script:
			continue

		var instance_id: String = String(child.get("animal_instance_id"))
		var child_animal_id: String = String(child.get("animal_id"))
		if not _is_valid_animal_instance_id(instance_id):
			push_error("main_world: animal '%s' has an invalid instance id" % child.name)
			continue
		if animals_by_id.has(instance_id):
			push_error("main_world: duplicate animal instance id '%s'" % instance_id)
			continue

		animals_by_id[instance_id] = child
		_connect_animal_signals(child)
		default_animal_templates[instance_id] = {
			"animal_id": child_animal_id,
			"position": (child as Node2D).position,
			"animal_color": child.get("animal_color")
		}


func _cache_aquaculture_containers() -> void:
	aquaculture_containers_by_id.clear()
	default_aquaculture_templates.clear()
	for child: Node in $aquaculture.get_children():
		if child.get_script() != aquaculture_container_script:
			continue

		var container_id: String = String(child.get("container_id"))
		if not _is_valid_aquaculture_container_id(container_id):
			push_error("main_world: aquaculture container '%s' has an invalid id" % child.name)
			continue
		if aquaculture_containers_by_id.has(container_id):
			push_error("main_world: duplicate aquaculture container id '%s'" % container_id)
			continue

		aquaculture_containers_by_id[container_id] = child
		_connect_signal_once(child, "product_received", _on_aquaculture_product_received)
		default_aquaculture_templates[container_id] = {
			"aquaculture_id": String(child.get("aquaculture_id")),
			"position": (child as Node2D).position,
		}


func _restore_default_animals() -> void:
	for instance_id_value: Variant in animals_by_id.keys():
		var instance_id: String = String(instance_id_value)
		if not default_animal_templates.has(instance_id):
			_remove_animal(instance_id)

	for instance_id_value: Variant in default_animal_templates:
		var instance_id: String = String(instance_id_value)
		var template: Dictionary = default_animal_templates[instance_id] as Dictionary
		var template_animal_id: String = String(template.get("animal_id", ""))
		var animal_data_value: Variant = data_manager.get_entry("animals", template_animal_id)
		var required_level: int = 1
		if typeof(animal_data_value) == TYPE_DICTIONARY:
			required_level = maxi(int((animal_data_value as Dictionary).get("required_level", 1)), 1)
		if game_manager.level < required_level:
			_remove_animal(instance_id)
			continue
		var animal: Node = animals_by_id.get(instance_id) as Node
		if animal != null and String(animal.get("animal_id")) != template_animal_id:
			_remove_animal(instance_id)
			animal = null

		if animal == null:
			animal = _create_animal(
				instance_id,
				template_animal_id,
				template.get("position", Vector2.ZERO) as Vector2,
				false
			)
		if animal == null:
			push_error("main_world: failed to restore default animal '%s'" % instance_id)
			continue

		animal.set("position", template.get("position", Vector2.ZERO))
		animal.set("animal_color", template.get("animal_color", Color.WHITE))
		animal.call("reset_state", maxi(game_manager.day - 1, 0))


func _remove_animal(instance_id: String) -> void:
	var animal: Node = animals_by_id.get(instance_id) as Node
	animals_by_id.erase(instance_id)
	if animal != null and is_instance_valid(animal):
		animal.free()


func _get_animal_housing_count(housing_id: String) -> int:
	var count: int = 0
	for animal_value: Variant in animals_by_id.values():
		if String(animal_value.get("current_state")) == animal_script.state_completed:
			continue
		var owned_animal_id: String = String(animal_value.get("animal_id"))
		var animal_data_value: Variant = data_manager.get_entry("animals", owned_animal_id)
		if typeof(animal_data_value) != TYPE_DICTIONARY:
			continue
		if String((animal_data_value as Dictionary).get("housing", "")) == housing_id:
			count += 1
	return count


func _get_owned_animal_count(target_animal_id: String) -> int:
	var count: int = 0
	for animal_value: Variant in animals_by_id.values():
		if String(animal_value.get("current_state")) == animal_script.state_completed:
			continue
		var owned_animal_id: String = String(animal_value.get("animal_id"))
		if owned_animal_id == target_animal_id:
			count += 1
	return count


func _connect_animal_signals(animal: Node) -> void:
	_connect_signal_once(animal, "animal_completed", _on_animal_completed)
	_connect_signal_once(animal, "product_collected", _on_animal_product_collected)


func _connect_achievement_signals() -> void:
	_connect_signal_once(game_manager, "level_changed", _on_achievement_level_changed)
	_connect_signal_once(inventory_manager, "item_sold", _on_achievement_item_sold)
	_connect_signal_once(inventory_manager, "warehouse_upgraded", _on_achievement_upgrade_purchased)
	_connect_signal_once($restaurant, "food_ready", _on_achievement_food_ready)
	_connect_signal_once($restaurant, "order_served", _on_achievement_order_served)
	_connect_signal_once($restaurant, "payment_collected", _on_achievement_payment_collected)
	_connect_signal_once($restaurant, "revenue_collected", _on_achievement_revenue_collected)
	_connect_signal_once($restaurant, "staff_hired", _on_achievement_staff_hired)
	_connect_signal_once($restaurant, "upgrade_purchased", _on_achievement_restaurant_upgrade)
	_connect_signal_once($truck_manager, "delivery_completed", _on_achievement_truck_delivery_completed)
	_connect_signal_once($hub/premium_market, "shipment_arrived", _on_achievement_import_arrived)
	_connect_signal_once(self, "upgrade_purchased", _on_achievement_world_upgrade)


func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _on_crop_harvested(tile_id: String, crop_id: String, item_id: String, amount: int) -> void:
	tutorial_crop_harvested.emit(tile_id, crop_id, item_id, amount)
	achievement_tracker.call("record_increment", "crops_harvested", 1)


func _on_animal_product_collected(instance_id: String, item_id: String, amount: int) -> void:
	tutorial_animal_product_collected.emit(instance_id, item_id, amount)
	achievement_tracker.call("record_increment", "animal_products_collected", amount)


func _on_aquaculture_product_received(container_id: String, item_id: String, amount: int) -> void:
	tutorial_aquaculture_product_collected.emit(container_id, item_id, amount)
	achievement_tracker.call("record_increment", "aquaculture_products_collected", amount)


func _on_achievement_food_ready(_customer_id: String, _recipe_id: String) -> void:
	achievement_tracker.call("record_increment", "cooking_orders_completed", 1)


func _on_achievement_order_served(_customer_id: String, _recipe_id: String) -> void:
	achievement_tracker.call("record_increment", "customer_orders_served", 1)


func _on_achievement_payment_collected(_customer_id: String, _recipe_id: String, revenue: int) -> void:
	achievement_tracker.call("record_increment", "restaurant_orders_paid", 1)
	if has_node("ui") and has_node("player"):
		$ui.call("spawn_floating_text", "Payment collected\n+%d VNĐ" % revenue, $player.global_position, Color.YELLOW)


func _on_achievement_revenue_collected(_recipe_id: String, _amount: int, revenue: int) -> void:
	achievement_tracker.call("record_increment", "money_earned", revenue)


func _on_achievement_item_sold(_item_id: String, amount: int, total_price: int) -> void:
	achievement_tracker.call("record_increment", "items_sold", amount)
	achievement_tracker.call("record_increment", "money_earned", total_price)


func _on_achievement_truck_delivery_completed(_truck_index: int, _item_id: String, _amount: int, payout: int) -> void:
	achievement_tracker.call("record_increment", "truck_shipments_completed", 1)
	if payout > 0:
		achievement_tracker.call("record_increment", "money_earned", payout)


func _on_achievement_staff_hired(_staff_id: String, _staff_type_id: String, _cost: int) -> void:
	_record_achievement_staff_roles()


func _record_achievement_staff_roles() -> void:
	var owned_roles: int = 0
	for staff_type_id: String in achievement_staff_roles:
		if int($restaurant.call("get_staff_type_count", staff_type_id)) > 0:
			owned_roles += 1
	achievement_tracker.call("record_maximum", "staff_roles_owned", owned_roles)


func _on_achievement_import_arrived(_cargo: Dictionary) -> void:
	achievement_tracker.call("record_increment", "import_shipments_completed", 1)


func _on_achievement_level_changed(new_level: int) -> void:
	achievement_tracker.call("record_maximum", "player_level", new_level)


func _on_achievement_upgrade_purchased(_level: int, _capacity: int) -> void:
	achievement_tracker.call("record_increment", "upgrades_purchased", 1)


func _on_achievement_restaurant_upgrade(_system_id: String, _level: int, _cost: int, _effect: int) -> void:
	achievement_tracker.call("record_increment", "upgrades_purchased", 1)


func _on_achievement_world_upgrade(_system_id: String, _level: int, _cost: int, _effect: int) -> void:
	achievement_tracker.call("record_increment", "upgrades_purchased", 1)


func _on_animal_completed(instance_id: String, _animal_id: String) -> void:
	call_deferred("_remove_completed_animal", instance_id)


func _remove_completed_animal(instance_id: String) -> void:
	var animal: Node = animals_by_id.get(instance_id) as Node
	if animal != null and String(animal.get("current_state")) == animal_script.state_completed:
		_remove_animal(instance_id)


func _is_valid_animal_instance_id(instance_id: String) -> bool:
	return (
		not instance_id.is_empty()
		and instance_id == instance_id.to_lower()
		and instance_id.is_valid_identifier()
	)


func _is_valid_aquaculture_container_id(container_id: String) -> bool:
	return (
		not container_id.is_empty()
		and container_id == container_id.to_lower()
		and container_id.is_valid_identifier()
	)


func _exit_tree() -> void:
	if game_manager.gameplay_active:
		save_manager.save_game()
		game_manager.stop_gameplay()
