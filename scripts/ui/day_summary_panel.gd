extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

var _money_earned: int = 0
var _money_spent: int = 0
var _crops_harvested: int = 0
var _animal_products: int = 0
var _seafood: int = 0
var _meals_served: int = 0
var _exp_gained: int = 0

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
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	title_lbl = Label.new()
	title_lbl.text = "DAY SUMMARY"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(400, 300)
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
			rest.connect("payment_collected", _on_payment_collected)


func _on_day_started(_day: Variant) -> void:
	_money_earned = 0
	_money_spent = 0
	_crops_harvested = 0
	_animal_products = 0
	_seafood = 0
	_meals_served = 0
	_exp_gained = 0

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
	elif cat == "animal":
		_animal_products += int(amount)
	elif cat == "seafood":
		_seafood += int(amount)


func _on_payment_collected(_cid: Variant, _rid: Variant, _tot: Variant) -> void:
	_meals_served += 1


func _on_day_finishing(day: Variant) -> void:
	title_lbl.text = "DAY %d SUMMARY" % int(day)

	for child in list_container.get_children():
		child.queue_free()

	_add_stat_row("Money Earned", "+%s" % vnd_format.format(_money_earned), Color(0.4, 0.8, 0.4))
	_add_stat_row("Money Spent", "-%s" % vnd_format.format(_money_spent), Color(0.8, 0.4, 0.4))
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
	var hbox: HBoxContainer = HBoxContainer.new()
	list_container.add_child(hbox)

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
