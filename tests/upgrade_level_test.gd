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
	var maximum_player_level: int = data_manager.get_max_player_level()
	_expect(maximum_player_level == 10, "maximum player level did not come from progression data")
	for system_id: String in ["warehouse", "coop", "cow_barn", "aquaculture", "restaurant", "kitchen"]:
		_expect(data_manager.get_progression_max_level(system_id) > 0, "upgrade system '%s' has no data-driven maximum" % system_id)
	_expect(data_manager.get_progression_max_level("unknown") == 0, "unknown upgrade system has a maximum")

	_expect(data_manager.get_crop_required_level("wheat") == 2, "farm unlock did not come from crops data")
	_expect(data_manager.get_animal_required_level("cow") == 2, "animal unlock did not come from animals data")
	_expect(data_manager.get_aquaculture_required_level("fish") == 3, "aquaculture unlock did not come from aquaculture data")
	_expect(not bool(restaurant.call("is_available")), "restaurant was unlocked at player level 1")
	_expect(int(data_manager.get_staff_type("waiter").get("unlock_level", 0)) == 4, "staff unlock did not come from staff data")

	var first_threshold: int = data_manager.get_level_exp(1)
	_expect(first_threshold == 100, "level-1 EXP threshold is wrong")
	_expect(game_manager.add_exp(first_threshold - 1), "valid EXP could not be added")
	_expect(game_manager.level == 1 and game_manager.current_exp == first_threshold - 1, "player leveled too early")
	_expect(game_manager.add_exp(1), "EXP threshold boundary failed")
	_expect(game_manager.level == 2 and game_manager.current_exp == 0, "EXP threshold did not level player")
	_expect(data_manager.get_crop_required_level("wheat") <= game_manager.level, "level 2 did not unlock farming data")
	_expect(data_manager.get_animal_required_level("cow") <= game_manager.level, "level 2 did not unlock animal data")
	var exp_snapshot: int = game_manager.current_exp
	_expect(not game_manager.add_exp(0) and not game_manager.add_exp(-1), "invalid EXP was accepted")
	_expect(game_manager.current_exp == exp_snapshot, "invalid EXP changed progression")
	_expect(game_manager.add_exp(data_manager.get_level_exp(2)), "level 3 EXP could not be applied")
	_expect(game_manager.level == 3 and data_manager.get_aquaculture_required_level("fish") <= game_manager.level, "aquaculture did not unlock at level 3")
	_expect(game_manager.add_exp(data_manager.get_level_exp(3)), "restaurant unlock EXP could not be applied")
	_expect(game_manager.level == 4 and bool(restaurant.call("is_available")), "restaurant did not unlock at level 4")

	var invalid_wallet: int = 4321
	game_manager.money = invalid_wallet
	_expect(not bool(world.call("upgrade_system", "unknown")), "unknown upgrade was accepted")
	_expect(game_manager.money == invalid_wallet, "invalid upgrade changed wallet")

	var warehouse_cost: int = data_manager.get_progression_upgrade_cost("warehouse", 2)
	game_manager.money = warehouse_cost - 1
	_expect(not bool(world.call("upgrade_system", "warehouse")), "warehouse upgraded with insufficient funds")
	_expect(inventory_manager.warehouse_level == 1 and game_manager.money == warehouse_cost - 1, "failed warehouse upgrade was not atomic")
	game_manager.money = warehouse_cost
	_expect(bool(world.call("upgrade_system", "warehouse")), "warehouse upgrade purchase failed")
	_expect(inventory_manager.warehouse_level == 2 and inventory_manager.get_capacity() == 150, "warehouse capacity did not upgrade")
	_expect(game_manager.money == 0, "warehouse upgrade charged the wrong amount")

	_expect(_fund_and_upgrade("coop"), "coop upgrade purchase failed")
	_expect(int(world.get("coop_level")) == 2 and int(world.call("get_upgrade_effect", "coop")) == 10, "coop capacity did not upgrade")
	var cow_cost: int = data_manager.get_progression_upgrade_cost("cow_barn", 2)
	game_manager.money = cow_cost - 1
	_expect(not bool(world.call("upgrade_system", "cow_barn")), "cow barn upgraded with insufficient funds")
	_expect(int(world.get("cow_barn_level")) == 1 and game_manager.money == cow_cost - 1, "failed cow barn transaction mutated state")
	_expect(_fund_and_upgrade("cow_barn"), "cow barn upgrade purchase failed")
	_expect(int(world.call("get_upgrade_effect", "cow_barn")) == 4, "cow barn capacity did not upgrade")
	_expect(_fund_and_upgrade("aquaculture"), "aquaculture upgrade purchase failed")
	_expect(int(world.get("aquaculture_level")) == 2 and int(world.call("get_upgrade_effect", "aquaculture")) == 2, "aquaculture area capacity did not upgrade")

	_expect(_fund_and_upgrade("restaurant"), "restaurant upgrade purchase failed")
	_expect(int(restaurant.get("restaurant_level")) == 2, "restaurant level did not upgrade")
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == 5, "restaurant table capacity did not upgrade")
	_expect(_fund_and_upgrade("kitchen"), "kitchen upgrade purchase failed")
	_expect(int(restaurant.get("kitchen_level")) == 2, "kitchen level did not upgrade")
	_expect(data_manager.get_kitchen_cooking_slots(2) == 2 and data_manager.get_kitchen_speed_percent(2) == 85, "kitchen upgrade effects are wrong")

	for system_id: String in ["warehouse", "coop", "cow_barn", "aquaculture", "restaurant", "kitchen"]:
		while int(world.call("get_upgrade_level", system_id)) < data_manager.get_progression_max_level(system_id):
			_expect(_fund_and_upgrade(system_id), "system '%s' could not reach its configured maximum" % system_id)
		var maximum_level: int = data_manager.get_progression_max_level(system_id)
		var maximum_effect: int = data_manager.get_progression_effect(system_id, maximum_level)
		_expect(int(world.call("get_upgrade_level", system_id)) == maximum_level, "system '%s' maximum level is wrong" % system_id)
		_expect(int(world.call("get_upgrade_effect", system_id)) == maximum_effect, "system '%s' maximum effect is wrong" % system_id)
		game_manager.money = 999999999
		var wallet_before_max_attempt: int = game_manager.money
		_expect(not bool(world.call("upgrade_system", system_id)), "system '%s' upgraded beyond maximum" % system_id)
		_expect(game_manager.money == wallet_before_max_attempt, "max-level upgrade attempt changed wallet for '%s'" % system_id)
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == data_manager.get_restaurant_table_capacity(5), "maximum restaurant capacity is not active")

	while game_manager.level < maximum_player_level:
		_expect(game_manager.add_exp(data_manager.get_level_exp(game_manager.level)), "player could not reach maximum level")
	_expect(game_manager.level == maximum_player_level, "player exceeded or missed maximum level")
	var max_level_exp_before: int = game_manager.current_exp
	_expect(game_manager.add_exp(data_manager.get_level_exp(maximum_player_level)), "maximum-level EXP was rejected")
	_expect(game_manager.level == maximum_player_level and game_manager.current_exp > max_level_exp_before, "maximum-level EXP changed level incorrectly")

	game_manager.money = 24680
	_expect(save_manager.save_game(), "upgrade state could not be saved")
	inventory_manager.set_warehouse_level(1)
	world.call("apply_progression_save_state", {"coop_level": 1, "cow_barn_level": 1, "aquaculture_level": 1})
	restaurant.call("apply_save_state", {
		"restaurant_level": 1,
		"kitchen_level": 1,
		"restaurant_tables": {},
		"restaurant_customers": {},
		"restaurant_customer_sequence": 0,
		"restaurant_spawn_elapsed": 0.0,
		"restaurant_cooking": {},
		"staff": {},
	})
	game_manager.level = 1
	game_manager.current_exp = 0
	game_manager.money = 0
	_expect(save_manager.load_game(), "upgrade state could not be loaded")
	_expect(game_manager.level == maximum_player_level and game_manager.money == 24680, "player progression did not restore")
	_expect(inventory_manager.warehouse_level == data_manager.get_progression_max_level("warehouse"), "warehouse level did not restore")
	_expect(int(world.get("coop_level")) == data_manager.get_progression_max_level("coop"), "coop level did not restore")
	_expect(int(world.get("cow_barn_level")) == data_manager.get_progression_max_level("cow_barn"), "cow barn level did not restore")
	_expect(int(world.get("aquaculture_level")) == data_manager.get_progression_max_level("aquaculture"), "aquaculture level did not restore")
	_expect(int(restaurant.get("restaurant_level")) == data_manager.get_progression_max_level("restaurant"), "restaurant level did not restore")
	_expect(int(restaurant.get("kitchen_level")) == data_manager.get_progression_max_level("kitchen"), "kitchen level did not restore")
	_expect((restaurant.get("tables_by_id") as Dictionary).size() == 20, "restaurant table capacity did not restore")

	var invalid_level_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	invalid_level_state["coop_level"] = data_manager.get_progression_max_level("coop") + 1
	_expect(not bool((save_manager.call("_validate_save_state", invalid_level_state) as Dictionary).get("ok", false)), "save accepted an undefined upgrade level")
	var invalid_capacity_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	invalid_capacity_state["coop_level"] = 1
	var crowded_animals: Dictionary = invalid_capacity_state.get("animals", {}) as Dictionary
	var crowded_age: Dictionary = invalid_capacity_state.get("animal_age", {}) as Dictionary
	var chicken_state: Dictionary = (crowded_animals.get("chicken_01", {}) as Dictionary).duplicate(true)
	for chicken_number: int in range(2, 7):
		var chicken_id: String = "capacity_chicken_%02d" % chicken_number
		crowded_animals[chicken_id] = chicken_state.duplicate(true)
		crowded_age[chicken_id] = int(crowded_age.get("chicken_01", 0))
	invalid_capacity_state["animals"] = crowded_animals
	invalid_capacity_state["animal_age"] = crowded_age
	_expect(not bool((save_manager.call("_validate_save_state", invalid_capacity_state) as Dictionary).get("ok", false)), "save accepted animals beyond housing capacity")
	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("aquaculture_level")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "Phase 10 v1 save without aquaculture level is incompatible")
	_expect(int((legacy_validation.get("state", {}) as Dictionary).get("aquaculture_level", 0)) == 1, "legacy aquaculture level did not migrate safely")

	_finish_tests()


func _fund_and_upgrade(system_id: String) -> bool:
	var target_level: int = int(world.call("get_upgrade_level", system_id)) + 1
	var cost: int = data_manager.get_progression_upgrade_cost(system_id, target_level)
	if cost <= 0:
		return false
	game_manager.money = cost
	var upgraded: bool = bool(world.call("upgrade_system", system_id))
	return upgraded and game_manager.money == 0


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
