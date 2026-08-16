extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")

var failures: int = 0
var customer_states: Array[String] = []

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_customer_order_test"):
		push_error("customer_order_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var restaurant: Node = world.get_node("restaurant")
	var settings: Dictionary = data_manager.get_customer_settings()
	var regular_customer: Dictionary = data_manager.get_customer_type("regular")
	_expect(not settings.is_empty(), "customer settings did not load from customers.json")
	_expect(String(settings.get("default_customer_type", "")) == "regular", "default customer type is wrong")
	_expect(float(settings.get("spawn_interval_seconds", 0.0)) > 0.0, "customer spawn interval is invalid")
	_expect(float(regular_customer.get("patience_seconds", 0.0)) > 0.0, "customer patience is invalid")
	_expect(int(regular_customer.get("order_quantity", 0)) == 1, "customer order quantity did not come from data")
	_expect(restaurant.call("spawn_customer", "locked_customer", "garlic_egg_rice") == null, "locked restaurant spawned a customer")

	_unlock_restaurant()
	_expect(bool(restaurant.call("is_available")), "restaurant did not unlock for customer tests")
	_expect(restaurant.has_node("customers"), "restaurant has no customer container")

	var customer: Node = restaurant.call("spawn_customer", "customer_phase8_01", "garlic_egg_rice") as Node
	_expect(customer != null, "customer creation failed")
	if customer == null:
		_finish_tests()
		return
	_expect(String(customer.get("current_state")) == customer_script.state_enter, "new customer did not start in ENTER")
	customer.connect("state_changed", _on_customer_state_changed)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(customer_states == [customer_script.state_seated, customer_script.state_ordering, customer_script.state_waiting_food], "customer did not follow ENTER -> SEATED -> ORDERING -> WAITING_FOOD")
	_expect(String(customer.get("current_state")) == customer_script.state_waiting_food, "customer did not wait for food")

	var table_id: String = String(customer.get("table_id"))
	var table: Node = (restaurant.get("tables_by_id") as Dictionary).get(table_id) as Node
	_expect(table != null, "customer was not assigned a table")
	if table != null:
		_expect(String(table.get("current_state")) == restaurant_table_script.state_occupied, "assigned table is not occupied")
		_expect(String(table.get("occupant_id")) == "customer_phase8_01", "table occupant does not match customer")
		_expect(not bool(table.call("reserve", "customer_phase8_other")), "occupied table accepted another customer")

	var order: Dictionary = customer.get("order") as Dictionary
	_expect(String(order.get("recipe_id", "")) == "garlic_egg_rice", "order lost its recipe id")
	_expect(int(order.get("quantity", 0)) == 1, "order quantity is wrong")
	_expect(String(order.get("state", "")) == customer_script.order_state_pending, "new order is not pending")
	var menu_entry: Dictionary = restaurant.call("get_menu_entry", String(order.get("recipe_id", ""))) as Dictionary
	_expect(not menu_entry.is_empty(), "order recipe was not validated against the menu")
	for ingredient_id_value: Variant in menu_entry.get("ingredients", {}) as Dictionary:
		_expect(data_manager.get_entry("items", String(ingredient_id_value)) != null, "order recipe references an unknown item")
	var order_snapshot: Dictionary = order.duplicate(true)
	_expect(not bool(customer.call("create_order", "chicken_rice", 1)), "customer created a duplicate order")
	_expect((customer.get("order") as Dictionary) == order_snapshot, "duplicate order attempt mutated the order")
	_expect(restaurant.call("spawn_customer", "invalid_recipe_customer", "fried_fish") == null, "recipe with unresolved ingredients produced an order")

	var wallet_before_lifecycle: int = game_manager.get_wallet_balance()
	_expect(bool(customer.call("mark_food_served")), "served-order foundation could not enter EATING")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "customer did not enter EATING")
	_expect(bool(customer.call("finish_eating")), "customer could not enter LEAVING")
	_expect(String(customer.get("current_state")) == customer_script.state_leaving, "customer did not enter LEAVING")
	_expect(String(customer.get("table_id")).is_empty(), "leaving customer retained a table")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_available, "table was not released when customer left")
	_expect(game_manager.get_wallet_balance() == wallet_before_lifecycle, "Phase 8 lifecycle created restaurant revenue")
	_expect(bool(customer.call("complete_departure")), "leaving customer could not complete departure")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not bool(restaurant.call("has_customer", "customer_phase8_01")), "departed customer remained registered")

	var saved_customer: Node = restaurant.call("spawn_customer", "customer_phase8_save", "garlic_egg_rice") as Node
	_expect(saved_customer != null, "save/load customer creation failed")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(String(saved_customer.get("current_state")) == customer_script.state_waiting_food, "save fixture did not reach WAITING_FOOD")
	_expect(bool(saved_customer.call("advance_patience", 17.5)), "patience did not advance")
	var saved_table_id: String = String(saved_customer.get("table_id"))
	restaurant.set("customer_spawn_elapsed", 12.25)
	game_manager.money = 123
	game_manager.reputation = 2.0
	_expect(save_manager.save_game(), "customer/order state could not be saved")

	saved_customer.call("advance_patience", float(saved_customer.get("patience_limit")))
	restaurant.set("customer_spawn_elapsed", 0.0)
	game_manager.money = 0
	game_manager.reputation = 1.0
	_expect(save_manager.load_game(), "customer/order state could not be loaded")
	var loaded_customer: Node = restaurant.call("get_customer", "customer_phase8_save") as Node
	_expect(loaded_customer != null, "saved customer was not restored")
	if loaded_customer == null:
		_finish_tests()
		return
	_expect(String(loaded_customer.get("current_state")) == customer_script.state_waiting_food, "customer lifecycle state was not restored")
	_expect(String(loaded_customer.get("table_id")) == saved_table_id, "customer/table association was not restored")
	_expect(is_equal_approx(float(loaded_customer.get("patience_elapsed")), 17.5), "patience timer was not restored")
	_expect(is_equal_approx(float(restaurant.get("customer_spawn_elapsed")), 12.25), "customer spawn timer was not restored")
	_expect(String((loaded_customer.get("order") as Dictionary).get("recipe_id", "")) == "garlic_egg_rice", "loaded order lost its recipe id")
	var loaded_table: Node = (restaurant.get("tables_by_id") as Dictionary).get(saved_table_id) as Node
	_expect(String(loaded_table.get("occupant_id")) == "customer_phase8_save", "loaded table occupant is wrong")

	var wallet_before_timeout: int = game_manager.get_wallet_balance()
	var reputation_before_timeout: float = game_manager.reputation
	var remaining_patience: float = float(loaded_customer.get("patience_limit")) - float(loaded_customer.get("patience_elapsed"))
	_expect(bool(loaded_customer.call("advance_patience", remaining_patience)), "timeout boundary did not advance")
	_expect(String(loaded_customer.get("current_state")) == customer_script.state_leaving, "timed-out customer did not enter LEAVING")
	var failed_order: Dictionary = loaded_customer.get("order") as Dictionary
	_expect(String(failed_order.get("state", "")) == customer_script.order_state_failed, "timed-out order was not failed")
	_expect(String(failed_order.get("failure_reason", "")) == "timeout", "timed-out order has the wrong failure reason")
	_expect(String(loaded_table.get("current_state")) == restaurant_table_script.state_available, "timeout did not release the table")
	_expect(game_manager.get_wallet_balance() == wallet_before_timeout, "timeout created fake revenue")
	var expected_reputation: float = maxf(reputation_before_timeout + float(regular_customer.get("timeout_reputation_change", 0.0)), 1.0)
	_expect(is_equal_approx(game_manager.reputation, expected_reputation), "timeout reputation impact is wrong")
	loaded_customer.call("advance_patience", 1.0)
	_expect(is_equal_approx(game_manager.reputation, expected_reputation), "timeout reputation impact was applied twice")

	_expect(save_manager.save_game(), "LEAVING customer state could not be saved")
	game_manager.reputation = 5.0
	_expect(save_manager.load_game(), "LEAVING customer state could not be loaded")
	loaded_customer = restaurant.call("get_customer", "customer_phase8_save") as Node
	_expect(loaded_customer != null and String(loaded_customer.get("current_state")) == customer_script.state_leaving, "LEAVING customer was not restored")
	_expect(loaded_customer != null and bool(loaded_customer.get("timeout_impact_applied")), "timeout impact flag was not restored")
	_expect(is_equal_approx(game_manager.reputation, expected_reputation), "loaded timeout changed reputation again")
	if loaded_customer != null:
		loaded_customer.call("complete_departure")
	await get_tree().process_frame
	await get_tree().process_frame

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("restaurant_customers")
	legacy_state.erase("restaurant_customer_sequence")
	legacy_state.erase("restaurant_spawn_elapsed")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy Phase 7 save is not compatible")
	if bool(legacy_validation.get("ok", false)):
		world.apply_restaurant_save_state(legacy_validation.get("state", {}) as Dictionary)
	_expect((restaurant.get("customers_by_id") as Dictionary).is_empty(), "legacy save created phantom customers")

	var validation_customer: Node = restaurant.call("spawn_customer", "customer_phase8_validation", "garlic_egg_rice") as Node
	_expect(validation_customer != null, "validation customer creation failed")
	await get_tree().process_frame
	await get_tree().process_frame
	var invalid_recipe_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var invalid_customers: Dictionary = invalid_recipe_state.get("restaurant_customers", {}) as Dictionary
	var invalid_customer: Dictionary = (invalid_customers.get("customer_phase8_validation", {}) as Dictionary).duplicate(true)
	var invalid_order: Dictionary = (invalid_customer.get("order", {}) as Dictionary).duplicate(true)
	invalid_order["recipe_id"] = "unknown_recipe"
	invalid_customer["order"] = invalid_order
	invalid_customers["customer_phase8_validation"] = invalid_customer
	invalid_recipe_state["restaurant_customers"] = invalid_customers
	_expect(not bool((save_manager.call("_validate_save_state", invalid_recipe_state) as Dictionary).get("ok", false)), "save accepted an unknown order recipe")

	var duplicate_table_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var duplicate_customers: Dictionary = duplicate_table_state.get("restaurant_customers", {}) as Dictionary
	var duplicate_customer: Dictionary = (duplicate_customers.get("customer_phase8_validation", {}) as Dictionary).duplicate(true)
	duplicate_customers["customer_phase8_duplicate"] = duplicate_customer
	duplicate_table_state["restaurant_customers"] = duplicate_customers
	_expect(not bool((save_manager.call("_validate_save_state", duplicate_table_state) as Dictionary).get("ok", false)), "save accepted multiple customers for one table")

	restaurant.call("remove_customer", "customer_phase8_validation")
	await get_tree().process_frame
	var customers_before_auto_spawn: int = (restaurant.get("customers_by_id") as Dictionary).size()
	game_manager.start_gameplay()
	restaurant.call("_process", float(settings.get("spawn_interval_seconds", 0.0)))
	game_manager.stop_gameplay()
	await get_tree().process_frame
	_expect((restaurant.get("customers_by_id") as Dictionary).size() == customers_before_auto_spawn + 1, "data-driven spawn timer did not create a customer")

	_finish_tests()


func _unlock_restaurant() -> void:
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, unlock_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)


func _on_customer_state_changed(_customer_id: String, state: String) -> void:
	customer_states.append(state)


func _finish_tests() -> void:
	if failures == 0:
		print("customer_order_test: PASS")
	else:
		push_error("customer_order_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("customer_order_test: %s" % message)


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
