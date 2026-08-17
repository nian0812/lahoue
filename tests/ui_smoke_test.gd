extends Node

var test_results: Array[String] = []
var test_count: int = 0
var pass_count: int = 0
var fail_count: int = 0


func _ready() -> void:
	print("=== UI Smoke Test — Phase 13 Tier 1 ===")
	await get_tree().create_timer(0.5).timeout

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

	print("")
	print("=== Results: %d/%d passed ===" % [pass_count, test_count])
	for result: String in test_results:
		print(result)

	if fail_count > 0:
		print("FAIL: %d tests failed" % fail_count)
	else:
		print("ALL TESTS PASSED")

	await get_tree().create_timer(0.2).timeout
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
