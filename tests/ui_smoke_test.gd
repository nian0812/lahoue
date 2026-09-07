extends Node

var test_results: Array[String] = []
var test_count: int = 0
var pass_count: int = 0
var fail_count: int = 0


func _ready() -> void:
	print("=== Full UI Layout / Functional Polish Test ===")
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_ui_smoke_test"):
		push_error("ui_smoke_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout
	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	await get_tree().process_frame

	_test_theme_loads()
	_test_vnd_formatter()
	_test_ui_node_exists()
	_test_hud_node_exists()
	_test_prompt_node_exists()
	_test_notification_node_exists()
	_test_pause_node_exists()
	_test_hud_signals_connected()
	_test_notification_method()
	_test_pause_process_mode()
	_test_input_actions()
	_test_shared_theme_variations()
	_test_all_gameplay_panels()
	_test_hud_required_values()
	_test_standardized_strings_and_ids()
	_test_responsive_layouts()
	await _test_single_modal_flow()
	await _test_save_continue_ui_stability()

	print("")
	print("=== Results: %d/%d passed ===" % [pass_count, test_count])
	for result: String in test_results:
		print(result)

	if fail_count > 0:
		print("FAIL: %d tests failed" % fail_count)
	else:
		print("ALL TESTS PASSED")

	await get_tree().create_timer(0.2).timeout
	_cleanup_save_files()
	get_tree().quit(0 if fail_count == 0 else 1)


func _assert(condition: bool, test_name: String) -> void:
	test_count += 1
	if condition:
		pass_count += 1
		test_results.append("  PASS: %s" % test_name)
	else:
		fail_count += 1
		test_results.append("  FAIL: %s" % test_name)


func _test_theme_loads() -> void:
	var theme: Theme = load("res://resources/theme/lahoue_theme.tres") as Theme
	_assert(theme != null, "Theme resource loads")
	if theme != null:
		var panel_style: StyleBox = theme.get_stylebox("panel", "PanelContainer")
		_assert(panel_style != null, "Theme has PanelContainer/panel style")
		var btn_normal: StyleBox = theme.get_stylebox("normal", "Button")
		_assert(btn_normal != null, "Theme has Button/normal style")
		var progress_fill: StyleBox = theme.get_stylebox("fill", "ProgressBar")
		_assert(progress_fill != null, "Theme has ProgressBar/fill style")


func _test_vnd_formatter() -> void:
	var formatter: GDScript = load("res://scripts/ui/vnd_formatter.gd") as GDScript
	_assert(formatter != null, "VND formatter script loads")
	if formatter != null:
		var result: String = formatter.format(79000)
		_assert(result == "79.000 ₫", "VND format 79000 -> '%s'" % result)
		var zero: String = formatter.format(0)
		_assert(zero == "0 ₫", "VND format 0 -> '%s'" % zero)
		var negative: String = formatter.format(-5000)
		_assert(negative == "-5.000 ₫", "VND format -5000 -> '%s'" % negative)
		var name_result: String = formatter.format_item_name("rice_seed")
		_assert(name_result == "Rice Seed", "Item name 'rice_seed' -> '%s'" % name_result)
		var large_vnd: String = formatter.format_vnd(1000000000)
		_assert(large_vnd == "1.000.000.000 VNĐ", "1B VNĐ remains readable: '%s'" % large_vnd)


func _test_ui_node_exists() -> void:
	var ui: CanvasLayer = get_node_or_null("/root/main_world/ui") as CanvasLayer
	_assert(ui != null, "UI CanvasLayer node exists")
	if ui != null:
		_assert(ui.get_script() != null, "UI has script (ui_manager)")


func _test_hud_node_exists() -> void:
	var hud: Control = get_node_or_null("/root/main_world/ui/hud") as Control
	_assert(hud != null, "HUD node exists under ui")


func _test_prompt_node_exists() -> void:
	var prompt: Control = get_node_or_null("/root/main_world/ui/interaction_prompt") as Control
	_assert(prompt != null, "Interaction prompt node exists under ui")


func _test_notification_node_exists() -> void:
	var notif: Control = get_node_or_null("/root/main_world/ui/notification_popup") as Control
	_assert(notif != null, "Notification popup node exists under ui")


func _test_pause_node_exists() -> void:
	var pause: Control = get_node_or_null("/root/main_world/ui/pause_menu") as Control
	_assert(pause != null, "Pause menu node exists under ui")


func _test_hud_signals_connected() -> void:
	var hud: Control = get_node_or_null("/root/main_world/ui/hud") as Control
	if hud == null:
		_assert(false, "HUD signal test (node missing)")
		return
	# Check that the HUD has connected to game_manager signals
	_assert(game_manager.day_started.is_connected(hud._on_day_started), "HUD connected to day_started")
	_assert(game_manager.money_changed.is_connected(hud._on_money_changed), "HUD connected to money_changed")
	_assert(game_manager.level_changed.is_connected(hud._on_level_changed), "HUD connected to level_changed")


func _test_notification_method() -> void:
	var notif: Control = get_node_or_null("/root/main_world/ui/notification_popup") as Control
	if notif == null:
		_assert(false, "Notification method test (node missing)")
		return
	_assert(notif.has_method("show_notification"), "Notification has show_notification method")


func _test_pause_process_mode() -> void:
	var pause: Control = get_node_or_null("/root/main_world/ui/pause_menu") as Control
	if pause == null:
		_assert(false, "Pause process mode test (node missing)")
		return
	_assert(pause.process_mode == Node.PROCESS_MODE_ALWAYS, "Pause menu has PROCESS_MODE_ALWAYS")
	_assert(not pause.visible, "Pause menu starts hidden")


func _test_input_actions() -> void:
	_assert(InputMap.has_action("open_inventory"), "InputMap has open_inventory")
	_assert(InputMap.has_action("open_upgrade"), "InputMap has open_upgrade")
	_assert(InputMap.has_action("open_restaurant"), "InputMap has open_restaurant")
	_assert(InputMap.has_action("open_recipes"), "InputMap has open_recipes")
	_assert(InputMap.has_action("open_staff"), "InputMap has open_staff")
	_assert(InputMap.has_action("open_achievements"), "InputMap has open_achievements")
	# Existing actions still present
	_assert(InputMap.has_action("interact"), "InputMap has interact (existing)")
	_assert(InputMap.has_action("pause"), "InputMap has pause (existing)")


func _test_shared_theme_variations() -> void:
	var theme: Theme = load("res://resources/theme/lahoue_theme.tres") as Theme
	_assert(theme != null and theme.get_stylebox("panel", "Card") != null, "Shared Theme has standard Card")
	_assert(theme != null and theme.get_stylebox("panel", "PremiumCard") != null, "Shared Theme has Premium Card")
	_assert(theme != null and theme.get_stylebox("panel", "WarningCard") != null, "Shared Theme has Warning Card")
	_assert(theme != null and theme.get_stylebox("panel", "IconSlot") != null, "Shared Theme has icon placeholders")


func _test_all_gameplay_panels() -> void:
	var ui: Node = get_node_or_null("/root/main_world/ui")
	if ui == null:
		_assert(false, "Gameplay panel test (UI missing)")
		return
	for property_name: String in [
		"inventory_panel", "shop_panel", "recipe_panel", "restaurant_panel",
		"upgrade_panel", "staff_panel", "achievement_panel", "truck_panel",
		"premium_market_panel", "tutorial_popup", "day_summary_panel",
	]:
		var panel: Control = ui.get(property_name) as Control
		_assert(panel != null, "%s exists" % property_name)
		if panel != null and panel.has_method("refresh"):
			panel.call("refresh")


func _test_hud_required_values() -> void:
	var hud: Control = get_node_or_null("/root/main_world/ui/hud") as Control
	if hud == null:
		_assert(false, "HUD required-value test (node missing)")
		return
	var text: String = _collect_text(hud)
	for required: String in ["Day", "Time:", "Lv ", "EXP", "Money:", "VNĐ", "Warehouse:"]:
		_assert(text.contains(required), "HUD shows %s" % required)


func _test_standardized_strings_and_ids() -> void:
	var ui: Node = get_node_or_null("/root/main_world/ui")
	var upgrade: Control = ui.get("upgrade_panel") as Control
	game_manager.level = 1
	game_manager.money = 200000
	upgrade.call("refresh")
	var upgrade_text: String = _collect_text(upgrade)
	_assert(upgrade_text.contains("Warehouse"), "Warehouse upgrade card is visible before permission level")
	_assert(upgrade_text.contains("Capacity: 75 → 150"), "Warehouse card shows current → next capacity")
	_assert(upgrade_text.contains("Requires Level 5"), "Locked upgrade states show required player level")
	_assert(upgrade_text.contains("Farm Expansion") and upgrade_text.contains("Farm Plots: 1/3"), "Farm Expansion shows current/allowed plots")
	_assert(upgrade_text.contains("100.000 VNĐ"), "Farm Expansion shows the 100K cost")

	game_manager.level = 4
	game_manager.money = 400000
	var truck: Control = ui.get("truck_panel") as Control
	truck.call("refresh")
	var truck_text: String = _collect_text(truck)
	var truck_button: Button = truck.find_child("upgrade_truck_button", true, false) as Button
	_assert(truck_button != null and truck_button.disabled, "Truck Upgrade is disabled when player level is too low")
	_assert(truck_text.contains("Requires Level 5"), "Truck Upgrade explains why clicking is unavailable")
	_assert(truck_text.contains("Capacity") and truck_text.contains("Delivery"), "Truck Upgrade shows current → next benefits")

	var restaurant: Control = ui.get("restaurant_panel") as Control
	restaurant.call("refresh")
	_assert(_collect_text(restaurant).contains("Requires Level 5"), "Restaurant locked state is explicit")
	var premium: Control = ui.get("premium_market_panel") as Control
	premium.call("refresh")
	_assert(_collect_text(premium).contains("Requires Level 35"), "Premium Market locked state is explicit")

	for property_name: String in ["inventory_panel", "shop_panel", "recipe_panel"]:
		var panel: Control = ui.get(property_name) as Control
		panel.call("refresh")
		var panel_text: String = _collect_text(panel)
		_assert(not panel_text.contains("rice_seed") and not panel_text.contains("st25_"), "%s hides raw data IDs" % property_name)
	var all_text: String = _collect_text(ui)
	_assert(not all_text.to_lower().contains("backspace"), "No UI flow instructs the player to use Backspace")

	game_manager.level = 1
	game_manager.money = 200000


func _test_responsive_layouts() -> void:
	var ui: Node = get_node_or_null("/root/main_world/ui")
	var panel_names: Array[String] = [
		"inventory_panel", "shop_panel", "recipe_panel", "restaurant_panel",
		"upgrade_panel", "staff_panel", "achievement_panel", "truck_panel",
		"premium_market_panel", "day_summary_panel",
	]
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(960, 540), Vector2(640, 480)]:
		ui.call("_fit_panels_to_size", viewport_size)
		for panel_name: String in panel_names:
			var panel: Control = ui.get(panel_name) as Control
			var fitted: Vector2 = panel.get_meta("responsive_size", Vector2.ZERO) as Vector2
			var within_bounds: bool = (
				fitted.x > 0.0 and fitted.y > 0.0
				and fitted.x <= maxf(viewport_size.x - 32.0, 320.0)
				and fitted.y <= maxf(viewport_size.y - 120.0, 300.0)
			)
			_assert(within_bounds, "%s fits %dx%d" % [panel_name, int(viewport_size.x), int(viewport_size.y)])
	ui.call("_fit_panels_to_size", get_viewport().get_visible_rect().size)


