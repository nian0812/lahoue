extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")

var failures: int = 0

@onready var world: Node = get_parent()
@onready var tracker: Node = world.get_node("achievement_tracker")


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_achievement_gameplay_test"):
		push_error("achievement_gameplay_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()
	_expect((tracker.call("get_definitions") as Dictionary).size() == 18, "production achievement set does not contain 18 definitions")

	var first_tile: Node = world.get_node("farm/tile_01")
	var rice_growth: float = data_manager.get_crop_growth_time_seconds("rice")
	_expect(first_tile.call("apply_saved_crop", "rice", rice_growth), "manual harvest fixture could not mature")
	_expect(first_tile.call("harvest"), "manual crop harvest failed")
	_expect(_is_completed("first_harvest"), "First Harvest did not complete from the real crop signal")
	_expect(not _is_claimed("first_harvest"), "First Harvest reward was auto-claimed")
	_expect(_progress("harvest_50") == 1 and _progress("harvest_250") == 1, "manual harvest did not increment each farming achievement exactly once")
	await get_tree().process_frame
	_expect(_notification_contains("Achievement Completed!\nFirst Harvest"), "completion notification did not show the achievement name")

	var achievement_panel: Node = world.get_node("ui/achievement_panel")
	achievement_panel.call("refresh")
	var claim_button: Button = achievement_panel.find_child("claim_first_harvest", true, false) as Button
	_expect(claim_button != null, "completed achievement has no Claim button")
	var wallet_before_claim: int = game_manager.get_wallet_balance()
	if claim_button != null:
		claim_button.emit_signal("pressed")
	_expect(game_manager.get_wallet_balance() == wallet_before_claim + 5000, "First Harvest Claim did not grant exactly 5,000 VND")
	_expect(_is_claimed("first_harvest"), "claimed achievement did not enter CLAIMED state")
	var wallet_after_claim: int = game_manager.get_wallet_balance()
	_expect(not tracker.call("claim_reward", "first_harvest"), "claimed achievement accepted a second Claim")
	_expect(game_manager.get_wallet_balance() == wallet_after_claim, "duplicate Claim granted a second reward")
	_expect(_panel_contains(achievement_panel, "CLAIMED"), "Achievement panel does not display CLAIMED")
	_expect(_panel_contains(achievement_panel, "Harvests 1 / 50"), "Achievement panel does not display human-readable progress")

	var animals: Dictionary = world.get("animals_by_id") as Dictionary
	_reach_level(10)
	game_manager.money = 50000000
	_expect(world.call("upgrade_system", "coop"), "achievement Chicken Coop fixture could not be purchased")
	var chicken: Node = world.call("purchase_animal", "chicken_01", "chicken", Vector2.ZERO) as Node
	_make_animal_ready(chicken)
	var manual_animal_product: Dictionary = (chicken.call("get_pending_products") as Array)[0] as Dictionary
	var manual_animal_amount: int = int(manual_animal_product.get("amount", 0))
	_expect(chicken.call("collect_next_product"), "manual animal product collection failed")
	_expect(_is_completed("first_animal_product"), "Farm Fresh did not complete from manual collection")
	_expect(_progress("animal_products_50") == manual_animal_amount, "manual animal product progress is wrong")

	var containers: Dictionary = world.get("aquaculture_containers_by_id") as Dictionary
	var fish: Node = containers.get("aquaculture_fish") as Node
	var fish_data: Dictionary = data_manager.get_entry("aquaculture", "fish") as Dictionary
	_expect(world.call("upgrade_pond", "aquaculture_fish"), "achievement Fish Pond fixture could not be purchased")
	_expect(fish.call("start_cycle"), "manual aquaculture cycle could not start")
	fish.call("advance_growth", float(fish_data.get("growth_time", 0.0)))
	var manual_aquaculture_amount: int = int((fish.get("pending_product") as Dictionary).get("amount", 0))
	_expect(fish.call("harvest_product"), "manual aquaculture product collection failed")
	_expect(_is_completed("first_aquaculture"), "Fresh Catch did not complete from manual collection")
	_expect(_progress("aquaculture_50") == manual_aquaculture_amount, "manual aquaculture progress is wrong")

	game_manager.money = 20000000
	var restaurant: Node = world.get_node("restaurant")
	_expect(world.call("upgrade_system", "restaurant"), "achievement Restaurant fixture could not be purchased")
	var waiter: Node = restaurant.call("hire_staff", "achievement_waiter", "waiter") as Node
	_expect(waiter != null and _is_completed("first_staff"), "Growing Team did not complete after the first successful hire")
	var chef: Node = restaurant.call("hire_staff", "achievement_chef", "chef") as Node
	var farm_worker: Node = restaurant.call("hire_staff", "achievement_farm_worker", "farm_worker") as Node
	var animal_worker: Node = restaurant.call("hire_staff", "achievement_animal_worker", "animal_worker") as Node
	var aquaculture_worker: Node = restaurant.call("hire_staff", "achievement_aquaculture_worker", "aquaculture_worker") as Node
	_expect(chef != null and farm_worker != null and animal_worker != null and aquaculture_worker != null, "full Staff team fixture could not be hired")
	_expect(_is_completed("full_staff_team") and _progress("full_staff_team") == 5, "Full Team did not complete with all five unique roles")

	var second_tile: Node = world.get_node("farm/tile_02")
	_expect(world.call("purchase_next_farm_plot"), "achievement second Farm Plot fixture could not be purchased")
	_expect(second_tile.call("apply_saved_crop", "rice", rice_growth), "automated harvest fixture could not mature")
	_make_animal_ready(chicken)
	var automated_animal_product: Dictionary = (chicken.call("get_pending_products") as Array)[0] as Dictionary
	var automated_animal_amount: int = int(automated_animal_product.get("amount", 0))
	_expect(fish.call("start_cycle"), "automated aquaculture cycle could not start")
	fish.call("advance_growth", float(fish_data.get("growth_time", 0.0)))
	var automated_aquaculture_amount: int = int((fish.get("pending_product") as Dictionary).get("amount", 0))

	var customer: Node = restaurant.call("spawn_customer", "achievement_customer", "garlic_egg_rice") as Node
	_expect(customer != null, "achievement cooking customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, customer)
	_expect(String(customer.get("current_state")) == customer_script.state_waiting_food, "achievement customer has no pending cooking order")
	_expect(inventory_manager.add_item("rice", 1), "Chef rice fixture could not be added")
	_expect(inventory_manager.add_item("egg", 1), "Chef egg fixture could not be added")

	var harvest_before_staff: int = _progress("harvest_50")
	var animal_before_staff: int = _progress("animal_products_50")
	var aquaculture_before_staff: int = _progress("aquaculture_50")
	_expect(restaurant.call("dispatch_staff_jobs"), "Staff automation jobs were not dispatched")
	_expect(_active_job_type(chef) == staff_script.job_cook, "Chef did not claim cooking")
	_expect(_active_job_type(farm_worker) == staff_script.job_harvest, "Farm Worker did not claim harvest")
	_expect(_active_job_type(animal_worker) == staff_script.job_collect_animal, "Animal Worker did not claim collection")
	_expect(_active_job_type(aquaculture_worker) == staff_script.job_collect_aquaculture, "Aquaculture Worker did not claim collection")
	_expect(restaurant.call("advance_staff", 10.0), "Staff automation jobs did not execute")
	_expect(_progress("harvest_50") == harvest_before_staff + 1, "Farm Worker harvest counted zero or more than once")
	_expect(_progress("animal_products_50") == animal_before_staff + automated_animal_amount, "Animal Worker collection counted incorrectly")
	_expect(_progress("aquaculture_50") == aquaculture_before_staff + automated_aquaculture_amount, "Aquaculture Worker collection counted incorrectly")

	var cooking_job: Dictionary = restaurant.call("get_cooking_job", "achievement_customer") as Dictionary
	_expect(String(cooking_job.get("state", "")) == restaurant_script.cooking_state_cooking, "Chef did not start the existing cooking flow")
	_expect(restaurant.call("advance_cooking", float(cooking_job.get("cooking_duration", 0.0))), "Chef cooking timer did not complete")
	_expect(_is_completed("first_dish"), "First Dish did not complete when Chef finished cooking")
	_expect(restaurant.call("dispatch_staff_jobs"), "ready dish was not dispatched to Waiter")
	_expect(_active_job_type(waiter) == staff_script.job_serve, "Waiter did not claim serving")
	_expect(restaurant.call("advance_staff", 10.0), "Waiter did not serve the customer")
	_expect(_progress("serve_10") == 1 and _progress("serve_100") == 1, "Waiter service counted zero or more than once")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "served customer did not enter EATING")

	var truck_manager: Node = world.get_node("truck_manager")
	_expect(inventory_manager.add_item("rice", 25), "Truck earning fixture could not be added")
	_expect(truck_manager.call("dispatch", "rice", 25), "Truck shipment could not be dispatched")
	var exp_before_truck_payout: int = game_manager.current_exp
	truck_manager.call("_process", float(truck_manager.call("get_delivery_time")) + 0.1)
	_expect(_is_completed("first_shipment"), "On The Road did not complete from a real Truck delivery")
	_expect(_progress("truck_25") == 1, "Truck shipment counted zero or more than once")
	_expect(_is_completed("earn_100k"), "First Profit did not use cumulative earned Truck revenue")
	var expected_truck_revenue: int = data_manager.get_item_sell_price("rice") * 25
	_expect(_progress("earn_1m") == expected_truck_revenue, "cumulative money tracker did not use the redesigned Rice sale value")
	_expect(game_manager.current_exp == exp_before_truck_payout + 25, "Truck shipment did not grant exactly 25 Sales EXP")
	truck_manager.call("_process", 1000.0)
	_expect(game_manager.current_exp == exp_before_truck_payout + 25, "completed Truck shipment granted Sales EXP twice")

	_reach_level(35)
	game_manager.money = 200000000
	var premium_market: Node = world.get_node("hub/premium_market")
	_expect(world.call("purchase_building", "international_license"), "achievement International License fixture could not be purchased")
	_expect(world.call("purchase_building", "helipad"), "achievement Helipad fixture could not be purchased")
	_expect(premium_market.call("confirm_order", {"st25_rice": 1}), "International Market shipment could not start")
	premium_market.call("advance_delivery", 1000000.0)
	premium_market.call("advance_delivery", 0.1)
	_expect(_is_completed("first_import"), "Going Global did not complete when imported cargo reached Warehouse")
	_expect(_progress("premium_import_10") == 1, "International shipment counted zero or more than once")

	_expect(restaurant.call("advance_staff", 10.0), "Staff did not return before save")
	_expect(restaurant.call("finish_customer_meal", "achievement_customer"), "achievement customer payment fixture could not finish")
	_expect(restaurant.call("remove_customer", "achievement_customer"), "achievement customer could not be removed before save")
	var saved_wallet: int = game_manager.get_wallet_balance()
	var saved_harvest_progress: int = _progress("harvest_50")
	var saved_money_progress: int = _progress("earn_1m")
	_expect(save_manager.save_game(), "gameplay achievement state could not be saved")
	tracker.call("reset_state")
	game_manager.money = 0
	_expect(save_manager.load_game(), "gameplay achievement state could not be loaded")
	_expect(_is_claimed("first_harvest"), "Continue lost claimed achievement state")
	_expect(_progress("harvest_50") == saved_harvest_progress, "Continue lost farming progress")
	_expect(_progress("earn_1m") == saved_money_progress, "Continue lost cumulative earned money")
	_expect(_is_completed("full_staff_team") and _progress("full_staff_team") == 5, "Continue did not preserve/reconcile the full Staff team")
	_expect(_is_completed("first_import") and _progress("premium_import_10") == 1, "Continue lost International Market progress")
	_expect(game_manager.get_wallet_balance() == saved_wallet, "Continue duplicated or lost the claimed reward")
	_expect(not tracker.call("claim_reward", "first_harvest"), "Continue allowed a claimed reward to be paid twice")
	_expect(game_manager.get_wallet_balance() == saved_wallet, "duplicate post-Continue Claim changed money")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("achievements")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy save without achievement progress is incompatible")
	_expect((legacy_validation.get("state", {}) as Dictionary).get("achievements", []) == [], "legacy save did not initialize achievement progress safely")

	_finish_tests()


func _progress(achievement_id: String) -> int:
	return int((tracker.call("get_achievement_state", achievement_id) as Dictionary).get("progress", 0))


func _is_completed(achievement_id: String) -> bool:
	return bool((tracker.call("get_achievement_state", achievement_id) as Dictionary).get("unlocked", false))


func _is_claimed(achievement_id: String) -> bool:
	return bool((tracker.call("get_achievement_state", achievement_id) as Dictionary).get("reward_claimed", false))


func _notification_contains(expected_text: String) -> bool:
	var notification: Node = world.get_node("ui/notification_popup")
	var container: Node = notification.get("notification_container") as Node
	if container == null:
		return false
	for panel: Node in container.get_children():
		var labels: Array[Node] = panel.find_children("*", "Label", true, false)
		for label_node: Node in labels:
			if (label_node as Label).text == expected_text:
				return true
	return false


func _panel_contains(panel: Node, expected_text: String) -> bool:
	var labels: Array[Node] = panel.find_children("*", "Label", true, false)
	for label_node: Node in labels:
		if (label_node as Label).text.contains(expected_text):
			return true
	return false


func _reach_level(target_level: int) -> void:
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, target_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)


func _make_animal_ready(animal: Node) -> void:
	for _attempt: int in range(5):
		if not (animal.call("get_pending_products") as Array).is_empty():
			return
		var next_day: int = int(animal.get("last_processed_day")) + 1
		game_manager.day = maxi(game_manager.day, next_day)
		animal.call("advance_lifecycle", next_day)
	_expect(false, "animal did not produce within five lifecycle days")


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


func _finish_tests() -> void:
	if failures == 0:
		print("achievement_gameplay_test: PASS")
	else:
		push_error("achievement_gameplay_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("achievement_gameplay_test: %s" % message)


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
