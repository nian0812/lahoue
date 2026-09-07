extends Area2D

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const manifest_sprite: GDScript = preload("res://scripts/visual/manifest_sprite.gd")

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

@onready var soil: Polygon2D = $VisualRoot/soil
@onready var crop_visual: Polygon2D = $VisualRoot/crop
@onready var crop_artwork: Sprite2D = $VisualRoot/CropArtwork

var current_state: int = farm_state.EMPTY
var crop_id: String = ""
var growth_elapsed: float = 0.0
var is_purchased: bool = true
var visual_stage: int = 0


func _ready() -> void:
	_update_visual()
	if not game_manager.day_finishing.is_connected(_on_day_finishing):
		game_manager.day_finishing.connect(_on_day_finishing)


func _on_day_finishing(_day: int) -> void:
	var remaining_time: float = game_manager.day_duration - game_manager.day_timer
	if remaining_time > 0.0:
		advance_growth(remaining_time)


func _process(delta: float) -> void:
	if not is_purchased or not game_manager.gameplay_active:
		return

	advance_growth(delta)


func interact(player: Node) -> bool:
	if not is_purchased:
		return false
	if current_state == farm_state.READY:
		return harvest()

	if current_state != farm_state.EMPTY:
		return false

	if not player.has_method("get_selected_seed_item"):
		return false

	var seed_item_id: String = String(player.call("get_selected_seed_item"))
	return plant_seed(seed_item_id)


func can_plant(seed_item_id: String) -> bool:
	if not is_purchased or current_state != farm_state.EMPTY or seed_item_id.is_empty():
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
	if not is_purchased or current_state != farm_state.PLANTED or delta <= 0.0:
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
	else:
		_refresh_crop_artwork()


func harvest() -> bool:
	if not is_purchased or current_state != farm_state.READY:
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
	if not is_purchased or saved_crop_id.is_empty() or not is_finite(saved_growth) or saved_growth < 0.0:
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
	return is_purchased and current_state == farm_state.READY


func set_purchased(value: bool) -> void:
	is_purchased = value
	visible = value
	set_process(value)
	if has_node("collision_shape"):
		$collision_shape.set_deferred("disabled", not value)


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
	_refresh_crop_artwork(true)


func _refresh_crop_artwork(force: bool = false) -> void:
	if not is_instance_valid(crop_artwork):
		return
	var next_stage: int = _get_visual_stage()
	if next_stage <= 0:
		visual_stage = 0
		crop_artwork.visible = false
		return
	if not force and visual_stage == next_stage and crop_artwork.texture != null:
		return
	var canonical_crop_id: String = asset_catalog.get_bound_id("crops", crop_id)
	var texture: Texture2D = asset_catalog.get_variant_texture(
		"crops",
		"crops",
		canonical_crop_id,
		"stage_%d" % next_stage
	)
	if texture == null:
		crop_artwork.visible = false
		return
	visual_stage = next_stage
	crop_artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	manifest_sprite.configure_sprite(crop_artwork, texture, _get_crop_visual_rect())
	crop_artwork.visible = true
	crop_visual.visible = false


func _get_crop_visual_rect() -> Rect2:
	if crop_id in ["coconut", "banana"]:
		return Rect2(-23.0, -42.0, 46.0, 68.0)
	if crop_id in [
		"corn", "cucumber", "tomato", "chili", "soybean", "lemongrass",
		"tea", "sugarcane", "coffee",
	]:
		return Rect2(-24.0, -31.0, 48.0, 56.0)
	return Rect2(-24.0, -20.0, 48.0, 44.0)


func _get_visual_stage() -> int:
	if not is_purchased or crop_id.is_empty() or current_state == farm_state.EMPTY:
		return 0
	if current_state == farm_state.READY:
		return 4
	var growth_time: float = data_manager.get_crop_growth_time_seconds(crop_id)
	if growth_time <= 0.0:
		return 1
	var progress: float = clampf(growth_elapsed / growth_time, 0.0, 0.9999)
	return mini(int(floor(progress * 4.0)) + 1, 3)
