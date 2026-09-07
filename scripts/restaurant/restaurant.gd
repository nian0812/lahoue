extends LaHoueZoneRoot

signal restaurant_interacted(player: Node)
signal availability_changed(is_available: bool)
signal revenue_collected(recipe_id: String, amount: int, total_revenue: int)
signal customer_spawned(customer_id: String)
signal customer_removed(customer_id: String)
signal cooking_started(customer_id: String, recipe_id: String)
signal food_ready(customer_id: String, recipe_id: String)
signal order_served(customer_id: String, recipe_id: String)
signal payment_collected(customer_id: String, recipe_id: String, total_revenue: int)
signal cooking_canceled(customer_id: String, recipe_id: String)
signal staff_hired(staff_id: String, staff_type_id: String, cost: int)
signal staff_job_assigned(staff_id: String, job_type: String, target_id: String)
signal staff_job_released(staff_id: String, job_type: String, target_id: String, succeeded: bool)
signal staff_payroll_processed(total_due: int, total_paid: int, outstanding_debt: int)
signal upgrade_purchased(system_id: String, level: int, cost: int, effect: int)

const state_locked: String = "locked"
const state_available: String = "available"
const cooking_state_cooking: String = "cooking"
const cooking_state_ready: String = "ready"
const cooking_state_served: String = "served"
const cooking_state_paid: String = "paid"
const valid_cooking_states: Array[String] = [
	cooking_state_cooking,
	cooking_state_ready,
	cooking_state_served,
	cooking_state_paid,
]
const customer_scene: PackedScene = preload("res://scenes/restaurant/customer.tscn")
const staff_scene: PackedScene = preload("res://scenes/restaurant/staff.tscn")
const restaurant_table_scene: PackedScene = preload("res://scenes/restaurant/restaurant_table.tscn")
const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")
const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")

@onready var building_visual: Polygon2D = $VisualRoot/building_visual
@onready var interaction_area: Area2D = $interaction_area
@onready var tables: Node2D = $tables
@onready var customers: Node2D = $customers
@onready var staffs: Node2D = $staffs

var current_state: String = state_locked
var restaurant_level: int = 0
var kitchen_level: int = 0
var tables_by_id: Dictionary = {}
var customers_by_id: Dictionary = {}
var cooking_jobs: Dictionary = {}
var staffs_by_id: Dictionary = {}
var staff_job_claims: Dictionary = {}
var menu_entries: Dictionary = {}
var is_configured: bool = false
var customer_sequence: int = 0
var customer_spawn_elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	_cache_tables()
	is_configured = _validate_configuration()
	if not game_manager.level_changed.is_connected(_on_level_changed):
		game_manager.level_changed.connect(_on_level_changed)
	if not game_manager.day_finishing.is_connected(_on_day_finishing):
		game_manager.day_finishing.connect(_on_day_finishing)
	refresh_availability()
	_connect_farm_tile_signals.call_deferred()


func _process(delta: float) -> void:
	if not is_available() or not game_manager.gameplay_active or get_tree().paused:
		return
	advance_cooking(delta)
	dispatch_staff_jobs()
	advance_staff(delta)
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
		var world: Node = get_parent()
		if world == null or not world.has_method("upgrade_system") or not bool(world.call("upgrade_system", "restaurant")):
			return false
	restaurant_interacted.emit(player)
	return true


func is_available() -> bool:
	return is_configured and current_state == state_available


func refresh_availability() -> void:
	var was_available: bool = current_state == state_available
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var world: Node = get_parent()
	var is_owned: bool = (
		world != null
		and world.has_method("is_building_owned")
		and bool(world.call("is_building_owned", "restaurant"))
	)
	if is_configured and is_owned and restaurant_level > 0 and unlock_level > 0 and game_manager.level >= unlock_level:
		kitchen_level = restaurant_level
		current_state = state_available
		menu_entries = data_manager.get_restaurant_menu(game_manager.level)
		_set_table_capacity(data_manager.get_restaurant_table_capacity(restaurant_level))
	else:
		if not is_owned:
			restaurant_level = 0
			kitchen_level = 0
		current_state = state_locked
		menu_entries.clear()
		_clear_staff()
		_clear_customers()
		cooking_jobs.clear()
		customer_spawn_elapsed = 0.0
		_reset_tables()
	_refresh_visual()
	if was_available != is_available():
		availability_changed.emit(is_available())


func get_menu_entries() -> Dictionary:
	return menu_entries.duplicate(true)


func get_upgrade_level(system_id: String) -> int:
	if system_id == "restaurant":
		return restaurant_level
	if system_id == "kitchen":
		return kitchen_level
	return 0


func can_upgrade_system(system_id: String) -> bool:
	if not is_available() or system_id != "restaurant":
		return false
	var current_level: int = get_upgrade_level(system_id)
	var target_level: int = current_level + 1
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	var required_player_level: int = data_manager.get_system_required_player_level(system_id, target_level)
	return (
		current_level > 0
		and required_player_level > 0
		and game_manager.level >= required_player_level
		and data_manager.get_progression_effect(system_id, target_level) > 0
		and cost > 0
		and game_manager.can_afford(cost)
	)


func upgrade_system(system_id: String) -> bool:
	if not can_upgrade_system(system_id):
		return false
	var current_level: int = get_upgrade_level(system_id)
	var target_level: int = current_level + 1
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	if not game_manager.spend_money(cost):
		return false
	var target_capacity: int = data_manager.get_restaurant_table_capacity(target_level)
	if not _set_table_capacity(target_capacity):
		_set_table_capacity(data_manager.get_restaurant_table_capacity(current_level))
		game_manager.add_money(cost)
		return false
	restaurant_level = target_level
	kitchen_level = target_level
	upgrade_purchased.emit(
		system_id,
		target_level,
		cost,
		data_manager.get_progression_effect(system_id, target_level)
	)
	return true


