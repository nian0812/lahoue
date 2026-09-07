extends Node

const truck_visual_scene: PackedScene = preload("res://scenes/vehicles/truck_visual.tscn")

signal delivery_completed(truck_index: int, item_id: String, amount: int, payout: int)
signal delivery_started(truck_index: int, item_id: String, amount: int)
signal truck_state_changed()

const max_trucks: int = 3

var truck_level: int = 1
var truck_count: int = 1
var deliveries: Array = []
var visual_trucks: Array = []

var visuals_initialized: bool = false

func _init_visuals_if_needed() -> void:
	if visuals_initialized: return
	var visuals_root: Node2D = _get_truck_visuals_root()
	if visuals_root == null or _get_truck_route() == null:
		return
	visuals_initialized = true
	
	for child in visuals_root.get_children():
		if child.name.begins_with("TruckVisual_"):
			child.queue_free()
			
	visual_trucks.clear()
	
	for i in range(max_trucks):
		var t: Node2D = truck_visual_scene.instantiate() as Node2D
		t.name = "TruckVisual_" + str(i)
		t.z_index = 50
		t.call("set_vehicle_level", truck_level)
		t.position = _get_truck_spawn_position(i)
		t.visible = (i < truck_count)
		visuals_root.add_child(t)
		visual_trucks.append(t)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_init_deliveries()
	if not game_manager.day_finishing.is_connected(_on_day_finishing):
		game_manager.day_finishing.connect(_on_day_finishing)

func _init_deliveries() -> void:
	deliveries.clear()
	for i in range(max_trucks):
		deliveries.append({})

func _process(delta: float) -> void:
	_init_visuals_if_needed()
	_refresh_visual_levels()
	if get_tree().paused:
		return
	var has_visuals: bool = (
		_get_truck_visuals_root() != null
		and visual_trucks.size() == max_trucks
	)

	for i in range(max_trucks):
		if has_visuals and i >= truck_count:
			visual_trucks[i].visible = false

	for i in range(truck_count):
		var d: Dictionary = deliveries[i]
		if d.is_empty():
			if has_visuals:
				visual_trucks[i].visible = true
				visual_trucks[i].position = _get_truck_spawn_position(i)
				visual_trucks[i].scale.x = 1.0
			continue
			
		var remaining: float = float(d.get("remaining", 0.0))
		var total_time: float = float(d.get("total_time", 1.0))
		remaining -= delta
		
		d["remaining"] = remaining
		
		var payout_done: bool = d.get("payout_done", false)
		if remaining <= 0.0 and not payout_done:
			d["payout_done"] = true
			_complete_delivery(i)
		
		var travel_time: float = get_visual_travel_time()
		
		if remaining <= -travel_time:
			if has_visuals:
				visual_trucks[i].visible = true
				visual_trucks[i].position = _get_truck_spawn_position(i)
				visual_trucks[i].scale.x = 1.0
			deliveries[i] = {}
			truck_state_changed.emit()
		else:
			if has_visuals:
				visual_trucks[i].visible = true
				var elapsed = total_time - remaining
				if elapsed < travel_time:
					var t = elapsed / travel_time
					visual_trucks[i].position = _get_truck_pos(t, i)
					visual_trucks[i].scale.x = 1.0
				elif remaining > 0.0:
					visual_trucks[i].position = _get_truck_pos(1.0, i)
					visual_trucks[i].scale.x = 1.0
				else:
					var return_elapsed = -remaining
					var t = return_elapsed / travel_time
					visual_trucks[i].position = _get_truck_pos(1.0 - t, i)
					visual_trucks[i].scale.x = -1.0

func get_truck_capacity() -> int:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 20
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return 20
	var level_data: Variant = (levels as Dictionary).get(str(truck_level), {})
	if typeof(level_data) != TYPE_DICTIONARY:
		return 20
	return int((level_data as Dictionary).get("capacity", 20))

func get_visual_speed() -> float:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 100.0
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return 100.0
	var level_data: Variant = (levels as Dictionary).get(str(truck_level), {})
	if typeof(level_data) != TYPE_DICTIONARY:
		return 100.0
	return float((level_data as Dictionary).get("visual_speed", 100.0))


func get_visual_travel_time() -> float:
	var zone: Node2D = _get_logistics_zone()
	if zone == null:
		return 0.0
	var distance: float = float(zone.get_meta("visual_travel_distance", 0.0))
	if distance <= 0.0:
		var route: Path2D = _get_truck_route()
		if route != null and route.curve != null:
			distance = route.curve.get_baked_length()
	var speed: float = get_visual_speed()
	return distance / speed if distance > 0.0 and speed > 0.0 else 0.0

func get_delivery_time() -> float:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 35.0
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return 35.0
	var level_data: Variant = (levels as Dictionary).get(str(truck_level), {})
	if typeof(level_data) != TYPE_DICTIONARY:
		return 35.0
	return float((level_data as Dictionary).get("delivery_time", 35))

func get_available_truck() -> int:
	# Returns index of first available truck, or -1
	for i in range(truck_count):
		if deliveries[i].is_empty():
			return i
	return -1

