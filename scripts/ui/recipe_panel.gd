extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

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
	header.add_child(ui_style.make_icon_slot("premium"))

	var title: Label = Label.new()
	title.text = "RECIPES"
	title.theme_type_variation = &"PanelTitle"
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(list_container)


func _on_close_pressed() -> void:
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.has_method("_close_active_panel"):
		ui_manager.call("_close_active_panel")
	else:
		visible = false


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
		var is_premium: bool = String(recipe_data.get("category", "")) == "premium"
		var req_level: int = 1
		var req_lvl_val: Variant = recipe_data.get("required_level")
		if typeof(req_lvl_val) == TYPE_INT or typeof(req_lvl_val) == TYPE_FLOAT:
			req_level = int(req_lvl_val)
		req_level = maxi(req_level, data_manager.get_restaurant_unlock_level())
		var is_locked: bool = game_manager.level < req_level
		var card_variation: StringName = &"WarningCard" if is_locked else (&"PremiumCard" if is_premium else &"Card")
		var row: PanelContainer = ui_style.make_card(card_variation)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(vbox)

		var hbox_top: HBoxContainer = HBoxContainer.new()
		vbox.add_child(hbox_top)
		hbox_top.add_child(ui_style.make_dish_icon_slot(recipe_id, true))

		var name_lbl: Label = Label.new()
		var r_name: String = String(recipe_data.get("name", recipe_id))
		name_lbl.text = r_name if r_name != r_name.to_lower() else r_name.capitalize()
		name_lbl.theme_type_variation = &"SectionTitle"
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)
		if is_premium:
			var badge: Label = Label.new()
			badge.text = "LAHOUE EMPIRE • PREMIUM" if recipe_id == "royal_seafood_platter" else "PREMIUM"
			badge.theme_type_variation = &"Premium"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hbox_top.add_child(badge)

		var meta_row: HBoxContainer = HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 16)
		vbox.add_child(meta_row)
		var price: int = int(recipe_data.get("selling_price", 0))
		var price_lbl: Label = Label.new()
		var world: Node = get_tree().current_scene
		var payout_multiplier: float = float(world.call("get_recipe_payout_multiplier", recipe_id)) if world != null and world.has_method("get_recipe_payout_multiplier") else 1.0
		price_lbl.text = "Serve: %s" % vnd_format.format_vnd(roundi(float(price) * payout_multiplier))
		price_lbl.theme_type_variation = &"Premium" if is_premium else &"StatusInfo"
		price_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		meta_row.add_child(price_lbl)

		var level_lbl: Label = Label.new()
		level_lbl.custom_minimum_size = Vector2(150.0, 0.0)
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_locked:
			level_lbl.text = "Requires Level %d • Locked" % req_level
			level_lbl.theme_type_variation = &"StatusLocked"
		else:
			level_lbl.text = "Required Level %d • Available" % req_level
			level_lbl.theme_type_variation = &"StatusSuccess"
		meta_row.add_child(level_lbl)

		var ingredients_title: Label = Label.new()
		ingredients_title.text = "Ingredients"
		ingredients_title.theme_type_variation = &"Muted"
		vbox.add_child(ingredients_title)
		var ingredients_list: VBoxContainer = VBoxContainer.new()
		ingredients_list.add_theme_constant_override("separation", 2)
		ingredients_list.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_child(ingredients_list)

		var ingredients: Variant = recipe_data.get("ingredients")
		if typeof(ingredients) == TYPE_DICTIONARY:
			var ingr_dict: Dictionary = ingredients as Dictionary
			for ing_id: Variant in ingr_dict:
				var amount: int = int(ingr_dict[ing_id])
				var owned: int = inventory_manager.get_amount(String(ing_id))
				var ok: bool = owned >= amount
				var symbol: String = "✔" if ok else "✘"
				var ingredient_label: Label = Label.new()
				ingredient_label.text = "%s %s x%d • Owned %d/%d" % [symbol, data_manager.get_item_display_name(String(ing_id)), amount, owned, amount]
				ingredient_label.add_theme_font_size_override("font_size", 12)
				ingredient_label.theme_type_variation = &"StatusSuccess" if ok else &"StatusWarning"
				ingredient_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ingredient_label.size_flags_horizontal = SIZE_EXPAND_FILL
				ingredients_list.add_child(ingredient_label)
		else:
			var no_ingr: Label = Label.new()
			no_ingr.text = "Incomplete Data"
			no_ingr.add_theme_font_size_override("font_size", 12)
			no_ingr.theme_type_variation = &"StatusLocked"
			ingredients_list.add_child(no_ingr)

		var action_row: HBoxContainer = HBoxContainer.new()
		action_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(action_row)
		var cook_btn: Button = Button.new()
		cook_btn.text = "Cook in Restaurant"
		cook_btn.custom_minimum_size = Vector2(190.0, 36.0)
		var restaurant: Node = world.get_node_or_null("restaurant") if world != null else null
		if is_locked:
			cook_btn.disabled = true
			cook_btn.text = "Requires Level %d" % req_level
		elif restaurant == null or not bool(restaurant.call("is_available")):
			cook_btn.disabled = true
			cook_btn.text = "Restaurant Locked"
		if cook_btn.disabled:
			cook_btn.add_theme_color_override("font_disabled_color", Color(0.96, 0.91, 0.82, 1.0))
		cook_btn.pressed.connect(_on_cook_recipe_pressed)
		action_row.add_child(cook_btn)

		list_container.add_child(row)


func _on_cook_recipe_pressed() -> void:
	var ui_manager: Node = get_parent()
	if ui_manager != null and ui_manager.get("restaurant_panel") != null:
		ui_manager.call("_toggle_panel", ui_manager.get("restaurant_panel"))
