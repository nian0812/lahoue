extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var market_controller: Node = null
var locked_label: Label
var content: VBoxContainer
var item_list: VBoxContainer
var cargo_container: VBoxContainer
var helicopter_info: Label
var message_label: Label
var upgrade_button: Button
var upgrade_reason_label: Label
var cargo_draft: Dictionary = {}
var update_elapsed: float = 0.0
var last_market_state: String = ""


func _ready() -> void:
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	_build_ui()


func _process(delta: float) -> void:
	if not visible or market_controller == null:
		return
	update_elapsed += delta
	if update_elapsed >= 0.25:
		update_elapsed = 0.0
		_refresh_status()


func set_market_controller(controller: Node) -> void:
	market_controller = controller


func refresh() -> void:
	if market_controller == null:
		return
	var unlocked: bool = bool(market_controller.call("is_unlocked"))
	locked_label.visible = not unlocked
	content.visible = unlocked
	if not unlocked:
		var world: Node = market_controller.get_parent().get_parent()
		var missing: Array[String] = []
		if game_manager.level < data_manager.get_premium_market_unlock_level():
			missing.append("Requires Level %d" % data_manager.get_premium_market_unlock_level())
		if world != null and world.has_method("is_building_owned"):
			if not bool(world.call("is_building_owned", "international_license")):
				missing.append("Buy International License")
			if not bool(world.call("is_building_owned", "helipad")):
				missing.append("Buy Helipad + Helicopter")
		locked_label.text = "Premium Market locked\n%s" % "\n".join(missing)
		return
	last_market_state = String(market_controller.get("current_state"))
	_refresh_items()
	_refresh_cargo()
	_refresh_status()


func _build_ui() -> void:
	custom_minimum_size = Vector2.ZERO
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380.0
	offset_right = 380.0
	offset_top = -280.0
	offset_bottom = 280.0

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.87, 0.98)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20.0
	style.content_margin_top = 18.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 18.0
	add_theme_stylebox_override("panel", style)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	header.add_child(ui_style.make_icon_slot("helicopter"))
	var title: Label = Label.new()
	title.text = "PREMIUM & INTERNATIONAL MARKET"
	title.theme_type_variation = &"PanelTitle"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button: Button = Button.new()
	close_button.text = "Close (ESC)"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	locked_label = Label.new()
	locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_label.add_theme_font_size_override("font_size", 24)
	locked_label.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(locked_label)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(content)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(split)

	var items_scroll: ScrollContainer = ScrollContainer.new()
	items_scroll.custom_minimum_size = Vector2(350, 0)
	items_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	items_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(items_scroll)
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 5)
	items_scroll.add_child(item_list)

	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(270, 0)
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	helicopter_info = Label.new()
	helicopter_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(helicopter_info)
	upgrade_button = Button.new()
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	right.add_child(upgrade_button)
	upgrade_reason_label = Label.new()
	upgrade_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(upgrade_reason_label)
	right.add_child(HSeparator.new())
	var cargo_title: Label = Label.new()
	cargo_title.text = "Selected Import Cargo"
	cargo_title.add_theme_font_size_override("font_size", 17)
	right.add_child(cargo_title)
	cargo_container = VBoxContainer.new()
	cargo_container.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(cargo_container)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color(0.65, 0.2, 0.15))
	content.add_child(message_label)


func _refresh_items() -> void:
	for child: Node in item_list.get_children():
		child.queue_free()
	for item_id: String in market_controller.call("get_market_item_ids") as Array[String]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label: Label = Label.new()
		name_label.text = "%s • Owned: %d" % [data_manager.get_item_display_name(item_id), inventory_manager.get_amount(item_id)]
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(name_label)
		var price_label: Label = Label.new()
		price_label.text = vnd_format.format_vnd(data_manager.get_item_buy_price(item_id))
		price_label.custom_minimum_size = Vector2(110, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price_label)
		var add_button: Button = Button.new()
		add_button.text = "+1"
		add_button.pressed.connect(_on_add_pressed.bind(item_id, 1))
		row.add_child(add_button)
		var max_button: Button = Button.new()
		max_button.text = "+Max"
		max_button.pressed.connect(_on_add_max_pressed.bind(item_id))
		row.add_child(max_button)
		item_list.add_child(row)


