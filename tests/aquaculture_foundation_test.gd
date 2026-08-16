extends Node

const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_aquaculture_test"):
		push_error("aquaculture_foundation_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()

	var player: Node = world.get_node("player")
	var fish_container: Node = world.aquaculture_containers_by_id.get("aquaculture_fish") as Node
	var squid_container: Node = world.aquaculture_containers_by_id.get("aquaculture_squid") as Node
	var octopus_container: Node = world.aquaculture_containers_by_id.get("aquaculture_octopus") as Node
	var fish_data: Dictionary = data_manager.get_entry("aquaculture", "fish") as Dictionary
	var squid_data: Dictionary = data_manager.get_entry("aquaculture", "squid") as Dictionary
	var octopus_data: Dictionary = data_manager.get_entry("aquaculture", "octopus") as Dictionary

	_expect(world.aquaculture_containers_by_id.size() == 3, "main_world did not register all aquaculture containers")
	_expect(fish_container != null, "fish container creation/setup failed")
	_expect(squid_container != null, "squid container creation/setup failed")
	_expect(octopus_container != null, "octopus container creation/setup failed")
	if fish_container == null or squid_container == null or octopus_container == null:
		_finish_tests()
		return

	_expect(bool(fish_container.get("is_configured")), "fish container did not load JSON data")
	_expect(bool(squid_container.get("is_configured")), "squid container did not load JSON data")
	_expect(bool(octopus_container.get("is_configured")), "octopus container did not load JSON data")
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_empty, "fish container did not start empty")
	_expect(not bool(fish_container.call("start_cycle")), "fish ignored its unlock level")
	_expect(not bool(squid_container.call("start_cycle")), "squid ignored its unlock level")
	_expect(not bool(octopus_container.call("start_cycle")), "octopus ignored its unlock level")
	_expect(inventory_manager.get_total_count() == 0, "locked aquaculture created a product")

	game_manager.level = int(fish_data.get("required_level", 1))
	await _interact_with(player, fish_container)
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_growing, "E interaction did not start fish growth")
	_expect(not bool(fish_container.call("harvest_product")), "growing fish was harvested early")

	var fish_growth_time: float = float(fish_data.get("growth_time", 0.0))
	var fish_almost_ready: float = fish_growth_time - 0.25
	fish_container.call("advance_growth", fish_almost_ready)
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_growing, "fish became ready before its JSON growth time")
	fish_container.call("advance_growth", 0.25)
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_ready, "fish did not become ready at its JSON growth time")
	var fish_pending: Dictionary = (fish_container.get("pending_product") as Dictionary).duplicate(true)
	_expect(String(fish_pending.get("item_id", "")) == String(fish_data.get("item_id", "")), "fish pending item did not come from aquaculture.json")
	_expect(int(fish_pending.get("amount", 0)) == int(fish_data.get("yield", 0)), "fish yield did not come from aquaculture.json")
	_expect(not bool(fish_container.get("product_collected")), "ready fish was marked collected")

	var exp_before_capacity: int = game_manager.current_exp
	var fill_amount: int = inventory_manager.get_free_space()
	_expect(fill_amount > 0, "capacity fixture had no free inventory space")
	_expect(inventory_manager.add_item("rice_seed", fill_amount), "could not fill inventory capacity")
	_expect(not bool(fish_container.call("harvest_product")), "full inventory accepted fish")
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_ready, "capacity failure changed ready state")
	_expect(fish_container.get("pending_product") == fish_pending, "capacity failure lost pending fish")
	_expect(not bool(fish_container.get("product_collected")), "capacity failure marked fish collected")
	_expect(game_manager.current_exp == exp_before_capacity, "capacity failure awarded EXP")

	var saved_ready_position: Vector2 = Vector2(1256.0, 336.0)
	fish_container.position = saved_ready_position
	_expect(save_manager.save_game(), "ready aquaculture state could not be saved")
	fish_container.call("reset_container")
	fish_container.position = Vector2.ZERO
	inventory_manager.clear()
	_expect(save_manager.load_game(), "ready aquaculture state could not be loaded")
	_expect(fish_container.position.is_equal_approx(saved_ready_position), "aquaculture position was not restored")
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_ready, "ready aquaculture state was not restored")
	_expect(is_equal_approx(float(fish_container.get("growth_timer")), fish_growth_time), "ready growth timer was not restored")
	_expect(fish_container.get("pending_product") == fish_pending, "pending fish was not restored")
	_expect(not bool(fish_container.call("harvest_product")), "loaded full inventory accepted fish")
	_expect(inventory_manager.remove_item("rice_seed", fill_amount), "could not free inventory capacity")

	await _interact_with(player, fish_container)
	var fish_item_id: String = String(fish_data.get("item_id", ""))
	var fish_yield: int = int(fish_data.get("yield", 0))
	_expect(inventory_manager.get_amount(fish_item_id) == fish_yield, "E interaction did not collect fish")
	_expect(game_manager.current_exp == int(fish_data.get("exp", 0)), "fish EXP did not come from aquaculture.json")
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_empty, "fish container did not reset after harvest")
	_expect(not bool(fish_container.call("harvest_product")), "fish was harvested twice in one cycle")
	_expect(inventory_manager.get_amount(fish_item_id) == fish_yield, "duplicate fish harvest changed inventory")

	_expect(bool(squid_container.call("start_cycle")), "unlocked squid cycle did not start")
	squid_container.call("advance_growth", float(squid_data.get("growth_time", 0.0)))
	_expect(String(squid_container.get("current_state")) == aquaculture_container_script.state_ready, "squid production did not become ready")
	_expect(bool(squid_container.call("harvest_product")), "squid product could not be received")
	_expect(inventory_manager.get_amount(String(squid_data.get("item_id", ""))) == int(squid_data.get("yield", 0)), "squid yield is wrong")
	_expect(not bool(squid_container.call("harvest_product")), "squid was harvested twice")

	_expect(bool(octopus_container.call("start_cycle")), "unlocked octopus cycle did not start")
	octopus_container.call("advance_growth", float(octopus_data.get("growth_time", 0.0)))
	_expect(String(octopus_container.get("current_state")) == aquaculture_container_script.state_ready, "octopus production did not become ready")
	_expect(bool(octopus_container.call("harvest_product")), "octopus product could not be received")
	_expect(inventory_manager.get_amount(String(octopus_data.get("item_id", ""))) == int(octopus_data.get("yield", 0)), "octopus yield is wrong")
	_expect(not bool(octopus_container.call("harvest_product")), "octopus was harvested twice")

	var expected_exp: int = int(fish_data.get("exp", 0)) + int(squid_data.get("exp", 0)) + int(octopus_data.get("exp", 0))
	_expect(game_manager.current_exp == expected_exp, "aquaculture EXP total is wrong")

	_expect(bool(fish_container.call("start_cycle")), "second fish cycle did not start")
	var partial_growth: float = fish_growth_time * 0.4
	fish_container.call("advance_growth", partial_growth)
	var saved_growing_position: Vector2 = Vector2(1308.0, 352.0)
	fish_container.position = saved_growing_position
	_expect(save_manager.save_game(), "growing aquaculture state could not be saved")
	fish_container.call("reset_container")
	fish_container.position = Vector2.ZERO
	_expect(save_manager.load_game(), "growing aquaculture state could not be loaded")
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_growing, "growing state was not restored")
	_expect(is_equal_approx(float(fish_container.get("growth_timer")), partial_growth), "partial growth timer was not restored")
	_expect(fish_container.position.is_equal_approx(saved_growing_position), "growing container position was not restored")
	_expect((fish_container.get("pending_product") as Dictionary).is_empty(), "load invented a pending growing product")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state["aquaculture"] = {}
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "old v1 empty aquaculture field is not compatible")
	if bool(legacy_validation.get("ok", false)):
		world.apply_aquaculture_save_state(legacy_validation.get("state", {}) as Dictionary)
	_expect(String(fish_container.get("current_state")) == aquaculture_container_script.state_empty, "legacy empty aquaculture did not reset containers")

	var invalid_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var invalid_aquaculture: Dictionary = invalid_state.get("aquaculture", {}) as Dictionary
	invalid_aquaculture["unknown_container"] = fish_container.call("get_save_state")
	invalid_state["aquaculture"] = invalid_aquaculture
	var invalid_validation: Dictionary = save_manager.call("_validate_save_state", invalid_state) as Dictionary
	_expect(not bool(invalid_validation.get("ok", false)), "unknown aquaculture container was accepted")

	var mismatched_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var mismatched_aquaculture: Dictionary = mismatched_state.get("aquaculture", {}) as Dictionary
	var mismatched_fish: Dictionary = (mismatched_aquaculture.get("aquaculture_fish", {}) as Dictionary).duplicate(true)
	mismatched_fish["aquaculture_id"] = "octopus"
	mismatched_aquaculture["aquaculture_fish"] = mismatched_fish
	mismatched_state["aquaculture"] = mismatched_aquaculture
	var mismatched_validation: Dictionary = save_manager.call("_validate_save_state", mismatched_state) as Dictionary
	_expect(not bool(mismatched_validation.get("ok", false)), "mismatched container aquaculture_id was accepted")

	_finish_tests()


func _interact_with(player: Node, target: Node) -> void:
	player.global_position = (target as Node2D).global_position - Vector2(60.0, 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	player.get("interaction_area").position = Vector2.RIGHT * float(player.get("interaction_offset"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_try_interact")


func _finish_tests() -> void:
	if failures == 0:
		print("aquaculture_foundation_test: PASS")
	else:
		push_error("aquaculture_foundation_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("aquaculture_foundation_test: %s" % message)


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
