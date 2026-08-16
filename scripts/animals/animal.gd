extends Area2D

signal animal_interacted(animal_instance_id: String, animal_id: String)
signal state_changed(animal_instance_id: String, state: String)
signal product_created(animal_instance_id: String, item_id: String, amount: int, kind: String)
signal product_collected(animal_instance_id: String, item_id: String, amount: int)
signal lifecycle_completed(animal_instance_id: String, animal_id: String)
signal animal_completed(animal_instance_id: String, animal_id: String)

const state_active: String = "active"
const state_product_ready: String = "product_ready"
const state_end_of_life: String = "end_of_life"
const state_completed: String = "completed"
const valid_states: Array[String] = [
	state_active,
	state_product_ready,
	state_end_of_life,
	state_completed
]

const product_kind_daily: String = "daily"
const product_kind_end_of_life: String = "end_of_life"
const valid_product_kinds: Array[String] = [
	product_kind_daily,
	product_kind_end_of_life
]

@export var animal_instance_id: String = ""
@export var animal_id: String = ""
@export var animal_color: Color = Color(0.92, 0.82, 0.58, 1.0)

@onready var body: Polygon2D = $body
@onready var product_indicator: Polygon2D = $product_indicator

var current_state: String = state_active
var age_days: int = 0
var production_timer: float = 0.0
var product_collected_for_cycle: bool = true
var last_processed_day: int = 0
var pending_products: Array = []
var end_product_created: bool = false
var is_configured: bool = false


static func is_valid_state(value: String) -> bool:
	return valid_states.has(value)


static func is_valid_product_kind(value: String) -> bool:
	return valid_product_kinds.has(value)


func _ready() -> void:
	if data_manager.is_ready:
		_initialize_from_data()
	else:
		data_manager.data_loaded.connect(_initialize_from_data, CONNECT_ONE_SHOT)

	if not game_manager.day_finished.is_connected(_on_day_finished):
		game_manager.day_finished.connect(_on_day_finished)

	_update_visual()


func _initialize_from_data() -> void:
	is_configured = _validate_configuration()
	if not is_configured:
		push_error(
			"animal: invalid configuration for instance '%s' and animal '%s'" % [
				animal_instance_id,
				animal_id
			]
		)
	_update_visual()


func interact(_player: Node) -> bool:
	if not is_configured:
		return false

	animal_interacted.emit(animal_instance_id, animal_id)
	if pending_products.is_empty():
		return true

	return collect_next_product()


