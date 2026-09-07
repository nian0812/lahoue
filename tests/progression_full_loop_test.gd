extends Node

const staff_script: Script = preload("res://scripts/restaurant/staff.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_progression_full_loop_test"):
		push_error("progression_full_loop_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	_validate_data_contract()

	var restaurant: Node = world.get_node("restaurant")
	var truck_manager: Node = world.get_node("truck_manager")
	var premium_market: Node = world.get_node("hub/premium_market")
	var tile_01: Node = world.get_node("farm/tile_01")
	var tile_02: Node = world.get_node("farm/tile_02")

	_expect(game_manager.level == 1, "New Game did not start at Level 1")
	_expect(game_manager.money == 200000, "New Game starting money is not 200K")
	_expect(inventory_manager.warehouse_level == 1 and inventory_manager.get_capacity() == 75, "New Game Warehouse Lv1 is wrong")
	_expect(inventory_manager.get_amount("rice") == 10 and inventory_manager.get_amount("wheat") == 10, "New Game starter inventory is wrong")
	_expect((world.get("purchased_farm_plots") as Array).size() == 1, "New Game did not own exactly one farm plot")
	_expect(tile_01.visible and bool(tile_01.get("is_purchased")), "Farm Plot #1 is not visible and usable")
	_expect(not tile_02.visible and not bool(tile_02.get("is_purchased")), "locked Farm Plot #2 is not completely hidden")
	_expect((world.get("farm_tiles_by_id") as Dictionary).size() == 40, "world does not contain 40 fixed farm plots")
	_expect((world.get("animals_by_id") as Dictionary).is_empty(), "New Game incorrectly starts with owned animals")
	_expect(not bool(restaurant.call("is_available")), "Restaurant auto-owned itself at Level 1")
	_expect(int(world.call("get_pond_level", "aquaculture_fish")) == 0, "New Game incorrectly owns Fish Pond")
	_expect(int(truck_manager.get("truck_count")) == 1 and int(truck_manager.get("truck_level")) == 1, "New Game Truck #1 Lv1 is wrong")

	var plot_money_before: int = game_manager.money
	_expect(bool(world.call("purchase_next_farm_plot")), "Farm Plot #2 purchase failed")
	_expect(game_manager.money == plot_money_before - 100000, "Farm Plot purchase did not deduct exactly 100K")
	_expect(tile_02.visible and bool(tile_02.get("is_purchased")), "purchased Farm Plot #2 did not appear")

	_set_level(5)
	_set_money(10000000)
	_expect(not bool(restaurant.call("is_available")), "Restaurant became owned from level permission alone")
	_expect(bool(world.call("can_upgrade_system", "restaurant")), "Restaurant Lv1 purchase right did not unlock at Level 5")
	var restaurant_money_before: int = game_manager.money
	_expect(bool(world.call("upgrade_system", "restaurant")), "Restaurant Lv1 purchase failed")
	_expect(game_manager.money == restaurant_money_before - 1000000, "Restaurant Lv1 did not cost 1M")
	_expect(bool(restaurant.call("is_available")), "paid Restaurant did not become available")
	_expect(int(restaurant.get("restaurant_level")) == 1 and int(restaurant.get("kitchen_level")) == 1, "Restaurant and Kitchen Lv1 are not synchronized")
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == 2, "Restaurant Lv1 does not have exactly two tables")
	_expect(not bool(world.call("can_upgrade_system", "restaurant")), "Level 5 rich player could buy Restaurant Lv2 before permission")

	_expect(bool(world.call("upgrade_system", "coop")), "Chicken Coop Lv1 purchase failed at Level 5")
	_expect(not bool(world.call("can_upgrade_system", "coop")), "Chicken Coop Lv2 ignored its player-level permission")

	var waiter: Node = restaurant.call("hire_staff", "waiter_payroll_test", "waiter") as Node
	_expect(waiter != null, "Waiter hire failed")
	_set_money(50000)
	restaurant.call("_on_day_finishing", game_manager.day)
	_expect(game_manager.money == 50000, "unaffordable payroll made the wallet negative or partially deducted")
	_expect(waiter != null and not bool(waiter.get("is_paid")), "unpaid Waiter was not marked unpaid")
	_expect(waiter != null and int(waiter.get("salary_debt")) == 70000, "Waiter salary debt is not 70K")
	_expect(waiter != null and [staff_script.state_off_duty, staff_script.state_returning].has(String(waiter.get("current_state"))), "unpaid Waiter did not go OFF DUTY")
	_expect(waiter != null and not bool(waiter.call("can_accept_job", staff_script.job_serve)), "unpaid Waiter still accepts jobs")
	game_manager.add_money(20000)
	_expect(int(restaurant.call("pay_staff_debts")) == 70000, "outstanding payroll could not be paid")
	_expect(bool(waiter.get("is_paid")) and int(waiter.get("salary_debt")) == 0, "paid debt did not reactivate Waiter")

	_set_level(7)
	_set_money(5000000)
	_expect(bool(world.call("upgrade_system", "pig_pen")), "Pig Pen Lv1 purchase failed at Level 7")
	var meat_chicken: Node = world.call("purchase_animal", "meat_chicken_test", "meat_chicken", Vector2.ZERO) as Node
	var pig: Node = world.call("purchase_animal", "pig_test", "pig", Vector2.ZERO) as Node
	_expect(meat_chicken != null and pig != null, "Meat Chicken or Pig purchase failed")
	_make_animal_product_ready(meat_chicken)
	_make_animal_product_ready(pig)
	_expect(_first_pending_item(meat_chicken) == "chicken_meat", "Meat Chicken does not produce Chicken Meat")
	_expect(_first_pending_item(pig) == "pork", "Pig does not produce Pork")
	_expect(bool(meat_chicken.call("collect_next_product")) and bool(world.call("has_animal", "meat_chicken_test")), "Meat Chicken disappeared after product collection")
	_expect(bool(pig.call("collect_next_product")) and bool(world.call("has_animal", "pig_test")), "Pig disappeared after product collection")

	_set_level(10)
	_set_money(3000000)
	var pond_money_before: int = game_manager.money
	_expect(bool(world.call("upgrade_pond", "aquaculture_fish")), "Fish Pond purchase failed at Level 10")
	_expect(game_manager.money == pond_money_before - 500000, "Fish Pond did not cost 500K")
	var fish_pond: Node = (world.get("aquaculture_containers_by_id") as Dictionary).get("aquaculture_fish") as Node
	_expect(int(fish_pond.get("pond_level")) == 1 and bool(fish_pond.call("start_cycle")), "purchased Fish Pond could not start a cycle")

	_set_level(35)
	_set_money(250000000)
	_expect(not bool(premium_market.call("is_unlocked")), "Premium Market unlocked without paid ownership")
	_expect(bool(world.call("purchase_building", "international_license")), "International License purchase failed")
	_expect(not bool(premium_market.call("is_unlocked")), "International License alone unlocked Premium Market")
	var helipad_money_before: int = game_manager.money
	_expect(bool(world.call("purchase_building", "helipad")), "Helipad + Helicopter Lv1 purchase failed")
	_expect(game_manager.money == helipad_money_before - 100000000, "Helipad + Helicopter Lv1 did not cost 100M")
	_expect(bool(premium_market.call("is_unlocked")), "paid International License + Helipad did not unlock Premium Market")
	_expect(bool(world.call("purchase_building", "vip_area")), "VIP Area purchase failed")
	_expect(is_equal_approx(float(world.call("get_recipe_payout_multiplier", "wagyu_steak")), 1.5), "VIP premium payout is not 1.5x")
	_expect(is_equal_approx(float(world.call("get_recipe_payout_multiplier", "garlic_egg_rice")), 1.0), "VIP incorrectly multiplies normal recipes")
	var vip_exp_before: int = game_manager.current_exp
	var vip_wallet_before: int = game_manager.money
	var vip_base_revenue: int = int((restaurant.call("get_menu_entry", "st25_wagyu_rice") as Dictionary).get("selling_price", 0))
	var vip_revenue: int = roundi(float(vip_base_revenue) * 1.5)
	_expect(bool(restaurant.call("collect_revenue", "st25_wagyu_rice")), "VIP payment transaction failed")
	_expect(game_manager.money == vip_wallet_before + vip_revenue, "VIP payment paid the wrong revenue")
	_expect(game_manager.current_exp == vip_exp_before + 1000, "VIP payment did not cap Sales EXP at 1000")

	_set_level(44)
	_set_money(100000000)
	_expect(not bool(world.call("can_upgrade_system", "resort")), "Resort purchase unlocked before Level 45")
	_set_level(45)
	var resort_money_before: int = game_manager.money
	_expect(bool(world.call("upgrade_system", "resort")), "Resort Lv1 purchase failed at Level 45")
	_expect(game_manager.money == resort_money_before - 50000000, "Resort Lv1 did not cost 50M")
	var resort_data: Dictionary = data_manager.get_progression_level_data("resort", 1)
	var income_before: int = game_manager.money
	_expect(bool(world.call("advance_resort", float(resort_data.get("booking_interval", 0.0)))), "Resort booking did not advance")
	_expect(game_manager.money == income_before + int(resort_data.get("booking_income", 0)), "Resort booking income is wrong")
	restaurant.call("_clear_customers")
	restaurant.call("_reset_tables")

	_set_level(55)
	_expect(game_manager.level == 55 and data_manager.get_max_player_level() == 55, "Level 55 cap is not active")
	_expect((data_manager.get_restaurant_menu(55) as Dictionary).size() == 50, "Level 55 does not unlock all 50 recipes")
	var level_before_max_exp: int = game_manager.level
	game_manager.add_exp(1000000)
	_expect(game_manager.level == level_before_max_exp, "EXP progressed beyond Level 55")

	game_manager.day = 3
	var saved_money: int = game_manager.money
	var saved_plots: Array = (world.get("purchased_farm_plots") as Array).duplicate()
	_expect(save_manager.save_game(), "modern Lv55 state did not save")
	_set_money(1)
	world.set("purchased_farm_plots", ["farm_01"])
	_expect(save_manager.load_game(), "modern Lv55 state did not continue")
	_expect(game_manager.money == saved_money and (world.get("purchased_farm_plots") as Array) == saved_plots, "Save/Continue did not restore economy ownership")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	for field: String in ["building_ownership", "purchased_farm_plots", "pond_levels", "pig_pen_level", "resort_level", "resort_state"]:
		legacy_state.erase(field)
	legacy_state["animals"] = {}
	legacy_state["animal_age"] = {}
	var legacy_staff: Dictionary = legacy_state.get("staff", {}) as Dictionary
	for staff_value: Variant in legacy_staff.values():
		if typeof(staff_value) == TYPE_DICTIONARY:
			(staff_value as Dictionary).erase("is_paid")
			(staff_value as Dictionary).erase("salary_debt")
	var legacy_result: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_result.get("ok", false)), "legacy save did not migrate: %s" % String(legacy_result.get("error", "")))
	if bool(legacy_result.get("ok", false)):
		var migrated: Dictionary = legacy_result.get("state", {}) as Dictionary
		_expect(typeof(migrated.get("building_ownership")) == TYPE_DICTIONARY, "legacy migration did not add building ownership")
		_expect((migrated.get("purchased_farm_plots", []) as Array).has("farm_01"), "legacy migration did not add farm plots")
		_expect(typeof(migrated.get("pond_levels")) == TYPE_DICTIONARY, "legacy migration did not add pond ownership")

	_cleanup_save_files()
	game_manager.stop_gameplay()
	if failures == 0:
		print("PROGRESSION FULL LOOP TEST: PASS")
		get_tree().quit(0)
	else:
		push_error("PROGRESSION FULL LOOP TEST: FAIL (%d failures)" % failures)
		get_tree().quit(1)


