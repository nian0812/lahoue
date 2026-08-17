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

var upgrade_panel: Control
var staff_panel: Control
var achievement_panel: Control
var level_up_popup: Control
var day_summary_panel: Control
var tooltip_node: Control

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

	# Apply theme and initial visibility
	var all_nodes: Array[Control] = [
		hud_node, prompt_node, notification_node, pause_node,
		inventory_panel, shop_panel, recipe_panel, restaurant_panel,
		upgrade_panel, staff_panel, achievement_panel, level_up_popup, day_summary_panel,
		tooltip_node
	]
	for node: Control in all_nodes:
		if node != null:
			node.theme = theme_res

	for panel: Control in [inventory_panel, shop_panel, recipe_panel, restaurant_panel, upgrade_panel, staff_panel, achievement_panel]:
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
	elif event.is_action_pressed("open_upgrade"):
		_toggle_panel(upgrade_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_staff"):
		_toggle_panel(staff_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_achievements"):
		_toggle_panel(achievement_panel)
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


func _close_active_panel() -> void:
	if active_panel != null:
		var panel_to_close: Control = active_panel
		active_panel = null

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

	# Restaurant events
	var restaurant: Node = parent.get_node_or_null("restaurant")
	if restaurant != null:
		if restaurant.has_signal("staff_hired"):
			if not restaurant.is_connected("staff_hired", _on_staff_hired):
				restaurant.connect("staff_hired", _on_staff_hired)
		if restaurant.has_signal("upgrade_purchased"):
			if not restaurant.is_connected("upgrade_purchased", _on_upgrade_purchased):
				restaurant.connect("upgrade_purchased", _on_upgrade_purchased)

	# World-level upgrades (animal housing, aquaculture)
	if parent.has_signal("upgrade_purchased"):
		if not parent.is_connected("upgrade_purchased", _on_upgrade_purchased):
			parent.connect("upgrade_purchased", _on_upgrade_purchased)


func _on_item_sold(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var price_text: String = vnd_format.format(int(p_total))
	notification_node.call("show_notification", "Sold: +%s" % price_text, "success")
	if player_node:
		spawn_floating_text("+%s" % price_text, _get_randomized_player_pos(), Color(0.4, 0.8, 0.4))


func _on_item_purchased(p_item_id: Variant, p_amount: Variant, p_total: Variant) -> void:
	var name_text: String = vnd_format.format_item_name(String(p_item_id))
	notification_node.call("show_notification", "Bought %d %s" % [int(p_amount), name_text], "info")
	if player_node:
		var price_text: String = vnd_format.format(int(p_total))
		spawn_floating_text("-%s" % price_text, _get_randomized_player_pos(), Color(0.8, 0.3, 0.3))


func _on_item_added(p_item_id: Variant, p_amount: Variant) -> void:
	if player_node:
		var name_text: String = vnd_format.format_item_name(String(p_item_id))
		spawn_floating_text("+%d %s" % [int(p_amount), name_text], _get_randomized_player_pos(), Color(1.0, 1.0, 0.8))


func _on_warehouse_upgraded(p_level: Variant, p_capacity: Variant) -> void:
	notification_node.call("show_notification", "Warehouse → Lv %d (Cap %d)" % [int(p_level), int(p_capacity)], "success")


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
	notification_node.call("show_notification", "Achievement Unlocked!", "success")


func _on_staff_hired(p_staff_id: Variant, p_type_id: Variant, p_cost: Variant) -> void:
	notification_node.call("show_notification", "Staff hired!", "info")


func _on_upgrade_purchased(p_system_id: Variant, p_level: Variant, p_cost: Variant, p_effect: Variant) -> void:
	var sys_name: String = vnd_format.format_item_name(String(p_system_id))
	notification_node.call("show_notification", "%s → Lv %d" % [sys_name, int(p_level)], "success")