func collect_next_product() -> bool:
	if not is_configured or pending_products.is_empty():
		return false

	var product_value: Variant = pending_products[0]
	if typeof(product_value) != TYPE_DICTIONARY:
		return false

	var product: Dictionary = product_value as Dictionary
	var item_id: String = String(product.get("item_id", ""))
	var amount: int = int(product.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return false
	if not inventory_manager.add_item(item_id, amount):
		return false

	pending_products.pop_front()
	game_manager.add_exp(int(product.get("collect_exp", 0)))
	product_collected.emit(animal_instance_id, item_id, amount)
	_refresh_state()
	if current_state == state_completed:
		animal_completed.emit(animal_instance_id, animal_id)
	return true


func advance_lifecycle(finished_day: int) -> bool:
	if not is_configured or finished_day <= last_processed_day:
		return false

	var lifespan_days: int = get_lifespan_days()
	if current_state == state_completed or (lifespan_days > 0 and age_days >= lifespan_days):
		return false

	last_processed_day = finished_day
	age_days += 1
	if lifespan_days > 0:
		age_days = mini(age_days, lifespan_days)

	if lifespan_days > 0 and age_days >= lifespan_days:
		_create_end_product(finished_day)
		_refresh_state()
		lifecycle_completed.emit(animal_instance_id, animal_id)
		return true

	if pending_products.is_empty():
		var daily_product: Dictionary = get_product_definition(product_kind_daily)
		var production_interval: float = get_production_interval_days()
		if not daily_product.is_empty() and production_interval > 0.0:
			production_timer += 1.0
			if production_timer >= production_interval:
				production_timer = maxf(production_timer - production_interval, 0.0)
				_enqueue_product(daily_product, product_kind_daily, finished_day)

	_refresh_state()
	return true


func reset_state(processed_day: int = -1) -> void:
	age_days = 0
	production_timer = 0.0
	pending_products.clear()
	end_product_created = false
	last_processed_day = maxi(game_manager.day - 1, 0) if processed_day < 0 else processed_day
	_refresh_state()


func get_save_state() -> Dictionary:
	return {
		"animal_id": animal_id,
		"position": {
			"x": position.x,
			"y": position.y
		},
		"state": current_state,
		"production_timer": production_timer,
		"product_collected": product_collected_for_cycle,
		"last_processed_day": last_processed_day,
		"pending_products": pending_products.duplicate(true),
		"end_product_created": end_product_created
	}


func apply_save_state(saved_state: Dictionary, saved_age_days: int) -> bool:
	if not is_configured or String(saved_state.get("animal_id", "")) != animal_id:
		return false

	var position_value: Variant = saved_state.get("position")
	var pending_value: Variant = saved_state.get("pending_products")
	if typeof(position_value) != TYPE_DICTIONARY or typeof(pending_value) != TYPE_ARRAY:
		return false

	var saved_position: Dictionary = position_value as Dictionary
	position = Vector2(float(saved_position.get("x", 0.0)), float(saved_position.get("y", 0.0)))
	age_days = saved_age_days
	production_timer = float(saved_state.get("production_timer", 0.0))
	last_processed_day = int(saved_state.get("last_processed_day", 0))
	pending_products = (pending_value as Array).duplicate(true)
	end_product_created = bool(saved_state.get("end_product_created", false))
	_refresh_state()
	return (
		current_state == String(saved_state.get("state", ""))
		and product_collected_for_cycle == bool(saved_state.get("product_collected", false))
	)


func get_pending_products() -> Array:
	return pending_products.duplicate(true)


func get_lifespan_days() -> int:
	var animal_data: Dictionary = _get_animal_data()
	var lifespan_value: Variant = animal_data.get("lifespan_days")
	return int(lifespan_value) if _is_integer_value(lifespan_value, 1) else 0


func get_production_interval_days() -> float:
	var animal_data: Dictionary = _get_animal_data()
	var interval_value: Variant = animal_data.get("production_interval_days")
	if typeof(interval_value) != TYPE_INT and typeof(interval_value) != TYPE_FLOAT:
		return 0.0
	return float(interval_value)


func get_product_definition(kind: String) -> Dictionary:
	var animal_data: Dictionary = _get_animal_data()
	var field: String = "daily_product" if kind == product_kind_daily else "end_of_life_product"
	var product_value: Variant = animal_data.get(field)
	if typeof(product_value) != TYPE_DICTIONARY:
		return {}
	return (product_value as Dictionary).duplicate(true)


func _on_day_finished(finished_day: int) -> void:
	advance_lifecycle(finished_day)


func _create_end_product(produced_day: int) -> void:
	if end_product_created:
		return

	end_product_created = true
	var end_product: Dictionary = get_product_definition(product_kind_end_of_life)
	if not end_product.is_empty():
		_enqueue_product(end_product, product_kind_end_of_life, produced_day)


func _enqueue_product(product: Dictionary, kind: String, produced_day: int) -> void:
	var queued_product: Dictionary = {
		"item_id": String(product.get("item_id", "")),
		"amount": int(product.get("amount", 0)),
		"collect_exp": int(product.get("collect_exp", 0)),
		"kind": kind,
		"produced_day": produced_day
	}
	pending_products.append(queued_product)
	product_created.emit(
		animal_instance_id,
		String(queued_product["item_id"]),
		int(queued_product["amount"]),
		kind
	)


func _refresh_state() -> void:
	product_collected_for_cycle = pending_products.is_empty()
	var lifespan_days: int = get_lifespan_days()
	var lifecycle_is_complete: bool = lifespan_days > 0 and age_days >= lifespan_days
	var next_state: String = state_active

	if lifecycle_is_complete:
		next_state = state_completed if pending_products.is_empty() else state_end_of_life
	elif not pending_products.is_empty():
		next_state = state_product_ready

	if current_state != next_state:
		current_state = next_state
		state_changed.emit(animal_instance_id, current_state)

	_update_visual()


func _validate_configuration() -> bool:
	if animal_instance_id.is_empty() or animal_id.is_empty():
		return false

	var animal_data: Dictionary = _get_animal_data()
	if animal_data.is_empty() or String(animal_data.get("animal_id", "")) != animal_id:
		return false

	var required_level_value: Variant = animal_data.get("required_level")
	var purchase_price_value: Variant = animal_data.get("purchase_price")
	if not _is_integer_value(required_level_value, 1):
		return false
	if not _is_integer_value(purchase_price_value, 0):
		return false

	var lifespan_value: Variant = animal_data.get("lifespan_days")
	if lifespan_value != null and not _is_integer_value(lifespan_value, 1):
		return false

	var daily_product: Dictionary = get_product_definition(product_kind_daily)
	if not daily_product.is_empty():
		if not _is_product_definition_valid(daily_product):
			return false
		if get_production_interval_days() <= 0.0:
			return false

	var end_product: Dictionary = get_product_definition(product_kind_end_of_life)
	if not end_product.is_empty() and not _is_product_definition_valid(end_product):
		return false
	if lifespan_value != null and end_product.is_empty():
		return false

	return not daily_product.is_empty() or not end_product.is_empty()


func _is_product_definition_valid(product: Dictionary) -> bool:
	var item_id: String = String(product.get("item_id", ""))
	var amount_value: Variant = product.get("amount")
	var exp_value: Variant = product.get("collect_exp")
	return (
		not item_id.is_empty()
		and data_manager.get_entry("items", item_id) != null
		and _is_integer_value(amount_value, 1)
		and _is_integer_value(exp_value, 0)
	)


func _is_integer_value(value: Variant, minimum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum
	if typeof(value) != TYPE_FLOAT:
		return false

	var number_value: float = float(value)
	return is_finite(number_value) and floor(number_value) == number_value and number_value >= minimum


func _get_animal_data() -> Dictionary:
	var animal_value: Variant = data_manager.get_entry("animals", animal_id)
	if typeof(animal_value) != TYPE_DICTIONARY:
		return {}
	return animal_value as Dictionary


func _update_visual() -> void:
	if not is_node_ready():
		return

	body.color = animal_color
	body.modulate.a = 0.45 if current_state == state_completed else 1.0
	product_indicator.visible = not pending_products.is_empty()
	product_indicator.color = (
		Color(0.95, 0.42, 0.24, 1.0)
		if current_state == state_end_of_life
		else Color(1.0, 0.9, 0.25, 1.0)
	)