func get_menu_entry(recipe_id: String) -> Dictionary:
	var menu_entry_value: Variant = menu_entries.get(recipe_id)
	if typeof(menu_entry_value) != TYPE_DICTIONARY:
		return {}
	return (menu_entry_value as Dictionary).duplicate(true)


func _get_adjusted_recipe_price(recipe_id: String, base_price: int) -> int:
	if base_price <= 0:
		return 0
	var world: Node = get_parent()
	var multiplier: float = 1.0
	if world != null and world.has_method("get_recipe_payout_multiplier"):
		multiplier = float(world.call("get_recipe_payout_multiplier", recipe_id))
	return maxi(roundi(float(base_price) * maxf(multiplier, 1.0)), 1)


func collect_revenue(recipe_id: String, amount: int = 1) -> bool:
	if not is_available() or amount <= 0:
		return false
	var menu_entry: Dictionary = get_menu_entry(recipe_id)
	if menu_entry.is_empty():
		return false
	var unit_price: int = _get_adjusted_recipe_price(recipe_id, int(menu_entry.get("selling_price", 0)))
	if unit_price <= 0:
		return false
	if amount > game_manager.max_wallet_balance / unit_price:
		return false
	var total_revenue: int = unit_price * amount
	if not game_manager.add_money(total_revenue):
		return false
	game_manager.grant_sales_exp(total_revenue)
	revenue_collected.emit(recipe_id, amount, total_revenue)
	return true


func start_cooking(customer_id: String) -> bool:
	if not is_available() or cooking_jobs.has(customer_id):
		return false
	if _get_active_cooking_count() >= data_manager.get_kitchen_cooking_slots(kitchen_level):
		return false
	var customer: Node = get_customer(customer_id)
	if customer == null or String(customer.get("current_state")) != customer_script.state_waiting_food:
		return false
	var order: Dictionary = customer.get("order") as Dictionary
	if String(order.get("state", "")) != customer_script.order_state_pending:
		return false
	var recipe_id: String = String(order.get("recipe_id", ""))
	var quantity: int = int(order.get("quantity", 0))
	var menu_entry: Dictionary = get_menu_entry(recipe_id)
	if menu_entry.is_empty() or quantity <= 0:
		return false
	var speed_percent: int = data_manager.get_kitchen_speed_percent(kitchen_level)
	var base_duration: float = float(menu_entry.get("cooking_time_seconds", 0.0))
	var cooking_duration: float = base_duration * float(speed_percent) / 100.0
	if speed_percent <= 0 or not is_finite(cooking_duration) or cooking_duration <= 0.0:
		return false
	var required_items: Dictionary = _get_order_ingredients(menu_entry, quantity)
	if required_items.is_empty():
		return false
	cooking_jobs[customer_id] = {
		"recipe_id": recipe_id,
		"quantity": quantity,
		"state": cooking_state_cooking,
		"cooking_elapsed": 0.0,
		"cooking_duration": cooking_duration,
		"payment_collected": false,
	}
	if not inventory_manager.remove_items_atomic(required_items):
		cooking_jobs.erase(customer_id)
		return false
	cooking_started.emit(customer_id, recipe_id)
	return true


func advance_cooking(delta: float) -> bool:
	if not is_available() or not is_finite(delta) or delta <= 0.0:
		return false
	var advanced: bool = false
	for customer_id_value: Variant in cooking_jobs:
		var customer_id: String = String(customer_id_value)
		var job: Dictionary = cooking_jobs[customer_id] as Dictionary
		if String(job.get("state", "")) != cooking_state_cooking:
			continue
		var duration: float = float(job.get("cooking_duration", 0.0))
		var elapsed: float = minf(float(job.get("cooking_elapsed", 0.0)) + delta, duration)
		job["cooking_elapsed"] = elapsed
		advanced = true
		if elapsed >= duration:
			job["state"] = cooking_state_ready
			food_ready.emit(customer_id, String(job.get("recipe_id", "")))
	return advanced


func serve_order(customer_id: String) -> bool:
	var job: Dictionary = cooking_jobs.get(customer_id, {}) as Dictionary
	if String(job.get("state", "")) != cooking_state_ready:
		return false
	var customer: Node = get_customer(customer_id)
	if customer == null or not _job_matches_customer_order(job, customer):
		return false
	job["state"] = cooking_state_served
	if not bool(customer.call("mark_food_served")):
		job["state"] = cooking_state_ready
		return false
	order_served.emit(customer_id, String(job.get("recipe_id", "")))
	return true


func finish_customer_meal(customer_id: String) -> bool:
	var job: Dictionary = cooking_jobs.get(customer_id, {}) as Dictionary
	if String(job.get("state", "")) != cooking_state_served or bool(job.get("payment_collected", false)):
		return false
	var customer: Node = get_customer(customer_id)
	if customer == null or String(customer.get("current_state")) != customer_script.state_eating:
		return false
	if not _job_matches_customer_order(job, customer):
		return false
	var recipe_id: String = String(job.get("recipe_id", ""))
	var quantity: int = int(job.get("quantity", 0))
	var menu_entry: Dictionary = get_menu_entry(recipe_id)
	var unit_price: int = _get_adjusted_recipe_price(recipe_id, int(menu_entry.get("selling_price", 0)))
	if unit_price <= 0 or quantity <= 0 or quantity > game_manager.max_wallet_balance / unit_price:
		return false
	var total_revenue: int = unit_price * quantity
	if not game_manager.can_receive_money(total_revenue):
		return false
	job["state"] = cooking_state_paid
	job["payment_collected"] = true
	var requires_cleanup: bool = _has_cleanup_staff()
	if not bool(customer.call("finish_eating", requires_cleanup)):
		job["state"] = cooking_state_served
		job["payment_collected"] = false
		return false
	if not game_manager.add_money(total_revenue):
		job["state"] = cooking_state_served
		job["payment_collected"] = false
		return false
	game_manager.grant_sales_exp(total_revenue)
	revenue_collected.emit(recipe_id, quantity, total_revenue)
	payment_collected.emit(customer_id, recipe_id, total_revenue)
	return true


