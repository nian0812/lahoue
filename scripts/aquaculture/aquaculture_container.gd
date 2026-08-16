extends Area2D

signal state_changed(container_id: String, new_state: String)
signal product_received(container_id: String, item_id: String, amount: int)

const state_empty: String = "empty"
const state_growing: String = "growing"
const state_ready: String = "ready"
const valid_states: Array[String] = [state_empty, state_growing, state_ready]

@export var container_id: String = ""
@export var aquaculture_id: String = ""

@onready var water_visual: Polygon2D = $water_visual
@onready var product_visual: Polygon2D = $product_visual

var current_state: String = state_empty
var growth_timer: float = 0.0
var pending_product: Dictionary = {}
var product_collected: bool = true
var is_configured: bool = false


func _ready() -> void:
	is_configured = _validate_configuration()
	_refresh_visual()


func _process(delta: float) -> void:
	if not game_manager.gameplay_active:
		return
	advance_growth(delta)


func interact(_player: Node) -> bool:
	match current_state:
		state_empty:
			return start_cycle()
		state_ready:
			return harvest_product()
	return false


func can_start_cycle() -> bool:
	if not is_configured or current_state != state_empty:
		return false
	var aquaculture_data: Dictionary = data_manager.get_entry("aquaculture", aquaculture_id)
	var required_level: int = int(aquaculture_data.get("required_level", 1))
	return game_manager.level >= required_level


func start_cycle() -> bool:
	if not can_start_cycle():
		return false
	growth_timer = 0.0
	pending_product.clear()
	product_collected = false
	_set_state(state_growing)
	return true


func advance_growth(delta_seconds: float) -> void:
	if current_state != state_growing or delta_seconds <= 0.0:
		return
	var growth_time: float = data_manager.get_aquaculture_growth_time_seconds(aquaculture_id)
	if growth_time <= 0.0:
		return
	growth_timer = minf(growth_timer + delta_seconds, growth_time)
	if growth_timer >= growth_time:
		_prepare_product()


func harvest_product() -> bool:
	if current_state != state_ready or product_collected or pending_product.is_empty():
		return false
	var item_id: String = str(pending_product.get("item_id", ""))
	var amount: int = int(pending_product.get("amount", 0))
	var exp_reward: int = int(pending_product.get("exp", 0))
	if item_id.is_empty() or amount <= 0:
		return false
	if not inventory_manager.add_item(item_id, amount):
		return false
	product_collected = true
	if exp_reward > 0:
		game_manager.add_exp(exp_reward)
	product_received.emit(container_id, item_id, amount)
	reset_container()
	return true


func reset_container() -> void:
	growth_timer = 0.0
	pending_product.clear()
	product_collected = true
	_set_state(state_empty)


func get_save_state() -> Dictionary:
	return {
		"aquaculture_id": aquaculture_id,
		"position": {"x": position.x, "y": position.y},
		"state": current_state,
		"growth_timer": growth_timer,
		"pending_product": pending_product.duplicate(true),
		"product_collected": product_collected,
	}


func apply_save_state(saved_state: Dictionary) -> void:
	aquaculture_id = str(saved_state.get("aquaculture_id", aquaculture_id))
	var saved_position: Dictionary = saved_state.get("position", {})
	position = Vector2(float(saved_position.get("x", position.x)), float(saved_position.get("y", position.y)))
	current_state = str(saved_state.get("state", state_empty))
	growth_timer = float(saved_state.get("growth_timer", 0.0))
	pending_product = saved_state.get("pending_product", {}).duplicate(true)
	product_collected = bool(saved_state.get("product_collected", true))
	is_configured = _validate_configuration()
	_refresh_visual()


static func is_valid_state(value: String) -> bool:
	return value in valid_states


func _prepare_product() -> void:
	if current_state != state_growing:
		return
	var aquaculture_data: Dictionary = data_manager.get_entry("aquaculture", aquaculture_id)
	var item_id: String = str(aquaculture_data.get("item_id", ""))
	var amount: int = int(aquaculture_data.get("yield", 0))
	var exp_reward: int = int(aquaculture_data.get("exp", 0))
	if item_id.is_empty() or amount <= 0:
		return
	pending_product = {
		"item_id": item_id,
		"amount": amount,
		"exp": exp_reward,
	}
	product_collected = false
	_set_state(state_ready)


func _set_state(new_state: String) -> void:
	if current_state == new_state:
		_refresh_visual()
		return
	current_state = new_state
	_refresh_visual()
	state_changed.emit(container_id, current_state)


func _validate_configuration() -> bool:
	if container_id.is_empty() or aquaculture_id.is_empty():
		return false
	var aquaculture_data: Dictionary = data_manager.get_entry("aquaculture", aquaculture_id)
	if aquaculture_data.is_empty():
		return false
	var item_id: String = str(aquaculture_data.get("item_id", ""))
	return not data_manager.get_entry("items", item_id).is_empty()


func _refresh_visual() -> void:
	if not is_instance_valid(product_visual) or not is_instance_valid(water_visual):
		return
	product_visual.visible = current_state == state_ready
	water_visual.color = Color("#397ca6") if current_state == state_empty else Color("#2f6f91")