func has_available_truck() -> bool:
	return get_available_truck() >= 0

func is_truck_delivering(index: int) -> bool:
	if index < 0 or index >= max_trucks:
		return false
	return not deliveries[index].is_empty()

func get_truck_remaining(index: int) -> float:
	if index < 0 or index >= max_trucks:
		return 0.0
	return float(deliveries[index].get("remaining", 0.0))

func get_truck_delivery_info(index: int) -> Dictionary:
	if index < 0 or index >= max_trucks:
		return {}
	return deliveries[index].duplicate(true)

func dispatch_multiple(draft: Dictionary) -> bool:
	if draft.is_empty():
		return false
	var truck_idx: int = get_available_truck()
	if truck_idx < 0:
		return false
	
	var total_amount: int = 0
	var total_payout: int = 0
	for item_id in draft:
		var amount: int = int(draft[item_id])
		var sell_price: int = data_manager.get_item_sell_price(String(item_id))
		total_amount += amount
		total_payout += sell_price * amount
		
	# Check inventory first
	for item_id in draft:
		if not inventory_manager.has_item(String(item_id), int(draft[item_id])):
			return false
			
	# Remove items
	for item_id in draft:
		inventory_manager.remove_item(String(item_id), int(draft[item_id]))
		
	var delivery_time: float = get_delivery_time()
	deliveries[truck_idx] = {
		"items": draft.duplicate(true),
		"amount": total_amount,
		"payout": total_payout,
		"remaining": delivery_time,
		"total_time": delivery_time,
		"payout_done": false
	}
	
	var disp_item = "mixed_cargo"
	if draft.size() == 1:
		disp_item = String(draft.keys()[0])
	deliveries[truck_idx]["item_id"] = disp_item
	
	delivery_started.emit(truck_idx, disp_item, total_amount)
	truck_state_changed.emit()
	return true

func dispatch(item_id: String, amount: int) -> bool:
	if amount <= 0 or item_id.is_empty():
		return false
	var truck_idx: int = get_available_truck()
	if truck_idx < 0:
		return false
	# Validate item exists and has sell price
	var sell_price: int = data_manager.get_item_sell_price(item_id)
	if sell_price <= 0:
		return false
	# Check inventory
	if not inventory_manager.has_item(item_id, amount):
		return false
	# Remove item immediately
	if not inventory_manager.remove_item(item_id, amount):
		return false
	var total_payout: int = sell_price * amount
	var delivery_time: float = get_delivery_time()
	deliveries[truck_idx] = {
		"item_id": item_id,
		"amount": amount,
		"payout": total_payout,
		"remaining": delivery_time,
		"total_time": delivery_time
	}
	delivery_started.emit(truck_idx, item_id, amount)
	truck_state_changed.emit()
	return true

func _complete_delivery(truck_idx: int) -> void:
	var d: Dictionary = deliveries[truck_idx]
	if d.is_empty():
		return
	var item_id: String = String(d.get("item_id", ""))
	var amount: int = int(d.get("amount", 0))
	var payout: int = int(d.get("payout", 0))
	
	var received_payout: int = 0
	if payout > 0 and game_manager.add_money(payout):
		received_payout = payout
		game_manager.grant_sales_exp(payout)
	delivery_completed.emit(truck_idx, item_id, amount, received_payout)
	truck_state_changed.emit()

func get_truck_amount(index: int) -> int:
	if index < 0 or index >= max_trucks:
		return 0
	if deliveries[index].is_empty():
		return 0
	return int(deliveries[index].get("amount", 0))

func get_truck_phase(index: int) -> String:
	if index < 0 or index >= max_trucks:
		return "Ready"
	if deliveries[index].is_empty():
		return "Ready"
	var remaining: float = float(deliveries[index].get("remaining", 0.0))
	var total_time: float = float(deliveries[index].get("total_time", 1.0))
	var travel_time: float = get_visual_travel_time()
	var elapsed = total_time - remaining
	
	if elapsed < travel_time:
		return "Outbound"
	elif remaining > 0.0:
		return "Delivering"
	else:
		return "Returning"

# Upgrade truck level
func can_upgrade_truck() -> bool:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return false
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return false
	var next_level_data: Variant = (levels as Dictionary).get(str(truck_level + 1), {})
	if typeof(next_level_data) != TYPE_DICTIONARY:
		return false
	var cost: int = int((next_level_data as Dictionary).get("upgrade_cost", 0))
	var required_level: int = int((next_level_data as Dictionary).get("required_player_level", 0))
	return required_level > 0 and game_manager.level >= required_level and cost > 0 and game_manager.can_afford(cost)

func get_upgrade_cost() -> int:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 0
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return 0
	var next_level_data: Variant = (levels as Dictionary).get(str(truck_level + 1), {})
	if typeof(next_level_data) != TYPE_DICTIONARY:
		return 0
	return int((next_level_data as Dictionary).get("upgrade_cost", 0))

func get_max_truck_level() -> int:
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 1
	var levels: Variant = (truck_data as Dictionary).get("levels", {})
	if typeof(levels) != TYPE_DICTIONARY:
		return 1
	return (levels as Dictionary).size()

