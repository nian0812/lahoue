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
	var tile_03: Node = world.get_node("farm/tile_03")
	var expansion_point: Node2D = world.get_node("farm/farm_expansion_point") as Node2D
	var prompt: Control = world.get_node("ui/interaction_prompt") as Control
	var rice_data: Dictionary = data_manager.get_entry("crops", "rice") as Dictionary
	var growth_time: float = data_manager.get_crop_growth_time_seconds("rice")
	var harvest_item_id: String = String(rice_data.get("harvest_item", ""))
	var harvest_amount: int = int(rice_data.get("yield", 0))
	var harvest_exp: int = int(rice_data.get("exp", 0))

	_expect(world.farm_tiles_by_id.size() == 40, "main_world did not register all 40 farm plots")
	_expect(_farm_tile_child_count() == 40, "Farm grid contains duplicate or missing plot nodes")
	_expect(_visible_plot_count() == 1, "New Game did not show exactly one farm plot")
	_expect(bool(tile_01.get("is_purchased")), "starter farm plot is not purchased")
	_expect(not bool(tile_02.get("is_purchased")), "second farm plot started purchased")
	_expect(expansion_point != null and expansion_point.has_method("interact"), "Farm Expansion interaction point is missing")
	prompt.call("_update_text", expansion_point)
	_expect(String((prompt.get("prompt_label") as Label).text) == "[E] Mở rộng đất — 100.000 VNĐ", "Farm Expansion prompt is wrong")
	_expect(_grid_layout_is_valid(), "40 plots are not arranged as the fixed 8x5 Farm grid")
	_expect(_grid_is_clear_of_other_areas(), "Farm grid overlaps or sits beside a protected world area")

	_expect(game_manager.money == 200000, "New Game wallet fixture is not 200K")
	game_manager.money = data_manager.get_farm_plot_purchase_cost() - 1
	_expect(not bool(expansion_point.call("interact", player)), "Farm Expansion ignored insufficient funds")
	_expect(game_manager.money == data_manager.get_farm_plot_purchase_cost() - 1 and _visible_plot_count() == 1, "failed Farm Expansion purchase changed wallet or plots")
	game_manager.money = 200000
	player.global_position = expansion_point.global_position - Vector2(70.0, 0.0)
	player.facing_direction = Vector2.RIGHT
	player.interaction_area.position = Vector2.RIGHT * player.interaction_offset
	await get_tree().physics_frame
	player.call("_try_interact")
	_expect(game_manager.money == 100000, "first Farm Expansion purchase did not deduct exactly 100K")
	_expect(bool(tile_02.get("is_purchased")) and tile_02.visible, "plot #2 did not appear after the first purchase")
	_expect(bool(expansion_point.call("interact", player)), "second Farm Expansion purchase failed")
	_expect(game_manager.money == 0, "second Farm Expansion purchase did not deduct exactly 100K")
	_expect(bool(tile_03.get("is_purchased")) and tile_03.visible, "plot #3 did not appear after the second purchase")
	prompt.call("_update_text", expansion_point)
	_expect(String((prompt.get("prompt_label") as Label).text) == "Farm Plots: 3/3\nNext expansion available at Level 5", "level-limited Farm Expansion feedback is wrong")
	game_manager.money = data_manager.get_farm_plot_purchase_cost()
	_expect(not bool(expansion_point.call("interact", player)), "Farm Expansion ignored the Player Lv1 plot limit")
	_expect(game_manager.money == data_manager.get_farm_plot_purchase_cost() and (world.get("purchased_farm_plots") as Array).size() == 3, "level-locked Farm Expansion charged money or added a plot")
	_expect(save_manager.save_game(), "purchased Farm plots could not be saved")
	var mutated_plots: Array = world.get("purchased_farm_plots") as Array
	mutated_plots.clear()
	mutated_plots.append("farm_01")
	world.call("_refresh_farm_plot_visibility")
	_expect(_visible_plot_count() == 1, "Farm plot save mutation fixture failed (visible=%d)" % _visible_plot_count())
	_expect(save_manager.load_game(), "purchased Farm plots could not be loaded")
	_expect((world.get("purchased_farm_plots") as Array).size() == 3, "Continue did not restore exactly three purchased plots")
	_expect(_visible_plot_count() == 3 and tile_02.visible and tile_03.visible, "Continue did not restore purchased plot visibility")
	_expect(String(world.call("get_next_farm_plot_id")) == "farm_04", "Continue duplicated or attempted to repurchase an owned plot")
	game_manager.level = 5
	game_manager.money = data_manager.get_farm_plot_purchase_cost()
	_expect(bool(expansion_point.call("interact", player)), "next Farm Plot did not unlock at Player Lv5")
	_expect(game_manager.money == 0 and (world.get("purchased_farm_plots") as Array).size() == 4, "Lv5 Farm Plot purchase charged incorrectly or did not add one plot")
	_expect(bool(tile_01.call("is_empty")), "new farm tile is not empty")
	inventory_manager.clear()
	_expect(not bool(tile_01.call("interact", player)), "empty tile planted without a selected seed")

	_expect(inventory_manager.add_item("rice", 2), "could not add seed fixture")
	_expect(player.get_selected_seed_item() == "rice", "inventory seed was not selected")
	player.global_position = tile_01.global_position - Vector2(60.0, 0.0)
	player.facing_direction = Vector2.RIGHT
	player.interaction_area.position = Vector2.RIGHT * player.interaction_offset
	await get_tree().physics_frame
	player.call("_try_interact")
	_expect(bool(tile_01.call("is_planted")), "E interaction did not plant")
	_expect(String(tile_01.get("crop_id")) == "rice", "tile did not resolve crop data from the selected seed")
	_expect(inventory_manager.get_amount("rice") == 1, "planting did not consume one seed")
	_expect(not bool(tile_01.call("plant_seed", "rice")), "planted tile accepted another seed")
	_expect(inventory_manager.get_amount("rice") == 1, "failed planting consumed a seed")
	_expect(not bool(tile_01.call("harvest")), "crop was harvested before it was ready")

	tile_01.call("advance_growth", growth_time - 0.1)
	_expect(bool(tile_01.call("is_planted")), "crop became ready too early")
	tile_01.call("advance_growth", 0.1)
	_expect(bool(tile_01.call("is_ready")), "crop did not become ready on time")
	_expect(bool(tile_01.call("harvest")), "ready crop could not be harvested")
	_expect(bool(tile_01.call("is_empty")), "harvest did not clear the tile")
	_expect(
		inventory_manager.get_amount(harvest_item_id) == harvest_amount + 1,
		"harvest yield did not come from crop data"
	)
	_expect(game_manager.current_exp == harvest_exp, "harvest EXP did not come from crop data")

	_expect(inventory_manager.remove_item("rice", harvest_amount), "harvest fixture could not reserve its output")
	_expect(bool(tile_01.call("plant_seed", "rice")), "second seed could not be planted")
	_expect(inventory_manager.get_amount("rice") == 0, "second planting did not consume seed")
	_expect(player.get_selected_seed_item().is_empty(), "empty seed stack remained selected")
	_expect(not bool(tile_02.call("interact", player)), "tile planted when inventory had no seed")
	_expect(inventory_manager.add_item(harvest_item_id, harvest_amount), "saved harvest inventory fixture failed")

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

	_expect(inventory_manager.add_item("corn", 1), "could not add corn selection fixture")
	_expect(inventory_manager.add_item("rice", 1), "could not add rice selection fixture")
	_expect(player.select_seed("rice"), "player could not explicitly select an inventory seed")
	_expect(bool(tile_02.call("interact", player)), "explicitly selected seed could not be planted")
	_expect(String(tile_02.get("crop_id")) == "rice", "explicit seed selection planted the wrong crop")

	var remaining_purchases: int = data_manager.get_farm_plot_maximum() - (world.get("purchased_farm_plots") as Array).size()
	game_manager.level = 50
	game_manager.money = remaining_purchases * data_manager.get_farm_plot_purchase_cost()
	for _purchase_index: int in range(remaining_purchases):
		_expect(bool(expansion_point.call("interact", player)), "Farm Expansion failed before plot #40")
	_expect((world.get("purchased_farm_plots") as Array).size() == 40, "Farm Expansion did not stop at 40 plots")
	_expect(_visible_plot_count() == 40, "not all 40 purchased plots are visible and usable")
	_expect(game_manager.money == 0, "Farm Expansion maximum charged the wrong total")
	prompt.call("_update_text", expansion_point)
	_expect(String((prompt.get("prompt_label") as Label).text) == "Farm Plots: 40/40\nFarm fully expanded", "maximum Farm Expansion feedback is wrong")
	game_manager.money = data_manager.get_farm_plot_purchase_cost()
	_expect(not bool(expansion_point.call("interact", player)), "Farm Expansion purchased plot #41")
	_expect(game_manager.money == data_manager.get_farm_plot_purchase_cost(), "fully expanded Farm charged money again")
	_expect(_farm_tile_child_count() == 40, "maximum Farm Expansion duplicated plot nodes")

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