func get_cooking_job(customer_id: String) -> Dictionary:
	var job_value: Variant = cooking_jobs.get(customer_id)
	if typeof(job_value) != TYPE_DICTIONARY:
		return {}
	return (job_value as Dictionary).duplicate(true)


func hire_staff(new_staff_id: String, staff_type_id: String = "") -> Node:
	if not is_available() or not staff_script.is_valid_staff_id(new_staff_id) or staffs_by_id.has(new_staff_id):
		return null
	if staff_type_id.is_empty():
		staff_type_id = String(data_manager.get_staff_settings().get("default_staff_type", ""))
	var staff_data: Dictionary = data_manager.get_staff_type(staff_type_id)
	if staff_data.is_empty() or game_manager.level < int(staff_data.get("unlock_level", 0)):
		return null
	if get_staff_type_count(staff_type_id) >= int(staff_data.get("max_count", 0)):
		return null
	var hire_cost: int = int(staff_data.get("hire_cost", 0))
	if hire_cost <= 0 or not game_manager.spend_money(hire_cost):
		return null
	var staff: Node = staff_scene.instantiate()
	staff.name = new_staff_id
	var home_position: Vector2 = _get_staff_home_position(
		staff_type_id,
		get_staff_type_count(staff_type_id)
	)
	if not bool(staff.call("configure", new_staff_id, staff_type_id, self, home_position)):
		staff.free()
		game_manager.add_money(hire_cost)
		return null
	staff.position = home_position
	staffs.add_child(staff)
	staffs_by_id[new_staff_id] = staff
	staff_hired.emit(new_staff_id, staff_type_id, hire_cost)
	return staff


func assign_staff_job(staff_id: String, job_type: String, target_id: String) -> bool:
	var staff: Node = get_staff(staff_id)
	if staff == null or not staff_script.is_valid_job_type(job_type):
		return false
	var job_key: String = _get_staff_job_key(job_type, target_id)
	if staff_job_claims.has(job_key):
		return false
	var allow_waiter_cook_fallback: bool = _is_waiter_cook_fallback(staff, job_type)
	if not bool(staff.call("can_accept_job", job_type, allow_waiter_cook_fallback)) or not _is_staff_job_valid(job_type, target_id):
		return false
	var destination: Vector2 = _get_staff_job_destination(job_type, target_id)
	staff_job_claims[job_key] = staff_id
	if not bool(staff.call(
		"assign_job",
		{"job_type": job_type, "target_id": target_id},
		destination,
		allow_waiter_cook_fallback
	)):
		staff_job_claims.erase(job_key)
		return false
	staff_job_assigned.emit(staff_id, job_type, target_id)
	return true


func dispatch_staff_jobs() -> bool:
	if not is_available():
		return false
	_cancel_invalid_staff_jobs()
	var dispatched: bool = false
	var staff_ids: Array = staffs_by_id.keys()
	staff_ids.sort()
	for staff_id_value: Variant in staff_ids:
		var staff_id: String = String(staff_id_value)
		var staff: Node = get_staff(staff_id)
		if staff == null:
			continue
		var next_job: Dictionary = _find_next_staff_job(staff)
		if next_job.is_empty():
			continue
		dispatched = assign_staff_job(
			staff_id,
			String(next_job.get("job_type", "")),
			String(next_job.get("target_id", ""))
		) or dispatched
	return dispatched


func execute_staff_job(staff_id: String) -> bool:
	var staff: Node = get_staff(staff_id)
	if staff == null or not [
		staff_script.state_moving,
		staff_script.state_handling_order,
		staff_script.state_delivering_food,
		staff_script.state_harvesting,
		staff_script.state_collecting,
	].has(String(staff.get("current_state"))):
		return false
	var job: Dictionary = staff.get("active_job") as Dictionary
	var job_type: String = String(job.get("job_type", ""))
	var target_id: String = String(job.get("target_id", ""))
	var job_key: String = _get_staff_job_key(job_type, target_id)
	if not _staff_role_allows_job(staff, job_type):
		_release_staff_job(staff, false)
		return false
	if String(staff_job_claims.get(job_key, "")) != staff_id:
		_release_staff_job(staff, false)
		return false
	if String(staff.get("current_state")) == staff_script.state_moving and not bool(staff.call("begin_current_job")):
		_release_staff_job(staff, false)
		return false
	if not _is_staff_job_valid(job_type, target_id, job_key):
		_release_staff_job(staff, false)
		return false
	var succeeded: bool = false
	match job_type:
		staff_script.job_cook:
			succeeded = start_cooking(target_id)
		staff_script.job_serve:
			succeeded = serve_order(target_id)
		staff_script.job_payment:
			succeeded = finish_customer_meal(target_id)
		staff_script.job_clean:
			return true
		staff_script.job_harvest:
			var farm_tile: Node = _get_farm_tile(target_id)
			succeeded = farm_tile != null and bool(farm_tile.call("harvest"))
		staff_script.job_collect_animal:
			var animal: Node = _get_animal(target_id)
			succeeded = animal != null and bool(animal.call("collect_next_product"))
		staff_script.job_collect_aquaculture:
			var container: Node = _get_aquaculture_container(target_id)
			if container != null and bool(container.call("harvest_product")):
				succeeded = bool(container.call("start_cycle"))
		_:
			succeeded = false
	_release_staff_job(staff, succeeded)
	return succeeded


