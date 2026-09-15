extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var tab_container: TabContainer
var seeds_container: VBoxContainer
var animals_container: VBoxContainer


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_seeds()
	_refresh_animals()


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
	header.add_child(ui_style.make_icon_slot("crop"))

	var title: Label = Label.new()
	title.text = "SHOP"
	title.theme_type_variation = &"PanelTitle"
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	# Seeds Tab
	var scroll_seeds: ScrollContainer = ScrollContainer.new()
	scroll_seeds.name = "Seeds"
	scroll_seeds.custom_minimum_size = Vector2(0, 180)
	tab_container.add_child(scroll_seeds)

	var margin_seeds: MarginContainer = MarginContainer.new()
	margin_seeds.add_theme_constant_override("margin_top", 8)
	margin_seeds.add_theme_constant_override("margin_bottom", 8)
	margin_seeds.add_theme_constant_override("margin_left", 8)
	margin_seeds.add_theme_constant_override("margin_right", 8)
	margin_seeds.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_seeds.add_child(margin_seeds)

	seeds_container = VBoxContainer.new()
	seeds_container.add_theme_constant_override("separation", 8)
	seeds_container.size_flags_horizontal = SIZE_EXPAND_FILL
	margin_seeds.add_child(seeds_container)

	# Animals Tab
	var scroll_animals: ScrollContainer = ScrollContainer.new()
	scroll_animals.name = "Animals"
	scroll_animals.custom_minimum_size = Vector2(0, 180)
	tab_container.add_child(scroll_animals)

	var margin_animals: MarginContainer = MarginContainer.new()
	margin_animals.add_theme_constant_override("margin_top", 8)
	margin_animals.add_theme_constant_override("margin_bottom", 8)
	margin_animals.add_theme_constant_override("margin_left", 8)
	margin_animals.add_theme_constant_override("margin_right", 8)
	margin_animals.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_animals.add_child(margin_animals)

	animals_container = VBoxContainer.new()
	animals_container.add_theme_constant_override("separation", 8)
	animals_container.size_flags_horizontal = SIZE_EXPAND_FILL
	margin_animals.add_child(animals_container)


func _on_close_pressed() -> void:
	var ui_manager: Node = get_parent()
	if ui_manager and ui_manager.has_method("_close_active_panel"):
		ui_manager.call("_close_active_panel")
	else:
		visible = false


