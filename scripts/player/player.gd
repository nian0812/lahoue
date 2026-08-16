extends CharacterBody2D

signal interaction_requested(target: Node)
signal selected_seed_changed(seed_item_id: String)

@export var movement_speed: float = 240.0
@export var interaction_offset: float = 32.0

@onready var interaction_area: Area2D = $interaction_area

var facing_direction: Vector2 = Vector2.DOWN
var selected_seed_item_id: String = ""


func _ready() -> void:
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	game_manager.level_changed.connect(_on_level_changed)
	_refresh_selected_seed()


func _physics_process(_delta: float) -> void:
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
		var crop_value: Variant = entries.get(crop_id)
		if typeof(crop_value) != TYPE_DICTIONARY:
			continue

		var crop_data: Dictionary = crop_value as Dictionary
		if int(crop_data.get("required_level", 1)) > game_manager.level:
			continue

		var seed_item_id: String = String(crop_data.get("seed_item", ""))
		var item_value: Variant = data_manager.get_entry("items", seed_item_id)
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		if String((item_value as Dictionary).get("category", "")) != "seed":
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
	closest_target.call("interact", self)


func _resolve_interactable(area: Area2D) -> Node:
	if area.has_method("interact"):
		return area

	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent

	return null
