extends CanvasLayer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var hud_node: Control
var prompt_node: Control
var notification_node: Control
var pause_node: Control

var inventory_panel: Control
var shop_panel: Control
var recipe_panel: Control
var restaurant_panel: Control

var active_panel: Control = null


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	# Load theme and apply to UI components
	var theme_res: Theme = load("res://resources/theme/lahoue_theme.tres") as Theme

	hud_node = get_node_or_null("hud") as Control
	prompt_node = get_node_or_null("interaction_prompt") as Control
	notification_node = get_node_or_null("notification_popup") as Control
	pause_node = get_node_or_null("pause_menu") as Control

	inventory_panel = get_node_or_null("inventory_panel") as Control
	shop_panel = get_node_or_null("shop_panel") as Control
	recipe_panel = get_node_or_null("recipe_panel") as Control
	restaurant_panel = get_node_or_null("restaurant_panel") as Control

	# Apply theme and initial visibility
	var all_nodes: Array[Control] = [
		hud_node, prompt_node, notification_node, pause_node,
		inventory_panel, shop_panel, recipe_panel, restaurant_panel
	]
	for node: Control in all_nodes:
		if node != null:
			node.theme = theme_res

	for panel: Control in [inventory_panel, shop_panel, recipe_panel, restaurant_panel]:
		if panel != null:
			panel.visible = false

	# Wire player references
	call_deferred("_setup_player")

	# Connect notification signals
	_connect_notification_signals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if active_panel != null:
			_close_active_panel()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_inventory"):
		_toggle_panel(inventory_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_recipes"):
		_toggle_panel(recipe_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_restaurant"):
		_toggle_panel(restaurant_panel)
		get_viewport().set_input_as_handled()


func _toggle_panel(panel: Control) -> void:
	if panel == null:
		return
	if active_panel == panel:
		_close_active_panel()
	else:
		if active_panel != null:
			_close_active_panel()
		active_panel = panel
		panel.visible = true
		if panel.has_method("refresh"):
			panel.refresh()


func _close_active_panel() -> void:
	if active_panel != null:
		active_panel.visible = false
		active_panel = null


func _setup_player() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var player: Node = parent.get_node_or_null("player")
	if player == null:
		return

	if hud_node != null and hud_node.has_method("set_player"):
		hud_node.call("set_player", player)

	if prompt_node != null and prompt_node.has_method("set_player"):
		prompt_node.call("set_player", player)


func _connect_notification_signals() -> void:
	if notification_node == null or not notification_node.has_method("show_notification"):
		return

	# Inventory events
	inventory_manager.item_sold.connect(_on_item_sold)
	inventory_manager.item_purchased.connect(_on_item_purchased)
	inventory_manager.warehouse_upgraded.connect(_on_warehouse_upgraded)

	# Level change
	game_manager.level_changed.connect(_on_level_changed_notify)

	# Achievement unlock
	var parent: Node = get_parent()
	if parent == null:
		return

	var tracker: Node = parent.get_node_or_null("achievement_tracker")
	if tracker != null and tracker.has_signal("achievement_unlocked"):
		tracker.connect("achievement_unlocked", _on_achievement_unlocked)

	# Restaurant events
	var restaurant: Node = parent.get_node_or_null("restaurant")
	if restaurant != null:
		if restaurant.has_signal("staff_hired"):
			restaurant.connect("staff_hired", _on_staff_hired)
		if restaurant.has_signal("upgrade_purchased"):
			restaurant.connect("upgrade_purchased", _on_upgrade_purchased)

	# World-level upgrades (animal housing, aquaculture)
	if parent.has_signal("upgrade_purchased"):
		parent.connect("upgrade_purchased", _on_upgrade_purchased)


func _on_item_sold(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var price_text: String = vnd_format.format(int(p_total))
	notification_node.call("show_notification", "Sold: +%s" % price_text, "success")


func _on_item_purchased(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var name_text: String = vnd_format.format_item_name(String(p_item_id))
	notification_node.call("show_notification", "Bought %d %s" % [int(p_amount), name_text], "info")


func _on_warehouse_upgraded(p_level: Variant, p_capacity: Variant) -> void:
	notification_node.call("show_notification", "Warehouse → Lv %d (Cap %d)" % [int(p_level), int(p_capacity)], "success")


func _on_level_changed_notify(p_level: Variant) -> void:
	if int(p_level) <= 1:
		return
	notification_node.call("show_notification", "Level Up! → Lv %d" % int(p_level), "success")


func _on_achievement_unlocked(p_id: Variant) -> void:
	notification_node.call("show_notification", "Achievement Unlocked!", "success")


func _on_staff_hired(p_staff_id: Variant, p_type_id: Variant, p_cost: Variant) -> void:
	notification_node.call("show_notification", "Staff hired!", "info")


func _on_upgrade_purchased(p_system_id: Variant, p_level: Variant, p_cost: Variant, p_effect: Variant) -> void:
	var sys_name: String = vnd_format.format_item_name(String(p_system_id))
	notification_node.call("show_notification", "%s → Lv %d" % [sys_name, int(p_level)], "success")
