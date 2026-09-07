extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var _money_earned: int = 0
var _money_spent: int = 0
var _crops_harvested: int = 0
var _animal_products: int = 0
var _seafood: int = 0
var _meals_served: int = 0
var _exp_gained: int = 0
var _staff_payroll: int = 0

var _last_money: int = 0
var _last_exp: int = 0

var list_container: VBoxContainer
var title_lbl: Label

func _ready() -> void:
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()

	_last_money = game_manager.money
	_last_exp = game_manager.current_exp


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_row)
	title_row.add_child(ui_style.make_ui_icon_slot("day_summary", "sunrise_summary_banner"))
	title_lbl = Label.new()
	title_lbl.text = "DAY SUMMARY"
	title_lbl.theme_type_variation = &"HeaderLarge"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(title_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 12)
	scroll.add_child(list_container)

	var btn: Button = Button.new()
	btn.text = "Continue to Next Day"
	btn.custom_minimum_size = Vector2(0, 50)
	btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(btn)


func _connect_signals() -> void:
	game_manager.day_started.connect(_on_day_started)
	game_manager.day_finishing.connect(_on_day_finishing)
	game_manager.money_changed.connect(_on_money_changed)
	game_manager.exp_changed.connect(_on_exp_changed)

	inventory_manager.item_added.connect(_on_item_added)

	# Wait for restaurant to be ready
	call_deferred("_connect_restaurant")

func _connect_restaurant() -> void:
	var main_world: Node = get_tree().root.get_node_or_null("main_world")
	if main_world:
		var rest: Node = main_world.get_node_or_null("restaurant")
		if rest and rest.has_signal("payment_collected"):
			if not rest.is_connected("payment_collected", _on_payment_collected):
				rest.connect("payment_collected", _on_payment_collected)
		if rest and rest.has_signal("staff_payroll_processed"):
			if not rest.is_connected("staff_payroll_processed", _on_staff_payroll_processed):
				rest.connect("staff_payroll_processed", _on_staff_payroll_processed)


func _on_day_started(_day: Variant) -> void:
	_money_earned = 0
	_money_spent = 0
	_crops_harvested = 0
	_animal_products = 0
	_seafood = 0
	_meals_served = 0
	_exp_gained = 0
	_staff_payroll = 0

	_last_money = game_manager.money
	_last_exp = game_manager.current_exp


func _on_money_changed(new_money: Variant) -> void:
	var diff: int = int(new_money) - _last_money
	if diff > 0:
		_money_earned += diff
	elif diff < 0:
		_money_spent -= diff
	_last_money = int(new_money)


func _on_exp_changed(new_exp: Variant, _lvl: Variant) -> void:
	var diff: int = int(new_exp) - _last_exp
	if diff > 0:
		_exp_gained += diff
	_last_exp = int(new_exp)


func _on_item_added(item_id: Variant, amount: Variant) -> void:
	var ds: Dictionary = data_manager.get_dataset("items")
	var entries: Dictionary = ds.get("entries", {})
	var it_str: String = String(item_id)
	var data: Dictionary = entries.get(it_str, {}) as Dictionary
	var cat: String = String(data.get("category", ""))

	if cat == "farm":
		_crops_harvested += int(amount)
	elif cat == "animal_products":
		_animal_products += int(amount)
	elif cat == "seafood":
		_seafood += int(amount)


func _on_payment_collected(_cid: Variant, _rid: Variant, _tot: Variant) -> void:
	_meals_served += 1


func _on_staff_payroll_processed(_due: Variant, paid: Variant, _outstanding: Variant) -> void:
	_staff_payroll += maxi(int(paid), 0)


func _on_day_finishing(day: Variant) -> void:
	title_lbl.text = "DAY %d SUMMARY" % int(day)
	var ui_manager: Node = get_parent()
	if ui_manager != null and ui_manager.has_method("_close_active_panel"):
		ui_manager.call("_close_active_panel")

	for child in list_container.get_children():
		child.queue_free()

	var other_expenses: int = maxi(_money_spent - _staff_payroll, 0)
	var net_profit: int = _money_earned - _money_spent
	_add_stat_row("Revenue", "+%s" % vnd_format.format_vnd(_money_earned), ui_style.color_success)
	_add_stat_row("Expenses", "-%s" % vnd_format.format_vnd(other_expenses), ui_style.color_locked)
	_add_stat_row("Staff Payroll", "-%s" % vnd_format.format_vnd(_staff_payroll), ui_style.color_warning)
	_add_stat_row("Net Profit", ("+" if net_profit >= 0 else "") + vnd_format.format_vnd(net_profit), ui_style.color_success if net_profit >= 0 else ui_style.color_locked)
	_add_stat_row("EXP Gained", "+%d" % _exp_gained, Color(0.3, 0.6, 1.0))
	_add_stat_row("Crops Harvested", str(_crops_harvested), Color.WHITE)
	_add_stat_row("Animal Products", str(_animal_products), Color.WHITE)
	_add_stat_row("Seafood Collected", str(_seafood), Color.WHITE)
	_add_stat_row("Meals Served", str(_meals_served), Color.WHITE)

	visible = true
	get_tree().paused = true

	# Animation
	modulate.a = 0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)


func _add_stat_row(label_text: String, val_text: String, val_color: Color) -> void:
	var card: PanelContainer = ui_style.make_card()
	var hbox: HBoxContainer = HBoxContainer.new()
	card.add_child(hbox)
	list_container.add_child(card)
	var icon_id: String = "information"
	match label_text:
		"Revenue", "Net Profit": icon_id = "money_gain" if val_text.begins_with("+") else "money_cost"
		"Expenses": icon_id = "money_cost"
		"Staff Payroll": icon_id = "salary"
		"EXP Gained": icon_id = "exp_gain"
		"Crops Harvested", "Animal Products", "Seafood Collected": icon_id = "collect"
		"Meals Served": icon_id = "success_completed"
	hbox.add_child(ui_style.make_ui_icon_slot("status_action", icon_id, true))

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(lbl)

	var val: Label = Label.new()
	val.text = val_text
	val.modulate = val_color
	val.add_theme_font_size_override("font_size", 18)
	hbox.add_child(val)


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_on_continue_pressed()
