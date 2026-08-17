extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var list_container: VBoxContainer


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_data()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(600, 400)
	vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(list_container)


func _on_close_pressed() -> void:
	visible = false
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.get("active_panel") == self:
		ui_manager.set("active_panel", null)


func _refresh_data() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world: return
	var tracker: Node = main_world.get_node_or_null("achievement_tracker")
	if not tracker: return

	var defs: Dictionary = tracker.get("definitions")
	var states: Dictionary = tracker.get("achievement_states")

	if defs.is_empty():
		var empty: Label = Label.new()
		empty.text = "No achievements available."
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty)
		return

	var a_ids: Array = defs.keys()
	a_ids.sort()

	for a_id: String in a_ids:
		var def: Dictionary = defs[a_id]
		var state: Dictionary = states.get(a_id, {})

		var a_name: String = String(def.get("name", a_id))
		var a_desc: String = String(def.get("description", ""))
		var condition: Dictionary = def.get("condition", {})
		var target: int = int(condition.get("target", 1))

		var reward_raw: Variant = def.get("reward")
		var reward: Dictionary = reward_raw as Dictionary if typeof(reward_raw) == TYPE_DICTIONARY else {}

		var progress: int = int(state.get("progress", 0))
		var is_unlocked: bool = bool(state.get("unlocked", false))
		var is_claimed: bool = bool(state.get("reward_claimed", false))

		var row: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.06, 0.4)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", style)

		if is_unlocked:
			row.modulate = Color(1, 1, 1)
		else:
			row.modulate = Color(1, 1, 1, 0.6)

		var vbox: VBoxContainer = VBoxContainer.new()
		row.add_child(vbox)

		var hbox_top: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_top)

		var name_lbl: Label = Label.new()
		name_lbl.text = a_name
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)

		var status_lbl: Label = Label.new()
		if is_claimed:
			status_lbl.text = "Completed"
			status_lbl.modulate = Color(0.4, 0.8, 0.4)
		elif is_unlocked:
			status_lbl.text = "Unlocked"
			status_lbl.modulate = Color(0.8, 0.8, 0.4)
		else:
			status_lbl.text = "Locked"
			status_lbl.modulate = Color(0.8, 0.3, 0.3)
		hbox_top.add_child(status_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = a_desc
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(desc_lbl)

		var hbox_bottom: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_bottom)

		var pb: ProgressBar = ProgressBar.new()
		pb.size_flags_horizontal = SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(0, 14)
		pb.max_value = target
		pb.value = progress
		pb.show_percentage = false
		hbox_bottom.add_child(pb)

		var prog_lbl: Label = Label.new()
		prog_lbl.text = " %d / %d" % [progress, target]
		prog_lbl.add_theme_font_size_override("font_size", 14)
		hbox_bottom.add_child(prog_lbl)

		# If reward exists, display it
		if not reward.is_empty():
			var r_lbl: Label = Label.new()
			var r_type: String = String(reward.get("type", ""))
			var r_amt: int = int(reward.get("amount", 0))
			if r_type == "money":
				r_lbl.text = "  Reward: %s" % vnd_format.format(r_amt)
			elif r_type == "exp":
				r_lbl.text = "  Reward: +%d EXP" % r_amt
			elif r_type == "item":
				var item_id: String = String(reward.get("item_id", ""))
				r_lbl.text = "  Reward: %s x%d" % [vnd_format.format_item_name(item_id), r_amt]
			else:
				r_lbl.text = "  Reward: %s x%d" % [r_type, r_amt]
			r_lbl.add_theme_font_size_override("font_size", 14)
			r_lbl.modulate = Color(0.8, 0.7, 0.4)
			hbox_bottom.add_child(r_lbl)
		else:
			var lbl: Label = Label.new()
			lbl.text = "Incomplete"
			lbl.modulate = Color(0.8, 0.4, 0.4)
			hbox_bottom.add_child(lbl)

		row.mouse_entered.connect(func() -> void:
			row.modulate = Color(1.2, 1.2, 1.2)
			var t_data: Dictionary = {"title": "Achievement", "description": a_desc}
			var ui: Node = get_parent()
			if ui and ui.has_method("show_tooltip"):
				ui.call("show_tooltip", t_data, row.global_position)
		)
		row.mouse_exited.connect(func() -> void:
			row.modulate = Color.WHITE
			var ui: Node = get_parent()
			if ui and ui.has_method("hide_tooltip"):
				ui.call("hide_tooltip")
		)

		list_container.add_child(row)
