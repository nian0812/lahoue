extends Control

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var top_panel: PanelContainer
var bottom_panel: PanelContainer
var day_label: Label
var time_label: Label
var time_bar: ProgressBar
var rep_label: Label
var money_label: Label
var level_label: Label
var exp_bar: ProgressBar
var inv_label: Label
var seed_label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_bottom_bar()
	_connect_signals()
	_refresh_all()


func set_player(player: Node) -> void:
	if player == null:
		return
	if player.has_signal("selected_seed_changed"):
		if not player.selected_seed_changed.is_connected(_on_seed_changed):
			player.selected_seed_changed.connect(_on_seed_changed)
	var current_seed: Variant = player.get("selected_seed_item_id")
	if current_seed != null:
		_on_seed_changed(String(current_seed))


func _build_top_bar() -> void:
	top_panel = PanelContainer.new()
	top_panel.name = "top_panel"
	add_child(top_panel)
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = 70
	top_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_apply_hud_style(top_panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "top_bar"
	top_panel.add_child(hbox)
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = MOUSE_FILTER_IGNORE

	var world_section: HBoxContainer = _make_hud_section(hbox, "crop")
	var world_text: VBoxContainer = world_section.get_child(1) as VBoxContainer
	day_label = _make_label("Day 1", 15)
	world_text.add_child(day_label)
	time_label = _make_label("Time: 06:00", 12)
	time_label.modulate = Color(1, 1, 1, 0.7)
	world_text.add_child(time_label)
	time_bar = ProgressBar.new()
	time_bar.name = "time_bar"
	time_bar.custom_minimum_size = Vector2(140, 8)
	time_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	time_bar.max_value = 240.0
	time_bar.value = 0.0
	time_bar.show_percentage = false
	world_text.add_child(time_bar)

	var progress_section: HBoxContainer = _make_hud_section(hbox, "exp")
	var progress_text: VBoxContainer = progress_section.get_child(1) as VBoxContainer
	level_label = _make_label("Lv 1 — 0 / 100 EXP", 14)
	progress_text.add_child(level_label)
	exp_bar = ProgressBar.new()
	exp_bar.name = "exp_bar"
	exp_bar.custom_minimum_size = Vector2(210, 10)
	exp_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	exp_bar.max_value = 100
	exp_bar.value = 0
	exp_bar.show_percentage = false
	progress_text.add_child(exp_bar)

	var economy_section: HBoxContainer = _make_hud_section(hbox, "money")
	var economy_text: VBoxContainer = economy_section.get_child(1) as VBoxContainer
	money_label = _make_label("Money: 0 VNĐ", 15)
	economy_text.add_child(money_label)
	inv_label = _make_label("Warehouse: 0 / 75", 12)
	inv_label.modulate = Color(1, 1, 1, 0.7)
	economy_text.add_child(inv_label)


func _build_bottom_bar() -> void:
	bottom_panel = PanelContainer.new()
	bottom_panel.name = "bottom_panel"
	add_child(bottom_panel)
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -34
	bottom_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_apply_hud_style(bottom_panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "bottom_bar"
	bottom_panel.add_child(hbox)
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = MOUSE_FILTER_IGNORE

	seed_label = _make_label("Selected Crop: —", 13)
	hbox.add_child(seed_label)
	hbox.add_child(_make_spacer())
	rep_label = _make_label("Reputation: 1.0 ★", 13)
	hbox.add_child(rep_label)


func _make_hud_section(parent: HBoxContainer, icon_kind: String) -> HBoxContainer:
	var section: HBoxContainer = HBoxContainer.new()
	section.size_flags_horizontal = SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	section.mouse_filter = MOUSE_FILTER_IGNORE
	section.add_child(ui_style.make_icon_slot(icon_kind, true))
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	section.add_child(content)
	parent.add_child(section)
	return section


func _make_label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87, 1.0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _make_spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	return spacer


func _apply_hud_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.07, 0.72)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)


func _connect_signals() -> void:
	game_manager.day_started.connect(_on_day_started)
	game_manager.day_time_changed.connect(_on_day_time_changed)
	game_manager.money_changed.connect(_on_money_changed)
	game_manager.level_changed.connect(_on_level_changed)
	game_manager.exp_changed.connect(_on_exp_changed)
	game_manager.reputation_changed.connect(_on_reputation_changed)
	inventory_manager.capacity_changed.connect(_on_capacity_changed)


func _refresh_all() -> void:
	_on_day_started(game_manager.day)
	_on_day_time_changed(game_manager.day_timer, game_manager.day_duration)
	_on_money_changed(game_manager.money)
	_on_level_changed(game_manager.level)
	_on_exp_changed(game_manager.current_exp, game_manager.level)
	_on_reputation_changed(game_manager.reputation)
	var used: int = inventory_manager.get_used_capacity()
	var cap: int = inventory_manager.get_capacity()
	_on_capacity_changed(used, cap)


func _on_day_started(p_day: Variant) -> void:
	day_label.text = "Day %d" % int(p_day)


func _on_day_time_changed(p_timer: Variant, p_duration: Variant) -> void:
	time_bar.max_value = maxf(float(p_duration), 1.0)
	time_bar.value = float(p_timer)
	var day_progress: float = clampf(float(p_timer) / maxf(float(p_duration), 1.0), 0.0, 1.0)
	var clock_minutes: int = 360 + roundi(day_progress * 960.0)
	time_label.text = "Time: %02d:%02d" % [int(clock_minutes / 60), clock_minutes % 60]


func _on_money_changed(p_money: Variant) -> void:
	money_label.text = "Money: %s" % vnd_format.format_vnd(int(p_money))
	_animate_label(money_label)


func _on_level_changed(p_level: Variant) -> void:
	var player_level: int = int(p_level)
	if player_level >= data_manager.get_max_player_level():
		level_label.text = "Lv %d — EXP: MAX • LaHoue Empire" % player_level
	_animate_label(level_label)


func _on_exp_changed(p_exp: Variant, p_level: Variant) -> void:
	if int(p_level) >= data_manager.get_max_player_level():
		exp_bar.max_value = 1
		exp_bar.value = 1
		level_label.text = "Lv %d — EXP: MAX • LaHoue Empire" % int(p_level)
		return
	var threshold: int = data_manager.get_level_exp(int(p_level))
	exp_bar.max_value = maxi(threshold, 1)
	exp_bar.value = mini(int(p_exp), threshold)
	level_label.text = "Lv %d — %s / %s EXP" % [
		int(p_level),
		vnd_format.format_number(int(p_exp)),
		vnd_format.format_number(threshold),
	]


func _on_reputation_changed(p_reputation: Variant) -> void:
	rep_label.text = "Reputation: %.1f ★" % float(p_reputation)


func _on_capacity_changed(p_current: Variant, p_maximum: Variant) -> void:
	inv_label.text = "Warehouse: %d / %d" % [int(p_current), int(p_maximum)]


func _on_seed_changed(p_seed_item_id: Variant) -> void:
	var seed_id: String = String(p_seed_item_id)
	if seed_id.is_empty():
		seed_label.text = "Selected Crop: —"
		return
	seed_label.text = "Selected Crop: %s" % vnd_format.format_item_name(seed_id)


func _animate_label(label: Label) -> void:
	if label.size.length_squared() > 0.0:
		label.pivot_offset = label.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12)
