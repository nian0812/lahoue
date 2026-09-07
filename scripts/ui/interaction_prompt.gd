extends Control

const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var prompt_panel: PanelContainer
var prompt_label: Label
var player_ref: Node = null
var current_target: Node = null
var active_tween: Tween = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_prompt()


func set_player(player: Node) -> void:
	player_ref = player


func _process(_delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		_hide_prompt()
		return

	var area: Area2D = player_ref.get_node_or_null("interaction_area") as Area2D
	if area == null:
		_hide_prompt()
		return

	var closest: Node = _find_closest(area)
	if closest == null:
		if current_target != null:
			current_target = null
			_hide_prompt()
		return

	current_target = closest
	_update_text(closest)
	_show_prompt()


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.name = "prompt_panel"
	add_child(prompt_panel)
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -150
	prompt_panel.offset_right = 150
	prompt_panel.offset_top = -130
	prompt_panel.offset_bottom = -90
	prompt_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_apply_style(prompt_panel)

	var content: HBoxContainer = HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	prompt_panel.add_child(content)
	content.add_child(ui_style.make_atlas_icon_slot(
		"world_interaction_production_markers_sheet",
		"interact_use_marker",
		true
	))

	prompt_label = Label.new()
	prompt_label.name = "label"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87, 1.0))
	prompt_label.mouse_filter = MOUSE_FILTER_IGNORE
	prompt_label.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_child(prompt_label)

	prompt_panel.modulate.a = 0.0
	prompt_panel.visible = false


func _find_closest(area: Area2D) -> Node:
	var best: Node = null
	var best_dist: float = INF
	var origin: Vector2 = player_ref.global_position

	for overlapping: Area2D in area.get_overlapping_areas():
		var target: Node = _resolve(overlapping)
		if target == null:
			continue
		var pos: Vector2 = overlapping.global_position
		if target is Node2D:
			pos = (target as Node2D).global_position
		var d: float = origin.distance_squared_to(pos)
		if d < best_dist:
			best = target
			best_dist = d
	return best


func _resolve(area: Area2D) -> Node:
	if area.has_method("interact"):
		return area
	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent
	return null


func _update_text(target: Node) -> void:
	if target.has_method("get_interaction_prompt_text"):
		prompt_label.text = String(target.call("get_interaction_prompt_text"))
		return

	# Farm tile — check for enum state property and tile_id
	if target.get("tile_id") != null and target.get("current_state") is int:
		var state: int = int(target.get("current_state"))
		if state == 0:  # EMPTY
			var seed_id: String = ""
			if player_ref != null:
				var sid: Variant = player_ref.get("selected_seed_item_id")
				if sid != null:
					seed_id = String(sid)
			if seed_id.is_empty():
				prompt_label.text = "No Seeds in Inventory"
			else:
				if target.has_method("can_plant") and not target.call("can_plant", seed_id):
					var crop_id: String = data_manager.get_crop_id_for_seed(seed_id)
					prompt_label.text = "Requires Level %d" % data_manager.get_crop_required_level(crop_id)
				else:
					prompt_label.text = "[E] Plant   [R] Next seed"
		elif state == 2:  # READY
			prompt_label.text = "[E] Harvest"
		else:  # PLANTED
			prompt_label.text = "Crop Growing"
		return

	# Animal — check animal_instance_id
	if target.get("animal_instance_id") != null:
		var state_str: String = String(target.get("current_state"))
		if state_str == "product_ready" or state_str == "end_of_life":
			prompt_label.text = "[E] Collect"
		else:
			prompt_label.text = "Product not ready"
		return

	# Aquaculture container — check container_id + aquaculture_id
	if target.get("container_id") != null and target.get("aquaculture_id") != null:
		var state_str: String = String(target.get("current_state"))
		if state_str == "ready":
			prompt_label.text = "[E] Collect"
		elif state_str == "empty":
			if target.has_method("can_start_cycle") and not target.call("can_start_cycle"):
				var aq_id: String = String(target.get("aquaculture_id"))
				var data_mgr: Node = target.get_node_or_null("/root/data_manager")
				var req_level: int = 1
				if data_mgr != null and data_mgr.has_method("get_aquaculture_required_level"):
					req_level = int(data_mgr.call("get_aquaculture_required_level", aq_id))
				prompt_label.text = "Requires Level %d" % req_level
			else:
				prompt_label.text = "[E] Start"
		else:
			prompt_label.text = "Product not ready"
		return

	# Restaurant — check for restaurant_interacted signal
	if target.has_signal("restaurant_interacted"):
		if target.has_method("is_available") and not bool(target.call("is_available")):
			prompt_label.text = "Requires Level %d" % data_manager.get_restaurant_unlock_level()
		else:
			prompt_label.text = "[E] Restaurant"
		return

	# Hub building — check building_id
	var bid: Variant = target.get("building_id")
	if bid != null and not String(bid).is_empty():
		var bid_str: String = String(bid)
		match bid_str:
			"market":
				prompt_label.text = "[E] Shop"
			"warehouse":
				prompt_label.text = "[E] Warehouse"
			"upgrade_board":
				prompt_label.text = "[E] Upgrade"
			"truck_depot":
				prompt_label.text = "[E] Truck Depot"
			"premium_market":
				if target.has_method("is_unlocked") and not bool(target.call("is_unlocked")):
					prompt_label.text = "Requires Level %d" % data_manager.get_premium_market_unlock_level()
				else:
					var helicopter_state: String = String(target.get("current_state"))
					if helicopter_state == "importing":
						prompt_label.text = "[E] Premium Market — Helicopter importing"
					elif helicopter_state != "ready":
						prompt_label.text = "[E] Premium Market — Shipment active"
					else:
						prompt_label.text = "[E] Premium Market"
			_:
				prompt_label.text = "[E] Interact"
		return

	# Fallback
	prompt_label.text = "[E] Interact"


func _show_prompt() -> void:
	if prompt_panel.visible and prompt_panel.modulate.a > 0.9:
		return
	prompt_panel.visible = true
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.12)


func _hide_prompt() -> void:
	if not prompt_panel.visible:
		return
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.12)
	active_tween.tween_callback(func() -> void: prompt_panel.visible = false)


func _apply_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.07, 0.82)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 16.0
	style.content_margin_top = 8.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
