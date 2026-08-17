extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var staff_container: VBoxContainer
var hire_container: VBoxContainer
var split_container: HSplitContainer
var header_lbl: Label

func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_data()


func _process(_delta: float) -> void:
	if visible:
		# Update staff states continuously while visible, but don't rebuild the entire UI
		_update_staff_states()


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
	title.text = "STAFF MANAGEMENT"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	header_lbl = Label.new()
	vbox.add_child(header_lbl)

	split_container = HSplitContainer.new()
	split_container.name = "split"
	split_container.size_flags_vertical = SIZE_EXPAND_FILL
	split_container.custom_minimum_size = Vector2(800, 400)
	vbox.add_child(split_container)

	# Left side: Hired Staff
	var staff_vbox: VBoxContainer = VBoxContainer.new()
	staff_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split_container.add_child(staff_vbox)

	var t_title: Label = Label.new()
	t_title.text = "Hired Staff"
	t_title.add_theme_font_size_override("font_size", 18)
	staff_vbox.add_child(t_title)

	var staff_scroll: ScrollContainer = ScrollContainer.new()
	staff_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	staff_vbox.add_child(staff_scroll)

	staff_container = VBoxContainer.new()
	staff_container.size_flags_horizontal = SIZE_EXPAND_FILL
	staff_container.add_theme_constant_override("separation", 8)
	staff_scroll.add_child(staff_container)

	# Right side: Hire new staff
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split_container.add_child(right_vbox)

	var o_title: Label = Label.new()
	o_title.text = "Hire Staff"
	o_title.add_theme_font_size_override("font_size", 18)
	right_vbox.add_child(o_title)

	var hire_scroll: ScrollContainer = ScrollContainer.new()
	hire_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_child(hire_scroll)

	hire_container = VBoxContainer.new()
	hire_container.size_flags_horizontal = SIZE_EXPAND_FILL
	hire_container.add_theme_constant_override("separation", 8)
	hire_scroll.add_child(hire_container)


func _on_close_pressed() -> void:
	visible = false
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.get("active_panel") == self:
		ui_manager.set("active_panel", null)


func _refresh_data() -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world: return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if not rest: return

	if not rest.call("is_available"):
		header_lbl.text = "Restaurant is locked. Level up to unlock staff."
		header_lbl.modulate = Color(0.8, 0.3, 0.3)
		if split_container: split_container.visible = false
		return
	else:
		header_lbl.text = "Manage your restaurant staff"
		header_lbl.modulate = Color(1, 1, 1)
		if split_container: split_container.visible = true

	_refresh_hired(rest)
	_refresh_hire_options(rest)


func _refresh_hired(rest: Node) -> void:
	for child in staff_container.get_children():
		child.queue_free()

	var staffs_dict: Dictionary = rest.get("staffs_by_id")
	var s_ids: Array = staffs_dict.keys()
	s_ids.sort()

	var has_staff: bool = false
	for sid: String in s_ids:
		has_staff = true
		var staff: Node = staffs_dict[sid]
		var type_id: String = String(staff.get("staff_type_id"))

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

		var vbox: VBoxContainer = VBoxContainer.new()
		row.add_child(vbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = type_id.capitalize() + " (#%s)" % sid.right(4)
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_child(name_lbl)

		var state_lbl: Label = Label.new()
		state_lbl.name = "state_" + sid
		state_lbl.modulate = Color(0.8, 0.8, 0.8)
		state_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(state_lbl)

		staff_container.add_child(row)

	if not has_staff:
		var empty: Label = Label.new()
		empty.text = "No staff hired yet."
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		staff_container.add_child(empty)

	_update_staff_states()


func _update_staff_states() -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world: return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if not rest: return

	var staffs_dict: Dictionary = rest.get("staffs_by_id")
	for child: Node in staff_container.get_children():
		var lbls: Array[Node] = child.find_children("state_*", "Label", true, false)
		for lbl: Label in lbls:
			var sid: String = lbl.name.trim_prefix("state_")
			if staffs_dict.has(sid):
				var staff: Node = staffs_dict[sid]
				var state: String = String(staff.get("current_state"))
				var job: Dictionary = staff.get("active_job")
				var txt: String = state.capitalize()
				if state != "idle" and not job.is_empty():
					var j_type: String = String(job.get("job_type", ""))
					var t_id: String = String(job.get("target_id", ""))
					txt += " (%s" % j_type.capitalize()
					if t_id != "":
						txt += " -> %s)" % t_id.trim_prefix("customer_").left(6)
					else:
						txt += ")"
				lbl.text = txt


func _refresh_hire_options(rest: Node) -> void:
	for child in hire_container.get_children():
		child.queue_free()

	var ds: Dictionary = data_manager.get_dataset("staff")
	var entries: Dictionary = ds.get("entries", {})

	for type_id_val: Variant in entries:
		var type_id: String = String(type_id_val)
		var data: Dictionary = entries[type_id_val] as Dictionary

		var req_lvl: int = int(data.get("unlock_level", 0))
		var cost: int = data_manager.get_staff_hire_cost(type_id)

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

		var vbox: VBoxContainer = VBoxContainer.new()
		row.add_child(vbox)

		var hbox_top: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_top)

		var name_lbl: Label = Label.new()
		name_lbl.text = type_id.capitalize()
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)

		var cost_lbl: Label = Label.new()
		cost_lbl.text = vnd_format.format(cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox_top.add_child(cost_lbl)

		var hbox_bottom: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_bottom)

		var jobs: Array = data.get("allowed_jobs", [])
		var jobs_str: String = ""
		for j: Variant in jobs:
			jobs_str += String(j).capitalize() + ", "
		jobs_str = jobs_str.trim_suffix(", ")

		var desc_lbl: Label = Label.new()
		desc_lbl.text = "Can: " + jobs_str
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		desc_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_bottom.add_child(desc_lbl)

		var hire_btn: Button = Button.new()
		hire_btn.text = "Hire"

		var can_afford: bool = game_manager.money >= cost
		var level_ok: bool = game_manager.level >= req_lvl

		if not level_ok:
			hire_btn.disabled = true
			hire_btn.text = "Lv %d" % req_lvl
			row.modulate = Color(1, 1, 1, 0.5)
		elif not can_afford:
			hire_btn.disabled = true
			cost_lbl.modulate = Color(0.8, 0.3, 0.3)

		hire_btn.pressed.connect(_on_hire_pressed.bind(type_id, rest))
		hbox_bottom.add_child(hire_btn)

		hire_container.add_child(row)


func _on_hire_pressed(type_id: String, rest: Node) -> void:
	var new_id: String = "%s_%d" % [type_id, Time.get_ticks_msec()]
	var staff: Node = rest.call("hire_staff", new_id, type_id)
	if staff != null:
		refresh()