func complete_staff_cleaning(staff_id: String) -> bool:
	var staff: Node = get_staff(staff_id)
	if staff == null or String(staff.get("current_state")) != staff_script.state_cleaning_table:
		return false
	var job: Dictionary = staff.get("active_job") as Dictionary
	var target_id: String = String(job.get("target_id", ""))
	var job_key: String = _get_staff_job_key(staff_script.job_clean, target_id)
	if String(staff_job_claims.get(job_key, "")) != staff_id:
		_release_staff_job(staff, false)
		return false
	var table: Node = tables_by_id.get(target_id) as Node
	var succeeded: bool = (
		table != null
		and String(table.get("current_state")) == restaurant_table_script.state_needs_cleanup
		and bool(table.call("release_table"))
	)
	_release_staff_job(staff, succeeded)
	return succeeded


func advance_staff(delta: float) -> bool:
	if not is_available() or not is_finite(delta) or delta <= 0.0:
		return false
	_cancel_invalid_staff_jobs()
	var advanced: bool = false
	for staff_value: Variant in staffs_by_id.values():
		advanced = bool(staff_value.call("advance", delta)) or advanced
	return advanced


func get_staff(staff_id: String) -> Node:
	return staffs_by_id.get(staff_id) as Node


func has_staff(staff_id: String) -> bool:
	return staffs_by_id.has(staff_id)


func get_staff_type_count(staff_type_id: String) -> int:
	var count: int = 0
	for staff_value: Variant in staffs_by_id.values():
		if String(staff_value.get("staff_type_id")) == staff_type_id:
			count += 1
	return count


func get_staff_daily_payroll() -> int:
	var total: int = 0
	for staff_value: Variant in staffs_by_id.values():
		total += data_manager.get_staff_daily_salary(String(staff_value.get("staff_type_id")))
	return total


func get_staff_outstanding_debt() -> int:
	var total: int = 0
	for staff_value: Variant in staffs_by_id.values():
		total += maxi(int(staff_value.get("salary_debt")), 0)
	return total


func pay_staff_debts() -> int:
	var total_paid: int = 0
	var staff_ids: Array = staffs_by_id.keys()
	staff_ids.sort()
	for staff_id_value: Variant in staff_ids:
		var staff: Node = staffs_by_id.get(String(staff_id_value)) as Node
		if staff == null:
			continue
		var debt: int = maxi(int(staff.get("salary_debt")), 0)
		if debt <= 0:
			staff.call("set_payroll_status", true, 0)
			continue
		if not game_manager.spend_money(debt):
			if not (staff.get("active_job") as Dictionary).is_empty():
				_release_staff_job(staff, false)
			staff.call("set_payroll_status", false, debt)
			continue
		staff.call("set_payroll_status", true, 0)
		total_paid += debt
	return total_paid


func mark_customer_table_for_cleanup(customer_id: String, table_id: String) -> bool:
	var table: Node = tables_by_id.get(table_id) as Node
	if table == null or String(table.get("occupant_id")) != customer_id:
		return false
	return bool(table.call("mark_needs_cleanup"))


static func is_valid_cooking_state(value: String) -> bool:
	return valid_cooking_states.has(value)


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
	_connect_customer_signals(customer)
	if generated_id:
		customer_sequence += 1
	customer_spawned.emit(new_customer_id)
	call_deferred("_begin_customer_visit", new_customer_id)
	return customer


func remove_customer(customer_id: String) -> bool:
	var customer: Node = customers_by_id.get(customer_id) as Node
	if customer == null:
		return false
	_cancel_staff_jobs_for_target(customer_id)
	var assigned_table_id: String = String(customer.get("table_id"))
	if not assigned_table_id.is_empty():
		release_customer_table(customer_id, assigned_table_id)
	var removed_job: Dictionary = cooking_jobs.get(customer_id, {}) as Dictionary
	if not removed_job.is_empty() and String(removed_job.get("state", "")) != cooking_state_paid:
		cooking_canceled.emit(customer_id, String(removed_job.get("recipe_id", "")))
	cooking_jobs.erase(customer_id)
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
	var staff_states: Dictionary = {}
	for staff_id_value: Variant in staffs_by_id:
		var staff_id: String = String(staff_id_value)
		staff_states[staff_id] = staffs_by_id[staff_id].call("get_save_state")
	return {
		"restaurant_level": restaurant_level,
		"kitchen_level": kitchen_level,
		"restaurant_tables": table_states,
		"restaurant_customers": customer_states,
		"restaurant_customer_sequence": customer_sequence,
		"restaurant_spawn_elapsed": customer_spawn_elapsed,
		"restaurant_cooking": cooking_jobs.duplicate(true),
		"staff": staff_states,
	}


