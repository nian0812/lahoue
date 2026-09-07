extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_cooking_test"):
		push_error("cooking_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	_unlock_restaurant()

	var restaurant: Node = world.get_node("restaurant")
	var recipe: Dictionary = data_manager.get_entry("recipes", "garlic_egg_rice") as Dictionary
	var menu_entry: Dictionary = restaurant.call("get_menu_entry", "garlic_egg_rice") as Dictionary
	_expect(not menu_entry.is_empty(), "valid cooking recipe is unavailable")
	_expect(float(menu_entry.get("cooking_time_seconds", 0.0)) == float(recipe.get("cooking_time", 0.0)), "cooking timer did not come from recipes.json")
	_expect(float(menu_entry.get("cooking_time_seconds", 0.0)) > 0.0, "recipe cooking timer is invalid")
	var normalized_ingredients: Dictionary = menu_entry.get("ingredients", {}) as Dictionary
	var recipe_ingredients: Dictionary = recipe.get("ingredients", {}) as Dictionary
	_expect(normalized_ingredients.size() == recipe_ingredients.size(), "recipe ingredient count changed during normalization")
	for item_id_value: Variant in recipe_ingredients:
		var item_id: String = String(item_id_value)
		_expect(int(normalized_ingredients.get(item_id, 0)) == int(recipe_ingredients[item_id_value]), "recipe ingredient '%s' changed during normalization" % item_id)
		_expect(data_manager.get_entry("items", item_id) != null, "recipe ingredient '%s' is unknown" % item_id)
	_expect((restaurant.call("get_menu_entry", "fried_fish") as Dictionary).is_empty(), "recipe with unresolved ingredients entered cooking")
	_expect(data_manager.get_kitchen_cooking_slots(1) == 1, "kitchen capacity did not come from progression data")
	_expect(data_manager.get_kitchen_speed_percent(1) == 100, "kitchen speed did not come from progression data")

	var customer: Node = restaurant.call("spawn_customer", "cooking_customer", "garlic_egg_rice") as Node
	_expect(customer != null, "cooking customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, customer)
	_expect(customer != null and String(customer.get("current_state")) == customer_script.state_waiting_food, "cooking customer has no pending order")
	_expect(not bool(restaurant.call("start_cooking", "unknown_customer")), "unknown customer started cooking")

	inventory_manager.clear()
	_expect(inventory_manager.add_item("rice", 1), "rice fixture could not be added")
	var inventory_before_failure: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not bool(restaurant.call("start_cooking", "cooking_customer")), "cooking started without all ingredients")
	_expect(inventory_manager.items == inventory_before_failure, "failed cooking transaction lost ingredients")
	_expect(not inventory_manager.remove_items_atomic({"rice": 1, "unknown_item": 1}), "invalid ingredient batch was accepted")
	_expect(inventory_manager.items == inventory_before_failure, "invalid ingredient batch partially mutated inventory")

	_expect(inventory_manager.add_item("egg", 1), "egg fixture could not be added")
	_expect(bool(restaurant.call("start_cooking", "cooking_customer")), "valid cooking transaction failed")
	_expect(inventory_manager.get_amount("rice") == 0 and inventory_manager.get_amount("egg") == 0, "cooking did not consume exact ingredients")
	var inventory_after_start: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not bool(restaurant.call("start_cooking", "cooking_customer")), "duplicate cooking was accepted")
	_expect(inventory_manager.items == inventory_after_start, "duplicate cooking mutated inventory")

	var job: Dictionary = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	var duration: float = float(job.get("cooking_duration", 0.0))
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_cooking, "new cooking job has the wrong state")
	_expect(duration > 0.0, "cooking job has no duration")
	_expect(bool(restaurant.call("advance_cooking", 3.25)), "cooking timer did not advance")
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(is_equal_approx(float(job.get("cooking_elapsed", 0.0)), 3.25), "cooking timer advanced incorrectly")

	_expect(save_manager.save_game(), "active cooking state could not be saved")
	restaurant.set("cooking_jobs", {})
	inventory_manager.add_item("rice", 1)
	_expect(save_manager.load_game(), "active cooking state could not be loaded")
	customer = restaurant.call("get_customer", "cooking_customer") as Node
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(customer != null and String(customer.get("current_state")) == customer_script.state_waiting_food, "loaded cooking customer state is wrong")
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_cooking, "active cooking state was not restored")
	_expect(is_equal_approx(float(job.get("cooking_elapsed", 0.0)), 3.25), "active cooking timer was not restored")
	_expect(inventory_manager.get_amount("rice") == 0 and inventory_manager.get_amount("egg") == 0, "load duplicated consumed ingredients")

	var remaining: float = float(job.get("cooking_duration", 0.0)) - float(job.get("cooking_elapsed", 0.0))
	_expect(bool(restaurant.call("advance_cooking", remaining - 0.01)), "near-complete cooking timer did not advance")
	_expect(String((restaurant.call("get_cooking_job", "cooking_customer") as Dictionary).get("state", "")) == restaurant_script.cooking_state_cooking, "food became ready too early")
	_expect(bool(restaurant.call("advance_cooking", 0.01)), "cooking timer did not reach completion")
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_ready, "food did not enter ready state")
	_expect(is_equal_approx(float(job.get("cooking_elapsed", 0.0)), float(job.get("cooking_duration", 0.0))), "ready food timer is incomplete")

	_expect(save_manager.save_game(), "food-ready state could not be saved")
	restaurant.set("cooking_jobs", {})
	_expect(save_manager.load_game(), "food-ready state could not be loaded")
	customer = restaurant.call("get_customer", "cooking_customer") as Node
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_ready, "food-ready state was not restored")

	var other_customer: Node = restaurant.call("spawn_customer", "cooking_other", "garlic_egg_rice") as Node
	_expect(other_customer != null, "second customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, other_customer)
	_expect(not bool(restaurant.call("serve_order", "cooking_other")), "food was served to the wrong customer")
	_expect(String(customer.get("current_state")) == customer_script.state_waiting_food, "wrong serve mutated the correct customer")
	_expect(bool(restaurant.call("serve_order", "cooking_customer")), "ready food could not be served")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "mark_food_served did not move customer to EATING")
	_expect(String((customer.get("order") as Dictionary).get("state", "")) == customer_script.order_state_served, "served order state is wrong")
	_expect(String((restaurant.call("get_cooking_job", "cooking_customer") as Dictionary).get("state", "")) == restaurant_script.cooking_state_served, "cooking job did not enter served state")
	_expect(not bool(restaurant.call("serve_order", "cooking_customer")), "duplicate serving was accepted")

	var table_id: String = String(customer.get("table_id"))
	var table: Node = (restaurant.get("tables_by_id") as Dictionary).get(table_id) as Node
	var wallet_before_payment: int = game_manager.get_wallet_balance()
	var expected_revenue: int = int(menu_entry.get("selling_price", 0))
	var exp_before_payment: int = game_manager.current_exp
	game_manager.money = game_manager.max_wallet_balance
	_expect(not bool(restaurant.call("finish_customer_meal", "cooking_customer")), "overflow payment transaction was accepted")
	_expect(game_manager.current_exp == exp_before_payment, "failed Restaurant payment granted Sales EXP")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "failed payment moved the customer out of EATING")
	_expect(String((restaurant.call("get_cooking_job", "cooking_customer") as Dictionary).get("state", "")) == restaurant_script.cooking_state_served, "failed payment mutated the cooking job")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_occupied, "failed payment released the table")
	game_manager.money = wallet_before_payment
	_expect(bool(restaurant.call("finish_customer_meal", "cooking_customer")), "valid meal payment failed")
	_expect(String(customer.get("current_state")) == customer_script.state_leaving, "finish_eating did not move customer to LEAVING")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_available, "payment flow did not release table")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "restaurant revenue is incorrect")
	var expected_sales_exp: int = game_manager.calculate_sales_exp(expected_revenue)
	_expect(game_manager.current_exp == exp_before_payment + expected_sales_exp, "Restaurant payment granted the wrong Sales EXP")
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_paid and bool(job.get("payment_collected", false)), "payment state was not recorded")
	_expect(not bool(restaurant.call("finish_customer_meal", "cooking_customer")), "duplicate payment was accepted")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "duplicate payment changed wallet")
	_expect(game_manager.current_exp == exp_before_payment + expected_sales_exp, "duplicate Restaurant payment granted Sales EXP twice")

	_expect(save_manager.save_game(), "paid order state could not be saved")
	game_manager.money = 0
	restaurant.call("remove_customer", "cooking_customer")
	_expect(save_manager.load_game(), "paid order state could not be loaded")
	customer = restaurant.call("get_customer", "cooking_customer") as Node
	job = restaurant.call("get_cooking_job", "cooking_customer") as Dictionary
	_expect(customer != null and String(customer.get("current_state")) == customer_script.state_leaving, "paid customer state was not restored")
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_paid and bool(job.get("payment_collected", false)), "paid cooking job was not restored")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "paid revenue was not restored")
	_expect(not bool(restaurant.call("finish_customer_meal", "cooking_customer")), "loaded paid order allowed duplicate payment")
	if customer != null:
		customer.call("complete_departure")
	await get_tree().process_frame
	await get_tree().process_frame

	other_customer = restaurant.call("get_customer", "cooking_other") as Node
	_expect(other_customer != null, "timeout customer disappeared unexpectedly")
	inventory_manager.add_item("rice", 1)
	inventory_manager.add_item("egg", 1)
	_expect(bool(restaurant.call("start_cooking", "cooking_other")), "timeout cooking fixture could not start")
	var wallet_before_timeout: int = game_manager.get_wallet_balance()
	other_customer.call("advance_patience", float(other_customer.get("patience_limit")))
	_expect(String(other_customer.get("current_state")) == customer_script.state_leaving, "timed-out customer did not leave")
	_expect((restaurant.call("get_cooking_job", "cooking_other") as Dictionary).is_empty(), "timeout retained an active cooking job")
	_expect(game_manager.get_wallet_balance() == wallet_before_timeout, "timeout created restaurant revenue")
	_expect(not bool(restaurant.call("finish_customer_meal", "cooking_other")), "failed timeout order accepted payment")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("restaurant_cooking")
	legacy_state["kitchen_level"] = 0
	legacy_state.erase("building_ownership")
	legacy_state.erase("purchased_farm_plots")
	legacy_state.erase("pond_levels")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "Phase 8 save without cooking state is not compatible")

	_finish_tests()


func _unlock_restaurant() -> void:
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, unlock_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)
	game_manager.money = data_manager.get_progression_upgrade_cost("restaurant", 1)
	world.call("upgrade_system", "restaurant")


func _finish_customer_entry(restaurant: Node, customer: Node) -> void:
	if customer == null:
		return
	customer.set("is_walking_in", false)
	var empty_path: Array[Vector2] = []
	customer.set("walk_path", empty_path)
	restaurant.call("_on_customer_arrived_at_table", String(customer.get("customer_id")))


func _finish_tests() -> void:
	if failures == 0:
		print("cooking_test: PASS")
	else:
		push_error("cooking_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("cooking_test: %s" % message)


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
