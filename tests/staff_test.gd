extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")

var failures: int = 0
var observed_states: Array[String] = []

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_staff_test"):
		push_error("staff_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	var restaurant: Node = world.get_node("restaurant")
	var staff_data: Dictionary = data_manager.get_staff_type("waiter")
	_expect(not staff_data.is_empty(), "waiter data did not load from staff.json/progression.json")
	_expect(int(staff_data.get("hire_cost", 0)) == 40000, "waiter hire cost did not use progression staff data")
	_expect(int(staff_data.get("unlock_level", 0)) == data_manager.get_restaurant_unlock_level(), "waiter unlock level is inconsistent")
	_expect((staff_data.get("allowed_jobs", []) as Array).has(staff_script.job_clean), "waiter job capability data is incomplete")
	_expect(restaurant.call("hire_staff", "locked_waiter", "waiter") == null, "locked restaurant hired staff")

	_unlock_restaurant()
	var hire_cost: int = int(staff_data.get("hire_cost", 0))
	_expect(restaurant.call("hire_staff", "poor_waiter", "waiter") == null, "staff hire succeeded without funds")
	_expect(game_manager.get_wallet_balance() == 0, "failed hire made wallet negative")
	_expect(game_manager.add_money(hire_cost * 3), "staff wallet fixture could not be funded")
	var staff_01: Node = restaurant.call("hire_staff", "waiter_01", "waiter") as Node
	_expect(staff_01 != null, "staff spawn/hire failed")
	if staff_01 == null:
		_finish_tests()
		return
	var wallet_after_first_hire: int = game_manager.get_wallet_balance()
	_expect(wallet_after_first_hire == hire_cost * 2, "staff hire charged the wrong amount")
	_expect(restaurant.call("hire_staff", "waiter_01", "waiter") == null, "duplicate staff id was hired")
	_expect(game_manager.get_wallet_balance() == wallet_after_first_hire, "duplicate hire changed wallet")
	_expect(restaurant.call("hire_staff", "unknown_staff", "unknown") == null, "unknown staff type was hired")
	var staff_02: Node = restaurant.call("hire_staff", "waiter_02", "waiter") as Node
	_expect(staff_02 != null, "second staff fixture could not be hired")
	_expect(String(staff_01.get("current_state")) == staff_script.state_idle, "new staff did not start IDLE")
	staff_01.connect("state_changed", _on_staff_state_changed)

	var customer: Node = restaurant.call("spawn_customer", "staff_customer", "garlic_egg_rice") as Node
	_expect(customer != null, "staff customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(customer != null and String(customer.get("current_state")) == customer_script.state_waiting_food, "staff customer has no pending order")
	_expect(inventory_manager.add_item("rice", 1), "rice fixture could not be added")
	_expect(inventory_manager.add_item("egg", 1), "egg fixture could not be added")

	_expect(bool(restaurant.call("assign_staff_job", "waiter_01", staff_script.job_cook, "staff_customer")), "cook job assignment failed")
	_expect(String(staff_01.get("current_state")) == staff_script.state_moving, "assigned staff did not enter MOVING")
	_expect(not bool(restaurant.call("assign_staff_job", "waiter_02", staff_script.job_cook, "staff_customer")), "two staff claimed the same cook job")
	_expect(bool(restaurant.call("advance_staff", 2.0)), "staff did not move to the kitchen")
	_expect(not (restaurant.call("get_cooking_job", "staff_customer") as Dictionary).is_empty(), "handling order did not start Phase 9 cooking")
	_expect(String(staff_01.get("current_state")) == staff_script.state_returning, "completed cook job did not enter RETURNING")
	_expect((restaurant.get("staff_job_claims") as Dictionary).is_empty(), "completed cook job retained ownership")
	_expect(bool(restaurant.call("advance_staff", 2.0)), "staff did not return home")
	_expect(String(staff_01.get("current_state")) == staff_script.state_idle, "returned staff did not become IDLE")

	var cooking_job: Dictionary = restaurant.call("get_cooking_job", "staff_customer") as Dictionary
	_expect(bool(restaurant.call("advance_cooking", float(cooking_job.get("cooking_duration", 0.0)))), "cooking timer did not complete")
	_expect(String((restaurant.call("get_cooking_job", "staff_customer") as Dictionary).get("state", "")) == restaurant_script.cooking_state_ready, "staff order food did not become ready")
	_expect(bool(restaurant.call("assign_staff_job", "waiter_01", staff_script.job_serve, "staff_customer")), "serve job assignment failed")
	_expect(not bool(restaurant.call("assign_staff_job", "waiter_02", staff_script.job_serve, "staff_customer")), "two staff claimed the same serve job")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "staff did not deliver food")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "staff serving did not call mark_food_served")
	_expect(String((restaurant.call("get_cooking_job", "staff_customer") as Dictionary).get("state", "")) == restaurant_script.cooking_state_served, "served cooking state is wrong")
	_expect(not bool(restaurant.call("serve_order", "staff_customer")), "staff flow allowed duplicate serving")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "serving staff did not return")

	var table_id: String = String(customer.get("table_id"))
	var table: Node = (restaurant.get("tables_by_id") as Dictionary).get(table_id) as Node
	var wallet_before_payment: int = game_manager.get_wallet_balance()
	var expected_revenue: int = int((restaurant.call("get_menu_entry", "garlic_egg_rice") as Dictionary).get("selling_price", 0))
	_expect(bool(restaurant.call("assign_staff_job", "waiter_01", staff_script.job_payment, "staff_customer")), "payment job assignment failed")
	_expect(not bool(restaurant.call("assign_staff_job", "waiter_02", staff_script.job_payment, "staff_customer")), "two staff claimed the same payment job")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "staff did not collect payment")
	_expect(String(customer.get("current_state")) == customer_script.state_leaving, "payment did not finish eating lifecycle")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "staff payment revenue is incorrect")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_needs_cleanup, "staff-enabled payment did not mark table for cleanup")
	_expect(not bool(restaurant.call("finish_customer_meal", "staff_customer")), "staff flow allowed duplicate payment")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "duplicate payment changed wallet")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "payment staff did not return")

	_expect(bool(restaurant.call("assign_staff_job", "waiter_01", staff_script.job_clean, table_id)), "cleanup job assignment failed")
	_expect(not bool(restaurant.call("assign_staff_job", "waiter_02", staff_script.job_clean, table_id)), "two staff claimed the same cleanup job")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "staff did not reach cleanup table")
	_expect(String(staff_01.get("current_state")) == staff_script.state_cleaning_table, "staff did not enter CLEANING_TABLE")
	_expect(bool(restaurant.call("advance_staff", 0.75)), "cleanup timer did not advance")
	_expect(is_equal_approx(float((staff_01.get("active_job") as Dictionary).get("elapsed", 0.0)), 0.75), "cleanup timer advanced incorrectly")

	var duplicate_job_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var duplicate_staff: Dictionary = duplicate_job_state.get("staff", {}) as Dictionary
	duplicate_staff["waiter_02"] = (duplicate_staff.get("waiter_01", {}) as Dictionary).duplicate(true)
	duplicate_job_state["staff"] = duplicate_staff
	_expect(not bool((save_manager.call("_validate_save_state", duplicate_job_state) as Dictionary).get("ok", false)), "save accepted duplicate staff job ownership")
	_expect(save_manager.save_game(), "active staff cleanup could not be saved")
	staff_01.position = Vector2.ZERO
	table.call("release_table")
	_expect(save_manager.load_game(), "active staff cleanup could not be loaded")
	staff_01 = restaurant.call("get_staff", "waiter_01") as Node
	staff_02 = restaurant.call("get_staff", "waiter_02") as Node
	table = (restaurant.get("tables_by_id") as Dictionary).get(table_id) as Node
	_expect(staff_01 != null and staff_02 != null, "hired staff existence was not restored")
	_expect(staff_01 != null and String(staff_01.get("current_state")) == staff_script.state_cleaning_table, "staff state was not restored")
	_expect(staff_01 != null and is_equal_approx(float((staff_01.get("active_job") as Dictionary).get("elapsed", 0.0)), 0.75), "staff job timer was not restored")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_needs_cleanup, "cleanup table state was not restored")
	_expect(not bool(restaurant.call("assign_staff_job", "waiter_02", staff_script.job_clean, table_id)), "loaded job ownership allowed a duplicate claim")
	_expect(bool(restaurant.call("advance_staff", 1.25)), "loaded cleanup job did not finish")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_available, "table cleanup did not release the table")
	_expect(String(staff_01.get("current_state")) == staff_script.state_returning, "cleaner did not return after cleanup")
	_expect(bool(restaurant.call("advance_staff", 1.0)), "cleaner did not reach home")
	_expect(String(staff_01.get("current_state")) == staff_script.state_idle, "cleaner did not return to IDLE")

	var timeout_customer: Node = restaurant.call("spawn_customer", "staff_timeout", "garlic_egg_rice") as Node
	_expect(timeout_customer != null, "job-failure customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(bool(restaurant.call("assign_staff_job", "waiter_01", staff_script.job_cook, "staff_timeout")), "job-failure fixture could not be assigned")
	timeout_customer.call("advance_patience", float(timeout_customer.get("patience_limit")))
	_expect(String(staff_01.get("current_state")) == staff_script.state_returning, "failed job did not reset staff immediately")
	_expect((restaurant.get("staff_job_claims") as Dictionary).is_empty(), "failed job retained ownership")
	var timeout_save_validation: Dictionary = save_manager.call("_validate_save_state", save_manager.call("_build_save_state")) as Dictionary
	_expect(bool(timeout_save_validation.get("ok", false)), "failed customer job left an unsaveable runtime state")
	_expect(bool(restaurant.call("advance_staff", 2.0)), "failed job staff did not return home")

	_expect(observed_states.has(staff_script.state_moving), "state machine never entered MOVING")
	_expect(observed_states.has(staff_script.state_handling_order), "state machine never entered HANDLING_ORDER")
	_expect(observed_states.has(staff_script.state_delivering_food), "state machine never entered DELIVERING_FOOD")
	_expect(observed_states.has(staff_script.state_cleaning_table), "state machine never entered CLEANING_TABLE")
	_expect(observed_states.has(staff_script.state_returning), "state machine never entered RETURNING")
	_expect(observed_states.has(staff_script.state_idle), "state machine never returned to IDLE")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("staff")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy v1 save without staff state is incompatible")
	if bool(legacy_validation.get("ok", false)):
		world.apply_restaurant_save_state(legacy_validation.get("state", {}) as Dictionary)
	_expect((restaurant.get("staffs_by_id") as Dictionary).is_empty(), "legacy save created phantom staff")

	_finish_tests()


func _unlock_restaurant() -> void:
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, unlock_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)


func _on_staff_state_changed(_staff_id: String, state: String) -> void:
	observed_states.append(state)


func _finish_tests() -> void:
	if failures == 0:
		print("staff_test: PASS")
	else:
		push_error("staff_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("staff_test: %s" % message)


func _cleanup_save_files() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return
	user_directory.list_dir_begin()
	var file_name: String = user_directory.get_next()
	while not file_name.is_empty():
		if not user_directory.current_is_dir() and file_name.begins_with("savegame"):
			user_directory.remove(file_name)
		file_name = user_directory.get_next()
	user_directory.list_dir_end()