func _refresh_seeds() -> void:
	for child in seeds_container.get_children():
		child.queue_free()

	var crops_dataset: Dictionary = data_manager.get_dataset("crops")
	var entries: Dictionary = crops_dataset.get("entries", {})
	var seed_ids: Array[String] = []

	for crop_id_value: Variant in entries:
		var data: Dictionary = entries[crop_id_value] as Dictionary
		var seed_item: String = String(data.get("seed_item", ""))
		if not seed_item.is_empty() and not seed_ids.has(seed_item):
			seed_ids.append(seed_item)

	seed_ids.sort()

	for seed_id: String in seed_ids:
		var row: PanelContainer = ui_style.make_card()

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		row.add_child(hbox)
		hbox.add_child(ui_style.make_item_icon_slot(seed_id, "planting", true))

		var buy_price: int = data_manager.get_item_buy_price(seed_id)
		var req_level: int = data_manager.get_item_required_level(seed_id)
		var owned: int = inventory_manager.get_amount(seed_id)

		var can_afford: bool = game_manager.money >= buy_price
		var level_ok: bool = game_manager.level >= req_level
		var has_cap: bool = inventory_manager.can_add(1)

		var name_lbl: Label = Label.new()
		name_lbl.text = vnd_format.format_item_name(seed_id)
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var own_lbl: Label = Label.new()
		own_lbl.text = "Owned: %d" % owned
		own_lbl.custom_minimum_size = Vector2(80, 0)
		own_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(own_lbl)

		var price_lbl: Label = Label.new()
		price_lbl.text = vnd_format.format_vnd(buy_price)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not can_afford:
			price_lbl.modulate = Color(0.8, 0.3, 0.3)
		hbox.add_child(price_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(60, 0)

		if not level_ok:
			buy_btn.disabled = true
			buy_btn.text = "Requires Level %d" % req_level
			row.theme_type_variation = &"WarningCard"
		elif not can_afford:
			buy_btn.disabled = true
			buy_btn.text = "Not Enough Money"
		elif not has_cap:
			buy_btn.disabled = true
			buy_btn.text = "Warehouse Full"

		buy_btn.pressed.connect(_on_buy_seed.bind(seed_id))
		hbox.add_child(buy_btn)

		row.mouse_entered.connect(func() -> void:
			row.modulate = Color(1.2, 1.2, 1.2)
			var t_data: Dictionary = {"title": vnd_format.format_item_name(seed_id), "description": "Category: Seed"}
			if buy_price > 0:
				t_data["cost"] = vnd_format.format_vnd(buy_price)
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

		seeds_container.add_child(row)


func _on_buy_seed(seed_id: String) -> void:
	if inventory_manager.purchase_seed(seed_id, 1):
		refresh() # Update buttons state
	else:
		var ui_manager: Node = get_parent()
		if ui_manager and ui_manager.get("notification_node") != null:
			if not inventory_manager.can_add(1):
				ui_manager.get("notification_node").call("show_notification", "Inventory Full!", "error")
			elif game_manager.money < data_manager.get_item_buy_price(seed_id):
				ui_manager.get("notification_node").call("show_notification", "Not Enough Money", "warning")


func _refresh_animals() -> void:
	for child in animals_container.get_children():
		child.queue_free()

	var animals_dataset: Dictionary = data_manager.get_dataset("animals")
	var entries: Dictionary = animals_dataset.get("entries", {})
	var animal_ids: Array[String] = []

	for animal_id_value: Variant in entries:
		animal_ids.append(String(animal_id_value))

	animal_ids.sort()

	for animal_id: String in animal_ids:
		var row: PanelContainer = ui_style.make_card()

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		row.add_child(hbox)

		var animal_data: Dictionary = entries[animal_id] as Dictionary
		var buy_price: int = int(animal_data.get("purchase_price", 0))
		var req_level: int = data_manager.get_animal_required_level(animal_id)
		var housing_id: String = String(animal_data.get("housing", ""))

		# We must use get_node("/root/main_world") to check housing
		var main_world: Node = get_tree().root.get_node_or_null("main_world")

		var can_afford: bool = game_manager.money >= buy_price
		var level_ok: bool = game_manager.level >= req_level
		var has_cap: bool = false
		var curr_count: int = 0
		var max_cap: int = 0
		var owned_count: int = 0

		if main_world and main_world.has_method("_get_animal_housing_count"):
			curr_count = main_world.call("_get_animal_housing_count", housing_id)
			max_cap = data_manager.get_animal_housing_capacity(housing_id, main_world.call("get_upgrade_level", housing_id))
			has_cap = curr_count < max_cap
			owned_count = main_world.call("_get_owned_animal_count", animal_id)

		var housing_name: String = "Coop" if housing_id == "coop" else "Pig Pen" if housing_id == "pig_pen" else "Cow Barn" if housing_id == "cow_barn" else "Housing"
		var icon_kind: String = "layer_chicken" if animal_id == "chicken" else "meat_chicken" if animal_id == "meat_chicken" else "animal"
		hbox.add_child(ui_style.make_icon_slot(icon_kind, true))

		var name_lbl: Label = Label.new()
		name_lbl.text = String(animal_data.get("display_name", animal_id.replace("_", " ").capitalize()))
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var cap_lbl: Label = Label.new()
		var product_id: String = String(animal_data.get("primary_product", ""))
		cap_lbl.text = "Product: %s | Owned: %d | %s: %d/%d" % [data_manager.get_item_display_name(product_id), owned_count, housing_name, curr_count, max_cap]
		cap_lbl.custom_minimum_size = Vector2(280, 0)
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(cap_lbl)

		var price_lbl: Label = Label.new()
		price_lbl.text = vnd_format.format_vnd(buy_price)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not can_afford:
			price_lbl.modulate = Color(0.8, 0.3, 0.3)
		hbox.add_child(price_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(60, 0)

		if not level_ok:
			buy_btn.disabled = true
			buy_btn.text = "Requires Level %d" % req_level
			row.theme_type_variation = &"WarningCard"
		elif not can_afford:
			buy_btn.disabled = true
			buy_btn.text = "Not Enough Money"
		elif not has_cap:
			buy_btn.disabled = true
			buy_btn.text = "%s Full" % housing_name

		buy_btn.pressed.connect(_on_buy_animal.bind(animal_id))
		hbox.add_child(buy_btn)

		animals_container.add_child(row)


func _on_buy_animal(animal_id: String) -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world:
		return

	var instance_id: String = "%s_%d" % [animal_id, Time.get_ticks_msec()]
	var spawn_pos: Vector2 = Vector2.ZERO
	# Use player position if available
	var player: Node2D = main_world.get_node_or_null("player") as Node2D
	if player:
		spawn_pos = player.position

	var animal: Node = main_world.call("purchase_animal", instance_id, animal_id, spawn_pos) as Node
	if animal != null:
		var ui_manager: Node = get_parent()
		if ui_manager and ui_manager.get("notification_node") != null:
			ui_manager.get("notification_node").call("show_notification", "Purchased %s" % vnd_format.format_item_name(animal_id), "success")
		refresh()
	else:
		var ui_manager: Node = get_parent()
		if ui_manager and ui_manager.get("notification_node") != null:
			ui_manager.get("notification_node").call("show_notification", "Cannot purchase animal", "error")
