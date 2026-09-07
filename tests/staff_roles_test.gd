extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const restaurant_table_script: Script = preload("res://scripts/restaurant/restaurant_table.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_staff_roles_test"):
		push_error("staff_roles_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()
	_unlock_restaurant()
	game_manager.level = 10
	game_manager.money = 500000
	for _plot_index: int in range(5):
		world.call("purchase_next_farm_plot")
	game_manager.money = 1000000

	var restaurant: Node = world.get_node("restaurant")
	var waiter_data: Dictionary = data_manager.get_staff_type("waiter")
	var chef_data: Dictionary = data_manager.get_staff_type("chef")
	var farm_worker_data: Dictionary = data_manager.get_staff_type("farm_worker")
	_expect(int(waiter_data.get("hire_cost", 0)) == 200000, "waiter hire cost is wrong")
	_expect(int(chef_data.get("hire_cost", 0)) == 300000, "chef hire cost is wrong")
	_expect(int(farm_worker_data.get("hire_cost", 0)) == 500000, "farm worker hire cost is wrong")
	_expect((waiter_data.get("allowed_jobs", []) as Array) == [staff_script.job_serve, staff_script.job_payment, staff_script.job_clean], "waiter capabilities are wrong")
	_expect((chef_data.get("allowed_jobs", []) as Array) == [staff_script.job_cook], "chef capabilities are wrong")
	_expect((farm_worker_data.get("allowed_jobs", []) as Array) == [staff_script.job_harvest], "farm worker capabilities are wrong")
	_expect(int(waiter_data.get("max_count", 0)) == 3, "waiter limit is wrong")
	_expect(int(chef_data.get("max_count", 0)) == 2, "chef limit is wrong")
	_expect(int(farm_worker_data.get("max_count", 0)) == 2, "farm worker limit is wrong")

	var wallet_before_roles: int = game_manager.get_wallet_balance()
	var waiter: Node = restaurant.call("hire_staff", "waiter_01", "waiter") as Node
	var chef: Node = restaurant.call("hire_staff", "chef_01", "chef") as Node
	var farm_worker: Node = restaurant.call("hire_staff", "farm_worker_01", "farm_worker") as Node
	_expect(waiter != null and chef != null and farm_worker != null, "multi-role hire failed")
	_expect(game_manager.get_wallet_balance() == wallet_before_roles - 1000000, "role hire costs were not charged exactly once")
	_expect(_staff_label(waiter) == "Waiter", "waiter visual label is wrong")
	_expect(_staff_label(chef) == "Chef", "chef visual label is wrong")
	_expect(_staff_label(farm_worker) == "Farm Worker", "farm worker visual label is wrong")
	var waiter_home_marker: Marker2D = restaurant.get_node("staff_home_marker") as Marker2D
	var kitchen_marker: Marker2D = restaurant.get_node("kitchen_station_marker") as Marker2D
	var farm_home_marker: Marker2D = world.get_node("farm_worker_home_marker") as Marker2D
	_expect(waiter.global_position.is_equal_approx(waiter_home_marker.global_position), "waiter did not spawn in the Restaurant service area")
	_expect(chef.global_position.distance_to(kitchen_marker.global_position) < 50.0, "chef did not spawn near the Kitchen")
	_expect(farm_worker.global_position.is_equal_approx(farm_home_marker.global_position), "farm worker did not spawn at the Farm home")
	_expect(farm_worker.global_position.distance_to(restaurant.global_position) > 500.0, "farm worker still spawned in the Restaurant")
	_expect(not restaurant.call("dispatch_staff_jobs"), "idle staff found a job before any order or mature crop existed")
	_expect(String(farm_worker.get("current_state")) == staff_script.state_idle, "farm worker did not remain idle at the Farm")
	_expect(farm_worker.global_position.is_equal_approx(farm_home_marker.global_position), "idle farm worker left the Farm home")

	var customer: Node = restaurant.call("spawn_customer", "roles_customer", "garlic_egg_rice") as Node
	_expect(customer != null, "multi-role customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, customer)
	_expect(String(customer.get("current_state")) == customer_script.state_waiting_food, "multi-role customer has no pending order")
	_expect(inventory_manager.add_item("rice", 1), "chef rice fixture could not be added")
	_expect(inventory_manager.add_item("egg", 1), "chef egg fixture could not be added")

	var tiles: Dictionary = world.get("farm_tiles_by_id") as Dictionary
	var tile_01: Node = tiles.get("farm_01") as Node
	var tile_02: Node = tiles.get("farm_02") as Node
	var tile_03: Node = tiles.get("farm_03") as Node
	var wheat_growth: float = data_manager.get_crop_growth_time_seconds("wheat")
	_expect(tile_01.call("apply_saved_crop", "wheat", wheat_growth), "first mature crop fixture failed")
	_expect(tile_02.call("apply_saved_crop", "wheat", wheat_growth), "second mature crop fixture failed")
	_expect(tile_03.call("apply_saved_crop", "wheat", wheat_growth * 0.5), "immature crop fixture failed")

	var chef_start: Vector2 = chef.position
	var farm_start: Vector2 = farm_worker.position
	_expect(restaurant.call("dispatch_staff_jobs"), "multi-role jobs were not dispatched")
	_expect(_active_job_type(chef) == staff_script.job_cook, "chef did not claim cooking")
	_expect(_active_job_type(farm_worker) == staff_script.job_harvest, "farm worker did not claim harvest")
	_expect((waiter.get("active_job") as Dictionary).is_empty(), "waiter took a cook or farm job")
	_expect((restaurant.get("staff_job_claims") as Dictionary).size() == 2, "multi-role claim count is wrong")
	_expect(restaurant.call("advance_staff", 0.1), "staff movement did not advance")
	_expect(chef.position != chef_start and farm_worker.position != farm_start, "chef or farm worker teleported instead of moving")
	_expect((restaurant.call("get_cooking_job", "roles_customer") as Dictionary).is_empty(), "chef cooked remotely before reaching the kitchen")
	_expect(tile_01.call("is_ready"), "farm worker harvested remotely before reaching the crop")

	_expect(restaurant.call("advance_staff", 10.0), "chef/farm worker did not reach their jobs")
	var cooking_job: Dictionary = restaurant.call("get_cooking_job", "roles_customer") as Dictionary
	_expect(String(cooking_job.get("state", "")) == restaurant_script.cooking_state_cooking, "chef did not start the existing cooking flow")
	_expect(inventory_manager.get_amount("rice") == 0 and inventory_manager.get_amount("egg") == 0, "chef ingredients were not removed exactly once")
	_expect(tile_01.call("is_empty"), "farm worker did not clear the harvested plot")
	_expect(inventory_manager.get_amount("wheat") == 3, "farm worker harvest yield is wrong")
	_expect(tile_02.call("is_ready"), "farm worker harvested a second plot without moving to it")
	_expect(not tile_03.call("is_ready"), "immature crop became a harvest job")

	_expect(restaurant.call("advance_cooking", float(cooking_job.get("cooking_duration", 0.0))), "chef cooking timer did not finish")
	_expect(restaurant.call("dispatch_staff_jobs"), "ready food was not dispatched to waiter")
	_expect(_active_job_type(waiter) == staff_script.job_serve, "waiter did not claim ready food")
	_expect((chef.get("active_job") as Dictionary).is_empty(), "chef claimed serving")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not reach the customer")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "waiter did not serve the customer")

	_expect(restaurant.call("dispatch_staff_jobs"), "farm worker did not claim the next mature plot")
	_expect(_active_job_type(farm_worker) == staff_script.job_harvest, "farm worker did not continue to the next harvest")
	_expect(restaurant.call("advance_staff", 10.0), "second farm harvest did not complete")
	_expect(tile_02.call("is_empty"), "second mature plot was not harvested")
	_expect(inventory_manager.get_amount("wheat") == 6, "second harvest duplicated or lost output")
	_expect(not tile_03.call("is_ready"), "farm worker harvested an immature plot")
	_expect(restaurant.call("advance_staff", 10.0), "farm worker did not return to the Farm after harvesting")
	_expect(String(farm_worker.get("current_state")) == staff_script.state_idle, "farm worker did not become idle after returning")
	_expect(farm_worker.global_position.is_equal_approx(farm_home_marker.global_position), "farm worker returned to the Restaurant instead of the Farm")

	var table_id: String = String(customer.get("table_id"))
	var table: Node = (restaurant.get("tables_by_id") as Dictionary).get(table_id) as Node
	var wallet_before_payment: int = game_manager.get_wallet_balance()
	var expected_revenue: int = int((restaurant.call("get_menu_entry", "garlic_egg_rice") as Dictionary).get("selling_price", 0))
	_expect(restaurant.call("dispatch_staff_jobs"), "waiter payment was not dispatched")
	_expect(_active_job_type(waiter) == staff_script.job_payment, "waiter did not claim payment")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not collect payment")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "waiter payment amount is wrong")
	_expect(not restaurant.call("finish_customer_meal", "roles_customer"), "payment was collected twice")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not return after payment")
	_expect(restaurant.call("dispatch_staff_jobs"), "table cleanup was not dispatched")
	_expect(_active_job_type(waiter) == staff_script.job_clean, "waiter did not claim cleanup")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not reach the cleanup table")
	_expect(restaurant.call("advance_staff", float(waiter_data.get("cleaning_time_seconds", 0.0))), "waiter cleanup timer did not finish")
	_expect(String(table.get("current_state")) == restaurant_table_script.state_available, "waiter did not make the table available")

	var missing_customer: Node = restaurant.call("spawn_customer", "roles_missing", "garlic_egg_rice") as Node
	_expect(missing_customer != null, "missing-ingredient customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, missing_customer)
	_expect(not restaurant.call("dispatch_staff_jobs"), "chef claimed cooking without ingredients")
	_expect((restaurant.call("get_cooking_job", "roles_missing") as Dictionary).is_empty(), "missing ingredients consumed a kitchen slot")

	game_manager.money = data_manager.get_staff_hire_cost("chef")
	var chef_02: Node = restaurant.call("hire_staff", "chef_02", "chef") as Node
	_expect(chef_02 != null, "second chef hire failed")
	_expect(inventory_manager.add_item("rice", 1), "manual-race rice fixture failed")
	_expect(inventory_manager.add_item("egg", 1), "manual-race egg fixture failed")
	_expect(restaurant.call("dispatch_staff_jobs"), "chef race job was not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_cook) == 1, "two chefs claimed the same order or exceeded kitchen capacity")
	var rice_before_manual_cook: int = inventory_manager.get_amount("rice")
	var egg_before_manual_cook: int = inventory_manager.get_amount("egg")
	_expect(restaurant.call("start_cooking", "roles_missing"), "manual cooking could not win the chef race")
	_expect(not restaurant.call("dispatch_staff_jobs"), "invalid chef claim was not released after manual cooking")
	_expect(_count_claims(restaurant, staff_script.job_cook) == 0, "chef retained a duplicate manual-cooking claim")
	_expect(inventory_manager.get_amount("rice") == rice_before_manual_cook - 1, "manual/chef race removed rice twice")
	_expect(inventory_manager.get_amount("egg") == egg_before_manual_cook - 1, "manual/chef race removed egg twice")
	_expect(restaurant.call("remove_customer", "roles_missing"), "chef race customer cleanup failed")
	_expect(restaurant.call("advance_staff", 10.0), "chefs did not return after the manual race")

	game_manager.money = data_manager.get_staff_hire_cost("farm_worker")
	var farm_worker_02: Node = restaurant.call("hire_staff", "farm_worker_02", "farm_worker") as Node
	_expect(farm_worker_02 != null, "second farm worker hire failed")
	var tile_04: Node = tiles.get("farm_04") as Node
	_expect(tile_04.call("apply_saved_crop", "wheat", wheat_growth), "farm race crop fixture failed")
	var wheat_before_manual_harvest: int = inventory_manager.get_amount("wheat")
	_expect(restaurant.call("dispatch_staff_jobs"), "farm race job was not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_harvest) == 1, "two farm workers claimed the same plot")
	_expect(tile_04.call("harvest"), "manual harvest could not win the farm worker race")
	_expect(not restaurant.call("dispatch_staff_jobs"), "invalid farm claim was not released after manual harvest")
	_expect(_count_claims(restaurant, staff_script.job_harvest) == 0, "farm worker retained a harvested plot claim")
	_expect(restaurant.call("advance_staff", 10.0), "farm worker did not return after manual harvest")
	_expect(inventory_manager.get_amount("wheat") == wheat_before_manual_harvest + 3, "manual/farm race duplicated crop output")

	var tile_05: Node = tiles.get("farm_05") as Node
	_expect(tile_05.call("apply_saved_crop", "wheat", wheat_growth), "full-inventory crop fixture failed")
	var free_space: int = inventory_manager.get_free_space()
	_expect(free_space > 0 and inventory_manager.add_item("wheat", free_space), "inventory-full fixture failed")
	var wheat_at_capacity: int = inventory_manager.get_amount("wheat")
	_expect(not restaurant.call("dispatch_staff_jobs"), "farm worker claimed harvest with full inventory")
	_expect(tile_05.call("is_ready"), "full inventory destroyed a mature crop")
	_expect(inventory_manager.get_amount("wheat") == wheat_at_capacity, "full inventory lost or overflowed crop output")

	game_manager.money = data_manager.get_staff_hire_cost("waiter") * 2
	var waiter_02: Node = restaurant.call("hire_staff", "waiter_02", "waiter") as Node
	var waiter_03: Node = restaurant.call("hire_staff", "waiter_03", "waiter") as Node
	_expect(waiter_02 != null and waiter_03 != null, "waiter hires below the limit failed")
	var wallet_at_limits: int = game_manager.get_wallet_balance()
	_expect(restaurant.call("hire_staff", "waiter_04", "waiter") == null, "waiter limit exceeded 3")
	_expect(restaurant.call("hire_staff", "chef_03", "chef") == null, "chef limit exceeded 2")
	_expect(restaurant.call("hire_staff", "farm_worker_03", "farm_worker") == null, "farm worker limit exceeded 2")
	_expect(game_manager.get_wallet_balance() == wallet_at_limits, "failed over-limit hires changed money")

	inventory_manager.clear()
	tile_05.call("clear_tile")
	var tile_06: Node = tiles.get("farm_06") as Node
	_expect(tile_06.call("apply_saved_crop", "wheat", wheat_growth), "saved harvest crop fixture failed")
	_expect(restaurant.call("dispatch_staff_jobs"), "saved harvest job was not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_harvest) == 1, "saved harvest job had duplicate ownership")
	_expect(save_manager.save_game(), "active multi-role staff state could not be saved")
	_expect(save_manager.load_game(), "active multi-role staff state could not be loaded")
	_expect(restaurant.call("get_staff_type_count", "waiter") == 3, "waiters were not restored")
	_expect(restaurant.call("get_staff_type_count", "chef") == 2, "chefs were not restored")
	_expect(restaurant.call("get_staff_type_count", "farm_worker") == 2, "farm workers were not restored")
	_expect(_count_claims(restaurant, staff_script.job_harvest) == 1, "harvest ownership was not restored exactly once")
	_expect(restaurant.call("advance_staff", 10.0), "loaded farm worker did not reach the saved crop")
	_expect(tile_06.call("is_empty"), "loaded farm worker did not clear the crop")
	_expect(inventory_manager.get_amount("wheat") == 3, "loaded harvest duplicated or lost output")
	_expect(restaurant.call("advance_staff", 10.0), "loaded farm worker did not return to its role home")
	_expect_staff_at_role_home(restaurant, "waiter_01", "waiter", 0)
	_expect_staff_at_role_home(restaurant, "chef_01", "chef", 0)
	_expect_staff_at_role_home(restaurant, "farm_worker_01", "farm_worker", 0)
	_expect_staff_at_role_home(restaurant, "farm_worker_02", "farm_worker", 1)

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	var legacy_staff: Dictionary = legacy_state.get("staff", {}) as Dictionary
	var legacy_waiter: Dictionary = (legacy_staff.get("waiter_01", {}) as Dictionary).duplicate(true)
	legacy_waiter.erase("staff_type_id")
	legacy_staff["waiter_01"] = legacy_waiter
	legacy_state["staff"] = legacy_staff
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy staff without an explicit role is incompatible")
	if bool(legacy_validation.get("ok", false)):
		var normalized_staff: Dictionary = (legacy_validation.get("state", {}) as Dictionary).get("staff", {}) as Dictionary
		_expect(String((normalized_staff.get("waiter_01", {}) as Dictionary).get("staff_type_id", "")) == "waiter", "legacy staff did not default to waiter")

	_finish_tests()


func _unlock_restaurant() -> void:
	var unlock_level: int = data_manager.get_restaurant_unlock_level()
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, unlock_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)
	game_manager.money = data_manager.get_progression_upgrade_cost("restaurant", 1)
	world.call("upgrade_system", "restaurant")


func _finish_customer_entry(restaurant: Node, customer: Node) -> void:
	if customer == null:
		return
	customer.set("is_walking_in", false)
	var empty_path: Array[Vector2] = []
	customer.set("walk_path", empty_path)
	restaurant.call("_on_customer_arrived_at_table", String(customer.get("customer_id")))


func _active_job_type(staff: Node) -> String:
	if staff == null:
		return ""
	return String((staff.get("active_job") as Dictionary).get("job_type", ""))


func _staff_label(staff: Node) -> String:
	if staff == null:
		return ""
	var label: Label = staff.get_node_or_null("staff_label") as Label
	return label.text if label != null else ""


func _expect_staff_at_role_home(restaurant: Node, staff_id: String, staff_type_id: String, role_index: int) -> void:
	var staff: Node2D = restaurant.call("get_staff", staff_id) as Node2D
	var expected_local: Vector2 = restaurant.call("_get_staff_home_position", staff_type_id, role_index) as Vector2
	_expect(
		staff != null and staff.global_position.is_equal_approx(restaurant.to_global(expected_local)),
		"loaded %s did not return to the correct role home" % staff_id
	)


func _count_claims(restaurant: Node, job_type: String) -> int:
	var count: int = 0
	for job_key_value: Variant in (restaurant.get("staff_job_claims") as Dictionary):
		if String(job_key_value).begins_with(job_type + ":"):
			count += 1
	return count


func _finish_tests() -> void:
	if failures == 0:
		print("staff_roles_test: PASS")
	else:
		push_error("staff_roles_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("staff_roles_test: %s" % message)


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