func upgrade_truck() -> bool:
	if not can_upgrade_truck():
		return false
	var cost: int = get_upgrade_cost()
	if not game_manager.spend_money(cost):
		return false
	truck_level += 1
	_refresh_visual_levels()
	truck_state_changed.emit()
	return true

# Buy additional truck
func can_buy_truck() -> bool:
	if truck_count >= max_trucks:
		return false
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return false
	var purchase_cost: Variant = (truck_data as Dictionary).get("purchase_cost", {})
	if typeof(purchase_cost) != TYPE_DICTIONARY:
		return false
	var next_truck: String = str(truck_count + 1)
	var cost: int = int((purchase_cost as Dictionary).get(next_truck, 0))
	return cost > 0 and game_manager.can_afford(cost)

func get_buy_truck_cost() -> int:
	if truck_count >= max_trucks:
		return 0
	var progression: Dictionary = data_manager.get_dataset("progression")
	var truck_data: Variant = progression.get("truck", {})
	if typeof(truck_data) != TYPE_DICTIONARY:
		return 0
	var purchase_cost: Variant = (truck_data as Dictionary).get("purchase_cost", {})
	if typeof(purchase_cost) != TYPE_DICTIONARY:
		return 0
	var next_truck: String = str(truck_count + 1)
	return int((purchase_cost as Dictionary).get(next_truck, 0))

func buy_truck() -> bool:
	if not can_buy_truck():
		return false
	var cost: int = get_buy_truck_cost()
	if not game_manager.spend_money(cost):
		return false
	truck_count += 1
	truck_state_changed.emit()
	return true

# Save / Load
func get_save_state() -> Dictionary:
	var delivery_states: Array = []
	for i in range(max_trucks):
		delivery_states.append(deliveries[i].duplicate(true))
	return {
		"truck_level": truck_level,
		"truck_count": truck_count,
		"deliveries": delivery_states
	}

func apply_save_state(state: Dictionary) -> void:
	truck_level = int(state.get("truck_level", 1))
	truck_count = int(state.get("truck_count", 1))
	truck_level = clampi(truck_level, 1, get_max_truck_level())
	truck_count = clampi(truck_count, 1, max_trucks)
	_init_deliveries()
	var saved_deliveries: Variant = state.get("deliveries", [])
	if typeof(saved_deliveries) == TYPE_ARRAY:
		for i in range(mini((saved_deliveries as Array).size(), max_trucks)):
			var d: Variant = (saved_deliveries as Array)[i]
			if typeof(d) == TYPE_DICTIONARY and not (d as Dictionary).is_empty():
				deliveries[i] = (d as Dictionary).duplicate(true)
	_refresh_visual_levels()
	truck_state_changed.emit()

func clear() -> void:
	truck_level = 1
	truck_count = 1
	_init_deliveries()
	_refresh_visual_levels()
	truck_state_changed.emit()


func _refresh_visual_levels() -> void:
	for truck_value: Variant in visual_trucks:
		var truck: Node = truck_value as Node
		if truck != null and truck.has_method("set_vehicle_level") and int(truck.get("vehicle_level")) != truck_level:
			truck.call("set_vehicle_level", truck_level)

func _on_day_finishing(day: int) -> void:
	var skipped_time: float = game_manager.day_duration - game_manager.day_timer
	for i in range(truck_count):
		var d: Dictionary = deliveries[i]
		if not d.is_empty():
			var remaining: float = float(d.get("remaining", 0.0))
			d["remaining"] = remaining - skipped_time

func _get_truck_pos(t: float, i: int) -> Vector2:
	var route: Path2D = _get_truck_route()
	if route == null or route.curve == null or route.curve.point_count == 0:
		return _get_truck_spawn_position(i)
	var route_length: float = route.curve.get_baked_length()
	var base_position: Vector2 = route.curve.sample_baked(
		clampf(t, 0.0, 1.0) * route_length
	)
	var first_position: Vector2 = route.curve.get_point_position(0)
	return base_position + _get_truck_spawn_position(i) - first_position


func _get_logistics_zone() -> Node2D:
	return get_parent().get_node_or_null("truck_road") as Node2D


func _get_truck_route() -> Path2D:
	var zone: Node2D = _get_logistics_zone()
	if zone == null:
		return null
	return zone.get_node_or_null("Paths/TruckRoute") as Path2D


func _get_truck_visuals_root() -> Node2D:
	var zone: Node2D = _get_logistics_zone()
	if zone == null:
		return null
	return zone.get_node_or_null("Paths/TruckVisuals") as Node2D


func _get_truck_spawn_position(index: int) -> Vector2:
	var zone: Node2D = _get_logistics_zone()
	var visuals_root: Node2D = _get_truck_visuals_root()
	if zone == null or visuals_root == null:
		return Vector2.ZERO
	var marker: Marker2D = zone.get_node_or_null(
		"NPCMarkers/TruckSpawn%02d" % (index + 1)
	) as Marker2D
	return (
		visuals_root.to_local(marker.global_position)
		if marker != null
		else Vector2.ZERO
	)
