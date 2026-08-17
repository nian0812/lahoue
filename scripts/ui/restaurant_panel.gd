extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var tables_container: VBoxContainer
var orders_container: VBoxContainer
var header_lbl: Label
var kitchen_lbl: Label


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_data()


func _process(_delta: float) -> void:
	if visible:
		_update_progress_bars()


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
	title.text = "RESTAURANT"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	header_lbl = Label.new()
	vbox.add_child(header_lbl)

	var split: HSplitContainer = HSplitContainer.new()
	split.name = "split"
	split.size_flags_vertical = SIZE_EXPAND_FILL
	split.custom_minimum_size = Vector2(800, 400)
	vbox.add_child(split)

	# Left side: Tables
	var tables_vbox: VBoxContainer = VBoxContainer.new()
	tables_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(tables_vbox)

	var t_title: Label = Label.new()
	t_title.text = "Tables Overview"
	t_title.add_theme_font_size_override("font_size", 18)
	tables_vbox.add_child(t_title)

	var tables_scroll: ScrollContainer = ScrollContainer.new()
	tables_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	tables_vbox.add_child(tables_scroll)

	tables_container = VBoxContainer.new()
	tables_container.size_flags_horizontal = SIZE_EXPAND_FILL
	tables_container.add_theme_constant_override("separation", 8)
	tables_scroll.add_child(tables_container)

	# Right side: Orders & Kitchen
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(right_vbox)

	var o_title: Label = Label.new()
	o_title.text = "Active Orders"
	o_title.add_theme_font_size_override("font_size", 18)
	right_vbox.add_child(o_title)

	var orders_scroll: ScrollContainer = ScrollContainer.new()
	orders_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_child(orders_scroll)

	orders_container = VBoxContainer.new()
	orders_container.size_flags_horizontal = SIZE_EXPAND_FILL
	orders_container.add_theme_constant_override("separation", 8)
	orders_scroll.add_child(orders_container)
	
	var div: HSeparator = HSeparator.new()
	right_vbox.add_child(div)
	
	kitchen_lbl = Label.new()
	right_vbox.add_child(kitchen_lbl)


func _on_close_pressed() -> void:
	visible = false
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.get("active_panel") == self:
		ui_manager.set("active_panel", null)


func _refresh_data() -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world:
		return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if not rest:
		return

	if not rest.call("is_available"):
		header_lbl.text = "Restaurant is locked. Level up to unlock."
		header_lbl.modulate = Color(0.8, 0.3, 0.3)
		var split: Node = get_node_or_null("MarginContainer/VBoxContainer/split")
		if split:
			split.visible = false
		kitchen_lbl.visible = false
		return
	else:
		var split: Node = get_node_or_null("MarginContainer/VBoxContainer/split")
		if split:
			split.visible = true
		kitchen_lbl.visible = true

	var r_level: int = rest.get("restaurant_level")
	var k_level: int = rest.get("kitchen_level")
	header_lbl.text = "Restaurant Lv %d | Kitchen Lv %d" % [r_level, k_level]
	header_lbl.modulate = Color(1, 1, 1)

	var slots: int = data_manager.get_kitchen_cooking_slots(k_level)
	var active_cooks: int = rest.call("_get_active_cooking_count")
	kitchen_lbl.text = "Kitchen Slots: %d / %d used" % [active_cooks, slots]

	_refresh_tables(rest)
	_refresh_orders(rest)


func _update_progress_bars() -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world: return
	var rest: Node = main_world.get_node_or_null("restaurant")
	if not rest: return
	
	var jobs: Dictionary = rest.get("cooking_jobs")
	for child: Node in orders_container.get_children():
		var pbs: Array[Node] = child.find_children("pb_*", "ProgressBar", true, false)
		for pb: ProgressBar in pbs:
			var cid: String = pb.name.trim_prefix("pb_")
			if jobs.has(cid):
				var job: Dictionary = jobs[cid]
				pb.value = float(job.get("cooking_elapsed", 0.0))


