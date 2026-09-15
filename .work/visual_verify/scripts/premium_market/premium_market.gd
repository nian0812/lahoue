extends LaHoueZoneRoot

signal market_interacted(player: Node)
signal shipment_started(cargo: Dictionary, total_cost: int)
signal shipment_arrived(cargo: Dictionary)
signal helicopter_state_changed(state: String)
signal helicopter_upgraded(level: int, cost: int)

const state_ready: String = "ready"
const state_departing: String = "departing"
const state_importing: String = "importing"
const state_returning: String = "returning"
const state_arrived: String = "arrived"
const valid_states: Array[String] = [
	state_ready,
	state_departing,
	state_importing,
	state_returning,
	state_arrived,
]

@export var building_id: String = "premium_market"

@onready var helicopter: Node2D = $helicopter
@onready var helipad_marker: Marker2D = $helipad_marker
@onready var takeoff_marker: Marker2D = $takeoff_marker
@onready var outside_marker: Marker2D = $outside_marker

var helicopter_level: int = 1
var current_state: String = state_ready
var active_shipment: Dictionary = {}
var phase_elapsed: float = 0.0
var last_error: String = ""


func _ready() -> void:
	super._ready()
	process_mode = PROCESS_MODE_ALWAYS
	if not game_manager.day_finishing.is_connected(_on_day_finishing):
		game_manager.day_finishing.connect(_on_day_finishing)
	_refresh_visual()


func _process(delta: float) -> void:
	if not game_manager.gameplay_active or get_tree().paused:
		return
	advance_delivery(delta)


func interact(player: Node) -> bool:
	market_interacted.emit(player)
	return true


func is_unlocked() -> bool:
	var unlock_level: int = data_manager.get_premium_market_unlock_level()
	var world: Node = get_parent().get_parent()
	return (
		unlock_level > 0
		and game_manager.level >= unlock_level
		and world != null
		and world.has_method("is_building_owned")
		and bool(world.call("is_building_owned", "international_license"))
		and bool(world.call("is_building_owned", "helipad"))
	)


func get_market_item_ids() -> Array[String]:
	return data_manager.get_premium_import_item_ids()


func get_capacity() -> int:
	return int(data_manager.get_helicopter_level_data(helicopter_level).get("capacity", 0))


func get_shipping_time() -> float:
	return float(data_manager.get_helicopter_level_data(helicopter_level).get("shipping_time", 0.0))


func get_visual_speed() -> float:
	return float(data_manager.get_helicopter_level_data(helicopter_level).get("visual_speed", 0.0))


func get_remaining_shipping_time() -> float:
	return float(active_shipment.get("shipping_remaining", 0.0))


func get_cargo_load(cargo: Dictionary) -> int:
	var total: int = 0
	for amount_value: Variant in cargo.values():
		if typeof(amount_value) != TYPE_INT:
			return -1
		var amount: int = int(amount_value)
		if amount <= 0:
			return -1
		total += amount
	return total


func calculate_import_cost(cargo: Dictionary) -> int:
	var total: int = 0
	for item_id_value: Variant in cargo:
		if typeof(item_id_value) != TYPE_STRING:
			return -1
		var item_id: String = String(item_id_value)
		if not get_market_item_ids().has(item_id):
			return -1
		var amount_value: Variant = cargo[item_id_value]
		if typeof(amount_value) != TYPE_INT or int(amount_value) <= 0:
			return -1
		var unit_price: int = data_manager.get_item_buy_price(item_id)
		if unit_price <= 0:
			return -1
		total += unit_price * int(amount_value)
	return total


