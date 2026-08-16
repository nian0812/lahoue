extends Node

signal inventory_changed(items)
signal capacity_changed(current, maximum)
signal item_added(item_id, amount)
signal item_removed(item_id, amount)
signal item_purchased(item_id, amount, total_price)
signal item_sold(item_id, amount, total_price)
signal warehouse_upgraded(level, capacity)

var items: Dictionary = {}
var warehouse_level: int = 1


func _ready() -> void:
	if data_manager.is_ready:
		_emit_capacity()
	else:
		data_manager.data_loaded.connect(_emit_capacity, CONNECT_ONE_SHOT)


func get_capacity() -> int:
	return data_manager.get_warehouse_capacity(warehouse_level)


func get_total_count() -> int:
	var total: int = 0
	for amount in items.values():
		total += int(amount)
	return total


func get_used_capacity() -> int:
	return get_total_count()


func get_stack_count() -> int:
	return items.size()


func get_free_space() -> int:
	return maxi(get_capacity() - get_total_count(), 0)


func can_add(amount: int) -> bool:
	if amount <= 0:
		return false

	return get_total_count() + amount <= get_capacity()


func can_add_item(item_id: String, amount: int) -> bool:
	return data_manager.get_entry("items", item_id) != null and can_add(amount)


func add_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	if data_manager.get_entry("items", item_id) == null:
		push_error("inventory_manager: unknown item '%s'" % item_id)
		return false

	if not can_add(amount):
		return false

	items[item_id] = int(items.get(item_id, 0)) + amount
	item_added.emit(item_id, amount)
	inventory_changed.emit(items.duplicate(true))
	_emit_capacity()
	return true


func can_purchase_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not can_add_item(item_id, amount):
		return false
	var unit_price: int = data_manager.get_item_buy_price(item_id)
	if unit_price <= 0:
		return false
	var required_level: int = data_manager.get_item_required_level(item_id)
	if required_level <= 0 or game_manager.level < required_level:
		return false
	return game_manager.can_afford(unit_price * amount)


func purchase_item(item_id: String, amount: int = 1) -> bool:
	if not can_purchase_item(item_id, amount):
		return false
	var total_price: int = data_manager.get_item_buy_price(item_id) * amount
	if not game_manager.spend_money(total_price):
		return false
	if not add_item(item_id, amount):
		game_manager.add_money(total_price)
		return false
	item_purchased.emit(item_id, amount, total_price)
	return true


func purchase_seed(seed_item_id: String, amount: int = 1) -> bool:
	var item_value: Variant = data_manager.get_entry("items", seed_item_id)
	if typeof(item_value) != TYPE_DICTIONARY:
		return false
	if String((item_value as Dictionary).get("category", "")) != "seed":
		return false
	return purchase_item(seed_item_id, amount)


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var current: int = int(items.get(item_id, 0))
	if current < amount:
		return false

	var remaining: int = current - amount
	if remaining == 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

	item_removed.emit(item_id, amount)
	inventory_changed.emit(items.duplicate(true))
	_emit_capacity()
	return true


func can_remove_items(requirements: Dictionary) -> bool:
	if requirements.is_empty():
		return false
	for item_id_value: Variant in requirements:
		if typeof(item_id_value) != TYPE_STRING:
			return false
		var item_id: String = String(item_id_value)
		var amount_value: Variant = requirements[item_id_value]
		if typeof(amount_value) != TYPE_INT:
			return false
		var amount: int = int(amount_value)
		if amount <= 0 or data_manager.get_entry("items", item_id) == null or not has_item(item_id, amount):
			return false
	return true


func remove_items_atomic(requirements: Dictionary) -> bool:
	if not can_remove_items(requirements):
		return false
	var next_items: Dictionary = items.duplicate(true)
	for item_id_value: Variant in requirements:
		var item_id: String = String(item_id_value)
		var amount: int = int(requirements[item_id_value])
		var remaining: int = int(next_items.get(item_id, 0)) - amount
		if remaining == 0:
			next_items.erase(item_id)
		else:
			next_items[item_id] = remaining
	items = next_items
	for item_id_value: Variant in requirements:
		item_removed.emit(String(item_id_value), int(requirements[item_id_value]))
	inventory_changed.emit(items.duplicate(true))
	_emit_capacity()
	return true


func can_sell_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not has_item(item_id, amount):
		return false
	return data_manager.get_item_sell_price(item_id) > 0


func sell_item(item_id: String, amount: int = 1) -> bool:
	if not can_sell_item(item_id, amount):
		return false
	var total_price: int = data_manager.get_item_sell_price(item_id) * amount
	if not remove_item(item_id, amount):
		return false
	if not game_manager.add_money(total_price):
		add_item(item_id, amount)
		return false
	item_sold.emit(item_id, amount, total_price)
	return true


func get_amount(item_id: String) -> int:
	return int(items.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount


func set_warehouse_level(value: int) -> bool:
	var new_capacity: int = data_manager.get_warehouse_capacity(value)
	if new_capacity <= 0 or get_total_count() > new_capacity:
		return false
	warehouse_level = value
	_emit_capacity()
	return true


func can_upgrade_warehouse() -> bool:
	var target_level: int = warehouse_level + 1
	var upgrade_cost: int = data_manager.get_warehouse_upgrade_cost(target_level)
	return (
		data_manager.get_warehouse_capacity(target_level) > 0
		and upgrade_cost > 0
		and game_manager.can_afford(upgrade_cost)
	)


func upgrade_warehouse() -> bool:
	if not can_upgrade_warehouse():
		return false
	var target_level: int = warehouse_level + 1
	var upgrade_cost: int = data_manager.get_warehouse_upgrade_cost(target_level)
	if not game_manager.spend_money(upgrade_cost):
		return false
	if not set_warehouse_level(target_level):
		game_manager.add_money(upgrade_cost)
		return false
	warehouse_upgraded.emit(warehouse_level, get_capacity())
	return true


func clear() -> void:
	items.clear()
	warehouse_level = 1
	inventory_changed.emit(items.duplicate(true))
	_emit_capacity()


func get_save_state() -> Dictionary:
	return {
		"inventory": items.duplicate(true),
		"warehouse_level": warehouse_level
	}


func apply_save_state(state: Dictionary) -> void:
	var saved_inventory: Variant = state.get("inventory", {})
	if typeof(saved_inventory) == TYPE_DICTIONARY:
		items = (saved_inventory as Dictionary).duplicate(true)
	else:
		items = {}

	warehouse_level = int(state.get("warehouse_level", 1))
	inventory_changed.emit(items.duplicate(true))
	_emit_capacity()


func _emit_capacity() -> void:
	capacity_changed.emit(get_total_count(), get_capacity())