func _refresh_tables(rest: Node) -> void:
	for child in tables_container.get_children():
		child.queue_free()

	var tables_dict: Dictionary = rest.get("tables_by_id")
	var t_ids: Array = tables_dict.keys()
	t_ids.sort()

	for tid: String in t_ids:
		var tbl: Node = tables_dict[tid]
		var state: String = String(tbl.get("current_state"))
		var occ: String = String(tbl.get("occupant_id"))

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

		var hbox: HBoxContainer = HBoxContainer.new()
		row.add_child(hbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = "Table %s" % tid
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var state_lbl: Label = Label.new()
		state_lbl.text = state.capitalize()
		
		if state == "available":
			state_lbl.modulate = Color(0.4, 0.8, 0.4)
		elif state == "occupied":
			state_lbl.modulate = Color(0.8, 0.4, 0.4)
			state_lbl.text += " (%s)" % occ.trim_prefix("customer_").left(6)
		elif state == "reserved":
			state_lbl.modulate = Color(0.8, 0.8, 0.4)
		elif state == "needs_cleanup":
			state_lbl.modulate = Color(0.6, 0.4, 0.2)
			
		hbox.add_child(state_lbl)
		tables_container.add_child(row)


func _refresh_orders(rest: Node) -> void:
	for child in orders_container.get_children():
		child.queue_free()

	var cust_dict: Dictionary = rest.get("customers_by_id")
	var jobs: Dictionary = rest.get("cooking_jobs")
	var has_orders: bool = false

	for cid: String in cust_dict:
		var cust: Node = cust_dict[cid]
		var state: String = String(cust.get("current_state"))
		var order: Dictionary = cust.get("order")
		var is_waiting: bool = state == "waiting_food" and String(order.get("state", "")) == "pending"
		var is_eating: bool = state == "eating"

		if not is_waiting and not is_eating:
			continue

		var recipe_id: String = String(order.get("recipe_id", ""))
		var qty: int = int(order.get("quantity", 0))
		var r_name: String = vnd_format.format_item_name(recipe_id)

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

		var hbox: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = "Cust: #%s" % cid.trim_prefix("customer_").left(6)
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var r_lbl: Label = Label.new()
		r_lbl.text = "%s x%d" % [r_name, qty]
		hbox.add_child(r_lbl)

		var action_hbox: HBoxContainer = HBoxContainer.new()
		action_hbox.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(action_hbox)

		if is_waiting:
			if not jobs.has(cid):
				var cook_btn: Button = Button.new()
				cook_btn.text = "Cook"
				cook_btn.pressed.connect(func() -> void:
					rest.call("start_cooking", cid)
					refresh()
				)
				action_hbox.add_child(cook_btn)
			else:
				var job: Dictionary = jobs[cid]
				var j_state: String = String(job.get("state", ""))
				if j_state == "cooking":
					var pb: ProgressBar = ProgressBar.new()
					pb.name = "pb_" + cid
					pb.custom_minimum_size = Vector2(100, 14)
					pb.max_value = float(job.get("cooking_duration", 1.0))
					pb.value = float(job.get("cooking_elapsed", 0.0))
					pb.show_percentage = false
					action_hbox.add_child(pb)
				elif j_state == "ready":
					var serve_btn: Button = Button.new()
					serve_btn.text = "Serve"
					serve_btn.pressed.connect(func() -> void:
						rest.call("serve_order", cid)
						refresh()
					)
					action_hbox.add_child(serve_btn)
		elif is_eating:
			if jobs.has(cid):
				var job: Dictionary = jobs[cid]
				if String(job.get("state", "")) == "served" and not bool(job.get("payment_collected", false)):
					var col_btn: Button = Button.new()
					col_btn.text = "Collect"
					col_btn.pressed.connect(func() -> void:
						rest.call("finish_customer_meal", cid)
						refresh()
					)
					action_hbox.add_child(col_btn)

		orders_container.add_child(row)
		has_orders = true

	if not has_orders:
		var empty: Label = Label.new()
		empty.text = "No active orders."
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orders_container.add_child(empty)
