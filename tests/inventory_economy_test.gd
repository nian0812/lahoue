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

	_expect(inventory_manager.get_capacity() == 100, "level-1 warehouse capacity is wrong")
	_expect(inventory_manager.get_used_capacity() == 0, "new inventory is not empty")
	_expect(inventory_manager.get_stack_count() == 0, "new inventory has stacks")
	_expect(inventory_manager.add_item("rice_seed", 2), "valid item could not be added")
	_expect(inventory_manager.add_item("rice_seed", 3), "matching item did not stack")
	_expect(inventory_manager.get_amount("rice_seed") == 5, "stacked quantity is wrong")
	_expect(inventory_manager.get_stack_count() == 1, "matching items created duplicate stacks")
	_expect(inventory_manager.get_used_capacity() == 5, "used capacity does not count stack quantities")
	_expect(inventory_manager.add_item("egg", 1), "second item stack could not be added")
	_expect(inventory_manager.get_stack_count() == 2, "different items did not create separate stacks")
	_expect(inventory_manager.remove_item("rice_seed", 2), "valid item quantity could not be removed")
	_expect(inventory_manager.get_amount("rice_seed") == 3, "remove item left the wrong quantity")
	_expect(inventory_manager.remove_item("egg", 1), "whole stack could not be removed")
	_expect(not inventory_manager.items.has("egg"), "zero-quantity stack was retained")

	var safe_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.add_item("unknown_item", 1), "unknown item was accepted")
	_expect(not inventory_manager.add_item("rice_seed", 0), "zero add quantity was accepted")
	_expect(not inventory_manager.add_item("rice_seed", -1), "negative add quantity was accepted")
	_expect(not inventory_manager.remove_item("rice_seed", 0), "zero remove quantity was accepted")
	_expect(not inventory_manager.remove_item("rice_seed", -1), "negative remove quantity was accepted")
	_expect(not inventory_manager.remove_item("rice_seed", 4), "insufficient stack was removed")
	_expect(inventory_manager.items == safe_inventory, "failed inventory operation mutated items")

	var fill_amount: int = inventory_manager.get_free_space()
	_expect(inventory_manager.add_item("corn_seed", fill_amount), "inventory could not be filled to capacity")
	var full_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(inventory_manager.get_free_space() == 0, "full inventory reports free space")
	_expect(not inventory_manager.add_item("fish", 1), "full inventory accepted an item")
	_expect(inventory_manager.items == full_inventory, "capacity failure lost or changed items")

	inventory_manager.clear()
	game_manager.level = 1
	var rice_seed_price: int = data_manager.get_item_buy_price("rice_seed")
	game_manager.money = rice_seed_price * 2
	_expect(inventory_manager.purchase_seed("rice_seed", 2), "seed purchase failed")
	_expect(inventory_manager.get_amount("rice_seed") == 2, "purchased seeds were not added")
	_expect(game_manager.get_wallet_balance() == 0, "seed purchase charged the wrong price")
	var purchased_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.purchase_seed("rice_seed", 1), "purchase succeeded with insufficient funds")
	_expect(game_manager.get_wallet_balance() == 0, "failed purchase changed wallet")
	_expect(inventory_manager.items == purchased_inventory, "failed purchase changed inventory")

	var wheat_seed_price: int = data_manager.get_item_buy_price("wheat_seed")
	game_manager.money = wheat_seed_price
	_expect(data_manager.get_item_required_level("wheat_seed") == 2, "seed unlock level did not come from crops.json")
	_expect(not inventory_manager.purchase_seed("wheat_seed", 1), "locked seed was purchased")
	_expect(game_manager.get_wallet_balance() == wheat_seed_price, "locked purchase spent money")
	game_manager.level = 2
	_expect(inventory_manager.purchase_seed("wheat_seed", 1), "unlocked seed purchase failed")
	_expect(game_manager.get_wallet_balance() == 0, "unlocked seed purchase charged the wrong price")
	_expect(not inventory_manager.purchase_seed("wagyu", 1), "non-seed item passed seed purchasing API")
	_expect(not inventory_manager.purchase_item("unknown_item", 1), "unknown item was purchased")
	_expect(not inventory_manager.purchase_item("rice_seed", 0), "zero purchase quantity was accepted")
	_expect(not inventory_manager.purchase_item("rice_seed", -1), "negative purchase quantity was accepted")

	inventory_manager.clear()
	var wagyu_price: int = data_manager.get_item_buy_price("wagyu")
	game_manager.money = wagyu_price
	_expect(inventory_manager.purchase_item("wagyu", 1), "general item purchase failed")
	_expect(inventory_manager.get_amount("wagyu") == 1, "purchased general item was not added")
	_expect(game_manager.get_wallet_balance() == 0, "general item purchase charged the wrong price")
	var wallet_before_unavailable_purchase: int = game_manager.get_wallet_balance()
	var inventory_before_unavailable_purchase: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.purchase_item("rice", 1), "item with null buy_price was purchased")
	_expect(game_manager.get_wallet_balance() == wallet_before_unavailable_purchase, "unavailable purchase changed wallet")
	_expect(inventory_manager.items == inventory_before_unavailable_purchase, "unavailable purchase changed inventory")

	inventory_manager.clear()
	game_manager.level = 2
	var seed_items: Array[String] = [
		"rice_seed", "corn_seed", "tomato_seed", "cabbage_seed",
		"wheat_seed", "tea_seed", "coffee_seed"
	]
	var all_seed_cost: int = 0
	for seed_item_id: String in seed_items:
		all_seed_cost += data_manager.get_item_buy_price(seed_item_id)
	game_manager.money = all_seed_cost
	for seed_item_id: String in seed_items:
		_expect(inventory_manager.purchase_seed(seed_item_id, 1), "seed shop failed for '%s'" % seed_item_id)
	_expect(game_manager.get_wallet_balance() == 0, "seed shop total did not use JSON prices")
	_expect(inventory_manager.get_stack_count() == seed_items.size(), "seed shop did not create one stack per seed")

	game_manager.money = rice_seed_price
	var capacity_fill: int = inventory_manager.get_free_space()
	_expect(inventory_manager.add_item("corn_seed", capacity_fill), "capacity purchase fixture failed")
	var wallet_before_capacity: int = game_manager.get_wallet_balance()
	var items_before_capacity: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.purchase_seed("rice_seed", 1), "shop ignored inventory capacity")
	_expect(game_manager.get_wallet_balance() == wallet_before_capacity, "capacity failure spent money")
	_expect(inventory_manager.items == items_before_capacity, "capacity failure changed inventory")

	inventory_manager.clear()
	game_manager.money = 0
	var rice_sell_price: int = data_manager.get_item_sell_price("rice")
	_expect(inventory_manager.add_item("rice", 3), "sell fixture could not be added")
	_expect(inventory_manager.sell_item("rice", 2), "valid crop sale failed")
	_expect(inventory_manager.get_amount("rice") == 1, "sale removed the wrong quantity")
	_expect(game_manager.get_wallet_balance() == rice_sell_price * 2, "sale credited the wrong JSON price")
	var wallet_after_sale: int = game_manager.get_wallet_balance()
	_expect(not inventory_manager.sell_item("rice", 2), "sale succeeded without enough items")
	_expect(inventory_manager.get_amount("rice") == 1, "failed sale removed items")
	_expect(game_manager.get_wallet_balance() == wallet_after_sale, "failed sale changed wallet")
	_expect(not inventory_manager.sell_item("rice", 0), "zero sale quantity was accepted")
	_expect(not inventory_manager.sell_item("rice", -1), "negative sale quantity was accepted")
	_expect(not inventory_manager.sell_item("unknown_item", 1), "unknown item was sold")
	_expect(inventory_manager.add_item("rice_seed", 1), "unsellable seed fixture failed")
	_expect(not inventory_manager.sell_item("rice_seed", 1), "item with null sell_price was sold")
	_expect(inventory_manager.get_amount("rice_seed") == 1, "failed unsellable transaction lost item")

	inventory_manager.clear()
	game_manager.money = 0
	var sellable_products: Array[String] = [
		"rice", "corn", "tomato", "cabbage", "wheat", "tea_leaf", "coffee_bean",
		"egg", "cow_milk", "beef", "chicken_meat",
		"fish", "shrimp", "crab", "squid", "octopus"
	]
	var expected_product_income: int = 0
	for item_id: String in sellable_products:
		var sell_price: int = data_manager.get_item_sell_price(item_id)
		_expect(sell_price > 0, "missing sell price for '%s'" % item_id)
		_expect(inventory_manager.add_item(item_id, 1), "product fixture failed for '%s'" % item_id)
		expected_product_income += sell_price
		_expect(inventory_manager.sell_item(item_id, 1), "product sale failed for '%s'" % item_id)
	_expect(inventory_manager.get_total_count() == 0, "product sales left inventory residue")
	_expect(game_manager.get_wallet_balance() == expected_product_income, "product sale income total is wrong")

	var wallet_before_invalid_credit: int = game_manager.get_wallet_balance()
	_expect(not game_manager.add_money(-100), "negative wallet credit was accepted")
	_expect(game_manager.get_wallet_balance() == wallet_before_invalid_credit, "negative credit made wallet invalid")
	_expect(not game_manager.spend_money(wallet_before_invalid_credit + 1), "wallet spent more than its balance")
	_expect(game_manager.get_wallet_balance() == wallet_before_invalid_credit, "failed wallet debit changed balance")
	inventory_manager.clear()
	_expect(inventory_manager.add_item("rice", 1), "wallet overflow fixture could not be added")
	game_manager.money = game_manager.max_wallet_balance
	var overflow_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(not inventory_manager.sell_item("rice", 1), "sale overflowed the wallet")
	_expect(game_manager.get_wallet_balance() == game_manager.max_wallet_balance, "overflow sale changed wallet")
	_expect(inventory_manager.items == overflow_inventory, "overflow sale lost the sold item")

	var chicken_data: Dictionary = data_manager.get_entry("animals", "chicken") as Dictionary
	var chicken_price: int = int(chicken_data.get("purchase_price", 0))
	game_manager.level = int(chicken_data.get("required_level", 1))
	game_manager.money = chicken_price - 1
	var animals_before_failed_purchase: int = world.animals_by_id.size()
	_expect(world.purchase_animal("economy_chicken", "chicken", Vector2(1160.0, 320.0)) == null, "animal purchase ignored insufficient funds")
	_expect(world.animals_by_id.size() == animals_before_failed_purchase, "failed animal purchase created an animal")
	_expect(game_manager.get_wallet_balance() == chicken_price - 1, "failed animal purchase spent money")
	game_manager.money = chicken_price
	var purchased_animal: Node = world.purchase_animal("economy_chicken", "chicken", Vector2(1160.0, 320.0))
	_expect(purchased_animal != null, "valid animal purchase failed")
	_expect(game_manager.get_wallet_balance() == 0, "animal purchase charged the wrong JSON price")
	if purchased_animal != null:
		world.call("_remove_animal", "economy_chicken")

	inventory_manager.clear()
	var level_two_upgrade_cost: int = data_manager.get_warehouse_upgrade_cost(2)
	game_manager.money = level_two_upgrade_cost
	_expect(inventory_manager.upgrade_warehouse(), "warehouse upgrade failed")
	_expect(inventory_manager.warehouse_level == 2, "warehouse level did not increase")
	_expect(inventory_manager.get_capacity() == 150, "upgraded warehouse capacity is wrong")
	_expect(game_manager.get_wallet_balance() == 0, "warehouse upgrade charged the wrong JSON cost")
	var level_three_upgrade_cost: int = data_manager.get_warehouse_upgrade_cost(3)
	game_manager.money = level_three_upgrade_cost - 1
	_expect(not inventory_manager.upgrade_warehouse(), "warehouse upgraded with insufficient funds")
	_expect(inventory_manager.warehouse_level == 2, "failed warehouse upgrade changed level")
	_expect(game_manager.get_wallet_balance() == level_three_upgrade_cost - 1, "failed upgrade changed wallet")

	inventory_manager.clear()
	_expect(inventory_manager.set_warehouse_level(2), "save fixture warehouse level failed")
	_expect(inventory_manager.add_item("rice", 4), "save fixture rice failed")
	_expect(inventory_manager.add_item("egg", 2), "save fixture egg failed")
	_expect(inventory_manager.add_item("fish", 1), "save fixture fish failed")
	game_manager.money = 123456
	var saved_inventory: Dictionary = inventory_manager.items.duplicate(true)
	_expect(save_manager.save_game(), "inventory/economy state could not be saved")
	inventory_manager.clear()
	game_manager.money = 0
	_expect(save_manager.load_game(), "inventory/economy state could not be loaded")
	_expect(inventory_manager.items == saved_inventory, "inventory stacks were not restored exactly")
	_expect(inventory_manager.warehouse_level == 2, "warehouse level was not restored")
	_expect(inventory_manager.get_capacity() == 150, "loaded inventory capacity is wrong")
	_expect(game_manager.get_wallet_balance() == 123456, "wallet was not restored")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	_expect(int(legacy_state.get("save_version", 0)) == 1, "Phase 6 changed the save version")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "existing v1 inventory/economy save is not compatible")

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
