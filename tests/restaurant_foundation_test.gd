extends Node

const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")

var failures: int = 0
var restaurant_interaction_count: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_restaurant_test"):
		push_error("restaurant_foundation_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var restaurant: Node = world.get_node("restaurant")
	var player: Node = world.get_node("player")
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	_expect(unlock_level == int((data_manager.get_dataset("progression").get("restaurant", {}) as Dictionary).get("unlock_level", 0)), "restaurant unlock level did not come from progression.json")
	_expect(bool(restaurant.get("is_configured")), "restaurant configuration failed")
	_expect(String(restaurant.get("current_state")) == "locked", "new restaurant did not start locked")
	_expect(not bool(restaurant.call("is_available")), "restaurant was available below unlock level")
	_expect(int(restaurant.get("restaurant_level")) == 0, "locked restaurant has an active level")
	_expect(int(restaurant.get_node("interaction_area").get("collision_layer")) == 4, "restaurant entrance is not on the shared interaction layer")
	_expect((restaurant.call("get_menu_entries") as Dictionary).is_empty(), "locked restaurant exposed a menu")
	_expect(not bool(restaurant.call("interact", player)), "locked restaurant accepted direct interaction")
	_expect(not bool(restaurant.call("collect_revenue", "garlic_egg_rice", 1)), "locked restaurant collected revenue")

	var table_capacity: int = data_manager.get_restaurant_table_capacity(1)
	var tables_by_id: Dictionary = restaurant.get("tables_by_id") as Dictionary
	_expect(table_capacity == 3, "restaurant level-1 table capacity is wrong")
	_expect(tables_by_id.size() == table_capacity, "restaurant did not create the configured tables")
	for table_id_value: Variant in tables_by_id:
		var table: Node = tables_by_id[table_id_value] as Node
		_expect(String(table.get("current_state")) == restaurant_table_script.state_available, "table '%s' did not start available" % table_id_value)
		_expect(String(table.get("occupant_id")).is_empty(), "table '%s' started with an occupant" % table_id_value)
		_expect(table.has_node("seat_marker"), "table '%s' has no customer seat marker" % table_id_value)

	_expect(restaurant.has_node("entrance_marker"), "restaurant entrance marker is missing")
	_expect(restaurant.has_node("customer_queue_marker"), "customer queue marker is missing")
	_expect(restaurant.has_node("order_counter_marker"), "order counter marker is missing")
	_expect(restaurant.has_node("kitchen_station_marker"), "kitchen station marker is missing")
	_expect(restaurant.has_node("serving_counter_marker"), "serving counter marker is missing")
	restaurant.connect("restaurant_interacted", _on_restaurant_interacted)
	await _interact_with(player, restaurant)
	_expect(restaurant_interaction_count == 0, "E interaction reached locked restaurant")

	var exp_to_unlock: int = 0
	for level_value: int in range(game_manager.level, unlock_level):
		exp_to_unlock += data_manager.get_level_exp(level_value)
	game_manager.add_exp(exp_to_unlock)
	_expect(game_manager.level == unlock_level, "level progression did not reach restaurant unlock")
	_expect(bool(restaurant.call("is_available")), "restaurant did not become available at unlock level")
	_expect(String(restaurant.get("current_state")) == "available", "restaurant state did not transition to available")
	_expect(int(restaurant.get("restaurant_level")) == 1, "restaurant did not initialize at level 1")
	_expect(int(restaurant.get_node("interaction_area").get("collision_layer")) == 4, "unlocked restaurant left the interaction layer")

	await _interact_with(player, restaurant)
	_expect(restaurant_interaction_count == 1, "E interaction did not reach unlocked restaurant")

	var menu: Dictionary = restaurant.call("get_menu_entries") as Dictionary
	_expect(not menu.is_empty(), "unlocked restaurant menu is empty")
	_expect(menu.has("garlic_egg_rice"), "valid recipe was not added to menu")
	_expect(not menu.has("fried_fish"), "recipe with unresolved ingredients entered menu")
	_expect(not menu.has("wagyu_steak"), "unavailable premium recipe entered menu")
	var garlic_recipe: Dictionary = data_manager.get_entry("recipes", "garlic_egg_rice") as Dictionary
	var garlic_menu_entry: Dictionary = restaurant.call("get_menu_entry", "garlic_egg_rice") as Dictionary
	_expect(int(garlic_menu_entry.get("selling_price", 0)) == int(garlic_recipe.get("selling_price", 0)), "menu price did not come from recipes.json")
	var garlic_ingredients: Dictionary = garlic_menu_entry.get("ingredients", {}) as Dictionary
	_expect(int(garlic_ingredients.get("rice", 0)) == 1, "menu lost the rice ingredient ID")
	_expect(int(garlic_ingredients.get("egg", 0)) == 1, "menu lost the egg ingredient ID")
	_expect(int(garlic_menu_entry.get("required_level", 0)) == unlock_level, "null recipe level did not inherit restaurant unlock")
	for recipe_id_value: Variant in menu:
		var menu_entry: Dictionary = menu[recipe_id_value] as Dictionary
		_expect(int(menu_entry.get("selling_price", 0)) > 0, "menu recipe '%s' has no valid price" % recipe_id_value)
		var ingredients: Dictionary = menu_entry.get("ingredients", {}) as Dictionary
		_expect(not ingredients.is_empty(), "menu recipe '%s' has no ingredients" % recipe_id_value)
		for item_id_value: Variant in ingredients:
			_expect(data_manager.get_entry("items", String(item_id_value)) != null, "menu recipe '%s' references unknown item" % recipe_id_value)

	game_manager.money = 0
	var recipe_price: int = int(garlic_recipe.get("selling_price", 0))
	_expect(bool(restaurant.call("collect_revenue", "garlic_egg_rice", 2)), "valid restaurant revenue transaction failed")
	_expect(game_manager.get_wallet_balance() == recipe_price * 2, "restaurant revenue used the wrong menu price")
	var wallet_after_revenue: int = game_manager.get_wallet_balance()
	_expect(not bool(restaurant.call("collect_revenue", "unknown_recipe", 1)), "unknown recipe produced revenue")
	_expect(not bool(restaurant.call("collect_revenue", "garlic_egg_rice", 0)), "zero restaurant transaction was accepted")
	_expect(not bool(restaurant.call("collect_revenue", "garlic_egg_rice", -1)), "negative restaurant transaction was accepted")
	_expect(game_manager.get_wallet_balance() == wallet_after_revenue, "invalid restaurant transaction changed wallet")
	game_manager.money = game_manager.max_wallet_balance
	var overflow_amount: int = game_manager.max_wallet_balance / recipe_price + 1
	_expect(not bool(restaurant.call("collect_revenue", "garlic_egg_rice", overflow_amount)), "restaurant revenue overflow was accepted")
	_expect(game_manager.get_wallet_balance() == game_manager.max_wallet_balance, "overflow transaction changed wallet")

	var table_01: Node = tables_by_id.get("table_01") as Node
	var table_02: Node = tables_by_id.get("table_02") as Node
	_expect(not bool(table_01.call("reserve", "INVALID CUSTOMER")), "table accepted invalid customer id")
	_expect(bool(table_01.call("reserve", "customer_01")), "available table could not be reserved")
	_expect(String(table_01.get("current_state")) == restaurant_table_script.state_reserved, "table did not enter reserved state")
	_expect(not bool(table_01.call("seat_customer", "other_customer")), "wrong customer occupied a reservation")
	_expect(bool(table_01.call("seat_customer", "customer_01")), "reserved customer could not be seated")
	_expect(String(table_01.get("current_state")) == restaurant_table_script.state_occupied, "table did not enter occupied state")
	_expect(bool(table_02.call("reserve", "customer_02")), "second table could not be reserved")
	_expect(bool(table_02.call("seat_customer", "customer_02")), "second customer could not be seated")
	_expect(bool(table_02.call("mark_needs_cleanup")), "occupied table did not enter cleanup state")
	_expect(String(table_02.get("current_state")) == restaurant_table_script.state_needs_cleanup, "cleanup table state is wrong")
	_expect(bool(table_02.call("release_table")), "cleanup table could not be released")
	_expect(String(table_02.get("current_state")) == restaurant_table_script.state_available, "released table is not available")

	game_manager.money = wallet_after_revenue
	_expect(save_manager.save_game(), "restaurant state could not be saved")
	_expect(bool(table_01.call("release_table")), "save mutation fixture could not release table")
	game_manager.money = 0
	_expect(save_manager.load_game(), "restaurant state could not be loaded")
	_expect(bool(restaurant.call("is_available")), "loaded restaurant availability is wrong")
	_expect(int(restaurant.get("restaurant_level")) == 1, "restaurant level was not restored")
	_expect(String(table_01.get("current_state")) == restaurant_table_script.state_occupied, "occupied table state was not restored")
	_expect(String(table_01.get("occupant_id")) == "customer_01", "table occupant was not restored")
	_expect(game_manager.get_wallet_balance() == wallet_after_revenue, "restaurant wallet state was not restored")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("restaurant_tables")
	legacy_state["restaurant_level"] = 0
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy v1 restaurant save is not compatible")
	if bool(legacy_validation.get("ok", false)):
		world.apply_restaurant_save_state(legacy_validation.get("state", {}) as Dictionary)
	_expect(bool(restaurant.call("is_available")), "legacy unlocked player did not migrate restaurant")
	_expect(int(restaurant.get("restaurant_level")) == 1, "legacy restaurant did not migrate to level 1")
	_expect(String(table_01.get("current_state")) == restaurant_table_script.state_available, "legacy table state did not reset safely")

	var invalid_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var invalid_tables: Dictionary = invalid_state.get("restaurant_tables", {}) as Dictionary
	var invalid_table: Dictionary = (invalid_tables.get("table_01", {}) as Dictionary).duplicate(true)
	invalid_table["state"] = restaurant_table_script.state_occupied
	invalid_table["occupant_id"] = ""
	invalid_tables["table_01"] = invalid_table
	invalid_state["restaurant_tables"] = invalid_tables
	var invalid_validation: Dictionary = save_manager.call("_validate_save_state", invalid_state) as Dictionary
	_expect(not bool(invalid_validation.get("ok", false)), "inconsistent restaurant table save was accepted")

	_finish_tests()


func _interact_with(player: Node, restaurant: Node) -> void:
	var entrance_position: Vector2 = (restaurant.get_node("entrance_marker") as Marker2D).global_position
	player.global_position = entrance_position - Vector2(60.0, 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	player.get("interaction_area").position = Vector2.RIGHT * float(player.get("interaction_offset"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_try_interact")


func _on_restaurant_interacted(_player: Node) -> void:
	restaurant_interaction_count += 1


func _finish_tests() -> void:
	if failures == 0:
		print("restaurant_foundation_test: PASS")
	else:
		push_error("restaurant_foundation_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("restaurant_foundation_test: %s" % message)


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
