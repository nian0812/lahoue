extends Node2D

signal state_changed(customer_id: String, state: String)
signal order_created(customer_id: String, order: Dictionary)
signal order_failed(customer_id: String, order: Dictionary, reason: String)

const state_enter: String = "enter"
const state_seated: String = "seated"
const state_ordering: String = "ordering"
const state_waiting_food: String = "waiting_food"
const state_eating: String = "eating"
const state_leaving: String = "leaving"
const valid_states: Array[String] = [
	state_enter,
	state_seated,
	state_ordering,
	state_waiting_food,
	state_eating,
	state_leaving,
]

const order_state_pending: String = "pending"
const order_state_served: String = "served"
const order_state_failed: String = "failed"
const valid_order_states: Array[String] = [
	order_state_pending,
	order_state_served,
	order_state_failed,
]

@onready var customer_visual: Polygon2D = $customer_visual

var customer_id: String = ""
var customer_type_id: String = ""
var current_state: String = state_enter
var table_id: String = ""
var requested_recipe_id: String = ""
var order: Dictionary = {}
var patience_elapsed: float = 0.0
var patience_limit: float = 0.0
var leaving_elapsed: float = 0.0
var leaving_duration: float = 0.0
var timeout_reputation_change: float = 0.0
var timeout_impact_applied: bool = false
var restaurant: Node = null


func _ready() -> void:
	_refresh_visual()


func _process(delta: float) -> void:
	if restaurant == null or not is_instance_valid(restaurant):
		return
	if not game_manager.gameplay_active or get_tree().paused:
		return
	if current_state == state_waiting_food:
		advance_patience(delta)
	elif current_state == state_leaving:
		leaving_elapsed = minf(leaving_elapsed + delta, leaving_duration)
		if leaving_elapsed >= leaving_duration:
			complete_departure()


func configure(
	new_customer_id: String,
	new_customer_type_id: String,
	controller: Node,
	preferred_recipe_id: String = ""
) -> bool:
	var customer_data: Dictionary = data_manager.get_customer_type(new_customer_type_id)
	if not is_valid_customer_id(new_customer_id) or customer_data.is_empty() or controller == null:
		return false
	customer_id = new_customer_id
	customer_type_id = new_customer_type_id
	restaurant = controller
	requested_recipe_id = preferred_recipe_id
	patience_limit = float(customer_data.get("patience_seconds", 0.0))
	leaving_duration = float(customer_data.get("leaving_duration_seconds", 0.0))
	timeout_reputation_change = float(customer_data.get("timeout_reputation_change", 0.0))
	return patience_limit > 0.0 and leaving_duration > 0.0 and timeout_reputation_change < 0.0


func assign_table(new_table_id: String) -> bool:
	if current_state != state_enter or not is_valid_table_id(new_table_id):
		return false
	table_id = new_table_id
	_set_state(state_seated)
	return true


func begin_ordering() -> bool:
	if current_state != state_seated or table_id.is_empty():
		return false
	_set_state(state_ordering)
	return true


func create_order(recipe_id: String, quantity: int) -> bool:
	if current_state != state_ordering or not order.is_empty() or quantity <= 0:
		return false
	if restaurant == null or not is_instance_valid(restaurant):
		return false
	var menu_entry: Dictionary = restaurant.call("get_menu_entry", recipe_id) as Dictionary
	if menu_entry.is_empty():
		return false
	var ingredients_value: Variant = menu_entry.get("ingredients", {})
	if typeof(ingredients_value) != TYPE_DICTIONARY or (ingredients_value as Dictionary).is_empty():
		return false
	for item_id_value: Variant in ingredients_value as Dictionary:
		if data_manager.get_entry("items", String(item_id_value)) == null:
			return false
	order = {
		"recipe_id": recipe_id,
		"quantity": quantity,
		"state": order_state_pending,
		"failure_reason": "",
	}
	patience_elapsed = 0.0
	_set_state(state_waiting_food)
	order_created.emit(customer_id, order.duplicate(true))
	return true


func advance_patience(delta: float) -> bool:
	if current_state != state_waiting_food or not is_finite(delta) or delta <= 0.0:
		return false
	patience_elapsed = minf(patience_elapsed + delta, patience_limit)
	if patience_elapsed < patience_limit:
		return true
	_timeout_order()
	return true


func mark_food_served() -> bool:
	if current_state != state_waiting_food or String(order.get("state", "")) != order_state_pending:
		return false
	order["state"] = order_state_served
	_set_state(state_eating)
	return true


