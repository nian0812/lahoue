extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_inventory_economy_test"):
		push_error("inventory_economy_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()

	_expect(inventory_manager.get_capacity() == 75, "Warehouse Lv1 capacity is not 75")
	_expect(inventory_manager.add_item("rice", 5), "valid stack could not be added")
	_expect(inventory_manager.get_amount("rice") == 5, "stack quantity is wrong")
	_expect(inventory_manager.remove_item("rice", 2), "valid stack quantity could not be removed")
	var safe_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.add_item("unknown_item", 1), "unknown item was accepted")
	_expect(not inventory_manager.remove_item("rice", 4), "insufficient stack was removed")
	_expect(inventory_manager.items == safe_inventory, "failed inventory transaction was not atomic")
	_expect(inventory_manager.add_item("corn", inventory_manager.get_free_space()), "Warehouse could not be filled")
	_expect(not inventory_manager.add_item("fish", 1), "full Warehouse accepted an item")

	inventory_manager.clear()
	game_manager.level = 1
	game_manager.money = data_manager.get_item_buy_price("rice") + data_manager.get_item_buy_price("wheat")
	_expect(inventory_manager.purchase_seed("rice"), "Rice seed purchase failed at Lv1")
	_expect(inventory_manager.purchase_seed("wheat"), "Wheat seed purchase failed at Lv1")
	game_manager.money = data_manager.get_item_buy_price("corn")
	_expect(not inventory_manager.purchase_seed("corn"), "Corn seed ignored its Lv4 unlock")
	game_manager.level = 4
	_expect(inventory_manager.purchase_seed("corn"), "Corn seed did not unlock at Lv4")

	inventory_manager.clear()
	game_manager.level = 55
	var crops: Dictionary = data_manager.get_dataset("crops").get("entries", {}) as Dictionary
	var all_seed_cost: int = 0
	for crop_value: Variant in crops.values():
		var crop: Dictionary = crop_value as Dictionary
		all_seed_cost += data_manager.get_item_buy_price(String(crop.get("seed_item", "")))
	game_manager.money = all_seed_cost
	for crop_id_value: Variant in crops:
		var crop_id: String = String(crop_id_value)
		var crop: Dictionary = crops[crop_id] as Dictionary
		var seed_id: String = String(crop.get("seed_item", ""))
		_expect(inventory_manager.purchase_seed(seed_id), "seed purchase failed for '%s'" % crop_id)
	_expect(inventory_manager.get_stack_count() == 18, "seed shop does not expose all 18 crops")
	_expect(game_manager.money == 0, "seed purchases did not use data prices")
	_expect(game_manager.current_exp == 0, "seed purchases incorrectly granted sales EXP")

	inventory_manager.clear()
	game_manager.level = 55
	game_manager.current_exp = 0
	_expect(game_manager.calculate_sales_exp(100000) == 10, "100K revenue does not calculate 10 Sales EXP")
	_expect(game_manager.calculate_sales_exp(1000000) == 100, "1M revenue does not calculate 100 Sales EXP")
	_expect(game_manager.calculate_sales_exp(10000000) == 1000, "10M revenue does not calculate 1000 Sales EXP")
	_expect(game_manager.calculate_sales_exp(50000000) == 1000, "Sales EXP is not capped at 1000")
	game_manager.money = 0
	_expect(inventory_manager.add_item("rice", 10), "100K sale fixture failed")
	_expect(inventory_manager.sell_item("rice", 10), "100K raw crop sale failed")
	_expect(game_manager.money == 100000 and game_manager.current_exp == 10, "100K sale did not pay 10 Sales EXP")
	inventory_manager.clear()
	game_manager.money = 0
	_expect(inventory_manager.add_item("chicken_meat", 10), "1M sale fixture failed")
	_expect(inventory_manager.sell_item("chicken_meat", 10), "1M sale failed")
	_expect(game_manager.money == 1000000 and game_manager.current_exp == 110, "1M sale did not pay 100 Sales EXP")
	inventory_manager.clear()
	game_manager.money = 0
	_expect(inventory_manager.add_item("beef", 50), "10M sale fixture failed")
	_expect(inventory_manager.sell_item("beef", 50), "10M sale failed")
	_expect(game_manager.money == 10000000 and game_manager.current_exp == 1110, "10M sale did not cap at 1000 Sales EXP")
	_expect(inventory_manager.add_item("wagyu", 1), "import fixture failed")
	var wallet_before_import_sale: int = game_manager.money
	var exp_before_import_sale: int = game_manager.current_exp
	_expect(not inventory_manager.sell_item("wagyu", 1), "imported ingredient was directly sellable")
	_expect(game_manager.money == wallet_before_import_sale and inventory_manager.get_amount("wagyu") == 1, "failed import sale mutated economy")
	_expect(game_manager.current_exp == exp_before_import_sale, "failed import sale granted Sales EXP")

	inventory_manager.clear()
	inventory_manager.set_warehouse_level(1)
	game_manager.current_exp = 0
	game_manager.level = 4
	game_manager.money = 100000
	_expect(not inventory_manager.upgrade_warehouse(), "Warehouse Lv2 ignored Lv5 permission")
	_expect(game_manager.money == 100000 and inventory_manager.warehouse_level == 1, "locked Warehouse upgrade was not atomic")
	game_manager.level = 5
	_expect(inventory_manager.upgrade_warehouse(), "Warehouse Lv2 purchase failed at Lv5")
	_expect(inventory_manager.get_capacity() == 150 and game_manager.money == 0, "Warehouse Lv2 cost/capacity is wrong")

	game_manager.level = 3
	game_manager.money = 500000
	_expect(bool(world.call("upgrade_system", "coop")), "Coop purchase failed")
	var animal: Node = world.call("purchase_animal", "economy_layer", "chicken", Vector2(1160.0, 320.0)) as Node
	_expect(animal != null, "Layer Chicken purchase failed after owning Coop")
	_expect(game_manager.money == 0, "Coop plus Layer Chicken charged the wrong total")

	game_manager.level = 5
	game_manager.money = 123456
	inventory_manager.clear()
	_expect(inventory_manager.set_warehouse_level(2), "save Warehouse fixture failed")
	_expect(inventory_manager.add_item("rice", 4), "save inventory fixture failed")
	_expect(save_manager.save_game(), "economy state could not be saved")
	inventory_manager.clear()
	game_manager.money = 0
	_expect(save_manager.load_game(), "economy state could not be loaded")
	_expect(inventory_manager.get_amount("rice") == 4, "inventory did not restore")
	_expect(inventory_manager.warehouse_level == 2 and inventory_manager.get_capacity() == 150, "Warehouse did not restore (level=%d capacity=%d)" % [inventory_manager.warehouse_level, inventory_manager.get_capacity()])
	_expect(game_manager.money == 123456 and bool(world.call("is_building_owned", "coop")), "wallet/ownership did not restore")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("building_ownership")
	legacy_state.erase("purchased_farm_plots")
	legacy_state.erase("pond_levels")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy economy save did not migrate")

	_finish_tests()


func _finish_tests() -> void:
	if failures == 0:
		print("inventory_economy_test: PASS")
	else:
		push_error("inventory_economy_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("inventory_economy_test: %s" % message)


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
