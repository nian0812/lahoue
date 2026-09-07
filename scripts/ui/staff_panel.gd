extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var staff_container: VBoxContainer
var hire_container: VBoxContainer
var split_container: HSplitContainer
var header_lbl: Label
var payroll_button: Button

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
	header.add_child(ui_style.make_icon_slot("staff"))

	var title: Label = Label.new()
	title.text = "STAFF MANAGEMENT"
	title.theme_type_variation = &"PanelTitle"
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	header_lbl = Label.new()
	vbox.add_child(header_lbl)
	payroll_button = Button.new()
	payroll_button.pressed.connect(_on_payroll_pressed)
	vbox.add_child(payroll_button)

	split_container = HSplitContainer.new()
	split_container.name = "split"
	split_container.size_flags_vertical = SIZE_EXPAND_FILL
	split_container.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(split_container)

	# Left side: Hired Staff
	var staff_vbox: VBoxContainer = VBoxContainer.new()
	staff_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split_container.add_child(staff_vbox)

	var t_title: Label = Label.new()
	t_title.text = "Hired Staff"
	t_title.theme_type_variation = &"SectionTitle"
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
	o_title.theme_type_variation = &"SectionTitle"
	right_vbox.add_child(o_title)

	var hire_scroll: ScrollContainer = ScrollContainer.new()
	hire_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_child(hire_scroll)

	hire_container = VBoxContainer.new()
	hire_container.size_flags_horizontal = SIZE_EXPAND_FILL
	hire_container.add_theme_constant_override("separation", 8)
	hire_scroll.add_child(hire_container)


func _on_close_pressed() -> void:
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.has_method("_close_active_panel"):
		ui_manager.call("_close_active_panel")
	else:
		visible = false


