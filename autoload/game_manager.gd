extends Node

const max_wallet_balance: int = 9007199254740991
const sales_exp_revenue_step: int = 10000
const max_sales_exp_per_transaction: int = 1000

signal game_state_changed(state)
signal day_started(day)
signal day_time_changed(day_timer, day_duration)
signal day_finishing(day)
signal day_finished(day)
signal level_changed(level)
signal exp_changed(current_exp, level)
signal money_changed(money)
signal reputation_changed(reputation)

var day_duration: float = 240.0

var gameplay_active: bool = false
var day: int = 1
var day_timer: float = 0.0
var money: int = 0
var current_exp: int = 0
var level: int = 1
var reputation: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)

	if data_manager.is_ready:
		_load_day_duration()
	else:
		data_manager.data_loaded.connect(_load_day_duration, CONNECT_ONE_SHOT)


func _load_day_duration() -> void:
	var progression: Dictionary = data_manager.get_dataset("progression")
	if progression.is_empty():
		return

	day_duration = float(progression.get("day_duration_seconds", 240.0))


func _process(delta: float) -> void:
	if not gameplay_active:
		return

	if get_tree().paused:
		return

	day_timer += delta
	day_time_changed.emit(day_timer, day_duration)

	if day_timer >= day_duration:
		finish_day()


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_active:
		return

	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("finish_day"):
		if not get_tree().paused:
			finish_day()
		get_viewport().set_input_as_handled()


func start_gameplay() -> void:
	gameplay_active = true
	game_state_changed.emit("gameplay")
	day_started.emit(day)
	day_time_changed.emit(day_timer, day_duration)


func stop_gameplay() -> void:
	gameplay_active = false
	if get_tree().paused:
		get_tree().paused = false
	game_state_changed.emit("stopped")


func toggle_pause() -> void:
	if not gameplay_active:
		return

	get_tree().paused = not get_tree().paused
	game_state_changed.emit("paused" if get_tree().paused else "gameplay")


func finish_day() -> void:
	if not gameplay_active or get_tree().paused:
		return

	day_finishing.emit(day)

	# Future Phase 1-compatible systems can connect to day_finishing.
	# finish_day() remains the single end-of-day entry point.
	day_finished.emit(day)

	day += 1
	day_timer = 0.0

	day_started.emit(day)
	day_time_changed.emit(day_timer, day_duration)
func get_wallet_balance() -> int:
	return money


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


func can_receive_money(amount: int) -> bool:
	return amount > 0 and money >= 0 and money <= max_wallet_balance - amount


func add_money(amount: int) -> bool:
	if not can_receive_money(amount):
		return false
	money += amount
	money_changed.emit(money)
	return true


func spend_money(amount: int) -> bool:
	if amount < 0:
		return false

	if not can_afford(amount):
		return false

	money -= amount
	money_changed.emit(money)
	return true


func add_exp(amount: int) -> bool:
	if amount <= 0 or current_exp < 0 or current_exp > max_wallet_balance - amount:
		return false

	current_exp += amount
	_process_level_up()
	exp_changed.emit(current_exp, level)
	return true


func calculate_sales_exp(revenue: int) -> int:
	if revenue <= 0:
		return 0
	return mini(floori(float(revenue) / float(sales_exp_revenue_step)), max_sales_exp_per_transaction)


func grant_sales_exp(revenue: int) -> int:
	var sales_exp: int = calculate_sales_exp(revenue)
	if sales_exp <= 0 or not add_exp(sales_exp):
		return 0
	return sales_exp


func _process_level_up() -> void:
	var maximum_level: int = data_manager.get_max_player_level()
	while level < maximum_level:
		var required_exp: int = data_manager.get_level_exp(level)
		if required_exp <= 0 or current_exp < required_exp:
			break

		current_exp -= required_exp
		level += 1
		level_changed.emit(level)


func change_reputation(amount: float) -> void:
	reputation = clampf(reputation + amount, 1.0, 5.0)
	reputation_changed.emit(reputation)


func get_save_state() -> Dictionary:
	return {
		"day": day,
		"day_timer": day_timer,
		"money": money,
		"exp": current_exp,
		"level": level,
		"reputation": reputation
	}


func apply_save_state(state: Dictionary) -> void:
	day = int(state.get("day", 1))
	day_timer = float(state.get("day_timer", 0.0))
	money = int(state.get("money", 0))
	current_exp = int(state.get("exp", 0))
	level = int(state.get("level", 1))
	reputation = float(state.get("reputation", 1.0))

	money_changed.emit(money)
	exp_changed.emit(current_exp, level)
	level_changed.emit(level)
	reputation_changed.emit(reputation)
	day_time_changed.emit(day_timer, day_duration)
