extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_farming_test"):
		push_error("farming_foundation_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var player: Node = world.get_node("player")
	var tile_01: Node = world.get_node("farm/tile_01")
	var tile_02: Node = world.get_node("farm/tile_02")
	var rice_data: Dictionary = data_manager.get_entry("crops", "rice") as Dictionary
	var growth_time: float = data_manager.get_crop_growth_time_seconds("rice")
	var harvest_item_id: String = String(rice_data.get("harvest_item", ""))
	var harvest_amount: int = int(rice_data.get("yield", 0))
	var harvest_exp: int = int(rice_data.get("exp", 0))

	_expect(world.farm_tiles_by_id.size() == 6, "main_world did not register all farm tiles")
	_expect(bool(tile_01.call("is_empty")), "new farm tile is not empty")
	_expect(not bool(tile_01.call("interact", player)), "empty tile planted without a selected seed")

	_expect(inventory_manager.add_item("rice_seed", 2), "could not add seed fixture")
	_expect(player.get_selected_seed_item() == "rice_seed", "inventory seed was not selected")
	player.global_position = tile_01.global_position - Vector2(60.0, 0.0)
	player.facing_direction = Vector2.RIGHT
	player.interaction_area.position = Vector2.RIGHT * player.interaction_offset
	await get_tree().physics_frame
	player.call("_try_interact")
	_expect(bool(tile_01.call("is_planted")), "E interaction did not plant")
	_expect(String(tile_01.get("crop_id")) == "rice", "tile did not resolve crop data from the selected seed")
	_expect(inventory_manager.get_amount("rice_seed") == 1, "planting did not consume one seed")
	_expect(not bool(tile_01.call("plant_seed", "rice_seed")), "planted tile accepted another seed")
	_expect(inventory_manager.get_amount("rice_seed") == 1, "failed planting consumed a seed")
	_expect(not bool(tile_01.call("harvest")), "crop was harvested before it was ready")

	tile_01.call("advance_growth", growth_time - 0.1)
	_expect(bool(tile_01.call("is_planted")), "crop became ready too early")
	tile_01.call("advance_growth", 0.1)
	_expect(bool(tile_01.call("is_ready")), "crop did not become ready on time")
	_expect(bool(tile_01.call("harvest")), "ready crop could not be harvested")
	_expect(bool(tile_01.call("is_empty")), "harvest did not clear the tile")
	_expect(
		inventory_manager.get_amount(harvest_item_id) == harvest_amount,
		"harvest yield did not come from crop data"
	)
	_expect(game_manager.current_exp == harvest_exp, "harvest EXP did not come from crop data")

	_expect(bool(tile_01.call("plant_seed", "rice_seed")), "second seed could not be planted")
	_expect(inventory_manager.get_amount("rice_seed") == 0, "second planting did not consume seed")
	_expect(player.get_selected_seed_item().is_empty(), "empty seed stack remained selected")
	_expect(not bool(tile_02.call("interact", player)), "tile planted when inventory had no seed")

	var saved_growth: float = growth_time * 0.5
	tile_01.call("advance_growth", saved_growth)
	_expect(save_manager.save_game(), "farming state could not be saved")
	tile_01.call("clear_tile")
	inventory_manager.clear()
	_expect(save_manager.load_game(), "farming state could not be loaded")
	_expect(bool(tile_01.call("is_planted")), "loaded tile state is not planted")
	_expect(String(tile_01.get("crop_id")) == "rice", "loaded tile restored the wrong crop")
	_expect(
		is_equal_approx(float(tile_01.get("growth_elapsed")), saved_growth),
		"loaded crop growth does not match the saved value"
	)
	_expect(
		inventory_manager.get_amount(harvest_item_id) == harvest_amount,
		"inventory was not restored with farming state"
	)

	tile_01.call("advance_growth", growth_time - float(tile_01.get("growth_elapsed")))
	_expect(bool(tile_01.call("is_ready")), "loaded crop could not finish growing")
	_expect(save_manager.save_game(), "ready farming state could not be saved")
	tile_01.call("clear_tile")
	_expect(save_manager.load_game(), "ready farming state could not be loaded")
	_expect(bool(tile_01.call("is_ready")), "ready tile state was not restored")
	_expect(bool(tile_01.call("harvest")), "loaded ready crop could not be harvested")
	_expect(
		inventory_manager.get_amount(harvest_item_id) == harvest_amount * 2,
		"loaded crop harvest produced the wrong yield"
	)

	_expect(inventory_manager.add_item("corn_seed", 1), "could not add corn selection fixture")
	_expect(inventory_manager.add_item("rice_seed", 1), "could not add rice selection fixture")
	_expect(player.select_seed("rice_seed"), "player could not explicitly select an inventory seed")
	_expect(bool(tile_02.call("interact", player)), "explicitly selected seed could not be planted")
	_expect(String(tile_02.get("crop_id")) == "rice", "explicit seed selection planted the wrong crop")

	if failures == 0:
		print("farming_foundation_test: PASS")
	else:
		push_error("farming_foundation_test: %d failure(s)" % failures)

	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("farming_foundation_test: %s" % message)


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
