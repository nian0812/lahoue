extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	if not ProjectSettings.globalize_path("user://").to_lower().contains("lahoue_codex_animals_test"):
		push_error("animals_foundation_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var entries: Dictionary = data_manager.get_dataset("animals").get("entries", {}) as Dictionary
	_expect(entries.size() == 5, "animal dataset does not contain five production animals")
	_expect((world.get("animals_by_id") as Dictionary).is_empty(), "New Game incorrectly owns an animal")
	game_manager.level = 2
	game_manager.money = 10000000
	_expect(world.call("purchase_animal", "locked_layer", "chicken", Vector2.ZERO) == null, "animal purchase ignored housing and level permission")

	game_manager.level = 3
	_expect(world.call("upgrade_system", "coop"), "Chicken Coop Lv1 purchase failed")
	var layer: Node = world.call("purchase_animal", "layer_test", "chicken", Vector2.ZERO) as Node
	var meat: Node = world.call("purchase_animal", "meat_test", "meat_chicken", Vector2.ZERO) as Node
	_expect(layer != null and meat != null, "Layer and Meat Chicken purchases failed")
	_expect(String((layer.get_node("name_label") as Label).text) == "Layer Chicken", "Layer Chicken label is wrong")
	_expect(String((meat.get_node("name_label") as Label).text) == "Meat Chicken", "Meat Chicken label is wrong")
	_expect((layer.get_node("body") as Polygon2D).color != (meat.get_node("body") as Polygon2D).color, "Meat Chicken silhouette/color is not distinct")

	game_manager.level = 7
	_expect(world.call("upgrade_system", "pig_pen"), "Pig Pen Lv1 purchase failed")
	var pig: Node = world.call("purchase_animal", "pig_test", "pig", Vector2.ZERO) as Node
	game_manager.level = 12
	_expect(world.call("upgrade_system", "cow_barn"), "Cow Barn Lv1 purchase failed")
	var dairy: Node = world.call("purchase_animal", "dairy_test", "dairy_cow", Vector2.ZERO) as Node
	var beef: Node = world.call("purchase_animal", "beef_test", "cow", Vector2.ZERO) as Node
	_expect(pig != null and dairy != null and beef != null, "Pig or Cow purchases failed")

	var expected_products: Dictionary = {
		"layer_test": "egg",
		"meat_test": "chicken_meat",
		"pig_test": "pork",
		"dairy_test": "cow_milk",
		"beef_test": "beef",
	}
	for instance_id: String in expected_products:
		var animal: Node = (world.get("animals_by_id") as Dictionary).get(instance_id) as Node
		_make_ready(animal)
		var pending: Array = animal.call("get_pending_products") as Array
		_expect(pending.size() == 1 and String((pending[0] as Dictionary).get("item_id", "")) == String(expected_products[instance_id]), "animal '%s' produced the wrong recurring item" % instance_id)
		_expect(animal.call("collect_next_product"), "animal '%s' product collection failed" % instance_id)
		_expect(world.call("has_animal", instance_id), "animal '%s' disappeared after collection" % instance_id)

	game_manager.day = 3
	_expect(save_manager.save_game(), "recurring animal state could not be saved")
	world.call("apply_animal_save_state", {"animals": {}, "animal_age": {}, "animals_initialized": true})
	_expect(save_manager.load_game(), "recurring animal state could not be loaded")
	for instance_id: String in expected_products:
		_expect(world.call("has_animal", instance_id), "Continue lost animal '%s'" % instance_id)

	_expect(data_manager.get_item_sell_price("egg") == 20000, "Egg raw price is wrong")
	_expect(data_manager.get_item_sell_price("cow_milk") == 50000, "Milk raw price is wrong")
	_expect(data_manager.get_item_sell_price("chicken_meat") == 100000, "Chicken Meat raw price is wrong")
	_expect(data_manager.get_item_sell_price("pork") == 100000, "Pork raw price is wrong")
	_expect(data_manager.get_item_sell_price("beef") == 200000, "Beef raw price is wrong")

	_cleanup_save_files()
	if failures == 0:
		print("animals_foundation_test: PASS")
	else:
		push_error("animals_foundation_test: %d failure(s)" % failures)
	get_tree().quit(failures)


func _make_ready(animal: Node) -> void:
	if animal == null:
		return
	for finished_day: int in range(1, 4):
		animal.call("advance_lifecycle", finished_day)
		if not (animal.call("get_pending_products") as Array).is_empty():
			return


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("animals_foundation_test: %s" % message)


func _cleanup_save_files() -> void:
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	for file_name: String in ["savegame.json", "savegame.backup.json", "savegame.tmp.json"]:
		if directory.file_exists(file_name):
			directory.remove(file_name)
