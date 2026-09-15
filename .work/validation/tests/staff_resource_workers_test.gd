extends Node

const staff_script: Script = preload("res://scripts/restaurant/staff.gd")
const aquaculture_container_script: Script = preload("res://scripts/aquaculture/aquaculture_container.gd")

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_staff_resource_workers_test"):
		push_error("staff_resource_workers_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()
	_unlock_restaurant()
	game_manager.level = 30
	game_manager.money = 50000000
	world.call("upgrade_system", "coop")
	world.call("upgrade_system", "cow_barn")
	for pond_id: String in ["aquaculture_fish", "aquaculture_shrimp", "aquaculture_crab", "aquaculture_squid", "aquaculture_octopus"]:
		world.call("upgrade_pond", pond_id)
	world.call("purchase_animal", "chicken_01", "chicken", Vector2.ZERO)
	world.call("purchase_animal", "cow_01", "cow", Vector2.ZERO)
	world.call("purchase_animal", "dairy_cow_01", "dairy_cow", Vector2.ZERO)
	game_manager.money = 1700000

	var restaurant: Node = world.get_node("restaurant")
	var animal_data: Dictionary = data_manager.get_staff_type("animal_worker")
	var aquaculture_data: Dictionary = data_manager.get_staff_type("aquaculture_worker")
	_expect(int(animal_data.get("hire_cost", 0)) == 700000, "animal worker hire cost is wrong")
	_expect(int(aquaculture_data.get("hire_cost", 0)) == 1000000, "aquaculture worker hire cost is wrong")
	_expect(int(animal_data.get("max_count", 0)) == 2, "animal worker limit is wrong")
	_expect(int(aquaculture_data.get("max_count", 0)) == 1, "aquaculture worker limit is wrong")
	_expect((animal_data.get("allowed_jobs", []) as Array) == [staff_script.job_collect_animal], "animal worker capabilities are wrong")
	_expect((aquaculture_data.get("allowed_jobs", []) as Array) == [staff_script.job_collect_aquaculture], "aquaculture worker capabilities are wrong")
	var staff_panel: Node = world.get_node("ui/staff_panel")
	_expect(String(staff_panel.call("_get_job_display_name", staff_script.job_collect_animal)) == "Collect Animal Products", "animal worker UI capability is wrong")
	_expect(String(staff_panel.call("_get_job_display_name", staff_script.job_collect_aquaculture)) == "Collect & Restart Aquaculture", "aquaculture worker UI capability is wrong")
	_expect(String(staff_panel.call("_get_staff_status_text", staff_script.state_collecting, {"job_type": staff_script.job_collect_animal})) == "Collecting Animal Products", "animal worker UI status is wrong")
	_expect(String(staff_panel.call("_get_staff_status_text", staff_script.state_collecting, {"job_type": staff_script.job_collect_aquaculture})) == "Collecting & Restarting Aquaculture", "aquaculture worker UI status is wrong")

	var wallet_before_hire: int = game_manager.get_wallet_balance()
	var animal_worker_01: Node = restaurant.call("hire_staff", "animal_worker_01", "animal_worker") as Node
	var aquaculture_worker: Node = restaurant.call("hire_staff", "aquaculture_worker_01", "aquaculture_worker") as Node
	_expect(animal_worker_01 != null and aquaculture_worker != null, "resource worker hire failed")
	_expect(game_manager.get_wallet_balance() == wallet_before_hire - 1700000, "resource worker costs were not charged exactly once")
	var animal_home: Marker2D = world.get_node("animal_worker_home_marker") as Marker2D
	var aquaculture_home: Marker2D = world.get_node("aquaculture_worker_home_marker") as Marker2D
	_expect(animal_worker_01.global_position.is_equal_approx(animal_home.global_position), "animal worker did not spawn near animal housing")
	_expect(aquaculture_worker.global_position.is_equal_approx(aquaculture_home.global_position), "aquaculture worker did not spawn near aquaculture")
	_expect(animal_worker_01.global_position.distance_to(restaurant.global_position) > 500.0, "animal worker spawned in the Restaurant")
	_expect(aquaculture_worker.global_position.distance_to(restaurant.global_position) > 500.0, "aquaculture worker spawned in the Restaurant")
	_expect(not restaurant.call("dispatch_staff_jobs"), "resource workers found work with no ready product")
	_expect(String(animal_worker_01.get("current_state")) == staff_script.state_idle, "animal worker did not stay idle at home")
	_expect(String(aquaculture_worker.get("current_state")) == staff_script.state_idle, "aquaculture worker did not stay idle at home")

	var animals: Dictionary = world.get("animals_by_id") as Dictionary
	var chicken: Node = animals.get("chicken_01") as Node
	var cow: Node = animals.get("cow_01") as Node
	var dairy_cow: Node = animals.get("dairy_cow_01") as Node
	_expect(chicken != null and cow != null and dairy_cow != null, "animal fixtures are missing")
	_make_animal_ready(chicken)
	var chicken_product: Dictionary = (chicken.call("get_pending_products") as Array)[0] as Dictionary
	var chicken_item: String = String(chicken_product.get("item_id", ""))
	var chicken_amount: int = int(chicken_product.get("amount", 0))
	_expect(restaurant.call("dispatch_staff_jobs"), "ready chicken product was not dispatched")
	_expect(_active_job_type(animal_worker_01) == staff_script.job_collect_animal, "animal worker did not claim the chicken product")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 1, "animal product claim count is wrong")
	var animal_start: Vector2 = animal_worker_01.position
	_expect(restaurant.call("advance_staff", 0.1), "animal worker movement did not advance")
	_expect(animal_worker_01.position != animal_start, "animal worker teleported or did not move")
	_expect(inventory_manager.get_amount(chicken_item) == 0, "animal worker collected remotely")
	_expect(restaurant.call("advance_staff", 10.0), "animal worker did not reach the chicken")
	_expect(inventory_manager.get_amount(chicken_item) == chicken_amount, "chicken product yield is wrong")
	_expect((chicken.call("get_pending_products") as Array).is_empty(), "chicken product remained after collection")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 0, "animal claim was not released")
	_expect(restaurant.call("advance_staff", 10.0), "animal worker did not return home")
	_expect(animal_worker_01.global_position.is_equal_approx(animal_home.global_position), "animal worker returned to the wrong home")

	game_manager.money = data_manager.get_staff_hire_cost("animal_worker")
	var animal_worker_02: Node = restaurant.call("hire_staff", "animal_worker_02", "animal_worker") as Node
	_expect(animal_worker_02 != null, "second animal worker hire failed")
	_make_animal_ready(cow)
	_make_animal_ready(dairy_cow)
	var cow_product: Dictionary = (cow.call("get_pending_products") as Array)[0] as Dictionary
	var dairy_product: Dictionary = (dairy_cow.call("get_pending_products") as Array)[0] as Dictionary
	_expect(restaurant.call("dispatch_staff_jobs"), "cow and dairy products were not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 2, "two animal workers did not own distinct animal targets")
	_expect(restaurant.call("advance_staff", 10.0), "animal workers did not reach cow products")
	_expect(inventory_manager.get_amount(String(cow_product.get("item_id", ""))) == int(cow_product.get("amount", 0)), "cow product did not use animal data")
	_expect(inventory_manager.get_amount(String(dairy_product.get("item_id", ""))) == int(dairy_product.get("amount", 0)), "dairy cow product did not use animal data")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 0, "cow product claims were not released")
	_expect(restaurant.call("advance_staff", 10.0), "animal workers did not return after cow collection")

	_make_animal_ready(chicken)
	var race_product: Dictionary = (chicken.call("get_pending_products") as Array)[0] as Dictionary
	var race_item: String = String(race_product.get("item_id", ""))
	var race_before: int = inventory_manager.get_amount(race_item)
	_expect(restaurant.call("dispatch_staff_jobs"), "animal race job was not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 1, "two animal workers claimed the same animal")
	_expect(bool(chicken.call("collect_next_product")), "manual animal collection could not win the race")
	_expect(not restaurant.call("dispatch_staff_jobs"), "invalid animal claim was not canceled after manual collection")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 0, "animal worker retained a manually collected target")
	_expect(inventory_manager.get_amount(race_item) == race_before + int(race_product.get("amount", 0)), "manual/worker race duplicated animal output")
	_expect(restaurant.call("advance_staff", 10.0), "animal worker did not return after the manual race")

	_make_animal_ready(chicken)
	var capacity_pending: Array = chicken.call("get_pending_products") as Array
	var fill_amount: int = inventory_manager.get_free_space()
	_expect(fill_amount > 0 and inventory_manager.add_item("rice", fill_amount), "animal capacity fixture failed")
	_expect(not restaurant.call("dispatch_staff_jobs"), "animal worker claimed a product with full inventory")
	_expect(chicken.call("get_pending_products") == capacity_pending, "full inventory lost an animal product")
	inventory_manager.clear()
	_expect(bool(chicken.call("collect_next_product")), "animal capacity fixture could not be cleared manually")

	var containers: Dictionary = world.get("aquaculture_containers_by_id") as Dictionary
	var container_ids: Array = containers.keys()
	container_ids.sort()
	_expect(container_ids.size() >= 5, "Fish/Shrimp/Crab and other aquaculture fixtures are missing")
	for container_id_value: Variant in container_ids:
		var container: Node = containers.get(container_id_value) as Node
		_expect(bool(container.call("start_cycle")), "aquaculture fixture cycle did not start")
		var definition: Dictionary = data_manager.get_entry("aquaculture", String(container.get("aquaculture_id"))) as Dictionary
		container.call("advance_growth", float(definition.get("growth_time", 0.0)))
		_expect(String(container.get("current_state")) == aquaculture_container_script.state_ready, "aquaculture fixture did not become ready")

	for expected_jobs: int in range(container_ids.size(), 0, -1):
		_expect(restaurant.call("dispatch_staff_jobs"), "ready aquaculture product was not dispatched")
		_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 1, "aquaculture target was not claimed exactly once")
		var target_id: String = String((aquaculture_worker.get("active_job") as Dictionary).get("target_id", ""))
		var target: Node = containers.get(target_id) as Node
		var target_data: Dictionary = data_manager.get_entry("aquaculture", String(target.get("aquaculture_id"))) as Dictionary
		var target_item: String = String(target_data.get("item_id", ""))
		var amount_before: int = inventory_manager.get_amount(target_item)
		_expect(restaurant.call("advance_staff", 10.0), "aquaculture worker did not reach its target")
		_expect(inventory_manager.get_amount(target_item) == amount_before + int(target_data.get("yield", 0)), "aquaculture yield did not use data")
		_expect(String(target.get("current_state")) == aquaculture_container_script.state_growing, "aquaculture worker did not restart after collection")
		_expect(is_zero_approx(float(target.get("growth_timer"))), "restarted aquaculture cycle did not begin at zero")
		_expect((target.get("pending_product") as Dictionary).is_empty(), "restarted aquaculture retained a pending product")
		_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 0, "aquaculture claim was not released")
		_expect(restaurant.call("advance_staff", 10.0), "aquaculture worker did not return home")
		_expect(aquaculture_worker.global_position.is_equal_approx(aquaculture_home.global_position), "aquaculture worker returned to the wrong home")
		_expect(expected_jobs - 1 == _count_ready_aquaculture(containers), "aquaculture worker changed more than one ready container")

	var fish: Node = containers.get("aquaculture_fish") as Node
	var fish_data: Dictionary = data_manager.get_entry("aquaculture", "fish") as Dictionary
	finish_aquaculture_cycle(fish, fish_data)
	var fish_before_race: int = inventory_manager.get_amount(String(fish_data.get("item_id", "")))
	_expect(restaurant.call("dispatch_staff_jobs"), "aquaculture race job was not dispatched")
	_expect(bool(fish.call("harvest_product")), "manual aquaculture collection could not win the race")
	_expect(not restaurant.call("dispatch_staff_jobs"), "invalid aquaculture claim was not canceled after manual collection")
	_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 0, "aquaculture worker retained a manually collected target")
	_expect(String(fish.get("current_state")) == aquaculture_container_script.state_empty, "manual collection unexpectedly restarted aquaculture")
	_expect(inventory_manager.get_amount(String(fish_data.get("item_id", ""))) == fish_before_race + int(fish_data.get("yield", 0)), "manual/worker race duplicated aquaculture output")
	_expect(restaurant.call("advance_staff", 10.0), "aquaculture worker did not return after the manual race")

	_expect(bool(fish.call("start_cycle")), "full-inventory fish cycle did not start")
	finish_aquaculture_cycle(fish, fish_data)
	var fish_pending: Dictionary = (fish.get("pending_product") as Dictionary).duplicate(true)
	fill_amount = inventory_manager.get_free_space()
	_expect(fill_amount > 0 and inventory_manager.add_item("rice", fill_amount), "aquaculture capacity fixture failed")
	_expect(not restaurant.call("dispatch_staff_jobs"), "aquaculture worker claimed a product with full inventory")
	_expect(String(fish.get("current_state")) == aquaculture_container_script.state_ready, "full inventory restarted aquaculture without a product")
	_expect(fish.get("pending_product") == fish_pending, "full inventory lost an aquaculture product")
	inventory_manager.clear()
	_expect(bool(fish.call("harvest_product")), "aquaculture capacity fixture could not be cleared manually")

	var wallet_at_limits: int = game_manager.get_wallet_balance()
	_expect(restaurant.call("hire_staff", "animal_worker_03", "animal_worker") == null, "animal worker limit exceeded 2")
	_expect(restaurant.call("hire_staff", "aquaculture_worker_02", "aquaculture_worker") == null, "aquaculture worker limit exceeded 1")
	_expect(game_manager.get_wallet_balance() == wallet_at_limits, "failed over-limit hires changed money")

	game_manager.money = (
		data_manager.get_staff_hire_cost("waiter")
		+ data_manager.get_staff_hire_cost("chef")
		+ data_manager.get_staff_hire_cost("farm_worker")
	)
	var waiter: Node = restaurant.call("hire_staff", "waiter_resource_test", "waiter") as Node
	var chef: Node = restaurant.call("hire_staff", "chef_resource_test", "chef") as Node
	var farm_worker: Node = restaurant.call("hire_staff", "farm_worker_resource_test", "farm_worker") as Node
	_expect(waiter != null and chef != null and farm_worker != null, "multi-role fixture hires failed")
	var customer: Node = restaurant.call("spawn_customer", "resource_roles_customer", "garlic_egg_rice") as Node
	_expect(customer != null, "multi-role customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, customer)
	_expect(inventory_manager.add_item("rice", 1), "multi-role cooking rice fixture failed")
	_expect(inventory_manager.add_item("egg", 1), "multi-role cooking egg fixture failed")
	var farm_tile: Node = (world.get("farm_tiles_by_id") as Dictionary).get("farm_01") as Node
	var wheat_growth: float = data_manager.get_crop_growth_time_seconds("wheat")
	_expect(farm_tile.call("apply_saved_crop", "wheat", wheat_growth), "multi-role crop fixture failed")
	_make_animal_ready(chicken)
	_expect(bool(fish.call("start_cycle")), "multi-role aquaculture cycle did not start")
	finish_aquaculture_cycle(fish, fish_data)
	_expect(restaurant.call("dispatch_staff_jobs"), "simultaneous role jobs were not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_cook) == 1, "chef did not exclusively claim cooking")
	_expect(_count_claims(restaurant, staff_script.job_harvest) == 1, "farm worker did not exclusively claim the crop")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 1, "animal worker did not exclusively claim the animal")
	_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 1, "aquaculture worker did not exclusively claim the pond")
	_expect(_active_job_type(chef) == staff_script.job_cook, "chef took the wrong role job")
	_expect(_active_job_type(farm_worker) == staff_script.job_harvest, "farm worker took the wrong role job")
	_expect(_active_job_type(aquaculture_worker) == staff_script.job_collect_aquaculture, "aquaculture worker took the wrong role job")
	_expect((waiter.get("active_job") as Dictionary).is_empty(), "waiter took work before food was ready")
	_expect(restaurant.call("advance_staff", 10.0), "simultaneous role jobs did not execute")
	var cooking_job: Dictionary = restaurant.call("get_cooking_job", "resource_roles_customer") as Dictionary
	_expect(not cooking_job.is_empty(), "chef did not start the existing cooking flow")
	_expect(farm_tile.call("is_empty"), "farm worker did not use the existing harvest flow")
	_expect(String(fish.get("current_state")) == aquaculture_container_script.state_growing, "aquaculture role did not collect and restart")
	_expect(restaurant.call("advance_staff", 10.0), "multi-role workers did not return after work")
	_expect(restaurant.call("advance_cooking", float(cooking_job.get("cooking_duration", 0.0))), "multi-role cooking did not finish")
	_expect(restaurant.call("dispatch_staff_jobs"), "ready food was not dispatched to the waiter")
	_expect(_active_job_type(waiter) == staff_script.job_serve, "waiter did not exclusively claim serving")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not serve in the multi-role fixture")
	_expect(restaurant.call("remove_customer", "resource_roles_customer"), "multi-role customer cleanup failed")
	_expect(restaurant.call("advance_staff", 10.0), "waiter did not return after the multi-role fixture")

	_make_animal_ready(chicken)
	finish_aquaculture_cycle(fish, fish_data)
	var saved_animal_product: Dictionary = (chicken.call("get_pending_products") as Array)[0] as Dictionary
	_expect(restaurant.call("dispatch_staff_jobs"), "saved resource jobs were not dispatched")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 1, "saved animal job ownership is wrong")
	_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 1, "saved aquaculture job ownership is wrong")
	_expect(save_manager.save_game(), "active resource worker state could not be saved")
	_expect(save_manager.load_game(), "active resource worker state could not be loaded")
	_expect(restaurant.call("get_staff_type_count", "animal_worker") == 2, "animal workers were not restored")
	_expect(restaurant.call("get_staff_type_count", "aquaculture_worker") == 1, "aquaculture worker was not restored")
	_expect(_count_claims(restaurant, staff_script.job_collect_animal) == 1, "animal ownership was not restored exactly once")
	_expect(_count_claims(restaurant, staff_script.job_collect_aquaculture) == 1, "aquaculture ownership was not restored exactly once")
	animal_worker_01 = restaurant.call("get_staff", "animal_worker_01") as Node
	animal_worker_02 = restaurant.call("get_staff", "animal_worker_02") as Node
	aquaculture_worker = restaurant.call("get_staff", "aquaculture_worker_01") as Node
	chicken = (world.get("animals_by_id") as Dictionary).get("chicken_01") as Node
	fish = (world.get("aquaculture_containers_by_id") as Dictionary).get("aquaculture_fish") as Node
	var saved_animal_before: int = inventory_manager.get_amount(String(saved_animal_product.get("item_id", "")))
	var saved_fish_before: int = inventory_manager.get_amount(String(fish_data.get("item_id", "")))
	_expect(restaurant.call("advance_staff", 10.0), "loaded resource workers did not reach their targets")
	_expect(inventory_manager.get_amount(String(saved_animal_product.get("item_id", ""))) == saved_animal_before + int(saved_animal_product.get("amount", 0)), "loaded animal job duplicated or lost output")
	_expect(inventory_manager.get_amount(String(fish_data.get("item_id", ""))) == saved_fish_before + int(fish_data.get("yield", 0)), "loaded aquaculture job duplicated or lost output")
	_expect(String(fish.get("current_state")) == aquaculture_container_script.state_growing, "loaded aquaculture job did not restart the cycle")
	_expect(restaurant.call("advance_staff", 10.0), "loaded resource workers did not return home")
	_expect_staff_at_home(restaurant, "animal_worker_01", "animal_worker", 0)
	_expect_staff_at_home(restaurant, "animal_worker_02", "animal_worker", 1)
	_expect_staff_at_home(restaurant, "aquaculture_worker_01", "aquaculture_worker", 0)

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