func _refresh_data() -> void:
	var main_world: Node = get_tree().current_scene
	if not main_world: return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if not rest: return

	if not rest.call("is_available"):
		header_lbl.text = "Staff — Locked\nRestaurant must be purchased first."
		header_lbl.theme_type_variation = &"StatusLocked"
		if split_container: split_container.visible = false
		payroll_button.visible = false
		return
	else:
		var daily_payroll: int = int(rest.call("get_staff_daily_payroll"))
		var outstanding_debt: int = int(rest.call("get_staff_outstanding_debt"))
		header_lbl.text = "Daily Payroll: %s | Outstanding: %s" % [vnd_format.format_vnd(daily_payroll), vnd_format.format_vnd(outstanding_debt)]
		header_lbl.theme_type_variation = &"StatusWarning" if outstanding_debt > 0 else &"StatusInfo"
		if split_container: split_container.visible = true
		payroll_button.visible = outstanding_debt > 0
		payroll_button.text = "Pay Outstanding Staff Debt — %s" % vnd_format.format_vnd(outstanding_debt)
		payroll_button.disabled = outstanding_debt <= 0 or not game_manager.can_afford(outstanding_debt)

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

		var debt: int = maxi(int(staff.get("salary_debt")), 0)
		var row: PanelContainer = ui_style.make_card(&"WarningCard" if debt > 0 else &"Card")

		var vbox: VBoxContainer = VBoxContainer.new()
		row.add_child(vbox)

		var name_lbl: Label = Label.new()
		var salary: int = data_manager.get_staff_daily_salary(type_id)
		name_lbl.text = "Role: %s (#%s) — %s/day" % [type_id.replace("_", " ").capitalize(), sid.right(4), vnd_format.format_vnd(salary)]
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
	var main_world: Node = get_tree().current_scene
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
				var txt: String = _get_staff_status_text(state, job)
				if state != "idle" and not job.is_empty():
					var t_id: String = String(job.get("target_id", ""))
					if t_id != "":
						txt += " -> %s" % t_id.trim_prefix("customer_").left(12)
				var debt: int = maxi(int(staff.get("salary_debt")), 0)
				if debt > 0 or not bool(staff.get("is_paid")):
					lbl.text = "Unpaid — Debt: %s" % vnd_format.format_vnd(debt)
					lbl.theme_type_variation = &"StatusWarning"
				elif state == "idle":
					lbl.text = "Idle"
					lbl.theme_type_variation = &"StatusInfo"
				elif state == "off_duty":
					lbl.text = "Off Duty"
					lbl.theme_type_variation = &"StatusLocked"
				else:
					lbl.text = "Working — %s" % txt
					lbl.theme_type_variation = &"StatusSuccess"


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
		var salary: int = data_manager.get_staff_daily_salary(type_id)
		var max_count: int = int(data.get("max_count", 0))
		var hired_count: int = int(rest.call("get_staff_type_count", type_id))

		var row: PanelContainer = ui_style.make_card()

		var vbox: VBoxContainer = VBoxContainer.new()
		row.add_child(vbox)

		var hbox_top: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_top)

		var name_lbl: Label = Label.new()
		name_lbl.text = type_id.replace("_", " ").capitalize()
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)

		var cost_lbl: Label = Label.new()
		cost_lbl.text = "Hire: %s" % vnd_format.format_vnd(cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox_top.add_child(cost_lbl)

		var hbox_bottom: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_bottom)

		var jobs: Array = data.get("allowed_jobs", [])
		var jobs_str: String = ""
		for j: Variant in jobs:
			jobs_str += _get_job_display_name(String(j)) + ", "
		jobs_str = jobs_str.trim_suffix(", ")

		var desc_lbl: Label = Label.new()
		desc_lbl.text = "Can: %s | Salary: %s/day | Hired: %d/%d" % [jobs_str, vnd_format.format_vnd(salary), hired_count, max_count]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		desc_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_bottom.add_child(desc_lbl)

		var hire_btn: Button = Button.new()
		hire_btn.text = "Hire"

		var can_afford: bool = game_manager.money >= cost
		var level_ok: bool = game_manager.level >= req_lvl

		if max_count > 0 and hired_count >= max_count:
			hire_btn.disabled = true
			hire_btn.text = "Max"
			row.modulate = Color(1, 1, 1, 0.5)
		elif not level_ok:
			hire_btn.disabled = true
			hire_btn.text = "Requires Level %d" % req_lvl
			row.theme_type_variation = &"WarningCard"
		elif not can_afford:
			hire_btn.disabled = true
			hire_btn.text = "Not Enough Money"
			cost_lbl.theme_type_variation = &"StatusWarning"

		hire_btn.pressed.connect(_on_hire_pressed.bind(type_id, rest))
		hbox_bottom.add_child(hire_btn)

		hire_container.add_child(row)


func _get_job_display_name(job_type: String) -> String:
	match job_type:
		"cook":
			return "Cook"
		"serve":
			return "Serve"
		"payment":
			return "Payment"
		"clean":
			return "Clean"
		"harvest":
			return "Harvest Crops"
		"collect_animal":
			return "Collect Animal Products"
		"collect_aquaculture":
			return "Collect & Restart Aquaculture"
	return job_type.capitalize()


func _get_staff_status_text(state: String, job: Dictionary) -> String:
	var job_type: String = String(job.get("job_type", ""))
	match state:
		"idle":
			return "Idle"
		"moving":
			return "Moving to %s" % _get_job_display_name(job_type)
		"handling_order":
			return "Collecting Payment" if job_type == "payment" else "Cooking"
		"delivering_food":
			return "Serving"
		"cleaning_table":
			return "Cleaning"
		"harvesting":
			return "Harvesting"
		"collecting":
			return (
				"Collecting Animal Products"
				if job_type == "collect_animal"
				else "Collecting & Restarting Aquaculture"
			)
		"returning":
			return "Returning"
		"off_duty":
			return "OFF DUTY — salary unpaid"
	return state.capitalize()


func _on_hire_pressed(type_id: String, rest: Node) -> void:
	var new_id: String = "%s_%d" % [type_id, Time.get_ticks_msec()]
	var staff: Node = rest.call("hire_staff", new_id, type_id)
	if staff != null:
		refresh()


func _on_payroll_pressed() -> void:
	var main_world: Node = get_tree().current_scene
	if main_world == null:
		return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if rest != null:
		rest.call("pay_staff_debts")
		refresh()