func confirm_order(cargo: Dictionary) -> bool:
	last_error = ""
	if not is_unlocked():
		var world: Node = get_parent().get_parent()
		if game_manager.level < data_manager.get_premium_market_unlock_level():
			last_error = "Requires Level %d" % data_manager.get_premium_market_unlock_level()
		elif world == null or not bool(world.call("is_building_owned", "international_license")):
			last_error = "International Market License required"
		else:
			last_error = "Helipad + Helicopter required"
		return false
	if current_state != state_ready or not active_shipment.is_empty():
		last_error = "Shipment active"
		return false
	var cargo_copy: Dictionary = cargo.duplicate(true)
	var load: int = get_cargo_load(cargo_copy)
	if load <= 0:
		last_error = "Select import cargo first"
		return false
	if calculate_import_cost(cargo_copy) <= 0:
		last_error = "Import cargo is invalid"
		return false
	if load > get_capacity():
		last_error = "Helicopter capacity full"
		return false
	if not inventory_manager.can_add(load):
		last_error = "Warehouse capacity is insufficient"
		return false
	var total_cost: int = calculate_import_cost(cargo_copy)
	if not game_manager.can_afford(total_cost):
		last_error = "Not enough money"
		return false
	if not game_manager.spend_money(total_cost):
		last_error = "Could not confirm import payment"
		return false

	var shipping_time: float = get_shipping_time()
	active_shipment = {
		"items": cargo_copy,
		"total_cost": total_cost,
		"shipping_remaining": shipping_time,
		"shipping_total": shipping_time,
		"delivery_completed": false,
	}
	phase_elapsed = 0.0
	_set_state(state_departing)
	shipment_started.emit(cargo_copy.duplicate(true), total_cost)
	return true