func _validate_data_contract() -> void:
	_expect(data_manager.get_max_player_level() == 55, "configured player cap is not Level 55")
	_expect(data_manager.get_farm_plot_maximum() == 40 and data_manager.get_farm_plot_purchase_cost() == 100000, "farm plot contract is wrong")
	_expect(data_manager.get_warehouse_capacity(1) == 75 and data_manager.get_warehouse_capacity(7) == 1500, "Warehouse tier contract is wrong")
	_expect(data_manager.get_progression_max_level("warehouse") == 7, "Warehouse maximum is not Lv7")
	var expected_plot_limits: Dictionary = {1: 3, 5: 5, 10: 8, 15: 12, 20: 16, 25: 20, 30: 25, 35: 30, 40: 34, 45: 37, 50: 40}
	for required_level: int in expected_plot_limits:
		_expect(data_manager.get_farm_plot_limit(required_level) == int(expected_plot_limits[required_level]), "Farm Plot limit is wrong at Player Lv%d" % required_level)
	_expect(data_manager.get_restaurant_table_capacity(1) == 2 and data_manager.get_restaurant_table_capacity(10) == 20, "Restaurant table tiers are wrong")
	_expect(data_manager.get_kitchen_cooking_slots(1) == 1 and data_manager.get_kitchen_cooking_slots(10) == 6, "Kitchen tiers are wrong")
	_expect(data_manager.get_item_sell_price("egg") == 20000 and data_manager.get_item_sell_price("beef") == 200000, "animal raw prices are wrong")
	_expect(data_manager.get_item_sell_price("fish") == 50000 and data_manager.get_item_sell_price("octopus") == 500000, "aquaculture raw prices are wrong")
	_expect(data_manager.get_item_sell_price("st25_rice") <= 0 and data_manager.get_item_buy_price("st25_rice") == 100000, "imports can be profitably resold or have the wrong price")
	_expect(data_manager.get_level_exp(30) == 3600, "Lv30 EXP tier is not base +20%")
	_expect(data_manager.get_level_exp(40) == 5600, "Lv40 EXP tier is not base +40%")
	_expect(data_manager.get_level_exp(50) == 8750, "Lv50 EXP tier is not base +75%")

	var recipes: Dictionary = data_manager.get_dataset("recipes").get("entries", {}) as Dictionary
	_expect(recipes.size() == 50, "recipe dataset does not contain exactly 50 recipes")
	var used_items: Dictionary = {}
	for recipe_id_value: Variant in recipes:
		var recipe_id: String = String(recipe_id_value)
		var recipe: Dictionary = recipes[recipe_id_value] as Dictionary
		var ingredient_cost: int = 0
		for item_id_value: Variant in recipe.get("ingredients", {}) as Dictionary:
			var item_id: String = String(item_id_value)
			var amount: int = int((recipe.get("ingredients", {}) as Dictionary)[item_id_value])
			used_items[item_id] = true
			var unit_cost: int = data_manager.get_item_buy_price(item_id)
			if unit_cost <= 0:
				unit_cost = data_manager.get_item_sell_price(item_id)
			ingredient_cost += unit_cost * amount
		var selling_price: int = int(recipe.get("selling_price", 0))
		if String(recipe.get("category", "")) == "premium":
			_expect(selling_price >= ingredient_cost * 2, "premium recipe '%s' is below 2x ingredient cost" % recipe_id)
		else:
			_expect(selling_price > ingredient_cost, "normal recipe '%s' is not more profitable than raw ingredients" % recipe_id)
		_expect(int(recipe.get("required_level", 0)) <= 55, "recipe '%s' unlocks above Level 55" % recipe_id)
	var required_ingredients: Array[String] = [
		"rice", "wheat", "corn", "cucumber", "green_onion", "tomato", "chili", "carrot", "potato",
		"soybean", "garlic", "coconut", "lemongrass", "tea_leaf", "peanut", "sugarcane", "coffee_bean", "banana",
		"egg", "cow_milk", "chicken_meat", "pork", "beef", "fish", "shrimp", "crab", "squid", "octopus",
		"st25_rice", "butter", "cheese", "olive_oil", "salmon", "japanese_scallop",
		"lobster", "saffron", "king_crab", "wagyu", "bluefin_tuna", "truffle",
	]
	for item_id: String in required_ingredients:
		_expect(used_items.has(item_id), "50 recipes do not use required ingredient '%s'" % item_id)
	_expect(((recipes.get("potato_fries", {}) as Dictionary).get("ingredients", {}) as Dictionary).has("potato"), "Potato Fries does not use Potato")
	_expect(((recipes.get("soybean_tofu", {}) as Dictionary).get("ingredients", {}) as Dictionary).has("soybean"), "Tofu does not use Soybean")


func _set_level(value: int) -> void:
	var state: Dictionary = game_manager.get_save_state()
	state["level"] = value
	state["exp"] = 0
	game_manager.apply_save_state(state)


func _set_money(value: int) -> void:
	game_manager.money = value
	game_manager.money_changed.emit(value)


func _make_animal_product_ready(animal: Node) -> void:
	if animal == null:
		return
	animal.call("advance_lifecycle", 1)
	animal.call("advance_lifecycle", 2)


func _first_pending_item(animal: Node) -> String:
	if animal == null:
		return ""
	var pending: Array = animal.call("get_pending_products") as Array
	return String((pending[0] as Dictionary).get("item_id", "")) if not pending.is_empty() else ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("progression_full_loop_test: %s" % message)


func _cleanup_save_files() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return
	for file_name: String in ["savegame.json", "savegame.backup.json", "savegame.tmp.json"]:
		if user_directory.file_exists(file_name):
			user_directory.remove(file_name)
