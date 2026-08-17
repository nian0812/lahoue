extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var item_list_container: VBoxContainer
var capacity_label: Label
var capacity_bar: ProgressBar
var current_filter: String = "all"
var filter_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	inventory_manager.capacity_changed.connect(_on_capacity_changed)


func refresh() -> void:
	_refresh_list()
	var cap: int = inventory_manager.get_capacity()
	var used: int = inventory_manager.get_used_capacity()
	_on_capacity_changed(used, cap)


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

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Filters
	var filter_hbox: HBoxContainer = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(filter_hbox)

	_add_filter_tab(filter_hbox, "All", "all")
	_add_filter_tab(filter_hbox, "Seeds", "seed")
	_add_filter_tab(filter_hbox, "Crops", "farm")
	_add_filter_tab(filter_hbox, "Animal", "animal_products")
	_add_filter_tab(filter_hbox, "Seafood", "seafood")
	_add_filter_tab(filter_hbox, "Other", "other")

	var divider: HSeparator = HSeparator.new()
	vbox.add_child(divider)

	# Scroll area
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(500, 300)
	vbox.add_child(scroll)

	item_list_container = VBoxContainer.new()
	item_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	item_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(item_list_container)

	# Footer / Capacity
	var footer: HBoxContainer = HBoxContainer.new()
	vbox.add_child(footer)

	capacity_label = Label.new()
	capacity_label.text = "Capacity: 0/0"
	capacity_label.add_theme_font_size_override("font_size", 14)
	footer.add_child(capacity_label)

	capacity_bar = ProgressBar.new()
	capacity_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	capacity_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	capacity_bar.custom_minimum_size = Vector2(0, 14)
	capacity_bar.show_percentage = false
	footer.add_child(capacity_bar)


func _add_filter_tab(parent: Control, label: String, filter_id: String) -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.pressed.connect(_on_filter_selected.bind(filter_id))
	parent.add_child(btn)
	filter_buttons[filter_id] = btn
	if filter_id == current_filter:
		btn.button_pressed = true


func _on_filter_selected(filter_id: String) -> void:
	current_filter = filter_id
	for fid: String in filter_buttons:
		var btn: Button = filter_buttons[fid] as Button
		btn.set_pressed_no_signal(fid == current_filter)
	_refresh_list()


func _on_close_pressed() -> void:
	visible = false
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.get("active_panel") == self:
		ui_manager.set("active_panel", null)


func _on_inventory_changed(_items: Dictionary) -> void:
	if visible:
		_refresh_list()


func _on_capacity_changed(current: int, maximum: int) -> void:
	if not visible:
		return
	capacity_label.text = "Capacity: %d / %d" % [current, maximum]
	capacity_bar.max_value = maximum
	capacity_bar.value = current
	if current >= maximum:
		capacity_bar.modulate = Color(0.8, 0.3, 0.3)
	elif current >= maximum * 0.8:
		capacity_bar.modulate = Color(0.8, 0.6, 0.3)
	else:
		capacity_bar.modulate = Color.WHITE


func _refresh_list() -> void:
	for child in item_list_container.get_children():
		child.queue_free()

	var items: Dictionary = inventory_manager.items
	if items.is_empty():
		_add_empty_message("Inventory is empty.")
		return

	var has_items: bool = false
	var item_ids: Array = items.keys()
	item_ids.sort()

	for item_id_value: Variant in item_ids:
		var item_id: String = String(item_id_value)
		var amount: int = int(items[item_id_value])
		if amount <= 0:
			continue

		var item_data_variant: Variant = data_manager.get_entry("items", item_id)
		if typeof(item_data_variant) != TYPE_DICTIONARY:
			continue

		var item_data: Dictionary = item_data_variant as Dictionary
		var category: String = String(item_data.get("category", "other"))

		# Map unknown categories to 'other'
		if not ["seed", "farm", "animal_products", "seafood"].has(category):
			category = "other"

		if current_filter != "all" and category != current_filter:
			continue

		_add_item_row(item_id, amount, item_data)
		has_items = true

	if not has_items:
		_add_empty_message("No items found in this category.")


func _add_empty_message(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1, 1, 1, 0.5)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_child(lbl)
	item_list_container.add_child(margin)


func _add_item_row(item_id: String, amount: int, item_data: Dictionary) -> void:
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
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = vnd_format.format_item_name(item_id)
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var qty_lbl: Label = Label.new()
	qty_lbl.text = "x%d" % amount
	qty_lbl.custom_minimum_size = Vector2(60, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(qty_lbl)

	var price: int = data_manager.get_item_sell_price(item_id)
	if price > 0:
		var price_lbl: Label = Label.new()
		price_lbl.text = vnd_format.format(price)
		price_lbl.modulate = Color(0.8, 0.7, 0.4)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(price_lbl)

		var sell_btn: Button = Button.new()
		sell_btn.text = "Sell 1"
		sell_btn.custom_minimum_size = Vector2(70, 0)
		sell_btn.pressed.connect(func() -> void: inventory_manager.sell_item(item_id, 1))
		hbox.add_child(sell_btn)

		var sell_all_btn: Button = Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.custom_minimum_size = Vector2(80, 0)
		sell_all_btn.pressed.connect(func() -> void: inventory_manager.sell_item(item_id, inventory_manager.get_amount(item_id)))
		hbox.add_child(sell_all_btn)
	else:
		var no_sell: Label = Label.new()
		no_sell.text = "Cannot sell"
		no_sell.modulate = Color(1, 1, 1, 0.4)
		no_sell.custom_minimum_size = Vector2(166, 0)
		no_sell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(no_sell)

	item_list_container.add_child(row)