func finish_eating(requires_cleanup: bool = false) -> bool:
	if current_state != state_eating or String(order.get("state", "")) != order_state_served:
		return false
	_begin_leaving(requires_cleanup)
	return true


func complete_departure() -> bool:
	if current_state != state_leaving or restaurant == null or not is_instance_valid(restaurant):
		return false
	restaurant.call_deferred("remove_customer", customer_id)
	return true


func get_save_state() -> Dictionary:
	return {
		"customer_type_id": customer_type_id,
		"position": {"x": position.x, "y": position.y},
		"state": current_state,
		"table_id": table_id,
		"requested_recipe_id": requested_recipe_id,
		"order": order.duplicate(true),
		"patience_elapsed": patience_elapsed,
		"patience_limit": patience_limit,
		"leaving_elapsed": leaving_elapsed,
		"leaving_duration": leaving_duration,
		"timeout_reputation_change": timeout_reputation_change,
		"timeout_impact_applied": timeout_impact_applied,
	}


func apply_save_state(saved_state: Dictionary, controller: Node) -> bool:
	var saved_type: String = String(saved_state.get("customer_type_id", ""))
	if not configure(customer_id, saved_type, controller, String(saved_state.get("requested_recipe_id", ""))):
		return false
	var position_value: Variant = saved_state.get("position", {})
	if typeof(position_value) != TYPE_DICTIONARY:
		return false
	var saved_position: Dictionary = position_value as Dictionary
	position = Vector2(float(saved_position.get("x", 0.0)), float(saved_position.get("y", 0.0)))
	current_state = String(saved_state.get("state", state_enter))
	table_id = String(saved_state.get("table_id", ""))
	requested_recipe_id = String(saved_state.get("requested_recipe_id", ""))
	var order_value: Variant = saved_state.get("order", {})
	order = (order_value as Dictionary).duplicate(true) if typeof(order_value) == TYPE_DICTIONARY else {}
	patience_elapsed = float(saved_state.get("patience_elapsed", 0.0))
	patience_limit = float(saved_state.get("patience_limit", patience_limit))
	leaving_elapsed = float(saved_state.get("leaving_elapsed", 0.0))
	leaving_duration = float(saved_state.get("leaving_duration", leaving_duration))
	timeout_reputation_change = float(saved_state.get("timeout_reputation_change", timeout_reputation_change))
	timeout_impact_applied = bool(saved_state.get("timeout_impact_applied", false))
	_refresh_visual()
	return true


static func is_valid_customer_id(value: String) -> bool:
	return not value.is_empty() and value == value.to_lower() and value.is_valid_identifier()


static func is_valid_table_id(value: String) -> bool:
	return is_valid_customer_id(value)


static func is_valid_state(value: String) -> bool:
	return valid_states.has(value)


static func is_valid_order_state(value: String) -> bool:
	return valid_order_states.has(value)


func _timeout_order() -> void:
	if current_state != state_waiting_food or String(order.get("state", "")) != order_state_pending:
		return
	order["state"] = order_state_failed
	order["failure_reason"] = "timeout"
	order_failed.emit(customer_id, order.duplicate(true), "timeout")
	_begin_leaving(false)
	if not timeout_impact_applied:
		timeout_impact_applied = true
		game_manager.change_reputation(timeout_reputation_change)


func _begin_leaving(requires_cleanup: bool = false) -> void:
	if restaurant != null and is_instance_valid(restaurant) and not table_id.is_empty():
		var table_handled: bool = false
		if requires_cleanup and restaurant.has_method("mark_customer_table_for_cleanup"):
			table_handled = bool(restaurant.call("mark_customer_table_for_cleanup", customer_id, table_id))
		if not table_handled:
			restaurant.call("release_customer_table", customer_id, table_id)
	table_id = ""
	leaving_elapsed = 0.0
	_set_state(state_leaving)


func _set_state(value: String) -> void:
	current_state = value
	_refresh_visual()
	state_changed.emit(customer_id, current_state)


func _refresh_visual() -> void:
	if not is_instance_valid(customer_visual):
		return
	match current_state:
		state_enter:
			customer_visual.color = Color("#5d8fc7")
		state_seated, state_ordering:
			customer_visual.color = Color("#d3aa4b")
		state_waiting_food:
			customer_visual.color = Color("#df7e45")
		state_eating:
			customer_visual.color = Color("#65a85e")
		state_leaving:
			customer_visual.color = Color("#777777")