func apply_save_state(saved_state: Dictionary) -> void:
	restaurant_level = int(saved_state.get("restaurant_level", 0))
	kitchen_level = int(saved_state.get("kitchen_level", 0))
	_clear_staff()
	_clear_customers()
	cooking_jobs.clear()
	var saved_capacity: int = data_manager.get_restaurant_table_capacity(maxi(restaurant_level, 1))
	if not _set_table_capacity(saved_capacity):
		push_error("restaurant: failed to restore table capacity for level %d" % restaurant_level)
		return
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
		_connect_customer_signals(customer)
		var customer_state_name: String = String(customer.get("current_state"))
		if customer_state_name == customer_script.state_enter or customer_state_name == customer_script.state_seated or customer_state_name == customer_script.state_ordering:
			call_deferred("_resume_customer_visit", customer_id)
	var saved_cooking_value: Variant = saved_state.get("restaurant_cooking", {})
	if typeof(saved_cooking_value) == TYPE_DICTIONARY:
		for customer_id_value: Variant in saved_cooking_value as Dictionary:
			var customer_id: String = String(customer_id_value)
			if not customers_by_id.has(customer_id):
				continue
			var job_value: Variant = (saved_cooking_value as Dictionary)[customer_id_value]
			if typeof(job_value) == TYPE_DICTIONARY:
				cooking_jobs[customer_id] = (job_value as Dictionary).duplicate(true)
	_restore_staff(saved_state.get("staff", {}) as Dictionary)


func has_table(table_id: String) -> bool:
	if tables_by_id.has(table_id):
		return true
	var maximum_level: int = data_manager.get_progression_max_level("restaurant")
	var maximum_tables: int = data_manager.get_restaurant_table_capacity(maximum_level)
	for table_number: int in range(1, maximum_tables + 1):
		if table_id == "table_%02d" % table_number:
			return true
	return false


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
		and data_manager.get_kitchen_cooking_slots(1) > 0
		and data_manager.get_kitchen_speed_percent(1) > 0
		and not data_manager.get_staff_settings().is_empty()
	)


func _reset_tables() -> void:
	for table_value: Variant in tables_by_id.values():
		table_value.call("reset_table")


func _set_table_capacity(target_capacity: int) -> bool:
	if target_capacity <= 0:
		return false
	for table_number: int in range(tables_by_id.size(), target_capacity):
		var next_number: int = table_number + 1
		var table_id: String = "table_%02d" % next_number
		if tables_by_id.has(table_id):
			continue
		var table: Node = restaurant_table_scene.instantiate()
		table.name = table_id
		table.set("table_id", table_id)
		table.position = _get_upgrade_table_position(next_number)
		tables.add_child(table)
		if not table.has_method("get_save_state") or not table.has_method("reset_table"):
			table.free()
			return false
		tables_by_id[table_id] = table
	for table_id_value: Variant in tables_by_id.keys():
		var table_id: String = String(table_id_value)
		var number_text: String = table_id.trim_prefix("table_")
		if number_text.is_valid_int() and int(number_text) > target_capacity:
			var removed_table: Node = tables_by_id.get(table_id) as Node
			tables_by_id.erase(table_id)
			if removed_table != null and is_instance_valid(removed_table):
				removed_table.free()
	return tables_by_id.size() == target_capacity


func _get_upgrade_table_position(table_number: int) -> Vector2:
	var slot: Marker2D = get_node_or_null(
		"ExpansionAnchors/TableSlots/TableSlot%02d" % table_number
	) as Marker2D
	return slot.position if slot != null else $staff_home_marker.position


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
	
	if not customer.is_connected("arrived_at_table", _on_customer_arrived_at_table):
		customer.connect("arrived_at_table", _on_customer_arrived_at_table)
		
	var seat_pos: Vector2 = to_local((table.get_node("seat_marker") as Marker2D).global_position)
	var arr: Array[Vector2] = []
	var entry_route: Path2D = get_route("CustomerEntryRoute")
	if entry_route != null and entry_route.curve != null:
		for point_index: int in range(entry_route.curve.point_count):
			arr.append(entry_route.position + entry_route.curve.get_point_position(point_index))
	if arr.is_empty():
		arr.append($customer_queue_marker.position)
	arr.append(seat_pos)
	customer.position = arr[0]
	customer.set("is_walking_in", true)
	customer.set("walk_path", arr)


func get_customer_exit_route() -> Array[Vector2]:
	var exit_route: Array[Vector2] = []
	var entry_route: Path2D = get_route("CustomerEntryRoute")
	if entry_route == null or entry_route.curve == null:
		exit_route.append($entrance_marker.position)
		return exit_route
	for point_index: int in range(entry_route.curve.point_count - 1, -1, -1):
		exit_route.append(
			entry_route.position + entry_route.curve.get_point_position(point_index)
		)
	return exit_route

func _on_customer_arrived_at_table(customer_id: String) -> void:
	var customer: Node = customers_by_id.get(customer_id) as Node
	if customer == null:
		return
	var table_id: String = String(customer.get("table_id"))
	var table: Node = tables_by_id.get(table_id) as Node
	if table == null:
		return
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
		
	if customer.get("is_walking_out"):
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
	if customer.get("is_walking_in"):
		if not customer.is_connected("arrived_at_table", _on_customer_arrived_at_table):
			customer.connect("arrived_at_table", _on_customer_arrived_at_table)
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
		if recipe_ids.is_empty():
			return false
		recipe_id = String(recipe_ids.pick_random())
	return bool(customer.call("create_order", recipe_id, quantity))


func _get_order_ingredients(menu_entry: Dictionary, quantity: int) -> Dictionary:
	var ingredients_value: Variant = menu_entry.get("ingredients", {})
	if quantity <= 0 or typeof(ingredients_value) != TYPE_DICTIONARY:
		return {}
	var required_items: Dictionary = {}
	for item_id_value: Variant in ingredients_value as Dictionary:
		var item_id: String = String(item_id_value)
		var amount: int = int((ingredients_value as Dictionary)[item_id_value])
		if amount <= 0 or quantity > game_manager.max_wallet_balance / amount:
			return {}
		required_items[item_id] = amount * quantity
	return required_items


