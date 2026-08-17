extends Node2D

signal upgrade_purchased(system_id: String, level: int, cost: int, effect: int)

const farm_tile_script: Script = preload("res://scripts/farming/farm_tile.gd")
const animal_script: Script = preload("res://scripts/animals/animal.gd")
const animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")
const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")

var farm_tiles_by_id: Dictionary = {}
var animals_by_id: Dictionary = {}
var default_animal_templates: Dictionary = {}
var aquaculture_containers_by_id: Dictionary = {}
var default_aquaculture_templates: Dictionary = {}
var coop_level: int = 1
var cow_barn_level: int = 1
var aquaculture_level: int = 1

@onready var achievement_tracker: Node = $achievement_tracker


func _ready() -> void:
	_cache_farm_tiles()
	_cache_animals()
	_cache_aquaculture_containers()
	_connect_achievement_signals()

	if not data_manager.is_ready:
		push_error("main_world: cannot start gameplay because required game data failed to load")
		return

	var state_loaded: bool = false
	if save_manager.has_save():
		state_loaded = save_manager.load_game()

	if not state_loaded:
		save_manager.create_new_game()

	achievement_tracker.call("record_maximum", "player_level", game_manager.level)
	game_manager.start_gameplay()


func get_achievement_save_state() -> Array:
	return achievement_tracker.call("get_save_state") as Array


func apply_achievement_save_state(state: Array) -> void:
	achievement_tracker.call("apply_save_state", state)


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
		if not farm_tiles_by_id.has(tile_id):
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
		"cow_barn_level": cow_barn_level,
		"aquaculture_level": aquaculture_level,
	}


func apply_progression_save_state(state: Dictionary) -> void:
	coop_level = int(state.get("coop_level", 1))
	cow_barn_level = int(state.get("cow_barn_level", 1))
	aquaculture_level = int(state.get("aquaculture_level", 1))


func get_upgrade_level(system_id: String) -> int:
	match system_id:
		"warehouse":
			return inventory_manager.warehouse_level
		"coop":
			return coop_level
		"cow_barn":
			return cow_barn_level
		"aquaculture":
			return aquaculture_level
		"restaurant", "kitchen":
			return int($restaurant.call("get_upgrade_level", system_id))
	return 0


func get_upgrade_effect(system_id: String) -> int:
	return data_manager.get_progression_effect(system_id, get_upgrade_level(system_id))


func can_upgrade_system(system_id: String) -> bool:
	match system_id:
		"warehouse":
			return inventory_manager.can_upgrade_warehouse()
		"restaurant", "kitchen":
			return bool($restaurant.call("can_upgrade_system", system_id))
		"coop", "cow_barn", "aquaculture":
			var target_level: int = get_upgrade_level(system_id) + 1
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
	if system_id == "restaurant" or system_id == "kitchen":
		return bool($restaurant.call("upgrade_system", system_id))
	var target_level: int = get_upgrade_level(system_id) + 1
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	if not game_manager.spend_money(cost):
		return false
	match system_id:
		"coop":
			coop_level = target_level
		"cow_barn":
			cow_barn_level = target_level
		"aquaculture":
			aquaculture_level = target_level
		_:
			game_manager.add_money(cost)
			return false
	upgrade_purchased.emit(system_id, target_level, cost, get_upgrade_effect(system_id))
	return true


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

	var animal: Node = _create_animal(instance_id, new_animal_id, spawn_position, true)
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

func _on_crop_planted_vfx(_t_id: String, _c_id: String, tile: Node) -> void:
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


func _connect_animal_signals(animal: Node) -> void:
	_connect_signal_once(animal, "animal_completed", _on_animal_completed)
	_connect_signal_once(animal, "product_collected", _on_animal_product_collected)


func _connect_achievement_signals() -> void:
	_connect_signal_once(game_manager, "level_changed", _on_achievement_level_changed)
	_connect_signal_once(inventory_manager, "item_sold", _on_achievement_item_sold)
	_connect_signal_once(inventory_manager, "warehouse_upgraded", _on_achievement_upgrade_purchased)
	_connect_signal_once($restaurant, "food_ready", _on_achievement_food_ready)
	_connect_signal_once($restaurant, "payment_collected", _on_achievement_payment_collected)
	_connect_signal_once($restaurant, "revenue_collected", _on_achievement_revenue_collected)
	_connect_signal_once($restaurant, "upgrade_purchased", _on_achievement_restaurant_upgrade)
	_connect_signal_once(self, "upgrade_purchased", _on_achievement_world_upgrade)


func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _on_crop_harvested(_tile_id: String, _crop_id: String, _item_id: String, _amount: int) -> void:
	achievement_tracker.call("record_increment", "crops_harvested", 1)


func _on_animal_product_collected(_instance_id: String, _item_id: String, amount: int) -> void:
	achievement_tracker.call("record_increment", "animal_products_collected", amount)


func _on_aquaculture_product_received(_container_id: String, _item_id: String, amount: int) -> void:
	achievement_tracker.call("record_increment", "aquaculture_products_collected", amount)


func _on_achievement_food_ready(_customer_id: String, _recipe_id: String) -> void:
	achievement_tracker.call("record_increment", "cooking_orders_completed", 1)


func _on_achievement_payment_collected(_customer_id: String, _recipe_id: String, _revenue: int) -> void:
	achievement_tracker.call("record_increment", "restaurant_orders_paid", 1)


func _on_achievement_revenue_collected(_recipe_id: String, _amount: int, revenue: int) -> void:
	achievement_tracker.call("record_increment", "money_earned", revenue)


func _on_achievement_item_sold(_item_id: String, amount: int, total_price: int) -> void:
	achievement_tracker.call("record_increment", "items_sold", amount)
	achievement_tracker.call("record_increment", "money_earned", total_price)


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
