extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var list_container: VBoxContainer
var header_lbl: Label
var systems: Array[String] = [
	"warehouse",
	"coop",
	"pig_pen",
	"cow_barn",
	"restaurant",
	"resort",
]

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
	header.add_child(ui_style.make_icon_slot("warehouse"))

	var title: Label = Label.new()
	title.text = "UPGRADES"
	title.theme_type_variation = &"PanelTitle"
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	header_lbl = Label.new()
	header_lbl.add_theme_font_size_override("font_size", 16)
	header_lbl.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(header_lbl)

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


func _refresh_data() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var lvl: int = game_manager.level
	var current_exp: int = game_manager.current_exp
	var max_exp: int = data_manager.get_level_exp(lvl)
	if lvl < data_manager.get_max_player_level() and max_exp > 0:
		header_lbl.text = "Player Level: %d | EXP: %d / %d" % [lvl, current_exp, max_exp]
	else:
		header_lbl.text = "Player Level: %d | EXP: MAX" % lvl

	var main_world: Node = get_tree().current_scene
	if not main_world: return

	for sys_id: String in systems:
		var current_lvl: int = main_world.call("get_upgrade_level", sys_id)
		var max_lvl: int = data_manager.get_progression_max_level(sys_id)
		_build_upgrade_row(sys_id, current_lvl, max_lvl, main_world)

	_build_farm_plot_row(main_world)
	var containers_value: Variant = main_world.get("aquaculture_containers_by_id")
	if typeof(containers_value) == TYPE_DICTIONARY:
		var container_ids: Array = (containers_value as Dictionary).keys()
		container_ids.sort()
		for container_id_value: Variant in container_ids:
			_build_pond_row(main_world, String(container_id_value), (containers_value as Dictionary)[container_id_value] as Node)
	for building_id: String in ["vip_area", "international_license", "helipad"]:
		_build_special_building_row(main_world, building_id)