func _job_matches_customer_order(job: Dictionary, customer: Node) -> bool:
	var order: Dictionary = customer.get("order") as Dictionary
	return (
		String(job.get("recipe_id", "")) == String(order.get("recipe_id", ""))
		and int(job.get("quantity", 0)) == int(order.get("quantity", 0))
	)


func _get_active_cooking_count() -> int:
	var count: int = 0
	for job_value: Variant in cooking_jobs.values():
		if String(job_value.get("state", "")) == cooking_state_cooking:
			count += 1
	return count


func _is_staff_job_valid(job_type: String, target_id: String, ignored_claim_key: String = "") -> bool:
	if target_id.is_empty():
		return false
	if job_type == staff_script.job_clean:
		var table: Node = tables_by_id.get(target_id) as Node
		return table != null and String(table.get("current_state")) == restaurant_table_script.state_needs_cleanup
	if job_type == staff_script.job_harvest:
		var farm_tile: Node = _get_farm_tile(target_id)
		if farm_tile == null or not bool(farm_tile.call("is_ready")):
			return false
		var crop_data_value: Variant = data_manager.get_entry("crops", String(farm_tile.get("crop_id")))
		if typeof(crop_data_value) != TYPE_DICTIONARY:
			return false
		var crop_data: Dictionary = crop_data_value as Dictionary
		return inventory_manager.can_add_item(
			String(crop_data.get("harvest_item", "")),
			int(crop_data.get("yield", 0))
		)
	if job_type == staff_script.job_collect_animal:
		var animal: Node = _get_animal(target_id)
		if animal == null:
			return false
		var pending_products: Array = animal.call("get_pending_products") as Array
		if pending_products.is_empty() or typeof(pending_products[0]) != TYPE_DICTIONARY:
			return false
		var product: Dictionary = pending_products[0] as Dictionary
		return inventory_manager.can_add_item(
			String(product.get("item_id", "")),
			int(product.get("amount", 0))
		)
	if job_type == staff_script.job_collect_aquaculture:
		var container: Node = _get_aquaculture_container(target_id)
		if container == null or String(container.get("current_state")) != aquaculture_container_script.state_ready:
			return false
		var pending_product: Dictionary = container.get("pending_product") as Dictionary
		return inventory_manager.can_add_item(
			String(pending_product.get("item_id", "")),
			int(pending_product.get("amount", 0))
		)
	var customer: Node = get_customer(target_id)
	if customer == null:
		return false
	var customer_state: String = String(customer.get("current_state"))
	var order: Dictionary = customer.get("order") as Dictionary
	var cooking_job: Dictionary = cooking_jobs.get(target_id, {}) as Dictionary
	match job_type:
		staff_script.job_cook:
			return (
				customer_state == customer_script.state_waiting_food
				and String(order.get("state", "")) == customer_script.order_state_pending
				and cooking_job.is_empty()
				and _has_staff_cooking_capacity(ignored_claim_key)
				and _has_staff_cooking_ingredients(target_id, ignored_claim_key)
			)
		staff_script.job_serve:
			return String(cooking_job.get("state", "")) == cooking_state_ready
		staff_script.job_payment:
			return (
				customer_state == customer_script.state_eating
				and String(cooking_job.get("state", "")) == cooking_state_served
				and not bool(cooking_job.get("payment_collected", false))
			)
	return false


func _find_next_staff_job(staff: Node) -> Dictionary:
	var job_priority: Array[String] = [
		staff_script.job_serve,
		staff_script.job_payment,
		staff_script.job_cook,
		staff_script.job_clean,
		staff_script.job_harvest,
		staff_script.job_collect_animal,
		staff_script.job_collect_aquaculture,
	]
	for job_type: String in job_priority:
		if not _can_staff_accept_job(staff, job_type):
			continue
		var target_ids: Array = _get_staff_job_target_ids(job_type)
		target_ids.sort()
		for target_id_value: Variant in target_ids:
			var target_id: String = String(target_id_value)
			if staff_job_claims.has(_get_staff_job_key(job_type, target_id)):
				continue
			if _is_staff_job_valid(job_type, target_id):
				return {"job_type": job_type, "target_id": target_id}
	return {}


func _get_staff_job_target_ids(job_type: String) -> Array:
	if job_type == staff_script.job_clean:
		return tables_by_id.keys()
	if job_type == staff_script.job_harvest:
		var world: Node = get_parent()
		if world != null:
			var farm_tiles_value: Variant = world.get("farm_tiles_by_id")
			if typeof(farm_tiles_value) == TYPE_DICTIONARY:
				return (farm_tiles_value as Dictionary).keys()
		return []
	if job_type == staff_script.job_collect_animal:
		var world: Node = get_parent()
		if world != null:
			var animals_value: Variant = world.get("animals_by_id")
			if typeof(animals_value) == TYPE_DICTIONARY:
				return (animals_value as Dictionary).keys()
		return []
	if job_type == staff_script.job_collect_aquaculture:
		var world: Node = get_parent()
		if world != null:
			var containers_value: Variant = world.get("aquaculture_containers_by_id")
			if typeof(containers_value) == TYPE_DICTIONARY:
				return (containers_value as Dictionary).keys()
		return []
	return customers_by_id.keys()


func _can_staff_accept_job(staff: Node, job_type: String) -> bool:
	return bool(staff.call("can_accept_job", job_type, _is_waiter_cook_fallback(staff, job_type)))


func _staff_role_allows_job(staff: Node, job_type: String) -> bool:
	return (staff.get("allowed_jobs") as Array).has(job_type) or _is_waiter_cook_fallback(staff, job_type)