func _make_animal_ready(animal: Node) -> void:
	for _attempt: int in range(5):
		if not (animal.call("get_pending_products") as Array).is_empty():
			return
		var next_day: int = int(animal.get("last_processed_day")) + 1
		game_manager.day = maxi(game_manager.day, next_day)
		animal.call("advance_lifecycle", next_day)
	_expect(false, "animal did not produce within five data-driven lifecycle days")


func finish_aquaculture_cycle(container: Node, definition: Dictionary) -> void:
	container.call("advance_growth", float(definition.get("growth_time", 0.0)))
	_expect(String(container.get("current_state")) == aquaculture_container_script.state_ready, "aquaculture cycle did not become ready")


func _count_ready_aquaculture(containers: Dictionary) -> int:
	var count: int = 0
	for container_value: Variant in containers.values():
		if String(container_value.get("current_state")) == aquaculture_container_script.state_ready:
			count += 1
	return count


func _active_job_type(staff: Node) -> String:
	return String((staff.get("active_job") as Dictionary).get("job_type", "")) if staff != null else ""


func _count_claims(restaurant: Node, job_type: String) -> int:
	var count: int = 0
	for job_key_value: Variant in restaurant.get("staff_job_claims") as Dictionary:
		if String(job_key_value).begins_with(job_type + ":"):
			count += 1
	return count


func _expect_staff_at_home(restaurant: Node, staff_id: String, staff_type_id: String, role_index: int) -> void:
	var staff: Node2D = restaurant.call("get_staff", staff_id) as Node2D
	var expected_local: Vector2 = restaurant.call("_get_staff_home_position", staff_type_id, role_index) as Vector2
	_expect(staff != null and staff.global_position.is_equal_approx(restaurant.to_global(expected_local)), "loaded %s did not return to its role home" % staff_id)


func _finish_tests() -> void:
	if failures == 0:
		print("staff_resource_workers_test: PASS")
	else:
		push_error("staff_resource_workers_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("staff_resource_workers_test: %s" % message)


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
