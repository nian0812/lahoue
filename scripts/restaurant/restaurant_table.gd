extends Node2D

signal state_changed(table_id: String, state: String, occupant_id: String)

const state_available: String = "available"
const state_reserved: String = "reserved"
const state_occupied: String = "occupied"
const state_needs_cleanup: String = "needs_cleanup"
const valid_states: Array[String] = [
	state_available,
	state_reserved,
	state_occupied,
	state_needs_cleanup,
]

@export var table_id: String = ""

@onready var table_visual: Polygon2D = $table_visual
@onready var seat_marker: Marker2D = $seat_marker

var current_state: String = state_available
var occupant_id: String = ""


func _ready() -> void:
	_refresh_visual()


func reserve(customer_id: String) -> bool:
	if current_state != state_available or not _is_valid_occupant_id(customer_id):
		return false
	occupant_id = customer_id
	_set_state(state_reserved)
	return true


func seat_customer(customer_id: String) -> bool:
	if current_state != state_reserved or occupant_id != customer_id:
		return false
	_set_state(state_occupied)
	return true


func mark_needs_cleanup() -> bool:
	if current_state != state_occupied:
		return false
	occupant_id = ""
	_set_state(state_needs_cleanup)
	return true


func release_table() -> bool:
	if current_state == state_available:
		return false
	occupant_id = ""
	_set_state(state_available)
	return true


func reset_table() -> void:
	occupant_id = ""
	_set_state(state_available)


func get_save_state() -> Dictionary:
	return {
		"state": current_state,
		"occupant_id": occupant_id,
	}


func apply_save_state(saved_state: Dictionary) -> void:
	current_state = String(saved_state.get("state", state_available))
	occupant_id = String(saved_state.get("occupant_id", ""))
	_refresh_visual()


static func is_valid_state(value: String) -> bool:
	return valid_states.has(value)


static func is_valid_state_data(value: String, saved_occupant_id: String) -> bool:
	if not is_valid_state(value):
		return false
	if value == state_reserved or value == state_occupied:
		return _is_valid_occupant_id(saved_occupant_id)
	return saved_occupant_id.is_empty()


static func _is_valid_occupant_id(value: String) -> bool:
	return (
		not value.is_empty()
		and value == value.to_lower()
		and value.is_valid_identifier()
	)


func _set_state(value: String) -> void:
	current_state = value
	_refresh_visual()
	state_changed.emit(table_id, current_state, occupant_id)


func _refresh_visual() -> void:
	if not is_instance_valid(table_visual):
		return
	match current_state:
		state_available:
			table_visual.color = Color("#c7924f")
		state_reserved:
			table_visual.color = Color("#e0bb55")
		state_occupied:
			table_visual.color = Color("#d56a4b")
		state_needs_cleanup:
			table_visual.color = Color("#77716b")
