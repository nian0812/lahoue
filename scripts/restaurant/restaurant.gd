extends Node2D

signal restaurant_interacted(player: Node)
signal availability_changed(is_available: bool)
signal revenue_collected(recipe_id: String, amount: int, total_revenue: int)

const state_locked: String = "locked"
const state_available: String = "available"

@onready var building_visual: Polygon2D = $building_visual
@onready var interaction_area: Area2D = $interaction_area
@onready var tables: Node2D = $tables

var current_state: String = state_locked
var restaurant_level: int = 0
var tables_by_id: Dictionary = {}
var menu_entries: Dictionary = {}
var is_configured: bool = false


func _ready() -> void:
	_cache_tables()
	is_configured = _validate_configuration()
	if not game_manager.level_changed.is_connected(_on_level_changed):
		game_manager.level_changed.connect(_on_level_changed)
	refresh_availability()


func interact(player: Node) -> bool:
	if not is_available():
		return false
	restaurant_interacted.emit(player)
	return true


func is_available() -> bool:
	return is_configured and current_state == state_available


func refresh_availability() -> void:
	var was_available: bool = current_state == state_available
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	if is_configured and unlock_level > 0 and game_manager.level >= unlock_level:
		restaurant_level = maxi(restaurant_level, 1)
		current_state = state_available
		menu_entries = data_manager.get_restaurant_menu(game_manager.level)
	else:
		restaurant_level = 0
		current_state = state_locked
		menu_entries.clear()
		_reset_tables()
	_refresh_visual()
	if was_available != is_available():
		availability_changed.emit(is_available())


func get_menu_entries() -> Dictionary:
	return menu_entries.duplicate(true)


func get_menu_entry(recipe_id: String) -> Dictionary:
	var menu_entry_value: Variant = menu_entries.get(recipe_id)
	if typeof(menu_entry_value) != TYPE_DICTIONARY:
		return {}
	return (menu_entry_value as Dictionary).duplicate(true)


func collect_revenue(recipe_id: String, amount: int = 1) -> bool:
	if not is_available() or amount <= 0:
		return false
	var menu_entry: Dictionary = get_menu_entry(recipe_id)
	if menu_entry.is_empty():
		return false
	var unit_price: int = int(menu_entry.get("selling_price", 0))
	if unit_price <= 0:
		return false
	if amount > game_manager.max_wallet_balance / unit_price:
		return false
	var total_revenue: int = unit_price * amount
	if not game_manager.add_money(total_revenue):
		return false
	revenue_collected.emit(recipe_id, amount, total_revenue)
	return true


func get_save_state() -> Dictionary:
	var table_states: Dictionary = {}
	for table_id_value: Variant in tables_by_id:
		var table_id: String = String(table_id_value)
		table_states[table_id] = tables_by_id[table_id].call("get_save_state")
	return {
		"restaurant_level": restaurant_level,
		"restaurant_tables": table_states,
	}


func apply_save_state(saved_state: Dictionary) -> void:
	restaurant_level = int(saved_state.get("restaurant_level", 0))
	_reset_tables()
	var saved_tables_value: Variant = saved_state.get("restaurant_tables", {})
	if typeof(saved_tables_value) == TYPE_DICTIONARY:
		for table_id_value: Variant in saved_tables_value as Dictionary:
			var table_id: String = String(table_id_value)
			if not tables_by_id.has(table_id):
				continue
			var table_state_value: Variant = (saved_tables_value as Dictionary)[table_id_value]
			if typeof(table_state_value) == TYPE_DICTIONARY:
				tables_by_id[table_id].call("apply_save_state", table_state_value as Dictionary)
	refresh_availability()


func has_table(table_id: String) -> bool:
	return tables_by_id.has(table_id)


func _cache_tables() -> void:
	tables_by_id.clear()
	for child: Node in tables.get_children():
		if not child.has_method("get_save_state") or not child.has_method("reset_table"):
			continue
		var table_id: String = String(child.get("table_id"))
		if table_id.is_empty() or tables_by_id.has(table_id):
			push_error("restaurant: invalid or duplicate table id '%s'" % table_id)
			continue
		tables_by_id[table_id] = child


func _validate_configuration() -> bool:
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var initial_capacity: int = data_manager.get_restaurant_table_capacity(1)
	return unlock_level > 0 and initial_capacity > 0 and tables_by_id.size() == initial_capacity


func _reset_tables() -> void:
	for table_value: Variant in tables_by_id.values():
		table_value.call("reset_table")


func _on_level_changed(_level: int) -> void:
	refresh_availability()


func _refresh_visual() -> void:
	if not is_instance_valid(building_visual) or not is_instance_valid(interaction_area) or not is_instance_valid(tables):
		return
	var available: bool = is_available()
	building_visual.color = Color("#a85d3d") if available else Color("#55504c")
	tables.visible = available
