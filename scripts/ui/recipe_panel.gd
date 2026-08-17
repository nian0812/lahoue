extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var list_container: VBoxContainer


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_recipes()


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
	title.text = "RECIPES"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(500, 350)
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


func _refresh_recipes() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var recipes_dataset: Dictionary = data_manager.get_dataset("recipes")
	var entries: Dictionary = recipes_dataset.get("entries", {})
	var recipe_ids: Array[String] = []

	for recipe_id_value: Variant in entries:
		recipe_ids.append(String(recipe_id_value))

	recipe_ids.sort()

	for recipe_id: String in recipe_ids:
		var recipe_data: Dictionary = entries[recipe_id] as Dictionary
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
		var r_name: String = String(recipe_data.get("name", recipe_id))
		name_lbl.text = r_name.capitalize()
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)

		var price: int = int(recipe_data.get("selling_price", 0))
		var price_lbl: Label = Label.new()
		price_lbl.text = vnd_format.format(price)
		price_lbl.modulate = Color(0.8, 0.7, 0.4)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox_top.add_child(price_lbl)
		
		var req_level: int = 1
		var req_lvl_val: Variant = recipe_data.get("required_level")
		if typeof(req_lvl_val) == TYPE_INT or typeof(req_lvl_val) == TYPE_FLOAT:
			req_level = int(req_lvl_val)
			
		var unlock_level: int = data_manager.get_restaurant_unlock_level()
		req_level = maxi(req_level, unlock_level)

		if game_manager.level < req_level:
			row.modulate = Color(1, 1, 1, 0.5)
			var lock_lbl: Label = Label.new()
			lock_lbl.text = "(Lv %d)" % req_level
			lock_lbl.modulate = Color(0.8, 0.3, 0.3)
			hbox_top.add_child(lock_lbl)

		var hbox_bottom: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_bottom)

		var ingredients: Variant = recipe_data.get("ingredients")
		if typeof(ingredients) == TYPE_DICTIONARY:
			var ingr_dict: Dictionary = ingredients as Dictionary
			var parts: PackedStringArray = []
			for ing_id: Variant in ingr_dict:
				var amount: int = int(ingr_dict[ing_id])
				var ok: bool = inventory_manager.has_item(String(ing_id), amount)
				var symbol: String = "✔" if ok else "✘"
				parts.append("%s %s x%d" % [symbol, vnd_format.format_item_name(String(ing_id)), amount])
			
			var ingr_lbl: Label = Label.new()
			ingr_lbl.text = ", ".join(parts)
			ingr_lbl.add_theme_font_size_override("font_size", 12)
			ingr_lbl.modulate = Color(0.8, 0.8, 0.8)
			hbox_bottom.add_child(ingr_lbl)
		else:
			var no_ingr: Label = Label.new()
			no_ingr.text = "Incomplete Data"
			no_ingr.add_theme_font_size_override("font_size", 12)
			no_ingr.modulate = Color(0.8, 0.3, 0.3)
			hbox_bottom.add_child(no_ingr)

		list_container.add_child(row)
