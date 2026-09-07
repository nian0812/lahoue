extends Node2D

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")

signal state_changed(staff_id: String, state: String)
signal job_started(staff_id: String, job: Dictionary)
signal job_finished(staff_id: String, job: Dictionary)
signal job_failed(staff_id: String, job: Dictionary)

const state_idle: String = "idle"
const state_moving: String = "moving"
const state_handling_order: String = "handling_order"
const state_delivering_food: String = "delivering_food"
const state_cleaning_table: String = "cleaning_table"
const state_harvesting: String = "harvesting"
const state_collecting: String = "collecting"
const state_returning: String = "returning"
const state_off_duty: String = "off_duty"
const valid_states: Array[String] = [
	state_idle,
	state_moving,
	state_handling_order,
	state_delivering_food,
	state_cleaning_table,
	state_harvesting,
	state_collecting,
	state_returning,
	state_off_duty,
]

const job_cook: String = "cook"
const job_serve: String = "serve"
const job_payment: String = "payment"
const job_clean: String = "clean"
const job_harvest: String = "harvest"
const job_collect_animal: String = "collect_animal"
const job_collect_aquaculture: String = "collect_aquaculture"
const valid_job_types: Array[String] = [
	job_cook,
	job_serve,
	job_payment,
	job_clean,
	job_harvest,
	job_collect_animal,
	job_collect_aquaculture,
]

@onready var staff_visual: Polygon2D = $staff_visual
@onready var staff_label: Label = $staff_label

var staff_id: String = ""
var staff_type_id: String = ""
var current_state: String = state_idle
var active_job: Dictionary = {}
var home_position: Vector2 = Vector2.ZERO
var destination: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var cleaning_time_seconds: float = 0.0
var allowed_jobs: Array[String] = []
var restaurant: Node = null
var is_paid: bool = true
var salary_debt: int = 0


func _ready() -> void:
	_refresh_visual()
	_refresh_identity_label()


func configure(
	new_staff_id: String,
	new_staff_type_id: String,
	controller: Node,
	new_home_position: Vector2
) -> bool:
	var staff_data: Dictionary = data_manager.get_staff_type(new_staff_type_id)
	if not is_valid_staff_id(new_staff_id) or staff_data.is_empty() or controller == null:
		return false
	staff_id = new_staff_id
	staff_type_id = new_staff_type_id
	restaurant = controller
	home_position = new_home_position
	movement_speed = float(staff_data.get("movement_speed", 0.0))
	cleaning_time_seconds = float(staff_data.get("cleaning_time_seconds", 0.0))
	allowed_jobs.clear()
	for job_value: Variant in staff_data.get("allowed_jobs", []) as Array:
		allowed_jobs.append(String(job_value))
	is_paid = true
	salary_debt = 0
	_refresh_visual()
	_refresh_identity_label()
	return movement_speed > 0.0 and cleaning_time_seconds > 0.0 and not allowed_jobs.is_empty()


func can_accept_job(job_type: String, allow_waiter_cook_fallback: bool = false) -> bool:
	var role_allows_job: bool = allowed_jobs.has(job_type) or (
		allow_waiter_cook_fallback
		and staff_type_id == "waiter"
		and job_type == job_cook
	)
	return is_paid and current_state == state_idle and active_job.is_empty() and role_allows_job


func assign_job(job: Dictionary, target_position: Vector2, allow_waiter_cook_fallback: bool = false) -> bool:
	var job_type: String = String(job.get("job_type", ""))
	var target_id: String = String(job.get("target_id", ""))
	if not can_accept_job(job_type, allow_waiter_cook_fallback) or target_id.is_empty() or not is_finite(target_position.x) or not is_finite(target_position.y):
		return false
	active_job = {
		"job_type": job_type,
		"target_id": target_id,
		"elapsed": 0.0,
	}
	destination = target_position
	_set_state(state_moving)
	job_started.emit(staff_id, active_job.duplicate(true))
	return true


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	match current_state:
		state_moving:
			_move_toward_destination(delta)
		state_handling_order, state_delivering_food, state_harvesting, state_collecting:
			if restaurant != null and is_instance_valid(restaurant):
				restaurant.call("execute_staff_job", staff_id)
		state_cleaning_table:
			var elapsed: float = minf(float(active_job.get("elapsed", 0.0)) + delta, cleaning_time_seconds)
			active_job["elapsed"] = elapsed
			if elapsed >= cleaning_time_seconds and restaurant != null and is_instance_valid(restaurant):
				restaurant.call("complete_staff_cleaning", staff_id)
		state_returning:
			_move_toward_destination(delta)
		state_off_duty:
			return false
		_:
			return false
	return true


func begin_current_job() -> bool:
	if current_state != state_moving or active_job.is_empty():
		return false
	match String(active_job.get("job_type", "")):
		job_cook, job_payment:
			_set_state(state_handling_order)
		job_serve:
			_set_state(state_delivering_food)
		job_clean:
			_set_state(state_cleaning_table)
		job_harvest:
			_set_state(state_harvesting)
		job_collect_animal, job_collect_aquaculture:
			_set_state(state_collecting)
		_:
			return false
	return true


func finish_current_job(succeeded: bool) -> void:
	if active_job.is_empty():
		return
	var finished_job: Dictionary = active_job.duplicate(true)
	active_job.clear()
	destination = home_position
	_set_state(state_returning)
	if succeeded:
		job_finished.emit(staff_id, finished_job)
	else:
		job_failed.emit(staff_id, finished_job)