func _is_waiter_cook_fallback(staff: Node, job_type: String) -> bool:
	return (
		job_type == staff_script.job_cook
		and String(staff.get("staff_type_id")) == "waiter"
		and get_staff_type_count("chef") == 0
	)


func _has_staff_cooking_capacity(ignored_claim_key: String = "") -> bool:
	var claimed_cooks: int = 0
	for job_key_value: Variant in staff_job_claims:
		var job_key: String = String(job_key_value)
		if job_key == ignored_claim_key:
			continue
		if job_key.begins_with(staff_script.job_cook + ":"):
			claimed_cooks += 1
	return _get_active_cooking_count() + claimed_cooks < data_manager.get_kitchen_cooking_slots(kitchen_level)


func _has_staff_cooking_ingredients(target_id: String, ignored_claim_key: String = "") -> bool:
	var customer: Node = get_customer(target_id)
	if customer == null:
		return false
	var order: Dictionary = customer.get("order") as Dictionary
	var menu_entry: Dictionary = get_menu_entry(String(order.get("recipe_id", "")))
	var required_items: Dictionary = _get_order_ingredients(menu_entry, int(order.get("quantity", 0)))
	if required_items.is_empty():
		return false
	var reserved_items: Dictionary = _get_claimed_cooking_ingredients(ignored_claim_key)
	for item_id_value: Variant in required_items:
		var item_id: String = String(item_id_value)
		var required_amount: int = int(required_items[item_id_value]) + int(reserved_items.get(item_id, 0))
		if inventory_manager.get_amount(item_id) < required_amount:
			return false
	return true


func _get_claimed_cooking_ingredients(ignored_claim_key: String = "") -> Dictionary:
	var reserved_items: Dictionary = {}
	for job_key_value: Variant in staff_job_claims:
		var job_key: String = String(job_key_value)
		if job_key == ignored_claim_key or not job_key.begins_with(staff_script.job_cook + ":"):
			continue
		var target_id: String = job_key.trim_prefix(staff_script.job_cook + ":")
		var customer: Node = get_customer(target_id)
		if customer == null:
			continue
		var order: Dictionary = customer.get("order") as Dictionary
		var menu_entry: Dictionary = get_menu_entry(String(order.get("recipe_id", "")))
		var requirements: Dictionary = _get_order_ingredients(menu_entry, int(order.get("quantity", 0)))
		for item_id_value: Variant in requirements:
			var item_id: String = String(item_id_value)
			reserved_items[item_id] = int(reserved_items.get(item_id, 0)) + int(requirements[item_id_value])
	return reserved_items


func _get_staff_job_destination(job_type: String, target_id: String) -> Vector2:
	if job_type == staff_script.job_cook:
		return $kitchen_station_marker.position
	if job_type == staff_script.job_clean:
		var clean_table: Node = tables_by_id.get(target_id) as Node
		return clean_table.position if clean_table != null else $staff_home_marker.position
	if job_type == staff_script.job_harvest:
		var farm_tile: Node2D = _get_farm_tile(target_id) as Node2D
		return to_local(farm_tile.global_position) if farm_tile != null else $staff_home_marker.position
	if job_type == staff_script.job_collect_animal:
		var animal: Node2D = _get_animal(target_id) as Node2D
		return to_local(animal.global_position) if animal != null else $staff_home_marker.position
	if job_type == staff_script.job_collect_aquaculture:
		var container: Node2D = _get_aquaculture_container(target_id) as Node2D
		return to_local(container.global_position) if container != null else $staff_home_marker.position
	var customer: Node = get_customer(target_id)
	if customer == null:
		return $staff_home_marker.position
	var table: Node = tables_by_id.get(String(customer.get("table_id"))) as Node
	return table.position if table != null else customer.position


func _get_staff_job_key(job_type: String, target_id: String) -> String:
	return "%s:%s" % [job_type, target_id]


func _release_staff_job(staff: Node, succeeded: bool) -> void:
	if staff == null:
		return
	var job: Dictionary = (staff.get("active_job") as Dictionary).duplicate(true)
	var staff_id: String = String(staff.get("staff_id"))
	var job_type: String = String(job.get("job_type", ""))
	var target_id: String = String(job.get("target_id", ""))
	staff_job_claims.erase(_get_staff_job_key(job_type, target_id))
	staff.call("finish_current_job", succeeded)
	staff_job_released.emit(staff_id, job_type, target_id, succeeded)


func _has_cleanup_staff() -> bool:
	for staff_value: Variant in staffs_by_id.values():
		if (staff_value.get("allowed_jobs") as Array).has(staff_script.job_clean):
			return true
	return false


func _restore_staff(saved_staff: Dictionary) -> void:
	var staff_ids: Array = saved_staff.keys()
	staff_ids.sort()
	for staff_id_value: Variant in staff_ids:
		var staff_id: String = String(staff_id_value)
		var staff_state_value: Variant = saved_staff[staff_id_value]
		if typeof(staff_state_value) != TYPE_DICTIONARY:
			continue
		var staff_state: Dictionary = staff_state_value as Dictionary
		var staff: Node = staff_scene.instantiate()
		staff.name = staff_id
		staff.set("staff_id", staff_id)
		staffs.add_child(staff)
		var active_job: Dictionary = staff_state.get("active_job", {}) as Dictionary
		var staff_type_id: String = String(staff_state.get(
			"staff_type_id",
			data_manager.get_staff_settings().get("default_staff_type", "waiter")
		))
		if staff_type_id.is_empty():
			staff_type_id = "waiter"
		var home_position: Vector2 = _get_staff_home_position(
			staff_type_id,
			get_staff_type_count(staff_type_id)
		)
		var destination: Vector2 = home_position
		if not active_job.is_empty():
			destination = _get_staff_job_destination(
				String(active_job.get("job_type", "")),
				String(active_job.get("target_id", ""))
			)
		if not bool(staff.call("restore_saved_state", staff_state, self, destination, home_position)):
			staff.free()
			continue
		staffs_by_id[staff_id] = staff
		if not active_job.is_empty():
			var job_type: String = String(active_job.get("job_type", ""))
			var target_id: String = String(active_job.get("target_id", ""))
			staff_job_claims[_get_staff_job_key(job_type, target_id)] = staff_id
	_cancel_invalid_staff_jobs()


