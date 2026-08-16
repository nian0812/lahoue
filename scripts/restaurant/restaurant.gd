extends Node2D

signal restaurant_interacted(player: Node)
signal availability_changed(is_available: bool)
signal revenue_collected(recipe_id: String, amount: int, total_revenue: int)
signal customer_spawned(customer_id: String)
signal customer_removed(customer_id: String)

const state_locked: String = "locked"
const state_available: String = "available"
const customer_scene: PackedScene = preload("res://scenes/restaurant/customer.tscn")
const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")

@onready var building_visual: Polygon2D = $building_visual
@onready var interaction_area: Area2D = $interaction_area
@onready var tables: Node2D = $tables
@onready var customers: Node2D = $customers

var current_state: String = state_locked
var restaurant_level: int = 0
var tables_by_id: Dictionary = {}
var customers_by_id: Dictionary = {}
var menu_entries: Dictionary = {}
var is_configured: bool = false
var customer_sequence: int = 0
var customer_spawn_elapsed: float = 0.0


func _ready() -> void:
	_cache_tables()
	is_configured = _validate_configuration()
	if not game_manager.level_changed.is_connected(_on_level_changed):
		game_manager.level_changed.connect(_on_level_changed)
	refresh_availability()


func _process(delta: float) -> void:
	if not is_available() or not game_manager.gameplay_active or get_tree().paused:
		return
	var settings: Dictionary = data_manager.get_customer_settings()
	var spawn_interval: float = float(settings.get("spawn_interval_seconds", 0.0))
	if spawn_interval <= 0.0:
		return
	customer_spawn_elapsed = minf(customer_spawn_elapsed + delta, spawn_interval)
	if customer_spawn_elapsed < spawn_interval:
		return
	if spawn_customer() != null:
		customer_spawn_elapsed = 0.0


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
		_clear_customers()
		customer_spawn_elapsed = 0.0
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


func spawn_customer(
	new_customer_id: String = "",
	preferred_recipe_id: String = "",
	customer_type_id: String = ""
) -> Node:
	if not is_available() or menu_entries.is_empty() or _find_available_table() == null:
		return null
	var settings: Dictionary = data_manager.get_customer_settings()
	if settings.is_empty():
		return null
	if customer_type_id.is_empty():
		customer_type_id = String(settings.get("default_customer_type", ""))
	var customer_data: Dictionary = data_manager.get_customer_type(customer_type_id)
	if customer_data.is_empty():
		return null
	if not preferred_recipe_id.is_empty() and get_menu_entry(preferred_recipe_id).is_empty():
		return null

	var generated_id: bool = new_customer_id.is_empty()
	if generated_id:
		new_customer_id = _next_customer_id()
	if not customer_script.is_valid_customer_id(new_customer_id) or customers_by_id.has(new_customer_id):
		return null

	var customer: Node = customer_scene.instantiate()
	customer.name = new_customer_id
	if not bool(customer.call("configure", new_customer_id, customer_type_id, self, preferred_recipe_id)):
		customer.free()
		return null
	customer.position = $customer_queue_marker.position
	customers.add_child(customer)
	customers_by_id[new_customer_id] = customer
	if generated_id:
		customer_sequence += 1
	customer_spawned.emit(new_customer_id)
	call_deferred("_begin_customer_visit", new_customer_id)
	return customer


func remove_customer(customer_id: String) -> bool:
	var customer: Node = customers_by_id.get(customer_id) as Node
	if customer == null:
		return false
	var assigned_table_id: String = String(customer.get("table_id"))
	if not assigned_table_id.is_empty():
		release_customer_table(customer_id, assigned_table_id)
	customers_by_id.erase(customer_id)
	if is_instance_valid(customer):
		customer.queue_free()
	customer_removed.emit(customer_id)
	return true


func release_customer_table(customer_id: String, table_id: String) -> bool:
	var table: Node = tables_by_id.get(table_id) as Node
	if table == null or String(table.get("occupant_id")) != customer_id:
		return false
	return bool(table.call("release_table"))


func has_customer(customer_id: String) -> bool:
	return customers_by_id.has(customer_id)


func get_customer(customer_id: String) -> Node:
	return customers_by_id.get(customer_id) as Node


func get_save_state() -> Dictionary:
	var table_states: Dictionary = {}
	for table_id_value: Variant in tables_by_id:
		var table_id: String = String(table_id_value)
		table_states[table_id] = tables_by_id[table_id].call("get_save_state")
	var customer_states: Dictionary = {}
	for customer_id_value: Variant in customers_by_id:
		var customer_id: String = String(customer_id_value)
		customer_states[customer_id] = customers_by_id[customer_id].call("get_save_state")
	return {
		"restaurant_level": restaurant_level,
		"restaurant_tables": table_states,
		"restaurant_customers": customer_states,
		"restaurant_customer_sequence": customer_sequence,
		"restaurant_spawn_elapsed": customer_spawn_elapsed,
	}