func restore_saved_state(
	saved_state: Dictionary,
	controller: Node,
	restored_destination: Vector2,
	restored_home_position: Vector2
) -> bool:
	var saved_type: String = String(saved_state.get(
		"staff_type_id",
		data_manager.get_staff_settings().get("default_staff_type", "waiter")
	))
	if saved_type.is_empty():
		saved_type = "waiter"
	if not configure(staff_id, saved_type, controller, restored_home_position):
		return false
	var position_value: Variant = saved_state.get("position", {})
	if typeof(position_value) != TYPE_DICTIONARY:
		return false
	position = Vector2(float((position_value as Dictionary).get("x", 0.0)), float((position_value as Dictionary).get("y", 0.0)))
	current_state = String(saved_state.get("state", state_idle))
	is_paid = bool(saved_state.get("is_paid", true))
	salary_debt = maxi(int(saved_state.get("salary_debt", 0)), 0)
	var job_value: Variant = saved_state.get("active_job", {})
	active_job = (job_value as Dictionary).duplicate(true) if typeof(job_value) == TYPE_DICTIONARY else {}
	if not is_paid or salary_debt > 0:
		is_paid = false
		current_state = state_off_duty
		active_job.clear()
		position = home_position
	elif current_state == state_idle:
		position = home_position
	destination = home_position if current_state == state_returning else restored_destination
	_refresh_visual()
	_refresh_identity_label()
	return true


func get_save_state() -> Dictionary:
	return {
		"staff_type_id": staff_type_id,
		"position": {"x": position.x, "y": position.y},
		"state": current_state,
		"active_job": active_job.duplicate(true),
		"is_paid": is_paid,
		"salary_debt": salary_debt,
	}


func set_payroll_status(paid: bool, debt: int) -> void:
	is_paid = paid and debt <= 0
	salary_debt = maxi(debt, 0)
	if is_paid:
		if current_state == state_off_duty:
			position = home_position
			active_job.clear()
			_set_state(state_idle)
		_refresh_identity_label()
		return
	active_job.clear()
	destination = home_position
	if position.is_equal_approx(home_position):
		_set_state(state_off_duty)
	else:
		_set_state(state_returning)
	_refresh_identity_label()


static func is_valid_staff_id(value: String) -> bool:
	return not value.is_empty() and value == value.to_lower() and value.is_valid_identifier()


static func is_valid_state(value: String) -> bool:
	return valid_states.has(value)


static func is_valid_job_type(value: String) -> bool:
	return valid_job_types.has(value)


func _move_toward_destination(delta: float) -> void:
	position = position.move_toward(destination, movement_speed * delta)
	if not position.is_equal_approx(destination):
		return
	if current_state == state_returning:
		_set_state(state_idle if is_paid else state_off_duty)
		return
	if restaurant == null or not is_instance_valid(restaurant):
		finish_current_job(false)
		return
	restaurant.call("execute_staff_job", staff_id)


func _set_state(value: String) -> void:
	current_state = value
	_refresh_visual()
	state_changed.emit(staff_id, current_state)


func _refresh_visual() -> void:
	if not is_instance_valid(staff_visual):
		return
	var artwork_color: Color = Color.WHITE
	match current_state:
		state_idle:
			staff_visual.color = Color("#5b8fca")
		state_moving, state_returning:
			staff_visual.color = Color("#82a9d3")
			artwork_color = Color(0.9, 0.95, 1.0, 1.0)
		state_handling_order:
			staff_visual.color = Color("#d4a84f")
			artwork_color = Color(1.0, 0.92, 0.72, 1.0)
		state_delivering_food:
			staff_visual.color = Color("#70ad62")
			artwork_color = Color(0.82, 1.0, 0.78, 1.0)
		state_cleaning_table:
			staff_visual.color = Color("#a779c2")
			artwork_color = Color(0.92, 0.82, 1.0, 1.0)
		state_harvesting:
			staff_visual.color = Color("#68a95b")
			artwork_color = Color(0.82, 1.0, 0.78, 1.0)
		state_collecting:
			staff_visual.color = Color("#3f9aa8")
			artwork_color = Color(0.76, 0.96, 1.0, 1.0)
		state_off_duty:
			staff_visual.color = Color("#777777")
			artwork_color = Color(0.55, 0.55, 0.55, 1.0)
	var artwork_root: Node = get_node_or_null("AssetVisualRoot")
	if artwork_root != null:
		var asset_id: String = asset_catalog.get_bound_id("staff", staff_type_id)
		if not asset_id.is_empty() and String(artwork_root.get("semantic_id")) != asset_id:
			artwork_root.call("set_semantic_id", asset_id)
		artwork_root.call("set_artwork_modulate", artwork_color)


func _refresh_identity_label() -> void:
	if not is_instance_valid(staff_label):
		return
	var role_name: String = staff_type_id.capitalize() if not staff_type_id.is_empty() else "Staff"
	staff_label.text = role_name if is_paid else "%s (OFF DUTY)" % role_name
	var label_row: int = _get_identity_label_row()
	staff_label.offset_top = -54.0 - float(label_row * 14)
	staff_label.offset_bottom = staff_label.offset_top + 16.0


func _get_identity_label_row() -> int:
	var suffix: String = staff_id.get_slice("_", staff_id.get_slice_count("_") - 1)
	return maxi(suffix.to_int() - 1, 0) % 2
