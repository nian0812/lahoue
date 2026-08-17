extends Control

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
	prompt_panel.offset_top = -88
	prompt_panel.offset_bottom = -52
	prompt_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_apply_style(prompt_panel)

	prompt_label = Label.new()
	prompt_label.name = "label"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87, 1.0))
	prompt_label.mouse_filter = MOUSE_FILTER_IGNORE
	prompt_panel.add_child(prompt_label)

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
				prompt_label.text = "[R] Select seed"
			else:
				prompt_label.text = "[E] Plant   [R] Next seed"
		elif state == 2:  # READY
			prompt_label.text = "[E] Harvest"
		else:  # PLANTED
			prompt_label.text = "Growing..."
		return

	# Animal — check animal_instance_id
	if target.get("animal_instance_id") != null:
		var state_str: String = String(target.get("current_state"))
		if state_str == "product_ready" or state_str == "end_of_life":
			prompt_label.text = "[E] Collect"
		else:
			prompt_label.text = "[E] Check"
		return

	# Aquaculture container — check container_id + aquaculture_id
	if target.get("container_id") != null and target.get("aquaculture_id") != null:
		var state_str: String = String(target.get("current_state"))
		if state_str == "empty":
			prompt_label.text = "[E] Start"
		elif state_str == "ready":
			prompt_label.text = "[E] Harvest"
		else:
			prompt_label.text = "Growing..."
		return

	# Restaurant — check for restaurant_interacted signal
	if target.has_signal("restaurant_interacted"):
		prompt_label.text = "[E] Restaurant"
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