func _visible_plot_count() -> int:
	var count: int = 0
	for tile_value: Variant in (world.get("farm_tiles_by_id") as Dictionary).values():
		var tile: CanvasItem = tile_value as CanvasItem
		if tile != null and tile.visible and bool(tile.get("is_purchased")):
			count += 1
	return count


func _farm_tile_child_count() -> int:
	var count: int = 0
	for child: Node in world.get_node("farm").get_children():
		var tile_id: Variant = child.get("tile_id")
		if tile_id != null and not String(tile_id).is_empty():
			count += 1
	return count


func _grid_layout_is_valid() -> bool:
	for plot_number: int in range(1, 41):
		var tile_id: String = "farm_%02d" % plot_number
		var tile: Node2D = (world.get("farm_tiles_by_id") as Dictionary).get(tile_id) as Node2D
		if tile == null:
			return false
		var column: int = (plot_number - 1) % 8
		var row: int = int((plot_number - 1) / 8)
		var expected: Vector2 = Vector2(590.0 + float(column) * 60.0, 370.0 + float(row) * 60.0)
		if not tile.position.is_equal_approx(expected):
			return false
	return true


func _grid_is_clear_of_other_areas() -> bool:
	var protected_points: Array[Vector2] = [
		(world.get_node("hub/premium_market/helipad_marker") as Node2D).global_position,
		(world.get_node("hub/premium_market") as Node2D).global_position,
		(world.get_node("hub/resort") as Node2D).global_position,
		(world.get_node("animals/coop") as Node2D).global_position,
		(world.get_node("animals/pig_pen") as Node2D).global_position,
		(world.get_node("animals/cow_barn") as Node2D).global_position,
		(world.get_node("aquaculture/fish_container") as Node2D).global_position,
		(world.get_node("aquaculture/shrimp_container") as Node2D).global_position,
		(world.get_node("restaurant") as Node2D).global_position,
	]
	for tile_value: Variant in (world.get("farm_tiles_by_id") as Dictionary).values():
		var tile: Node2D = tile_value as Node2D
		if tile == null or tile.global_position.y + 30.0 >= 730.0:
			return false
		for protected_position: Vector2 in protected_points:
			if tile.global_position.distance_to(protected_position) < 65.0:
				return false
	return true


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
