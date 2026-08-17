extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var list_container: VBoxContainer
var header_lbl: Label
var systems: Array[String] = [
	"warehouse",
	"coop",
	"cow_barn",
	"aquaculture",
	"restaurant",
	"kitchen"
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

	var title: Label = Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 22)
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

	var lvl: int = game_manager.level
	var current_exp: int = game_manager.current_exp
	var max_exp: int = data_manager.get_level_exp(lvl)
	if max_exp > 0:
		header_lbl.text = "Player Level: %d | EXP: %d / %d" % [lvl, current_exp, max_exp]
	else:
		header_lbl.text = "Player Level: %d | EXP: MAX" % lvl

	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if not main_world: return

	for sys_id in systems:
		var current_lvl: int = main_world.call("get_upgrade_level", sys_id)
		var max_lvl: int = data_manager.get_progression_max_level(sys_id)

		# If system is locked/hidden (e.g., restaurant level 0 before unlock level)
		if current_lvl == 0 and not main_world.call("can_upgrade_system", sys_id):
			# Also check if it's completely unavailable
			var unlock_lvl: int = 1
			if sys_id == "restaurant" or sys_id == "kitchen":
				unlock_lvl = data_manager.get_restaurant_unlock_level()

			if game_manager.level < unlock_lvl:
				_build_locked_row(sys_id, unlock_lvl)
				continue

		_build_upgrade_row(sys_id, current_lvl, max_lvl, main_world)


func _build_locked_row(sys_id: String, unlock_lvl: int) -> void:
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
	row.modulate = Color(1, 1, 1, 0.5)

	var hbox: HBoxContainer = HBoxContainer.new()
	row.add_child(hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = sys_id.capitalize().replace("_", " ")
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var lock_lbl: Label = Label.new()
	lock_lbl.text = "Unlocks at Lv %d" % unlock_lvl
	lock_lbl.modulate = Color(0.8, 0.3, 0.3)
	hbox.add_child(lock_lbl)

	list_container.add_child(row)


func _build_upgrade_row(sys_id: String, current_lvl: int, max_lvl: int, main_world: Node) -> void:
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
	name_lbl.text = sys_id.capitalize().replace("_", " ")
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox_top.add_child(name_lbl)

	var lvl_lbl: Label = Label.new()
	lvl_lbl.text = "Lv %d / %d" % [current_lvl, max_lvl] if max_lvl > 0 else "Lv %d" % current_lvl
	hbox_top.add_child(lvl_lbl)

	var hbox_bottom: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox_bottom)

	var current_effect: int = data_manager.get_progression_effect(sys_id, current_lvl)
	var effect_lbl: Label = Label.new()
	effect_lbl.text = "Capacity: %d" % current_effect
	effect_lbl.add_theme_font_size_override("font_size", 14)
	effect_lbl.modulate = Color(0.8, 0.8, 0.8)
	effect_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox_bottom.add_child(effect_lbl)

	if current_lvl < max_lvl or max_lvl == 0:
		var target_lvl: int = current_lvl + 1
		var cost: int = data_manager.get_progression_upgrade_cost(sys_id, target_lvl)
		var can_upgrade: bool = main_world.call("can_upgrade_system", sys_id)

		var next_effect: int = data_manager.get_progression_effect(sys_id, target_lvl)
		if next_effect > current_effect:
			effect_lbl.text += " -> %d" % next_effect

		var cost_lbl: Label = Label.new()
		cost_lbl.text = vnd_format.format(cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_lbl.custom_minimum_size = Vector2(80, 0)
		if not game_manager.can_afford(cost):
			cost_lbl.modulate = Color(0.8, 0.3, 0.3)
		elif can_upgrade:
			cost_lbl.modulate = Color(0.8, 0.7, 0.4)
		hbox_bottom.add_child(cost_lbl)

		var up_btn: Button = Button.new()
		up_btn.text = "Upgrade"
		up_btn.disabled = not can_upgrade
		up_btn.pressed.connect(_on_upgrade_pressed.bind(sys_id, main_world))
		hbox_bottom.add_child(up_btn)
	else:
		var max_lbl: Label = Label.new()
		max_lbl.text = "MAX LEVEL"
		max_lbl.modulate = Color(0.4, 0.8, 0.4)
		hbox_bottom.add_child(max_lbl)

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


func _on_upgrade_pressed(sys_id: String, main_world: Node) -> void:
	if main_world.call("upgrade_system", sys_id):
		refresh()