func apply_save_state(saved_state: Dictionary) -> void:
	restaurant_level = int(saved_state.get("restaurant_level", 0))
	_clear_customers()
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
	customer_sequence = int(saved_state.get("restaurant_customer_sequence", 0))
	customer_spawn_elapsed = float(saved_state.get("restaurant_spawn_elapsed", 0.0))
	refresh_availability()
	if not is_available():
		return
	var saved_customers_value: Variant = saved_state.get("restaurant_customers", {})
	if typeof(saved_customers_value) != TYPE_DICTIONARY:
		return
	for customer_id_value: Variant in saved_customers_value as Dictionary:
		var customer_id: String = String(customer_id_value)
		var customer_state_value: Variant = (saved_customers_value as Dictionary)[customer_id_value]
		if typeof(customer_state_value) != TYPE_DICTIONARY:
			continue
		var customer_state: Dictionary = customer_state_value as Dictionary
		var customer: Node = customer_scene.instantiate()
		customer.name = customer_id
		customer.set("customer_id", customer_id)
		customers.add_child(customer)
		if not bool(customer.call("apply_save_state", customer_state, self)):
			customer.free()
			continue
		customers_by_id[customer_id] = customer
		var customer_state_name: String = String(customer.get("current_state"))
		if customer_state_name == customer_script.state_enter or customer_state_name == customer_script.state_seated or customer_state_name == customer_script.state_ordering:
			call_deferred("_resume_customer_visit", customer_id)


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
	return (
		unlock_level > 0
		and initial_capacity > 0
		and tables_by_id.size() == initial_capacity
		and not data_manager.get_customer_settings().is_empty()
	)


func _reset_tables() -> void:
	for table_value: Variant in tables_by_id.values():
		table_value.call("reset_table")


func _begin_customer_visit(customer_id: String) -> void:
	var customer: Node = customers_by_id.get(customer_id) as Node
	if customer == null or String(customer.get("current_state")) != customer_script.state_enter:
		return
	var table: Node = _find_available_table()
	if table == null or not bool(table.call("reserve", customer_id)):
		remove_customer(customer_id)
		return
	var table_id: String = String(table.get("table_id"))
	if not bool(customer.call("assign_table", table_id)):
		table.call("release_table")
		remove_customer(customer_id)
		return
	customer.position = to_local((table.get_node("seat_marker") as Marker2D).global_position)
	if not bool(table.call("seat_customer", customer_id)) or not bool(customer.call("begin_ordering")):
		table.call("release_table")
		remove_customer(customer_id)
		return
	if not _create_customer_order(customer):
		table.call("release_table")
		remove_customer(customer_id)


func _resume_customer_visit(customer_id: String) -> void:
	var customer: Node = customers_by_id.get(customer_id) as Node
	if customer == null:
		return
	var state: String = String(customer.get("current_state"))
	if state == customer_script.state_enter:
		_begin_customer_visit(customer_id)
		return
	var table_id: String = String(customer.get("table_id"))
	var table: Node = tables_by_id.get(table_id) as Node
	if table == null or String(table.get("occupant_id")) != customer_id:
		remove_customer(customer_id)
		return
	if state == customer_script.state_seated:
		if String(table.get("current_state")) == restaurant_table_script.state_reserved:
			table.call("seat_customer", customer_id)
		if not bool(customer.call("begin_ordering")):
			return
	if not _create_customer_order(customer):
		table.call("release_table")
		remove_customer(customer_id)


func _create_customer_order(customer: Node) -> bool:
	var customer_data: Dictionary = data_manager.get_customer_type(String(customer.get("customer_type_id")))
	var quantity: int = int(customer_data.get("order_quantity", 0))
	var recipe_id: String = String(customer.get("requested_recipe_id"))
	if recipe_id.is_empty():
		var recipe_ids: Array = menu_entries.keys()
		recipe_ids.sort()
		if recipe_ids.is_empty():
			return false
		recipe_id = String(recipe_ids[0])
	return bool(customer.call("create_order", recipe_id, quantity))


func _find_available_table() -> Node:
	var table_ids: Array = tables_by_id.keys()
	table_ids.sort()
	for table_id_value: Variant in table_ids:
		var table: Node = tables_by_id[table_id_value] as Node
		if String(table.get("current_state")) == restaurant_table_script.state_available:
			return table
	return null


func _next_customer_id() -> String:
	var next_sequence: int = customer_sequence + 1
	var candidate: String = "customer_%06d" % next_sequence
	while customers_by_id.has(candidate):
		next_sequence += 1
		candidate = "customer_%06d" % next_sequence
	return candidate


func _clear_customers() -> void:
	for customer_value: Variant in customers_by_id.values():
		if customer_value != null and is_instance_valid(customer_value):
			customer_value.free()
	customers_by_id.clear()


func _on_level_changed(_level: int) -> void:
	refresh_availability()


func _refresh_visual() -> void:
	if not is_instance_valid(building_visual) or not is_instance_valid(interaction_area) or not is_instance_valid(tables):
		return
	var available: bool = is_available()
	building_visual.color = Color("#a85d3d") if available else Color("#55504c")
	tables.visible = available
