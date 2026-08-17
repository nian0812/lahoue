extends Area2D

signal state_changed(tile_id: String, state: int)
signal crop_planted(tile_id: String, crop_id: String)
signal crop_ready(tile_id: String, crop_id: String)
signal crop_harvested(tile_id: String, crop_id: String, item_id: String, amount: int)

enum farm_state {
	EMPTY,
	PLANTED,
	READY
}

@export var tile_id: String = ""

@onready var soil: Polygon2D = $soil
@onready var crop_visual: Polygon2D = $crop

var current_state: int = farm_state.EMPTY
var crop_id: String = ""
var growth_elapsed: float = 0.0


func _ready() -> void:
	_update_visual()


func _process(delta: float) -> void:
	if not game_manager.gameplay_active:
		return

	advance_growth(delta)


func interact(player: Node) -> bool:
	if current_state == farm_state.READY:
		return harvest()

	if current_state != farm_state.EMPTY:
		return false

	if not player.has_method("get_selected_seed_item"):
		return false

	var seed_item_id: String = String(player.call("get_selected_seed_item"))
	return plant_seed(seed_item_id)


func can_plant(seed_item_id: String) -> bool:
	if current_state != farm_state.EMPTY or seed_item_id.is_empty():
		return false

	var candidate_crop_id: String = data_manager.get_crop_id_for_seed(seed_item_id)
	if candidate_crop_id.is_empty():
		return false

	var crop_data_value: Variant = data_manager.get_entry("crops", candidate_crop_id)
	if typeof(crop_data_value) != TYPE_DICTIONARY:
		return false

	var crop_data: Dictionary = crop_data_value as Dictionary
	var required_level: int = data_manager.get_crop_required_level(candidate_crop_id)
	if required_level <= 0 or required_level > game_manager.level:
		return false
	if data_manager.get_crop_growth_time_seconds(candidate_crop_id) <= 0.0:
		return false

	var harvest_item_id: String = String(crop_data.get("harvest_item", ""))
	if harvest_item_id.is_empty() or data_manager.get_entry("items", harvest_item_id) == null:
		return false
	if int(crop_data.get("yield", 0)) <= 0:
		return false

	return inventory_manager.has_item(seed_item_id)


func plant_seed(seed_item_id: String) -> bool:
	if not can_plant(seed_item_id):
		return false

	var candidate_crop_id: String = data_manager.get_crop_id_for_seed(seed_item_id)
	if not inventory_manager.remove_item(seed_item_id, 1):
		return false

	crop_id = candidate_crop_id
	growth_elapsed = 0.0
	_set_state(farm_state.PLANTED)
	crop_planted.emit(tile_id, crop_id)
	return true


func advance_growth(delta: float) -> void:
	if current_state != farm_state.PLANTED or delta <= 0.0:
		return

	var crop_data_value: Variant = data_manager.get_entry("crops", crop_id)
	if typeof(crop_data_value) != TYPE_DICTIONARY:
		return

	var growth_time: float = data_manager.get_crop_growth_time_seconds(crop_id)
	if growth_time <= 0.0:
		return

	growth_elapsed = minf(growth_elapsed + delta, growth_time)
	if growth_elapsed >= growth_time:
		_set_state(farm_state.READY)
		crop_ready.emit(tile_id, crop_id)


func harvest() -> bool:
	if current_state != farm_state.READY:
		return false

	var crop_data_value: Variant = data_manager.get_entry("crops", crop_id)
	if typeof(crop_data_value) != TYPE_DICTIONARY:
		return false

	var crop_data: Dictionary = crop_data_value as Dictionary
	var harvest_item_id: String = String(crop_data.get("harvest_item", ""))
	var harvest_amount: int = int(crop_data.get("yield", 0))
	if harvest_item_id.is_empty() or harvest_amount <= 0:
		return false
	if not inventory_manager.add_item(harvest_item_id, harvest_amount):
		return false

	var harvested_crop_id: String = crop_id
	var harvest_exp: int = int(crop_data.get("exp", 0))
	clear_tile()
	game_manager.add_exp(harvest_exp)
	crop_harvested.emit(
		tile_id,
		harvested_crop_id,
		harvest_item_id,
		harvest_amount
	)
	return true


func apply_saved_crop(saved_crop_id: String, saved_growth: float) -> bool:
	if saved_crop_id.is_empty() or not is_finite(saved_growth) or saved_growth < 0.0:
		return false

	var crop_data_value: Variant = data_manager.get_entry("crops", saved_crop_id)
	if typeof(crop_data_value) != TYPE_DICTIONARY:
		return false

	var growth_time: float = data_manager.get_crop_growth_time_seconds(saved_crop_id)
	if growth_time <= 0.0:
		return false

	crop_id = saved_crop_id
	growth_elapsed = clampf(saved_growth, 0.0, growth_time)
	_set_state(
		farm_state.READY if growth_elapsed >= growth_time else farm_state.PLANTED
	)
	return true


func clear_tile() -> void:
	crop_id = ""
	growth_elapsed = 0.0
	_set_state(farm_state.EMPTY)


func is_empty() -> bool:
	return current_state == farm_state.EMPTY


func is_planted() -> bool:
	return current_state == farm_state.PLANTED


func is_ready() -> bool:
	return current_state == farm_state.READY


func _set_state(value: int) -> void:
	current_state = value
	_update_visual()
	state_changed.emit(tile_id, current_state)


func _update_visual() -> void:
	if not is_node_ready():
		return

	var tw: Tween
	match current_state:
		farm_state.EMPTY:
			soil.color = Color(0.34, 0.19, 0.09, 1.0)
			crop_visual.visible = false
		farm_state.PLANTED:
			soil.color = Color(0.28, 0.16, 0.08, 1.0)
			crop_visual.color = Color(0.24, 0.68, 0.25, 1.0)
			crop_visual.visible = true
			tw = create_tween()
			tw.tween_property(crop_visual, "scale", Vector2(0.65, 0.65), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		farm_state.READY:
			soil.color = Color(0.42, 0.24, 0.1, 1.0)
			crop_visual.color = Color(0.96, 0.77, 0.18, 1.0)
			crop_visual.visible = true
			tw = create_tween()
			tw.tween_property(crop_visual, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
