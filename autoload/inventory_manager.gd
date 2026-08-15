extends Node

signal inventory_changed(items)
signal capacity_changed(current, maximum)
signal item_added(item_id, amount)
signal item_removed(item_id, amount)

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


func get_free_space() -> int:
	return maxi(get_capacity() - get_total_count(), 0)


func can_add(amount: int) -> bool:
	if amount <= 0:
		return false

	return get_total_count() + amount <= get_capacity()


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


func get_amount(item_id: String) -> int:
	return int(items.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount


func set_warehouse_level(value: int) -> void:
	warehouse_level = maxi(value, 1)
	_emit_capacity()


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
