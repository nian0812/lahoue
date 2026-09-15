extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_upgrade_level_test"):
		push_error("upgrade_level_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	var restaurant: Node = world.get_node("restaurant")

	_expect(data_manager.get_max_player_level() == 55, "maximum player level is not 55")
	var expected_maximums: Dictionary = {
		"warehouse": 7, "coop": 5, "pig_pen": 5,
		"cow_barn": 5, "restaurant": 10, "kitchen": 10, "resort": 5,
	}
	for system_id: String in expected_maximums:
		_expect(data_manager.get_progression_max_level(system_id) == int(expected_maximums[system_id]), "wrong maximum for '%s'" % system_id)
	var warehouse_specs: Dictionary = {
		1: {"capacity": 75, "level": 1}, 2: {"capacity": 150, "level": 5},
		3: {"capacity": 300, "level": 10}, 4: {"capacity": 500, "level": 18},
		5: {"capacity": 750, "level": 28}, 6: {"capacity": 1000, "level": 38},
		7: {"capacity": 1500, "level": 50},
	}
	for warehouse_level: int in warehouse_specs:
		var spec: Dictionary = warehouse_specs[warehouse_level] as Dictionary
		_expect(data_manager.get_warehouse_capacity(warehouse_level) == int(spec["capacity"]), "Warehouse Lv%d capacity is wrong" % warehouse_level)
		_expect(data_manager.get_system_required_player_level("warehouse", warehouse_level) == int(spec["level"]), "Warehouse Lv%d player-level permission is wrong" % warehouse_level)
	_expect(data_manager.get_crop_required_level("corn") == 4, "Corn unlock is not Lv4")
	_expect(data_manager.get_animal_required_level("pig") == 7, "Pig unlock is not Lv7")
	_expect(data_manager.get_aquaculture_required_level("fish") == 10, "Fish unlock is not Lv10")
	_expect(data_manager.get_staff_type("waiter").get("unlock_level", 0) == 5, "Waiter unlock is not Lv5")
	_expect(data_manager.get_premium_market_unlock_level() == 35, "Premium unlock is not Lv35")

	var first_threshold: int = data_manager.get_level_exp(1)
	_expect(first_threshold == 100, "Lv1 EXP threshold is wrong")
	_expect(game_manager.add_exp(first_threshold - 1), "valid EXP was rejected")
	_expect(game_manager.level == 1 and game_manager.current_exp == first_threshold - 1, "player leveled early")
	_expect(game_manager.add_exp(1), "EXP boundary was rejected")
	_expect(game_manager.level == 2 and game_manager.current_exp == 0, "EXP boundary did not reach Lv2")

	game_manager.level = 2
	game_manager.money = 300000
	_expect(not bool(world.call("upgrade_system", "coop")), "Coop ignored Lv3 permission")
	game_manager.level = 3
	_expect(bool(world.call("upgrade_system", "coop")), "Coop purchase failed at Lv3")
	_expect(int(world.get("coop_level")) == 1 and int(world.call("get_upgrade_effect", "coop")) == 5, "Coop Lv1 capacity is wrong")

	game_manager.level = 6
	game_manager.money = 500000
	_expect(not bool(world.call("upgrade_system", "pig_pen")), "Pig Pen ignored Lv7 permission")
	game_manager.level = 7
	_expect(bool(world.call("upgrade_system", "pig_pen")), "Pig Pen purchase failed at Lv7")
	_expect(int(world.call("get_upgrade_effect", "pig_pen")) == 3, "Pig Pen Lv1 capacity is wrong")

	game_manager.level = 11
	game_manager.money = 1000000
	_expect(not bool(world.call("upgrade_system", "cow_barn")), "Cow Barn ignored Lv12 permission")
	game_manager.level = 12
	_expect(bool(world.call("upgrade_system", "cow_barn")), "Cow Barn purchase failed at Lv12")
	_expect(int(world.call("get_upgrade_effect", "cow_barn")) == 2, "Cow Barn Lv1 capacity is wrong")

	game_manager.level = 4
	game_manager.money = 1000000
	_expect(not bool(world.call("upgrade_system", "restaurant")), "Restaurant ignored Lv5 permission")
	game_manager.level = 5
	_expect(bool(world.call("upgrade_system", "restaurant")), "Restaurant purchase failed at Lv5")
	_expect(bool(world.call("is_building_owned", "restaurant")), "Restaurant ownership was not recorded")
	_expect(int(restaurant.get("restaurant_level")) == 1 and int(restaurant.get("kitchen_level")) == 1, "Restaurant/Kitchen did not start synchronized")
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == 2, "Restaurant Lv1 does not have 2 tables")
	game_manager.level = 10
	game_manager.money = 500000
	_expect(bool(world.call("upgrade_system", "restaurant")), "Restaurant Lv2 upgrade failed")
	_expect(int(restaurant.get("kitchen_level")) == 2 and (restaurant.get("tables_by_id") as Dictionary).size() == 3, "Restaurant Lv2 effects are wrong")
	_expect(not bool(world.call("upgrade_system", "kitchen")), "Kitchen upgraded separately from Restaurant")

	inventory_manager.set_warehouse_level(1)
	game_manager.level = 4
	game_manager.money = 100000
	_expect(not bool(world.call("upgrade_system", "warehouse")), "Warehouse Lv2 ignored Lv5 permission")
	game_manager.level = 5
	_expect(bool(world.call("upgrade_system", "warehouse")), "Warehouse Lv2 upgrade failed")
	_expect(inventory_manager.get_capacity() == 150, "Warehouse Lv2 capacity is not 150")

	game_manager.level = 9
	game_manager.money = 500000
	_expect(not bool(world.call("upgrade_pond", "aquaculture_fish")), "Fish Pond ignored Lv10 permission")
	game_manager.level = 10
	_expect(bool(world.call("upgrade_pond", "aquaculture_fish")), "Fish Pond purchase failed")
	game_manager.money = 300000
	_expect(bool(world.call("upgrade_pond", "aquaculture_fish")), "Fish Pond Lv2 upgrade failed")
	_expect(int(world.call("get_pond_level", "aquaculture_fish")) == 2, "Fish Pond level did not change")
	_expect(is_equal_approx(data_manager.get_pond_cycle_time("fish", 2), data_manager.get_aquaculture_growth_time_seconds("fish") * 0.9), "Fish Pond Lv2 speed is wrong")

	game_manager.money = data_manager.get_farm_plot_purchase_cost()
	_expect(bool(world.call("purchase_next_farm_plot")), "second farm plot purchase failed")
	_expect((world.get("purchased_farm_plots") as Array).size() == 2, "farm plot ownership count is wrong")

	game_manager.level = 34
	game_manager.money = 10000000
	_expect(not bool(world.call("purchase_building", "vip_area")), "VIP Area ignored Lv35 permission")
	game_manager.level = 35
	_expect(bool(world.call("purchase_building", "vip_area")), "VIP Area purchase failed")
	_expect(is_equal_approx(float(world.call("get_recipe_payout_multiplier", "st25_wagyu_rice")), 1.5), "VIP payout multiplier is wrong")

	game_manager.level = 44
	game_manager.money = 50000000
	_expect(not bool(world.call("upgrade_system", "resort")), "Resort ignored Lv45 permission")
	game_manager.level = 45
	_expect(bool(world.call("upgrade_system", "resort")), "Resort purchase failed")
	var resort_income: int = int(data_manager.get_progression_level_data("resort", 1).get("booking_income", 0))
	var wallet_before_booking: int = game_manager.money
	var exp_before_booking: int = game_manager.current_exp
	_expect(bool(world.call("advance_resort", 60.0)), "Resort booking did not advance")
	_expect(game_manager.money == wallet_before_booking + resort_income, "Resort booking paid the wrong income")
	_expect(game_manager.current_exp == exp_before_booking + game_manager.calculate_sales_exp(resort_income), "Resort payout granted the wrong Sales EXP")

	for system_id: String in ["warehouse", "coop", "pig_pen", "cow_barn", "restaurant", "resort"]:
		while int(world.call("get_upgrade_level", system_id)) < data_manager.get_progression_max_level(system_id):
			var target_level: int = int(world.call("get_upgrade_level", system_id)) + 1
			game_manager.level = data_manager.get_system_required_player_level(system_id, target_level)
			game_manager.money = data_manager.get_progression_upgrade_cost(system_id, target_level)
			_expect(bool(world.call("upgrade_system", system_id)), "'%s' could not purchase level %d" % [system_id, target_level])
		var wallet_before_max: int = game_manager.money
		_expect(not bool(world.call("upgrade_system", system_id)), "'%s' upgraded beyond maximum" % system_id)
		_expect(game_manager.money == wallet_before_max, "max-level attempt changed wallet for '%s'" % system_id)

	for container_id: String in ["aquaculture_fish", "aquaculture_shrimp", "aquaculture_crab", "aquaculture_squid", "aquaculture_octopus"]:
		var container: Node = (world.get("aquaculture_containers_by_id") as Dictionary).get(container_id) as Node
		var aquaculture_id: String = String(container.get("aquaculture_id"))
		game_manager.level = data_manager.get_pond_unlock_level(aquaculture_id)
		while int(world.call("get_pond_level", container_id)) < data_manager.get_pond_max_level(aquaculture_id):
			var current_level: int = int(world.call("get_pond_level", container_id))
			game_manager.money = data_manager.get_pond_purchase_cost(aquaculture_id) if current_level == 0 else data_manager.get_pond_upgrade_cost(aquaculture_id, current_level + 1)
			_expect(bool(world.call("upgrade_pond", container_id)), "'%s' Pond could not reach level %d" % [aquaculture_id, current_level + 1])
		_expect(not bool(world.call("upgrade_pond", container_id)), "'%s' Pond upgraded beyond maximum" % aquaculture_id)

	game_manager.level = 55
	game_manager.current_exp = 0
	_expect(game_manager.add_exp(data_manager.get_level_exp(55)), "Lv55 EXP was rejected")
	_expect(game_manager.level == 55, "player exceeded Lv55")
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == 20 and int(restaurant.get("kitchen_level")) == 10, "Restaurant/Kitchen maximum effects are wrong")
	_expect(inventory_manager.get_capacity() == 1500, "Warehouse maximum capacity is wrong")

	game_manager.money = 24680
	_expect(save_manager.save_game(), "maximum progression state could not be saved")
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	_expect(save_manager.load_game(), "maximum progression state could not be loaded")
	_expect(game_manager.level == 55 and game_manager.money == 24680, "Lv55 player state did not restore")
	_expect(inventory_manager.warehouse_level == 7 and int(world.get("resort_level")) == 5, "maximum system levels did not restore")
	_expect(int(world.get_node("restaurant").get("restaurant_level")) == 10, "Restaurant level did not restore")

	var invalid_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	invalid_state["coop_level"] = 6
	_expect(not bool((save_manager.call("_validate_save_state", invalid_state) as Dictionary).get("ok", false)), "save accepted undefined Coop level")
	var legacy_warehouse_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_warehouse_state["warehouse_level"] = 10
	var legacy_warehouse_result: Dictionary = save_manager.call("_validate_save_state", legacy_warehouse_state) as Dictionary
	_expect(bool(legacy_warehouse_result.get("ok", false)), "legacy Warehouse Lv10 save did not migrate")
	_expect(int((legacy_warehouse_result.get("state", {}) as Dictionary).get("warehouse_level", 0)) == 7, "legacy Warehouse level did not migrate to Lv7")
	legacy_warehouse_state["warehouse_level"] = 11
	_expect(not bool((save_manager.call("_validate_save_state", legacy_warehouse_state) as Dictionary).get("ok", false)), "save accepted an impossible legacy Warehouse level")
	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("building_ownership")
	legacy_state.erase("purchased_farm_plots")
	legacy_state.erase("pond_levels")
	legacy_state.erase("resort_level")
	legacy_state.erase("resort_state")
	_expect(bool((save_manager.call("_validate_save_state", legacy_state) as Dictionary).get("ok", false)), "legacy progression state did not migrate")

	_finish_tests()


func _finish_tests() -> void:
	if failures == 0:
		print("upgrade_level_test: PASS")
	else:
		push_error("upgrade_level_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("upgrade_level_test: %s" % message)


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