func _test_single_modal_flow() -> void:
	var ui: Node = get_node_or_null("/root/main_world/ui")
	var inventory: Control = ui.get("inventory_panel") as Control
	var upgrades: Control = ui.get("upgrade_panel") as Control
	ui.call("_toggle_panel", inventory)
	_assert(ui.get("active_panel") == inventory and inventory.visible, "Inventory becomes the active modal")
	ui.call("_toggle_panel", upgrades)
	await get_tree().create_timer(0.2).timeout
	_assert(ui.get("active_panel") == upgrades and upgrades.visible and not inventory.visible, "Opening a modal closes the previous modal")
	ui.call("_close_active_panel")
	await get_tree().create_timer(0.15).timeout
	_assert(ui.get("active_panel") == null and not upgrades.visible, "ESC/Close flow clears the active modal")


func _test_save_continue_ui_stability() -> void:
	var ui: Node = get_node_or_null("/root/main_world/ui")
	await get_tree().process_frame
	await get_tree().process_frame
	var before_count: int = ui.get_child_count()
	_assert(save_manager.save_game(), "UI state can be saved through the normal Save flow")
	_assert(save_manager.load_game(), "UI state survives Continue")
	await get_tree().process_frame
	await get_tree().process_frame
	var after_count: int = ui.get_child_count()
	var named_panels_unique: bool = true
	for panel_name: String in [
		"inventory_panel", "shop_panel", "recipe_panel", "restaurant_panel",
		"upgrade_panel", "staff_panel", "achievement_panel", "truck_panel", "premium_market_panel",
	]:
		named_panels_unique = named_panels_unique and _count_named_descendants(ui, panel_name) == 1
	_assert(after_count == before_count and named_panels_unique, "Save/Continue does not duplicate UI panels")


func _collect_text(node: Node) -> String:
	var lines: Array[String] = []
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		lines.append(_collect_text(child))
	return "\n".join(lines)


func _count_descendants(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_descendants(child)
	return count


func _count_named_descendants(node: Node, target_name: String) -> int:
	var count: int = 1 if node.name == target_name else 0
	for child: Node in node.get_children():
		count += _count_named_descendants(child, target_name)
	return count


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
