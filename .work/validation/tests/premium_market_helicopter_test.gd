extends Node

const premium_market_script: Script = preload("res://scripts/premium_market/premium_market.gd")

var failures: int = 0
var arrival_count: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_premium_market_test"):
		push_error("premium_market_helicopter_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()

	var market: Node = world.get_node("hub/premium_market")
	var helicopter: Node2D = market.get_node("helicopter") as Node2D
	var helipad_marker: Marker2D = market.get_node("helipad_marker") as Marker2D
	var outside_marker: Marker2D = market.get_node("outside_marker") as Marker2D
	var panel: Control = world.get_node("ui/premium_market_panel") as Control
	var prompt: Control = world.get_node("ui/interaction_prompt") as Control
	market.connect("shipment_arrived", _on_shipment_arrived)

	game_manager.level = 34
	game_manager.money = 200000000
	_expect(not bool(market.call("is_unlocked")), "Premium Market unlocked before Level 35")
	var money_before_locked: int = game_manager.money
	_expect(not bool(market.call("confirm_order", {"wagyu": 1})), "Level 34 confirmed an import order")
	_expect(game_manager.money == money_before_locked, "locked import deducted money")
	_expect((market.get("active_shipment") as Dictionary).is_empty(), "locked import created a shipment")
	_expect(bool(market.call("interact", world.get_node("player"))), "Premium Market world interaction failed")
	_expect(world.get_node("ui").get("active_panel") == panel, "world interaction did not open the dedicated Premium Market panel")
	_expect(bool((panel.get("locked_label") as Label).visible), "locked panel did not show the Lv35/ownership requirements")
	_expect(not bool((panel.get("content") as VBoxContainer).visible), "locked panel exposed order actions")
	prompt.call("_update_text", market)
	_expect(String((prompt.get("prompt_label") as Label).text) == "Requires Level 35", "world prompt did not show the Level 35 requirement")
	world.get_node("ui").call("_close_active_panel")

	game_manager.level = 35
	game_manager.level_changed.emit(35)
	_expect(not bool(market.call("is_unlocked")), "Premium Market ignored building ownership")
	_expect(bool(world.call("purchase_building", "international_license")), "International License purchase failed")
	_expect(not bool(market.call("is_unlocked")), "Premium Market unlocked without Helipad")
	_expect(bool(world.call("purchase_building", "helipad")), "Helipad purchase failed")
	_expect(bool(market.call("is_unlocked")), "Premium Market did not unlock after Lv35 + License + Helipad")
	prompt.call("_update_text", market)
	_expect(String((prompt.get("prompt_label") as Label).text) == "[E] Premium Market", "unlocked world prompt is wrong")
	panel.call("refresh")
	_expect(not bool((panel.get("locked_label") as Label).visible), "owned Premium Market panel remained locked")
	_expect(bool((panel.get("content") as VBoxContainer).visible), "owned Premium Market panel did not expose market content")
	var premium_ids: Array[String] = market.call("get_market_item_ids") as Array[String]
	_expect(premium_ids.size() == 12, "Premium Market does not contain exactly 12 data-driven items")
	for required_id: String in [
		"wagyu", "lobster", "king_crab", "st25_rice", "salmon", "bluefin_tuna",
		"japanese_scallop", "cheese", "butter", "olive_oil", "truffle", "saffron",
	]:
		_expect(premium_ids.has(required_id), "Premium Market is missing '%s'" % required_id)
	_expect(not premium_ids.has("wagyu_beef") and not premium_ids.has("alaska_lobster"), "equivalent existing import IDs were duplicated")
	_expect(data_manager.get_item_display_name("wagyu") == "Wagyu Beef", "reused Wagyu display name is wrong")
	_expect(data_manager.get_item_display_name("lobster") == "Alaska Lobster", "reused lobster display name is wrong")
	_expect(not inventory_manager.purchase_item("wagyu", 1), "premium import remained obtainable through the normal purchase API")

	var money_before_draft: int = game_manager.money
	panel.call("_on_clear_pressed")
	panel.call("_on_add_pressed", "wagyu", 1)
	panel.call("_on_add_pressed", "lobster", 1)
	panel.call("_on_add_pressed", "st25_rice", 8)
	_expect(int(market.call("get_cargo_load", panel.get("cargo_draft") as Dictionary)) == 10, "mixed Lv1 draft did not reach capacity 10")
	panel.call("_on_add_pressed", "king_crab", 1)
	_expect(int(market.call("get_cargo_load", panel.get("cargo_draft") as Dictionary)) == 10, "draft exceeded helicopter capacity")
	_expect(String((panel.get("message_label") as Label).text) == "Helicopter capacity full", "capacity-full feedback is missing")
	_expect(game_manager.money == money_before_draft, "cargo selection deducted money")
	panel.call("_on_clear_pressed")
	_expect((panel.get("cargo_draft") as Dictionary).is_empty(), "Clear did not empty draft cargo")
	_expect(game_manager.money == money_before_draft, "Clear changed money")
	panel.call("_on_add_pressed", "wagyu", 1)
	panel.visible = true
	world.get_node("ui").set("active_panel", panel)
	panel.call("_on_close_pressed")
	_expect((market.get("active_shipment") as Dictionary).is_empty(), "closing the panel created an order")
	_expect(game_manager.money == money_before_draft, "closing the panel deducted money")
	panel.call("_on_clear_pressed")

	_expect(not bool(market.call("confirm_order", {})), "empty cargo was confirmed")
	_expect(not bool(market.call("confirm_order", {"wagyu": 11})), "cargo above Lv1 capacity was confirmed")
	var cargo: Dictionary = {"wagyu": 2, "lobster": 1, "st25_rice": 4}
	var cargo_load: int = int(market.call("get_cargo_load", cargo))
	var cargo_cost: int = int(market.call("calculate_import_cost", cargo))
	inventory_manager.add_item("rice", inventory_manager.get_free_space())
	game_manager.money = cargo_cost
	var money_before_full_confirm: int = game_manager.money
	_expect(not bool(market.call("confirm_order", cargo)), "order confirmed without current warehouse capacity")
	_expect(game_manager.money == money_before_full_confirm, "warehouse-capacity failure deducted money")
	_expect((market.get("active_shipment") as Dictionary).is_empty(), "warehouse-capacity failure created a shipment")
	inventory_manager.clear()
	game_manager.money = cargo_cost - 1
	_expect(not bool(market.call("confirm_order", cargo)), "order confirmed without enough money")
	_expect(game_manager.money == cargo_cost - 1, "insufficient-money failure changed money")

	game_manager.money = cargo_cost + 500000
	var money_before_confirm: int = game_manager.money
	_expect(bool(market.call("confirm_order", cargo)), "valid mixed import order was rejected")
	_expect(game_manager.money == money_before_confirm - cargo_cost, "Confirm did not deduct the exact import cost once")
	for item_id: String in cargo:
		_expect(inventory_manager.get_amount(item_id) == 0, "import item arrived immediately on Confirm")
	_expect(String(market.get("current_state")) == premium_market_script.state_departing, "helicopter did not enter Departing")
	_expect(helicopter.visible and helicopter.position.is_equal_approx(helipad_marker.position), "helicopter was not visibly parked at departure start")
	var parked_position: Vector2 = helicopter.position
	_expect(bool(market.call("advance_delivery", 0.1)), "helicopter departure did not advance")
	_expect(helicopter.visible and helicopter.position != parked_position, "physical helicopter did not move during departure")
	_expect(helicopter.z_index == (world.get_node("player") as Node2D).z_index, "helicopter does not share the player's world layer")
	var money_while_busy: int = game_manager.money
	_expect(not bool(market.call("confirm_order", {"saffron": 1})), "busy helicopter accepted a second shipment")
	_expect(game_manager.money == money_while_busy, "busy-helicopter rejection deducted money")

	var flight_duration: float = float(market.call("_get_flight_duration"))
	market.call("advance_delivery", flight_duration)
	_expect(String(market.get("current_state")) == premium_market_script.state_importing, "helicopter did not enter Importing after leaving the map")
	_expect(not helicopter.visible and helicopter.position.is_equal_approx(outside_marker.position), "helicopter did not visibly leave the map")
	var saved_remaining: float = float(market.call("get_remaining_shipping_time"))
	var saved_money: int = game_manager.money
	_expect(saved_remaining > 0.0 and saved_remaining < 60.0, "Lv1 import shipping timer is invalid")
	_expect(save_manager.save_game(), "active import shipment could not be saved")
	market.call("advance_delivery", 7.0)
	game_manager.money = 0
	_expect(save_manager.load_game(), "active import shipment could not be loaded")
	_expect(String(market.get("current_state")) == premium_market_script.state_importing, "Continue did not restore Importing state")
	_expect(is_equal_approx(float(market.call("get_remaining_shipping_time")), saved_remaining), "Continue did not restore remaining shipping time")
	_expect(game_manager.money == saved_money, "Continue deducted import payment again")
	for item_id: String in cargo:
		_expect(inventory_manager.get_amount(item_id) == 0, "Continue delivered import cargo early")

	game_manager.day_timer = game_manager.day_duration - 5.0
	market.call("_on_day_finishing", game_manager.day)
	_expect(is_equal_approx(float(market.call("get_remaining_shipping_time")), maxf(saved_remaining - 5.0, 0.0)), "day skip did not advance import shipping time")
	market.call("advance_delivery", float(market.call("get_remaining_shipping_time")))
	_expect(String(market.get("current_state")) == premium_market_script.state_returning, "completed shipping timer did not enter Returning")
	_expect(helicopter.visible and helicopter.position.is_equal_approx(outside_marker.position), "returning helicopter did not appear outside the map")

	inventory_manager.add_item("rice", inventory_manager.get_free_space())
	var return_start: Vector2 = helicopter.position
	market.call("advance_delivery", 0.1)
	_expect(helicopter.position != return_start, "physical helicopter did not move while returning")
	market.call("advance_delivery", flight_duration)
	_expect(String(market.get("current_state")) == premium_market_script.state_arrived, "helicopter did not visibly arrive at the Helipad")
	_expect(helicopter.position.is_equal_approx(helipad_marker.position), "arrived helicopter is not on the Helipad")
	market.call("advance_delivery", 0.01)
	_expect(String(market.get("current_state")) == premium_market_script.state_arrived, "full warehouse incorrectly completed delivery")
	for item_id: String in cargo:
		_expect(inventory_manager.get_amount(item_id) == 0, "full warehouse lost or partially delivered import cargo")
	_expect(inventory_manager.remove_item("rice", cargo_load), "could not free capacity for pending import")
	market.call("advance_delivery", 0.01)
	_expect(String(market.get("current_state")) == premium_market_script.state_ready, "helicopter did not return to Ready after safe delivery")
	_expect((market.get("active_shipment") as Dictionary).is_empty(), "completed import shipment was not cleared")
	for item_id: String in cargo:
		_expect(inventory_manager.get_amount(item_id) == int(cargo[item_id]), "import arrival quantity is wrong for '%s'" % item_id)
	_expect(arrival_count == 1, "import arrival signal did not fire exactly once")
	var delivered_amounts: Dictionary = {}
	for item_id: String in cargo:
		delivered_amounts[item_id] = inventory_manager.get_amount(item_id)
	market.call("advance_delivery", 120.0)
	for item_id: String in cargo:
		_expect(inventory_manager.get_amount(item_id) == int(delivered_amounts[item_id]), "completed shipment duplicated '%s'" % item_id)
	_expect(_has_import_arrival_notification(), "Import arrived notification is missing")

	game_manager.money = 900000000
	var expected_times: Array[float] = [60.0, 50.0, 40.0, 30.0, 20.0]
	var expected_capacities: Array[int] = [10, 20, 35, 50, 75]
	var expected_speeds: Array[float] = [140.0, 160.0, 185.0, 215.0, 250.0]
	var upgrade_costs: Array[int] = [50000000, 100000000, 200000000, 500000000]
	for level_index: int in range(5):
		_expect(int(market.get("helicopter_level")) == level_index + 1, "helicopter level progression is wrong")
		_expect(is_equal_approx(float(market.call("get_shipping_time")), expected_times[level_index]), "helicopter shipping time is wrong at Lv%d" % (level_index + 1))
		_expect(int(market.call("get_capacity")) == expected_capacities[level_index], "helicopter capacity is wrong at Lv%d" % (level_index + 1))
		_expect(is_equal_approx(float(market.call("get_visual_speed")), expected_speeds[level_index]), "helicopter visual speed is wrong at Lv%d" % (level_index + 1))
		if level_index < 4:
			_expect(int(market.call("get_upgrade_cost")) == upgrade_costs[level_index], "helicopter upgrade cost is wrong")
			var wallet_before_upgrade: int = game_manager.money
			_expect(bool(market.call("upgrade_helicopter")), "helicopter upgrade failed")
			_expect(game_manager.money == wallet_before_upgrade - upgrade_costs[level_index], "helicopter upgrade did not charge exactly once")
	_expect(not bool(market.call("upgrade_helicopter")), "helicopter upgraded above Lv5")
	_expect(int(market.call("get_upgrade_cost")) == 0, "Lv5 did not report MAX LEVEL")
	_expect(save_manager.save_game(), "Lv5 ready helicopter state could not be saved")
	market.call("clear")
	_expect(save_manager.load_game(), "Lv5 ready helicopter state could not be loaded")
	_expect(int(market.get("helicopter_level")) == 5, "Continue did not restore helicopter level")
	_expect(String(market.get("current_state")) == premium_market_script.state_ready, "Continue did not restore ready helicopter safely")

	var legacy_state: Dictionary = save_manager.call("_build_save_state") as Dictionary
	legacy_state.erase("helicopter_level")
	legacy_state.erase("helicopter_state")
	legacy_state.erase("helicopter_phase_elapsed")
	legacy_state.erase("premium_import_shipment")
	var legacy_validation: Dictionary = save_manager.call("_validate_save_state", legacy_state) as Dictionary
	_expect(bool(legacy_validation.get("ok", false)), "legacy save without Premium Market fields is incompatible")
	if bool(legacy_validation.get("ok", false)):
		var normalized: Dictionary = legacy_validation.get("state", {}) as Dictionary
		_expect(int(normalized.get("helicopter_level", 0)) == 1, "legacy save did not default helicopter to Lv1")
		_expect(String(normalized.get("helicopter_state", "")) == premium_market_script.state_ready, "legacy save did not default helicopter to Ready")
		_expect((normalized.get("premium_import_shipment", {}) as Dictionary).is_empty(), "legacy save invented an import shipment")

	_finish_tests()


func _on_shipment_arrived(_cargo: Dictionary) -> void:
	arrival_count += 1


func _has_import_arrival_notification() -> bool:
	var container: VBoxContainer = world.get_node("ui/notification_popup/container") as VBoxContainer
	for panel_value: Node in container.get_children():
		var labels: Array[Node] = panel_value.find_children("*", "Label", true, false)
		for label_value: Node in labels:
			if String((label_value as Label).text).contains("Import arrived!"):
				return true
	return false


func _finish_tests() -> void:
	if failures == 0:
		print("premium_market_helicopter_test: PASS")
	else:
		push_error("premium_market_helicopter_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("premium_market_helicopter_test: %s" % message)


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
