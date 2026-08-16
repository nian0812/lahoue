extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_animals_test"):
		push_error("animals_foundation_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var player: Node = world.get_node("player")
	var chicken: Node = world.animals_by_id.get("chicken_01") as Node
	var cow: Node = null
	var dairy_cow: Node = null
	var chicken_data: Dictionary = data_manager.get_entry("animals", "chicken") as Dictionary
	var cow_data: Dictionary = data_manager.get_entry("animals", "cow") as Dictionary
	var dairy_data: Dictionary = data_manager.get_entry("animals", "dairy_cow") as Dictionary
	var egg_data: Dictionary = chicken_data.get("daily_product", {}) as Dictionary
	var chicken_meat_data: Dictionary = chicken_data.get("end_of_life_product", {}) as Dictionary
	var beef_data: Dictionary = cow_data.get("end_of_life_product", {}) as Dictionary
	var milk_data: Dictionary = dairy_data.get("daily_product", {}) as Dictionary

	_expect(world.animals_by_id.size() == 1, "main_world did not register the starter chicken")
	_expect(chicken != null, "chicken creation failed")
	_expect(not world.animals_by_id.has("cow_01"), "locked cow was active in a new level-1 game")
	_expect(not world.animals_by_id.has("dairy_cow_01"), "locked dairy cow was active in a new game")
	if chicken == null:
		_finish_tests()
		return

	_expect(bool(chicken.get("is_configured")), "chicken did not load animal data")
	_expect(String(chicken.get("current_state")) == "active", "chicken did not start active")
	_expect(int(chicken.get("age_days")) == 0, "chicken did not start at age zero")
	_expect(bool(chicken.call("interact", player)), "active chicken could not be interacted with")
	_expect(inventory_manager.get_total_count() == 0, "active chicken created an early product")
	game_manager.level = 1
	game_manager.money = int(cow_data.get("purchase_price", 0)) + int(dairy_data.get("purchase_price", 0))
	var locked_money: int = game_manager.money
	_expect(
		world.purchase_animal("cow_01", "cow", Vector2(1160.0, 400.0)) == null,
		"cow purchase ignored its unlock level"
	)
	_expect(game_manager.money == locked_money, "failed locked purchase spent money")
	game_manager.level = 2
	cow = world.purchase_animal("cow_01", "cow", Vector2(1160.0, 400.0))
	_expect(cow != null, "unlocked cow could not be purchased")
	_expect(
		game_manager.money == locked_money - int(cow_data.get("purchase_price", 0)),
		"cow purchase price did not come from animals.json"
	)
	dairy_cow = world.purchase_animal("dairy_cow_01", "dairy_cow", Vector2(1080.0, 480.0))
	_expect(dairy_cow != null, "unlocked dairy cow could not be purchased")
	_expect(game_manager.money == 0, "dairy cow purchase price did not come from animals.json")
	if cow == null or dairy_cow == null:
		_finish_tests()
		return
	_expect(bool(cow.call("interact", player)), "active cow could not be interacted with")
	_expect(inventory_manager.get_total_count() == 0, "active cow created an early product")

	game_manager.start_gameplay()
	game_manager.finish_day()
	game_manager.stop_gameplay()
	_expect(int(chicken.get("age_days")) == 1, "chicken did not age on day_finished")
	_expect(String(chicken.get("current_state")) == "product_ready", "egg did not become ready")
	_expect(chicken.get_pending_products().size() == 1, "egg production did not create one pending product")
	_expect(
		String((chicken.get_pending_products()[0] as Dictionary).get("item_id", ""))
		== String(egg_data.get("item_id", "")),
		"chicken product did not come from animals.json"
	)
	_expect(not bool(chicken.get("product_collected_for_cycle")), "ready egg was marked collected")

	player.global_position = chicken.global_position - Vector2(60.0, 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	player.get("interaction_area").position = Vector2.RIGHT * float(player.get("interaction_offset"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_try_interact")
	var egg_item_id: String = String(egg_data.get("item_id", ""))
	var egg_amount: int = int(egg_data.get("amount", 0))
	var egg_exp: int = int(egg_data.get("collect_exp", 0))
	_expect(inventory_manager.get_amount(egg_item_id) == egg_amount, "E interaction did not collect egg")
	_expect(game_manager.current_exp == egg_exp, "egg EXP did not come from animals.json")
	_expect(String(chicken.get("current_state")) == "active", "chicken did not return to active")
	player.call("_try_interact")
	_expect(inventory_manager.get_amount(egg_item_id) == egg_amount, "egg was collected twice")

	_expect(bool(chicken.call("advance_lifecycle", 2)), "second chicken day was not processed")
	_expect(not bool(chicken.call("advance_lifecycle", 2)), "same chicken day was processed twice")
	var pending_before_capacity: Array = chicken.call("get_pending_products") as Array
	var exp_before_capacity: int = game_manager.current_exp
	var fill_amount: int = inventory_manager.get_free_space()
	_expect(fill_amount > 0, "capacity fixture had no free space")
	_expect(inventory_manager.add_item("rice_seed", fill_amount), "could not fill inventory capacity")
	_expect(not bool(chicken.call("collect_next_product")), "full inventory accepted an egg")
	_expect(
		chicken.call("get_pending_products") == pending_before_capacity,
		"capacity failure lost or changed the pending egg"
	)
	_expect(game_manager.current_exp == exp_before_capacity, "capacity failure awarded EXP")
	chicken.set("production_timer", 0.5)

	var earned_snapshot_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var earned_animals: Dictionary = earned_snapshot_state.get("animals", {}) as Dictionary
	var earned_chicken: Dictionary = (earned_animals.get("chicken_01", {}) as Dictionary).duplicate(true)
	var earned_pending: Array = (earned_chicken.get("pending_products", []) as Array).duplicate(true)
	var earned_product: Dictionary = (earned_pending[0] as Dictionary).duplicate(true)
	earned_product["amount"] = int(earned_product.get("amount", 0)) + 1
	earned_product["collect_exp"] = int(earned_product.get("collect_exp", 0)) + 1
	earned_pending[0] = earned_product
	earned_chicken["pending_products"] = earned_pending
	earned_animals["chicken_01"] = earned_chicken
	earned_snapshot_state["animals"] = earned_animals
	var earned_validation: Dictionary = save_manager.call("_validate_save_state", earned_snapshot_state) as Dictionary
	_expect(bool(earned_validation.get("ok", false)), "earned product snapshot broke after rebalance")

	var saved_position: Vector2 = Vector2(1044.0, 344.0)
	chicken.position = saved_position
	_expect(save_manager.save_game(), "animal state could not be saved")
	chicken.call("reset_state", 0)
	chicken.position = Vector2.ZERO
	inventory_manager.clear()
	_expect(save_manager.load_game(), "animal state could not be loaded")
	chicken = world.animals_by_id.get("chicken_01") as Node
	_expect(chicken != null, "loaded chicken instance is missing")
	if chicken == null:
		_finish_tests()
		return

	_expect(chicken.position.is_equal_approx(saved_position), "animal position was not restored")
	_expect(int(chicken.get("age_days")) == 2, "animal age was not restored")
	_expect(int(chicken.get("last_processed_day")) == 2, "animal processed day was not restored")
	_expect(String(chicken.get("current_state")) == "product_ready", "animal state was not restored")
	_expect(not bool(chicken.get("product_collected_for_cycle")), "product collection flag was not restored")
	_expect(
		is_equal_approx(float(chicken.get("production_timer")), 0.5),
		"animal production timer was not restored"
	)
	_expect(chicken.call("get_pending_products") == pending_before_capacity, "pending egg was not restored")
	_expect(not bool(chicken.call("collect_next_product")), "loaded full inventory accepted an egg")
	_expect(inventory_manager.remove_item("rice_seed", fill_amount), "could not free inventory capacity")
	_expect(bool(chicken.call("collect_next_product")), "pending egg could not be retried")
	_expect(inventory_manager.get_amount(egg_item_id) == egg_amount * 2, "retried egg yield is wrong")

	for finished_day: int in range(3, int(chicken_data.get("lifespan_days", 0)) + 1):
		_expect(bool(chicken.call("advance_lifecycle", finished_day)), "chicken day %d was not processed" % finished_day)

	_expect(int(chicken.get("age_days")) == 10, "chicken lifecycle did not end on day 10")
	_expect(String(chicken.get("current_state")) == "end_of_life", "chicken did not enter end_of_life")
	var end_pending: Array = chicken.call("get_pending_products") as Array
	_expect(end_pending.size() == 2, "end-of-life transition overwrote an uncollected egg")
	_expect(
		String((end_pending[1] as Dictionary).get("item_id", ""))
		== String(chicken_meat_data.get("item_id", "")),
		"chicken meat was not queued at end of life"
	)
	game_manager.day = int(chicken_data.get("lifespan_days", 10))
	_expect(save_manager.save_game(), "end-of-life animal state could not be saved")
	chicken.call("reset_state", 0)
	_expect(save_manager.load_game(), "end-of-life animal state could not be loaded")
	chicken = world.animals_by_id.get("chicken_01") as Node
	_expect(chicken != null, "end-of-life chicken was not restored")
	if chicken == null:
		_finish_tests()
		return
	_expect(int(chicken.get("age_days")) == 10, "end-of-life age was not restored")
	_expect(String(chicken.get("current_state")) == "end_of_life", "end-of-life state was not restored")
	end_pending = chicken.call("get_pending_products") as Array
	_expect(end_pending.size() == 2, "end-of-life pending products were not restored")
	_expect(bool(chicken.call("collect_next_product")), "final pending egg could not be collected")
	_expect(bool(chicken.call("collect_next_product")), "chicken meat could not be collected")
	var chicken_meat_id: String = String(chicken_meat_data.get("item_id", ""))
	var chicken_meat_amount: int = int(chicken_meat_data.get("amount", 0))
	_expect(chicken_meat_amount == 10, "chicken meat data does not match the 10-meat plan")
	_expect(
		inventory_manager.get_amount(chicken_meat_id) == chicken_meat_amount,
		"chicken did not add exactly 10 meat to inventory"
	)
	_expect(String(chicken.get("current_state")) == "completed", "chicken did not complete lifecycle")
	_expect(not bool(chicken.call("collect_next_product")), "completed chicken duplicated meat")
	await get_tree().process_frame
	_expect(not world.has_animal("chicken_01"), "completed chicken still occupied its coop slot")
	game_manager.money = int(chicken_data.get("purchase_price", 0))
	var replacement_chicken: Node = world.purchase_animal(
		"chicken_02",
		"chicken",
		Vector2(1120.0, 320.0)
	)
	_expect(replacement_chicken != null, "completed chicken could not be replaced")

	dairy_cow = world.animals_by_id.get("dairy_cow_01") as Node
	_expect(String(dairy_cow.get("current_state")) == "product_ready", "milk did not become ready")
	player.global_position = dairy_cow.global_position - Vector2(60.0, 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	player.get("interaction_area").position = Vector2.RIGHT * float(player.get("interaction_offset"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_try_interact")
	var milk_item_id: String = String(milk_data.get("item_id", ""))
	var milk_amount: int = int(milk_data.get("amount", 0))
	_expect(inventory_manager.get_amount(milk_item_id) == milk_amount, "milk yield is wrong")
	_expect(not bool(dairy_cow.call("collect_next_product")), "milk was collected twice in one cycle")

	cow = world.animals_by_id.get("cow_01") as Node
	for finished_day: int in range(2, int(cow_data.get("lifespan_days", 0)) + 1):
		_expect(bool(cow.call("advance_lifecycle", finished_day)), "cow day %d was not processed" % finished_day)
	_expect(String(cow.get("current_state")) == "end_of_life", "cow did not reach end_of_life")
	player.global_position = cow.global_position - Vector2(60.0, 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	player.get("interaction_area").position = Vector2.RIGHT * float(player.get("interaction_offset"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_try_interact")
	var beef_item_id: String = String(beef_data.get("item_id", ""))
	_expect(
		inventory_manager.get_amount(beef_item_id) == int(beef_data.get("amount", 0)),
		"beef yield is wrong"
	)
	_expect(String(cow.get("current_state")) == "completed", "cow lifecycle did not complete")
	await get_tree().process_frame
	for instance_id_value: Variant in world.animals_by_id.keys():
		world.call("_remove_animal", String(instance_id_value))
	_expect(world.animals_by_id.is_empty(), "zero-animal save fixture was not empty")
	_expect(save_manager.save_game(), "zero-animal state could not be saved")
	save_manager.create_new_game()
	_expect(world.has_animal("chicken_01"), "new game did not restore the starter chicken")
	_expect(save_manager.load_game(), "zero-animal state could not be loaded")
	_expect(world.animals_by_id.is_empty(), "zero-animal save respawned a free starter chicken")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state["animals"] = {}
	legacy_state["animal_age"] = {}
	legacy_state.erase("animals_initialized")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "old v1 empty animal fields are not compatible")
	if bool(legacy_validation.get("ok", false)):
		world.apply_animal_save_state(legacy_validation.get("state", {}) as Dictionary)
	_expect(world.has_animal("chicken_01"), "legacy v1 empty animals did not migrate to starter state")

	var invalid_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var invalid_animals: Dictionary = invalid_state.get("animals", {}) as Dictionary
	var invalid_chicken: Dictionary = (invalid_animals.get("chicken_01", {}) as Dictionary).duplicate(true)
	invalid_chicken["animal_id"] = "unknown_animal"
	invalid_animals["chicken_01"] = invalid_chicken
	invalid_state["animals"] = invalid_animals
	var invalid_validation: Dictionary = save_manager.call("_validate_save_state", invalid_state) as Dictionary
	_expect(not bool(invalid_validation.get("ok", false)), "unknown saved animal was accepted")

	_finish_tests()


func _finish_tests() -> void:
	if failures == 0:
		print("animals_foundation_test: PASS")
	else:
		push_error("animals_foundation_test: %d failure(s)" % failures)

	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("animals_foundation_test: %s" % message)


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