func advance_delivery(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or active_shipment.is_empty():
		return false
	var remaining_delta: float = delta
	var advanced: bool = false
	var transitions: int = 0
	while remaining_delta > 0.0 and not active_shipment.is_empty() and transitions < 8:
		transitions += 1
		match current_state:
			state_departing:
				var departure_duration: float = _get_flight_duration()
				if departure_duration <= 0.0:
					return false
				if phase_elapsed >= departure_duration:
					phase_elapsed = 0.0
					_set_state(state_importing)
					continue
				var departure_step: float = minf(remaining_delta, departure_duration - phase_elapsed)
				phase_elapsed += departure_step
				remaining_delta -= departure_step
				advanced = true
				_refresh_visual()
				if phase_elapsed >= departure_duration:
					phase_elapsed = 0.0
					_set_state(state_importing)
			state_importing:
				var shipping_remaining: float = get_remaining_shipping_time()
				var shipping_step: float = minf(remaining_delta, shipping_remaining)
				active_shipment["shipping_remaining"] = maxf(shipping_remaining - shipping_step, 0.0)
				remaining_delta -= shipping_step
				advanced = true
				if get_remaining_shipping_time() <= 0.0:
					phase_elapsed = 0.0
					_set_state(state_returning)
			state_returning:
				var return_duration: float = _get_flight_duration()
				if return_duration <= 0.0:
					return false
				if phase_elapsed >= return_duration:
					phase_elapsed = 0.0
					_set_state(state_arrived)
					remaining_delta = 0.0
					continue
				var return_step: float = minf(remaining_delta, return_duration - phase_elapsed)
				phase_elapsed += return_step
				remaining_delta -= return_step
				advanced = true
				_refresh_visual()
				if phase_elapsed >= return_duration:
					phase_elapsed = 0.0
					_set_state(state_arrived)
					remaining_delta = 0.0
			state_arrived:
				advanced = _attempt_delivery() or advanced
				remaining_delta = 0.0
			_:
				return advanced
	return advanced


func get_status_text() -> String:
	match current_state:
		state_ready:
			return "Ready"
		state_departing:
			return "Departing"
		state_importing:
			return "Importing — %ds" % ceili(get_remaining_shipping_time())
		state_returning:
			return "Returning"
		state_arrived:
			var items: Dictionary = active_shipment.get("items", {}) as Dictionary
			var load: int = get_cargo_load(items)
			return (
				"Arrived"
				if load > 0 and inventory_manager.can_add(load)
				else "Arrived — Waiting for Warehouse Space"
			)
	return current_state.capitalize()


func get_upgrade_cost() -> int:
	if helicopter_level >= data_manager.get_max_helicopter_level():
		return 0
	return int(data_manager.get_helicopter_level_data(helicopter_level + 1).get("upgrade_cost", 0))


func can_upgrade_helicopter() -> bool:
	var cost: int = get_upgrade_cost()
	return (
		is_unlocked()
		and current_state == state_ready
		and active_shipment.is_empty()
		and cost > 0
		and game_manager.can_afford(cost)
	)


func upgrade_helicopter() -> bool:
	if not can_upgrade_helicopter():
		return false
	var cost: int = get_upgrade_cost()
	if not game_manager.spend_money(cost):
		return false
	helicopter_level += 1
	helicopter_upgraded.emit(helicopter_level, cost)
	helicopter_state_changed.emit(current_state)
	return true


func get_save_state() -> Dictionary:
	return {
		"helicopter_level": helicopter_level,
		"helicopter_state": current_state,
		"helicopter_phase_elapsed": phase_elapsed,
		"premium_import_shipment": active_shipment.duplicate(true),
	}


func apply_save_state(state: Dictionary) -> void:
	helicopter_level = int(state.get("helicopter_level", 1))
	current_state = String(state.get("helicopter_state", state_ready))
	phase_elapsed = float(state.get("helicopter_phase_elapsed", 0.0))
	var shipment_value: Variant = state.get("premium_import_shipment", {})
	active_shipment = (
		(shipment_value as Dictionary).duplicate(true)
		if typeof(shipment_value) == TYPE_DICTIONARY
		else {}
	)
	if active_shipment.is_empty():
		current_state = state_ready
		phase_elapsed = 0.0
	_refresh_visual()
	helicopter_state_changed.emit(current_state)


func clear() -> void:
	helicopter_level = 1
	current_state = state_ready
	active_shipment.clear()
	phase_elapsed = 0.0
	last_error = ""
	_refresh_visual()
	helicopter_state_changed.emit(current_state)


static func is_valid_state(value: String) -> bool:
	return valid_states.has(value)


func _attempt_delivery() -> bool:
	if current_state != state_arrived or active_shipment.is_empty():
		return false
	if bool(active_shipment.get("delivery_completed", false)):
		return false
	var items: Dictionary = active_shipment.get("items", {}) as Dictionary
	var load: int = get_cargo_load(items)
	if load <= 0 or not inventory_manager.can_add(load):
		last_error = "Waiting for Warehouse Space"
		return false
	if not inventory_manager.add_items_atomic(items):
		last_error = "Waiting for Warehouse Space"
		return false
	active_shipment["delivery_completed"] = true
	var delivered_cargo: Dictionary = items.duplicate(true)
	active_shipment.clear()
	phase_elapsed = 0.0
	last_error = ""
	_set_state(state_ready)
	shipment_arrived.emit(delivered_cargo)
	return true


func _set_state(value: String) -> void:
	current_state = value
	_refresh_visual()
	helicopter_state_changed.emit(current_state)


func _get_flight_duration() -> float:
	var route_distance: float = (
		helipad_marker.position.distance_to(takeoff_marker.position)
		+ takeoff_marker.position.distance_to(outside_marker.position)
	)
	var speed: float = get_visual_speed()
	return route_distance / speed if route_distance > 0.0 and speed > 0.0 else 0.0


func _get_route_position(progress: float) -> Vector2:
	var first_distance: float = helipad_marker.position.distance_to(takeoff_marker.position)
	var second_distance: float = takeoff_marker.position.distance_to(outside_marker.position)
	var total_distance: float = first_distance + second_distance
	if total_distance <= 0.0:
		return helipad_marker.position
	var traveled: float = clampf(progress, 0.0, 1.0) * total_distance
	if traveled <= first_distance:
		return helipad_marker.position.lerp(takeoff_marker.position, traveled / first_distance)
	return takeoff_marker.position.lerp(
		outside_marker.position,
		(traveled - first_distance) / second_distance
	)


func _refresh_visual() -> void:
	if not is_node_ready() or not is_instance_valid(helicopter):
		return
	if helicopter.has_method("set_vehicle_level") and int(helicopter.get("vehicle_level")) != helicopter_level:
		helicopter.call("set_vehicle_level", helicopter_level)
	var world: Node = get_parent().get_parent()
	var helipad_owned: bool = world != null and world.has_method("is_building_owned") and bool(world.call("is_building_owned", "helipad"))
	if not helipad_owned:
		helicopter.visible = false
		return
	var flight_duration: float = _get_flight_duration()
	match current_state:
		state_ready, state_arrived:
			helicopter.visible = true
			helicopter.position = helipad_marker.position
		state_departing:
			helicopter.visible = true
			helicopter.position = _get_route_position(phase_elapsed / flight_duration if flight_duration > 0.0 else 0.0)
		state_importing:
			helicopter.visible = false
			helicopter.position = outside_marker.position
		state_returning:
			helicopter.visible = true
			helicopter.position = _get_route_position(1.0 - phase_elapsed / flight_duration if flight_duration > 0.0 else 1.0)


func _on_day_finishing(_day: int) -> void:
	var skipped_time: float = game_manager.day_duration - game_manager.day_timer
	if skipped_time > 0.0:
		advance_delivery(skipped_time)
