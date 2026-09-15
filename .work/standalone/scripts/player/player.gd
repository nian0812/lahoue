extends CharacterBody2D

signal interaction_requested(target: Node)
signal interaction_completed(target: Node, succeeded: bool)
signal selected_seed_changed(seed_item_id: String)

@export var movement_speed: float = 240.0
@export var interaction_offset: float = 32.0

@onready var interaction_area: Area2D = $interaction_area

var facing_direction: Vector2 = Vector2.DOWN
var selected_seed_item_id: String = ""
var delivery_customer_id: String = ""
var delivery_path: Array[Vector2] = []
var carrying_food: bool = false
var _delivery_restaurant: Node2D
var _delivery_pickup: Vector2


func _ready() -> void:
	save_manager.game_loaded.connect(func(_path: String): _cancel_delivery())
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	game_manager.level_changed.connect(_on_level_changed)
	_refresh_selected_seed()


func _physics_process(_delta: float) -> void:
	if not delivery_customer_id.is_empty():
		_advance_delivery(_delta)
		return
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if not input_direction.is_zero_approx():
		facing_direction = input_direction.normalized()
		interaction_area.position = facing_direction * interaction_offset

	velocity = input_direction * movement_speed
	move_and_slide()


func begin_food_delivery(restaurant: Node2D, customer_id: String) -> bool:
	if not delivery_customer_id.is_empty(): return false
	var customer: Node = restaurant.get_customer(customer_id)
	if customer == null or restaurant.get_cooking_job(customer_id).get("state", "") != "ready": return false
	for staff: Node in restaurant.staffs_by_id.values():
		if staff.active_job.get("job_type", "") == "serve" and staff.active_job.get("target_id", "") == customer_id: return false
	_delivery_restaurant = restaurant
	delivery_customer_id = customer_id
	carrying_food = false
	_delivery_pickup = restaurant.get_node("serving_counter_marker").global_position
	delivery_path = [_delivery_pickup]
	for point: Vector2 in restaurant.get_table_approach(customer.table_id):
		delivery_path.append(restaurant.to_global(point))
	delivery_path.append(restaurant.tables_by_id[customer.table_id].global_position + Vector2(26, 10))
	return true


func _advance_delivery(delta: float) -> void:
	if not game_manager.gameplay_active or get_tree().paused: return
	if not is_instance_valid(_delivery_restaurant) or _delivery_restaurant.get_cooking_job(delivery_customer_id).get("state", "") != "ready":
		_cancel_delivery()
		return
	if delivery_path.is_empty():
		_delivery_restaurant.serve_order(delivery_customer_id)
		get_node("animation_presentation").request_action("serve")
		_cancel_delivery()
		return
	var target: Vector2 = delivery_path[0]
	var distance: float = global_position.distance_to(target)
	if distance <= maxf(3.0, movement_speed * delta):
		global_position = target
		if target.is_equal_approx(_delivery_pickup): carrying_food = true
		delivery_path.pop_front()
		velocity = Vector2.ZERO
	else:
		facing_direction = global_position.direction_to(target)
		velocity = facing_direction * movement_speed
		move_and_slide()
	var rooftop: bool = carrying_food and _delivery_restaurant.to_local(global_position).y < -80
	z_index = 4 if rooftop else 0


func _cancel_delivery() -> void:
	delivery_customer_id = ""
	delivery_path.clear()
	carrying_food = false
	velocity = Vector2.ZERO
	z_index = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_next_seed"):
		select_next_seed()
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed("interact"):
		return

	_try_interact()
	get_viewport().set_input_as_handled()


func get_selected_seed_item() -> String:
	return selected_seed_item_id


func select_seed(seed_item_id: String) -> bool:
	var available_seed_items: Array[String] = _get_available_seed_items()
	if not available_seed_items.has(seed_item_id):
		return false

	_set_selected_seed(seed_item_id)
	return true


func select_next_seed() -> bool:
	var available_seed_items: Array[String] = _get_available_seed_items()
	if available_seed_items.is_empty():
		_set_selected_seed("")
		return false

	var current_index: int = available_seed_items.find(selected_seed_item_id)
	var next_index: int = 0 if current_index < 0 else (current_index + 1) % available_seed_items.size()
	_set_selected_seed(available_seed_items[next_index])
	return true


func _get_available_seed_items() -> Array[String]:
	var available_seed_items: Array[String] = []
	var crops: Dictionary = data_manager.get_dataset("crops")
	var entries_value: Variant = crops.get("entries", {})
	if typeof(entries_value) != TYPE_DICTIONARY:
		return available_seed_items

	var entries: Dictionary = entries_value as Dictionary
	var crop_ids: Array[String] = []
	for crop_id_value: Variant in entries:
		crop_ids.append(String(crop_id_value))
	crop_ids.sort()

	for crop_id: String in crop_ids:
		var crop_data_value: Variant = entries.get(crop_id)
		if typeof(crop_data_value) != TYPE_DICTIONARY:
			continue

		var crop_data: Dictionary = crop_data_value as Dictionary
		var seed_item_id: String = String(crop_data.get("seed_item", ""))
		
		if seed_item_id.is_empty():
			continue

		if inventory_manager.has_item(seed_item_id) and not available_seed_items.has(seed_item_id):
			available_seed_items.append(seed_item_id)

	return available_seed_items


func _refresh_selected_seed() -> void:
	var available_seed_items: Array[String] = _get_available_seed_items()
	if available_seed_items.has(selected_seed_item_id):
		return

	_set_selected_seed("" if available_seed_items.is_empty() else available_seed_items[0])


func _set_selected_seed(seed_item_id: String) -> void:
	if selected_seed_item_id == seed_item_id:
		return

	selected_seed_item_id = seed_item_id
	selected_seed_changed.emit(selected_seed_item_id)


func _on_inventory_changed(_items: Dictionary) -> void:
	_refresh_selected_seed()


func _on_level_changed(_level: int) -> void:
	_refresh_selected_seed()


func _try_interact() -> void:
	var closest_target: Node = null
	var closest_distance_squared: float = INF

	for area: Area2D in interaction_area.get_overlapping_areas():
		var target: Node = _resolve_interactable(area)
		if target == null:
			continue

		var target_position: Vector2 = area.global_position
		if target is Node2D:
			target_position = (target as Node2D).global_position

		var distance_squared: float = global_position.distance_squared_to(target_position)
		if distance_squared < closest_distance_squared:
			closest_target = target
			closest_distance_squared = distance_squared

	if closest_target == null:
		return

	interaction_requested.emit(closest_target)
	var succeeded: bool = bool(closest_target.call("interact", self))
	interaction_completed.emit(closest_target, succeeded)


func _resolve_interactable(area: Area2D) -> Node:
	if area.has_method("interact"):
		return area

	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent

	return null