func _get_staff_home_position(staff_type_id: String, role_index: int) -> Vector2:
	var world: Node = get_parent()
	if world != null and world.has_method("get_staff_home_global_position"):
		var global_home: Variant = world.call(
			"get_staff_home_global_position",
			staff_type_id,
			role_index
		)
		if global_home is Vector2:
			return to_local(global_home as Vector2)
	var local_prefix: String = "ChefHome" if staff_type_id == "chef" else "WaiterHome"
	var local_marker: Marker2D = get_npc_marker(
		"%s%02d" % [local_prefix, role_index + 1]
	)
	return local_marker.position if local_marker != null else $staff_home_marker.position


func _get_farm_tile(tile_id: String) -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var farm_tiles_value: Variant = world.get("farm_tiles_by_id")
	if typeof(farm_tiles_value) != TYPE_DICTIONARY:
		return null
	return (farm_tiles_value as Dictionary).get(tile_id) as Node


func _get_animal(instance_id: String) -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var animals_value: Variant = world.get("animals_by_id")
	if typeof(animals_value) != TYPE_DICTIONARY:
		return null
	return (animals_value as Dictionary).get(instance_id) as Node


func _get_aquaculture_container(container_id: String) -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var containers_value: Variant = world.get("aquaculture_containers_by_id")
	if typeof(containers_value) != TYPE_DICTIONARY:
		return null
	return (containers_value as Dictionary).get(container_id) as Node


func _connect_farm_tile_signals() -> void:
	for tile_id_value: Variant in _get_staff_job_target_ids(staff_script.job_harvest):
		var farm_tile: Node = _get_farm_tile(String(tile_id_value))
		if farm_tile != null and not farm_tile.is_connected("state_changed", _on_farm_tile_state_changed):
			farm_tile.connect("state_changed", _on_farm_tile_state_changed)


func _on_farm_tile_state_changed(_tile_id: String, _state: int) -> void:
	_cancel_invalid_staff_jobs.call_deferred()


func _cancel_invalid_staff_jobs() -> void:
	for staff_value: Variant in staffs_by_id.values():
		var staff: Node = staff_value as Node
		var active_job: Dictionary = staff.get("active_job") as Dictionary
		if active_job.is_empty():
			continue
		var job_type: String = String(active_job.get("job_type", ""))
		var target_id: String = String(active_job.get("target_id", ""))
		var job_key: String = _get_staff_job_key(job_type, target_id)
		if not _staff_role_allows_job(staff, job_type) or not _is_staff_job_valid(job_type, target_id, job_key):
			_release_staff_job(staff, false)


func _connect_customer_signals(customer: Node) -> void:
	var callback: Callable = _on_customer_order_failed
	if not customer.is_connected("order_failed", callback):
		customer.connect("order_failed", callback)


func _on_customer_order_failed(customer_id: String, order: Dictionary, _reason: String) -> void:
	_cancel_staff_jobs_for_target(customer_id)
	var job: Dictionary = cooking_jobs.get(customer_id, {}) as Dictionary
	if job.is_empty():
		return
	if String(job.get("recipe_id", "")) != String(order.get("recipe_id", "")):
		return
	cooking_jobs.erase(customer_id)
	cooking_canceled.emit(customer_id, String(job.get("recipe_id", "")))


func _cancel_staff_jobs_for_target(target_id: String) -> void:
	for staff_value: Variant in staffs_by_id.values():
		var active_job: Dictionary = staff_value.get("active_job") as Dictionary
		if String(active_job.get("target_id", "")) == target_id:
			_release_staff_job(staff_value as Node, false)


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


func _clear_staff() -> void:
	for staff_value: Variant in staffs_by_id.values():
		if staff_value != null and is_instance_valid(staff_value):
			staff_value.free()
	staffs_by_id.clear()
	staff_job_claims.clear()


func _on_level_changed(_level: int) -> void:
	refresh_availability()


func _on_day_finishing(_day: int) -> void:
	var total_due: int = 0
	for staff_value: Variant in staffs_by_id.values():
		var salary: int = data_manager.get_staff_daily_salary(String(staff_value.get("staff_type_id")))
		if salary <= 0:
			continue
		staff_value.set("salary_debt", maxi(int(staff_value.get("salary_debt")), 0) + salary)
		total_due += salary
	var total_paid: int = pay_staff_debts()
	staff_payroll_processed.emit(total_due, total_paid, get_staff_outstanding_debt())


func _refresh_visual() -> void:
	if not is_instance_valid(building_visual) or not is_instance_valid(interaction_area) or not is_instance_valid(tables):
		return
	var available: bool = is_available()
	building_visual.color = Color("#a85d3d") if available else Color("#55504c")
	var artwork_root: Node = get_node_or_null("VisualRoot")
	if artwork_root != null and artwork_root.has_method("set_artwork_enabled"):
		artwork_root.call("set_artwork_enabled", available)
	tables.visible = available