func _build_locked_row(sys_id: String, unlock_lvl: int) -> void:
	var row: PanelContainer = ui_style.make_card(&"WarningCard")

	var hbox: HBoxContainer = HBoxContainer.new()
	row.add_child(hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = sys_id.capitalize().replace("_", " ")
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var lock_lbl: Label = Label.new()
	lock_lbl.text = "Requires Level %d" % unlock_lvl
	lock_lbl.theme_type_variation = &"StatusLocked"
	hbox.add_child(lock_lbl)

	list_container.add_child(row)


func _build_upgrade_row(sys_id: String, current_lvl: int, max_lvl: int, main_world: Node) -> void:
	var row: PanelContainer = ui_style.make_card(&"PremiumCard" if sys_id == "resort" else &"Card")

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	row.add_child(vbox)

	var hbox_top: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox_top)

	var name_lbl: Label = Label.new()
	name_lbl.text = sys_id.capitalize().replace("_", " ")
	name_lbl.theme_type_variation = &"SectionTitle"
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox_top.add_child(name_lbl)

	var lvl_lbl: Label = Label.new()
	lvl_lbl.text = "Current Lv%d / %d" % [current_lvl, max_lvl] if max_lvl > 0 else "Current Lv%d" % current_lvl
	lvl_lbl.theme_type_variation = &"Muted"
	hbox_top.add_child(lvl_lbl)

	var current_effect: int = data_manager.get_progression_effect(sys_id, current_lvl)
	var effect_name: String = "Rooms" if sys_id == "resort" else ("Tables" if sys_id == "restaurant" else "Capacity")
	var benefit_lbl: Label = Label.new()
	benefit_lbl.theme_type_variation = &"StatusInfo"
	benefit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(benefit_lbl)
	var state_lbl: Label = Label.new()
	vbox.add_child(state_lbl)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	if current_lvl >= max_lvl:
		benefit_lbl.text = "%s: %d" % [effect_name, current_effect]
		state_lbl.text = "MAX LEVEL"
		state_lbl.theme_type_variation = &"StatusSuccess"
		list_container.add_child(row)
		return

	var target_lvl: int = current_lvl + 1
	var required_level: int = data_manager.get_system_required_player_level(sys_id, target_lvl)
	var cost: int = data_manager.get_progression_upgrade_cost(sys_id, target_lvl)
	var next_effect: int = data_manager.get_progression_effect(sys_id, target_lvl)
	benefit_lbl.text = "%s: %d → %d" % [effect_name, current_effect, next_effect]
	if sys_id == "restaurant":
		benefit_lbl.text += " | Kitchen Slots: %d → %d" % [data_manager.get_kitchen_cooking_slots(current_lvl), data_manager.get_kitchen_cooking_slots(target_lvl)]
	elif sys_id == "resort":
		var current_data: Dictionary = data_manager.get_progression_level_data(sys_id, current_lvl)
		var next_data: Dictionary = data_manager.get_progression_level_data(sys_id, target_lvl)
		benefit_lbl.text += " | Booking: %s / %ds → %s / %ds" % [
			vnd_format.format_vnd(int(current_data.get("booking_income", 0))), int(current_data.get("booking_interval", 0)),
			vnd_format.format_vnd(int(next_data.get("booking_income", 0))), int(next_data.get("booking_interval", 0)),
		]
	var can_upgrade: bool = bool(main_world.call("can_upgrade_system", sys_id))
	var reason: String = "Ready"
	if game_manager.level < required_level:
		reason = "Requires Level %d" % required_level
	elif not game_manager.can_afford(cost):
		reason = "Not Enough Money"
	elif current_lvl == 0:
		reason = "Available to Purchase"
	state_lbl.text = "%s • Required Player Level: %d" % [reason, required_level]
	state_lbl.theme_type_variation = ui_style.status_variation(reason)
	var cost_lbl: Label = Label.new()
	cost_lbl.text = "Upgrade Cost: %s" % vnd_format.format_vnd(cost)
	cost_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(cost_lbl)
	var up_btn: Button = Button.new()
	up_btn.text = "Buy" if current_lvl == 0 else "Upgrade to Lv%d" % target_lvl
	up_btn.disabled = not can_upgrade
	if up_btn.disabled:
		up_btn.add_theme_color_override("font_disabled_color", Color(0.34, 0.31, 0.27, 1.0))
	up_btn.pressed.connect(_on_upgrade_pressed.bind(sys_id, main_world))
	footer.add_child(up_btn)

	row.mouse_entered.connect(func() -> void:
		row.modulate = Color(1.2, 1.2, 1.2)
		var t_data: Dictionary = {"title": sys_id.capitalize().replace("_", " "), "description": "System Upgrade"}
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


func _build_farm_plot_row(main_world: Node) -> void:
	var purchased: int = (main_world.get("purchased_farm_plots") as Array).size()
	var maximum: int = data_manager.get_farm_plot_maximum()
	var cost: int = data_manager.get_farm_plot_purchase_cost()
	var current_limit: int = maxi(int(main_world.call("get_current_farm_plot_limit")), purchased)
	var status: String = "Farm Plots: %d/%d" % [purchased, current_limit]
	var unavailable_reason: String = ""
	if purchased >= current_limit and purchased < maximum:
		var next_level: int = int(main_world.call("get_next_farm_plot_expansion_level"))
		if next_level > 0:
			unavailable_reason = "Next expansion available at Level %d" % next_level
	_build_action_row(
		"Farm Expansion",
		status,
		cost,
		bool(main_world.call("can_purchase_farm_plot")),
		"Buy Plot",
		_on_farm_plot_pressed.bind(main_world),
		purchased >= maximum,
		unavailable_reason
	)


func _build_pond_row(main_world: Node, container_id: String, container: Node) -> void:
	if container == null:
		return
	var aquaculture_id: String = String(container.get("aquaculture_id"))
	var pond_level: int = int(main_world.call("get_pond_level", container_id))
	var unlock_level: int = data_manager.get_pond_unlock_level(aquaculture_id)
	if pond_level == 0 and game_manager.level < unlock_level:
		_build_locked_row("%s Pond" % aquaculture_id.capitalize(), unlock_level)
		return
	var max_level: int = data_manager.get_pond_max_level(aquaculture_id)
	var cost: int = (
		data_manager.get_pond_purchase_cost(aquaculture_id)
		if pond_level == 0
		else data_manager.get_pond_upgrade_cost(aquaculture_id, pond_level + 1)
	)
	var cycle_time: float = data_manager.get_pond_cycle_time(aquaculture_id, maxi(pond_level, 1))
	var next_cycle_time: float = data_manager.get_pond_cycle_time(aquaculture_id, mini(pond_level + 1, max_level))
	_build_action_row(
		"%s Pond" % aquaculture_id.capitalize(),
		"Current Lv%d / %d | Cycle %ds → %ds" % [pond_level, max_level, int(cycle_time), int(next_cycle_time)],
		cost,
		bool(main_world.call("can_upgrade_pond", container_id)),
		"Buy" if pond_level == 0 else "Upgrade",
		_on_pond_pressed.bind(container_id, main_world),
		pond_level >= max_level
	)


func _build_special_building_row(main_world: Node, building_id: String) -> void:
	var unlock_level: int = data_manager.get_building_unlock_level(building_id)
	if game_manager.level < unlock_level:
		_build_locked_row(building_id, unlock_level)
		return
	var owned: bool = bool(main_world.call("is_building_owned", building_id))
	_build_action_row(
		building_id.capitalize().replace("_", " "),
		"Owned" if owned else "Available to Purchase",
		data_manager.get_building_purchase_cost(building_id),
		bool(main_world.call("can_purchase_building", building_id)),
		"Buy",
		_on_building_pressed.bind(building_id, main_world),
		owned
	)


func _build_action_row(
	title: String,
	status: String,
	cost: int,
	enabled: bool,
	button_text: String,
	callback: Callable,
	completed: bool = false,
	disabled_reason: String = ""
) -> void:
	var row: PanelContainer = ui_style.make_card(&"PremiumCard" if title.contains("VIP") or title.contains("Helipad") else &"Card")
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	row.add_child(vbox)
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	var progression_marker: String = "building_owned_marker" if completed else "upgrade_available_marker" if enabled else "upgrade_locked_marker"
	header.add_child(ui_style.make_atlas_icon_slot("building_purchase_upgrade_construction_kit", progression_marker, true))
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"SectionTitle"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(name_label)
	var status_label: Label = Label.new()
	status_label.text = status
	status_label.theme_type_variation = &"StatusInfo"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_child(status_label)
	var reason: String = "OWNED" if completed and status == "Owned" else "MAX LEVEL" if completed else "Ready" if enabled else "Not Enough Money"
	if not disabled_reason.is_empty():
		reason = disabled_reason
	var reason_label: Label = ui_style.make_status_label(reason, ui_style.status_variation(reason))
	reason_label.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_child(reason_label)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	if not completed:
		footer.add_child(ui_style.make_money_icon_slot(cost, true))
	var cost_label: Label = Label.new()
	cost_label.text = "" if completed else "Cost: %s" % vnd_format.format_vnd(cost)
	cost_label.size_flags_horizontal = SIZE_EXPAND_FILL
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(cost_label)
	var action_button: Button = Button.new()
	action_button.text = "MAX / OWNED" if completed else button_text
	action_button.custom_minimum_size = Vector2(150.0, 36.0)
	action_button.size_flags_horizontal = SIZE_SHRINK_END
	action_button.disabled = completed or not enabled
	if action_button.disabled:
		action_button.add_theme_color_override("font_disabled_color", Color(0.34, 0.31, 0.27, 1.0))
	action_button.pressed.connect(callback)
	footer.add_child(action_button)
	list_container.add_child(row)


func _on_farm_plot_pressed(main_world: Node) -> void:
	if bool(main_world.call("purchase_next_farm_plot")):
		refresh()


func _on_pond_pressed(container_id: String, main_world: Node) -> void:
	if bool(main_world.call("upgrade_pond", container_id)):
		refresh()


func _on_building_pressed(building_id: String, main_world: Node) -> void:
	if bool(main_world.call("purchase_building", building_id)):
		refresh()


func _on_upgrade_pressed(sys_id: String, main_world: Node) -> void:
	if main_world.call("upgrade_system", sys_id):
		refresh()