func _refresh_cargo() -> void:
	for child: Node in cargo_container.get_children():
		child.queue_free()
	var sorted_ids: Array = cargo_draft.keys()
	sorted_ids.sort()
	if sorted_ids.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No cargo selected."
		cargo_container.add_child(empty_label)
	else:
		for item_id_value: Variant in sorted_ids:
			var item_id: String = String(item_id_value)
			var line: Label = Label.new()
			line.text = "%s x%d — %s" % [
				data_manager.get_item_display_name(item_id),
				int(cargo_draft[item_id]),
				vnd_format.format_vnd(data_manager.get_item_buy_price(item_id) * int(cargo_draft[item_id])),
			]
			cargo_container.add_child(line)
	var load: int = int(market_controller.call("get_cargo_load", cargo_draft)) if not cargo_draft.is_empty() else 0
	var total_cost: int = int(market_controller.call("calculate_import_cost", cargo_draft)) if not cargo_draft.is_empty() else 0
	var summary: Label = Label.new()
	summary.text = "Selected Import Cargo\nLoad: %d / %d\nTotal Cost: %s\nShipping Time: %ds" % [
		load,
		int(market_controller.call("get_capacity")),
		vnd_format.format_vnd(maxi(total_cost, 0)),
		int(market_controller.call("get_shipping_time")),
	]
	summary.theme_type_variation = &"Premium"
	cargo_container.add_child(summary)
	var buttons: HBoxContainer = HBoxContainer.new()
	var clear_button: Button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_on_clear_pressed)
	buttons.add_child(clear_button)
	var confirm_button: Button = Button.new()
	confirm_button.text = "Confirm Order"
	confirm_button.disabled = cargo_draft.is_empty() or String(market_controller.get("current_state")) != "ready"
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)
	cargo_container.add_child(buttons)


func _refresh_status() -> void:
	if market_controller == null or not bool(market_controller.call("is_unlocked")):
		return
	var market_state: String = String(market_controller.get("current_state"))
	if market_state != last_market_state:
		last_market_state = market_state
		_refresh_cargo()
	helicopter_info.text = "Helicopter Lv%d\nShipping: %ds\nCapacity: %d\nStatus: %s" % [
		int(market_controller.get("helicopter_level")),
		int(market_controller.call("get_shipping_time")),
		int(market_controller.call("get_capacity")),
		String(market_controller.call("get_status_text")),
	]
	var current_level: int = int(market_controller.get("helicopter_level"))
	var maximum_level: int = data_manager.get_max_helicopter_level()
	if current_level >= maximum_level:
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
		upgrade_reason_label.text = "MAX LEVEL"
		upgrade_reason_label.theme_type_variation = &"StatusSuccess"
	else:
		var cost: int = int(market_controller.call("get_upgrade_cost"))
		var current_data: Dictionary = data_manager.get_helicopter_level_data(current_level)
		var next_data: Dictionary = data_manager.get_helicopter_level_data(current_level + 1)
		upgrade_reason_label.text = "Next Lv%d: Capacity %d → %d | Shipping %ds → %ds" % [
			current_level + 1,
			int(current_data.get("capacity", 0)), int(next_data.get("capacity", 0)),
			int(current_data.get("shipping_time", 0)), int(next_data.get("shipping_time", 0)),
		]
		upgrade_reason_label.theme_type_variation = &"StatusInfo"
		upgrade_button.text = "Upgrade Lv%d — %s" % [current_level + 1, vnd_format.format_vnd(cost)]
		upgrade_button.disabled = not bool(market_controller.call("can_upgrade_helicopter"))
		if upgrade_button.disabled:
			var state: String = String(market_controller.get("current_state"))
			if state != "ready":
				upgrade_reason_label.text += "\nShipment active — upgrade unavailable"
				upgrade_reason_label.theme_type_variation = &"StatusWarning"
			elif not game_manager.can_afford(cost):
				upgrade_reason_label.text += "\nNot Enough Money"
				upgrade_reason_label.theme_type_variation = &"StatusWarning"


func _on_add_pressed(item_id: String, amount: int) -> void:
	var current_load: int = int(market_controller.call("get_cargo_load", cargo_draft)) if not cargo_draft.is_empty() else 0
	if current_load + amount > int(market_controller.call("get_capacity")):
		_set_message("Helicopter capacity full")
		return
	cargo_draft[item_id] = int(cargo_draft.get(item_id, 0)) + amount
	_set_message("")
	_refresh_cargo()


func _on_add_max_pressed(item_id: String) -> void:
	var current_load: int = int(market_controller.call("get_cargo_load", cargo_draft)) if not cargo_draft.is_empty() else 0
	var available: int = int(market_controller.call("get_capacity")) - current_load
	if available <= 0:
		_set_message("Helicopter capacity full")
		return
	_on_add_pressed(item_id, available)


func _on_clear_pressed() -> void:
	cargo_draft.clear()
	_set_message("")
	_refresh_cargo()


func _on_confirm_pressed() -> void:
	if bool(market_controller.call("confirm_order", cargo_draft)):
		cargo_draft.clear()
		_set_message("Import order confirmed")
	else:
		_set_message(String(market_controller.get("last_error")))
	refresh()


func _on_upgrade_pressed() -> void:
	if not bool(market_controller.call("upgrade_helicopter")):
		_set_message("Helicopter upgrade unavailable")
	else:
		_set_message("Helicopter upgraded")
	refresh()


func _on_close_pressed() -> void:
	var ui_manager: Node = get_parent()
	if ui_manager != null and ui_manager.has_method("_close_active_panel"):
		ui_manager.call("_close_active_panel")
	else:
		visible = false


func _set_message(value: String) -> void:
	message_label.text = value
