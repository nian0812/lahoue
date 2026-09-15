extends CanvasLayer

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var hud_node: Control
var prompt_node: Control
var notification_node: Control
var pause_node: Control

var inventory_panel: Control
var shop_panel: Control
var recipe_panel: Control
var restaurant_panel: Control

var upgrade_panel: Control
var staff_panel: Control
var achievement_panel: Control
var level_up_popup: Control
var day_summary_panel: Control
var tooltip_node: Control
var truck_panel: Control
var premium_market_panel: Control
var tutorial_popup: Control
var shortcut_hint_node: Control
var bottom_toolbar_node: Control

var active_panel: Control = null
var player_node: Node2D = null

var floating_text_scene: PackedScene = preload("res://scenes/ui/floating_text.tscn")
var _last_exp: int = -1
var _last_level: int = -1


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

	upgrade_panel = get_node_or_null("upgrade_panel") as Control
	staff_panel = get_node_or_null("staff_panel") as Control
	achievement_panel = get_node_or_null("achievement_panel") as Control
	level_up_popup = get_node_or_null("level_up_popup") as Control
	day_summary_panel = get_node_or_null("day_summary_panel") as Control
	tooltip_node = get_node_or_null("tooltip_panel") as Control
	truck_panel = get_node_or_null("truck_panel") as Control
	premium_market_panel = get_node_or_null("premium_market_panel") as Control
	tutorial_popup = get_node_or_null("tutorial_popup") as Control
	shortcut_hint_node = get_node_or_null("shortcut_hint") as Control
	bottom_toolbar_node = get_node_or_null("bottom_toolbar") as Control

	# Apply theme and initial visibility
	var all_nodes: Array[Control] = [
		hud_node, prompt_node, notification_node, pause_node,
		inventory_panel, shop_panel, recipe_panel, restaurant_panel,
		upgrade_panel, staff_panel, achievement_panel, level_up_popup, day_summary_panel,
		tooltip_node, truck_panel, premium_market_panel, tutorial_popup,
		shortcut_hint_node, bottom_toolbar_node
	]
	for node: Control in all_nodes:
		if node != null:
			node.theme = theme_res

	for panel: Control in [inventory_panel, shop_panel, recipe_panel, restaurant_panel, upgrade_panel, staff_panel, achievement_panel, truck_panel, premium_market_panel]:
		if panel != null:
			panel.visible = false

	# Wire toolbar and truck panel references
	if bottom_toolbar_node != null and bottom_toolbar_node.has_method("set_ui_manager"):
		bottom_toolbar_node.call("set_ui_manager", self)
	call_deferred("_setup_truck_panel")
	call_deferred("_setup_premium_market_panel")

	# Wire player references
	call_deferred("_setup_player")
	if not get_viewport().size_changed.is_connected(_fit_panels):
		get_viewport().size_changed.connect(_fit_panels)
	_fit_panels()

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
	elif event.is_action_pressed("open_upgrade"):
		_toggle_panel(upgrade_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_staff"):
		_toggle_panel(staff_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_shop"):
		_toggle_panel(shop_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_achievements"):
		_toggle_panel(achievement_panel)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		if shortcut_hint_node and shortcut_hint_node.has_method("toggle_visibility"):
			shortcut_hint_node.call("toggle_visibility")
		if bottom_toolbar_node and bottom_toolbar_node.has_method("toggle_visibility"):
			bottom_toolbar_node.call("toggle_visibility")
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

		# Open animation
		panel.modulate.a = 0
		panel.scale = Vector2.ONE * 0.95
		panel.pivot_offset = panel.size / 2
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		if panel.has_method("refresh"):
			panel.call("refresh")
		var panel_id: String = _get_panel_id(panel)
		if not panel_id.is_empty():
			panel_opened.emit(panel_id)


func _close_active_panel() -> void:
	if active_panel != null:
		var panel_to_close: Control = active_panel
		active_panel = null
		var panel_id: String = _get_panel_id(panel_to_close)
		if not panel_id.is_empty():
			panel_closed.emit(panel_id)

		# Close animation
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel_to_close, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(panel_to_close, "scale", Vector2.ONE * 0.95, 0.1).set_trans(Tween.TRANS_SINE)
		tw.set_parallel(false)
		tw.tween_callback(func() -> void:
			panel_to_close.visible = false
			panel_to_close.modulate.a = 1.0
			panel_to_close.scale = Vector2.ONE
		)

		if tooltip_node:
			tooltip_node.call("hide_tooltip")


func _get_panel_id(panel: Control) -> String:
	if panel == inventory_panel:
		return "inventory"
	if panel == shop_panel:
		return "shop"
	if panel == recipe_panel:
		return "recipe"
	if panel == restaurant_panel:
		return "restaurant"
	if panel == upgrade_panel:
		return "upgrade"
	if panel == staff_panel:
		return "staff"
	if panel == achievement_panel:
		return "achievement"
	if panel == truck_panel:
		return "truck"
	if panel == premium_market_panel:
		return "premium_market"
	return ""


func _fit_panels() -> void:
	_fit_panels_to_size(get_viewport().get_visible_rect().size)


func _fit_panels_to_size(viewport_size: Vector2) -> void:
	var preferred_sizes: Dictionary = {
		inventory_panel: Vector2(820, 560),
		shop_panel: Vector2(820, 560),
		recipe_panel: Vector2(820, 560),
		restaurant_panel: Vector2(940, 580),
		upgrade_panel: Vector2(820, 580),
		staff_panel: Vector2(940, 580),
		achievement_panel: Vector2(820, 580),
		truck_panel: Vector2(860, 580),
		premium_market_panel: Vector2(900, 600),
		day_summary_panel: Vector2(620, 580),
	}
	for panel_value: Variant in preferred_sizes:
		var panel: Control = panel_value as Control
		if panel == null:
			continue
		ui_style.fit_centered_modal(panel, viewport_size, preferred_sizes[panel_value] as Vector2)
		if panel.has_method("apply_responsive_layout"):
			panel.call("apply_responsive_layout", viewport_size)
	if bottom_toolbar_node != null and bottom_toolbar_node.has_method("apply_responsive_layout"):
		bottom_toolbar_node.call("apply_responsive_layout", viewport_size)
	if tutorial_popup != null and tutorial_popup.has_method("apply_responsive_layout"):
		tutorial_popup.call("apply_responsive_layout", viewport_size)

func show_tooltip(data: Dictionary, pos: Vector2) -> void:
	if tooltip_node:
		tooltip_node.call("show_tooltip", data, pos)

func hide_tooltip() -> void:
	if tooltip_node:
		tooltip_node.call("hide_tooltip")


func _setup_player() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var player: Node = parent.get_node_or_null("player")
	if player == null:
		return

	player_node = player as Node2D

	if hud_node != null and hud_node.has_method("set_player"):
		hud_node.call("set_player", player)

	if prompt_node != null and prompt_node.has_method("set_player"):
		prompt_node.call("set_player", player)


func _connect_notification_signals() -> void:
	if notification_node == null or not notification_node.has_method("show_notification"):
		return

	# Inventory events
	if not inventory_manager.item_sold.is_connected(_on_item_sold):
		inventory_manager.item_sold.connect(_on_item_sold)
	if not inventory_manager.item_purchased.is_connected(_on_item_purchased):
		inventory_manager.item_purchased.connect(_on_item_purchased)
	if not inventory_manager.warehouse_upgraded.is_connected(_on_warehouse_upgraded):
		inventory_manager.warehouse_upgraded.connect(_on_warehouse_upgraded)
	if not inventory_manager.item_added.is_connected(_on_item_added):
		inventory_manager.item_added.connect(_on_item_added)

	# Level change
	if not game_manager.level_changed.is_connected(_on_level_changed_notify):
		game_manager.level_changed.connect(_on_level_changed_notify)
	if not game_manager.exp_changed.is_connected(_on_exp_changed):
		game_manager.exp_changed.connect(_on_exp_changed)

	# Achievement unlock
	var parent: Node = get_parent()
	if parent == null:
		return

	var tracker: Node = parent.get_node_or_null("achievement_tracker")
	if tracker != null and tracker.has_signal("achievement_unlocked"):
		if not tracker.is_connected("achievement_unlocked", _on_achievement_unlocked):
			tracker.connect("achievement_unlocked", _on_achievement_unlocked)
	if tracker != null and tracker.has_signal("reward_claimed"):
		if not tracker.is_connected("reward_claimed", _on_achievement_reward_claimed):
			tracker.connect("reward_claimed", _on_achievement_reward_claimed)

	# Restaurant events
	var restaurant: Node = parent.get_node_or_null("restaurant")
	if restaurant != null:
		if restaurant.has_signal("restaurant_interacted"):
			if not restaurant.is_connected("restaurant_interacted", _on_restaurant_interacted):
				restaurant.connect("restaurant_interacted", _on_restaurant_interacted)
		if restaurant.has_signal("staff_hired"):
			if not restaurant.is_connected("staff_hired", _on_staff_hired):
				restaurant.connect("staff_hired", _on_staff_hired)
		if restaurant.has_signal("upgrade_purchased"):
			if not restaurant.is_connected("upgrade_purchased", _on_upgrade_purchased):
				restaurant.connect("upgrade_purchased", _on_upgrade_purchased)
		if restaurant.has_signal("payment_collected"):
			if not restaurant.is_connected("payment_collected", _on_restaurant_payment_collected):
				restaurant.connect("payment_collected", _on_restaurant_payment_collected)
		
		# Auto-refresh restaurant panel on state changes
		for sig in ["food_ready", "customer_spawned", "customer_removed", "order_served", "payment_collected", "cooking_started", "cooking_canceled"]:
			if restaurant.has_signal(sig):
				if not restaurant.is_connected(sig, _on_restaurant_state_changed):
					restaurant.connect(sig, _on_restaurant_state_changed)

	# World-level upgrades (animal housing, aquaculture)
	if parent.has_signal("upgrade_purchased"):
		if not parent.is_connected("upgrade_purchased", _on_upgrade_purchased):
			parent.connect("upgrade_purchased", _on_upgrade_purchased)

	var premium_market: Node = parent.get_node_or_null("hub/premium_market")
	if premium_market != null:
		if not premium_market.is_connected("market_interacted", _on_premium_market_interacted):
			premium_market.connect("market_interacted", _on_premium_market_interacted)
		if not premium_market.is_connected("shipment_started", _on_import_shipment_started):
			premium_market.connect("shipment_started", _on_import_shipment_started)
		if not premium_market.is_connected("shipment_arrived", _on_import_shipment_arrived):
			premium_market.connect("shipment_arrived", _on_import_shipment_arrived)
		if not premium_market.is_connected("helicopter_upgraded", _on_helicopter_upgraded):
			premium_market.connect("helicopter_upgraded", _on_helicopter_upgraded)


func _on_restaurant_interacted(player: Node) -> void:
	_toggle_panel(restaurant_panel)


func _on_premium_market_interacted(_player: Node) -> void:
	_toggle_panel(premium_market_panel)

func _on_restaurant_state_changed(_arg1=null, _arg2=null, _arg3=null) -> void:
	if active_panel == restaurant_panel and restaurant_panel != null:
		if restaurant_panel.has_method("refresh"):
			restaurant_panel.call("refresh")

func _on_item_sold(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var price_text: String = vnd_format.format_vnd(int(p_total))
	var sales_exp: int = game_manager.calculate_sales_exp(int(p_total))
	var item_name: String = data_manager.get_item_display_name(String(p_item_id))
	notification_node.call("show_notification", "Sold %s x%d\n+%s\n+%d EXP" % [item_name, int(p_amount), price_text, sales_exp], "success")
	if player_node:
		spawn_floating_text("+%s" % price_text, _get_randomized_player_pos(), Color(0.4, 0.8, 0.4))


func _on_item_purchased(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var name_text: String = vnd_format.format_item_name(String(p_item_id))
	notification_node.call("show_notification", "Bought %d %s" % [int(p_amount), name_text], "info")
	if player_node:
		var price_text: String = vnd_format.format_vnd(int(p_total))
		spawn_floating_text("-%s" % price_text, _get_randomized_player_pos(), Color(0.8, 0.3, 0.3))


func _on_item_added(p_item_id: Variant, p_amount: Variant) -> void:
	if player_node:
		var name_text: String = vnd_format.format_item_name(String(p_item_id))
		spawn_floating_text("+%d %s" % [int(p_amount), name_text], _get_randomized_player_pos(), Color(1.0, 1.0, 0.8))


func _on_warehouse_upgraded(p_level: Variant, p_capacity: Variant) -> void:
	notification_node.call("show_notification", "Warehouse upgraded!\nLv%d • Capacity %d" % [int(p_level), int(p_capacity)], "success")


func _on_level_changed_notify(new_lvl: Variant) -> void:
	var lvl: int = int(new_lvl)
	if _last_level > 0 and lvl > _last_level:
		if level_up_popup and level_up_popup.has_method("show_level_up"):
			level_up_popup.call("show_level_up", _last_level, lvl)
	else:
		notification_node.call("show_notification", "Level %d Reached" % lvl, "success")
	_last_level = lvl

	if active_panel != null and active_panel.has_method("refresh"):
		active_panel.call("refresh")

	# Removed duplicate _on_exp_changed here
func _on_exp_changed(new_exp: Variant, _lvl: Variant) -> void:
	var current_exp: int = int(new_exp)
	if _last_exp >= 0 and current_exp > _last_exp:
		if player_node:
			spawn_floating_text("+%d EXP" % (current_exp - _last_exp), _get_randomized_player_pos(), Color(0.3, 0.6, 1.0))
	_last_exp = current_exp
	if active_panel == upgrade_panel and upgrade_panel != null:
		upgrade_panel.call("refresh")

func _get_randomized_player_pos() -> Vector2:
	if player_node:
		var pos: Vector2 = player_node.global_position
		pos.x += randf_range(-30, 30)
		pos.y -= randf_range(20, 50)
		return pos
	return Vector2.ZERO

func spawn_floating_text(text: String, global_pos: Vector2, color: Color = Color.WHITE) -> void:
	var ft: Node2D = floating_text_scene.instantiate() as Node2D
	ft.global_position = global_pos
	get_parent().add_child(ft)
	ft.call("display", text, color)


func _on_achievement_unlocked(p_id: Variant) -> void:
	var achievement_name: String = _get_achievement_name(String(p_id))
	notification_node.call("show_notification", "Achievement Completed!\n%s" % achievement_name, "success")


func _on_achievement_reward_claimed(p_id: Variant) -> void:
	var achievement_name: String = _get_achievement_name(String(p_id))
	notification_node.call("show_notification", "Reward Claimed!\n%s" % achievement_name, "success")


func _get_achievement_name(achievement_id: String) -> String:
	var main_world: Node = get_parent()
	var tracker: Node = main_world.get_node_or_null("achievement_tracker") if main_world != null else null
	if tracker == null:
		return "Achievement"
	var definitions: Dictionary = tracker.call("get_definitions") as Dictionary
	var definition: Dictionary = definitions.get(achievement_id, {}) as Dictionary
	return String(definition.get("name", "Achievement"))


func _on_staff_hired(p_staff_id: Variant, p_type_id: Variant, p_cost: Variant) -> void:
	notification_node.call("show_notification", "%s hired!\nDaily payroll updated" % String(p_type_id).replace("_", " ").capitalize(), "info")


func _on_upgrade_purchased(p_system_id: Variant, p_level: Variant, p_cost: Variant, p_effect: Variant) -> void:
	var sys_name: String = vnd_format.format_item_name(String(p_system_id))
	notification_node.call("show_notification", "%s → Lv %d" % [sys_name, int(p_level)], "success")


func _setup_truck_panel() -> void:
	if truck_panel == null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var truck_mgr: Node = parent.get_node_or_null("truck_manager")
	if truck_mgr != null and truck_panel.has_method("set_truck_manager"):
		truck_panel.call("set_truck_manager", truck_mgr)
	if truck_panel.has_method("set_ui_manager"):
		truck_panel.call("set_ui_manager", self)
	# Connect delivery notifications
	if truck_mgr != null and truck_mgr.has_signal("delivery_completed"):
		if not truck_mgr.is_connected("delivery_completed", _on_delivery_completed):
			truck_mgr.connect("delivery_completed", _on_delivery_completed)


func _setup_premium_market_panel() -> void:
	if premium_market_panel == null:
		return
	var premium_market: Node = get_parent().get_node_or_null("hub/premium_market")
	if premium_market != null and premium_market_panel.has_method("set_market_controller"):
		premium_market_panel.call("set_market_controller", premium_market)


func _on_import_shipment_started(_cargo: Dictionary, total_cost: int) -> void:
	notification_node.call(
		"show_notification",
		"Import order confirmed: -%s" % vnd_format.format_vnd(total_cost),
		"info"
	)


func _on_import_shipment_arrived(cargo: Dictionary) -> void:
	var lines: Array[String] = ["Import arrived!"]
	var item_ids: Array = cargo.keys()
	item_ids.sort()
	for item_id_value: Variant in item_ids:
		var item_id: String = String(item_id_value)
		lines.append("%s x%d" % [
			data_manager.get_item_display_name(item_id),
			int(cargo[item_id]),
		])
	notification_node.call("show_notification", "\n".join(lines), "success")


func _on_helicopter_upgraded(level: int, _cost: int) -> void:
	notification_node.call("show_notification", "Helicopter → Lv %d" % level, "success")


func _on_delivery_completed(p_truck_idx: Variant, p_item_id: Variant, p_amount: Variant, p_payout: Variant) -> void:
	var price_text: String = vnd_format.format_vnd(int(p_payout))
	var sales_exp: int = game_manager.calculate_sales_exp(int(p_payout))
	notification_node.call("show_notification", "Truck #%d giao hàng thành công!\n+%s\n+%d EXP" % [int(p_truck_idx) + 1, price_text, sales_exp], "success")
	if player_node:
		spawn_floating_text("+%s" % price_text, _get_randomized_player_pos(), Color(0.4, 0.8, 0.4))


func _on_restaurant_payment_collected(_customer_id: Variant, recipe_id: Variant, revenue: Variant) -> void:
	var recipe_data: Dictionary = data_manager.get_entry("recipes", String(recipe_id)) as Dictionary
	var dish_name: String = String(recipe_data.get("name", String(recipe_id).replace("_", " ").capitalize()))
	notification_node.call(
		"show_notification",
		"Restaurant payment • %s\n+%s\n+%d EXP" % [dish_name, vnd_format.format_vnd(int(revenue)), game_manager.calculate_sales_exp(int(revenue))],
		"success"
	)


func open_hub_panel(building_id: String) -> void:
	match building_id:
		"market":
			_toggle_panel(shop_panel)
		"warehouse":
			_toggle_panel(inventory_panel)
		"upgrade_board", "vip_area", "resort":
			_toggle_panel(upgrade_panel)
		"truck_depot":
			_toggle_panel(truck_panel)
		"premium_market":
			_toggle_panel(premium_market_panel)
