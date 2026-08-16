extends Node2D

const farm_tile_script: Script = preload("res://scripts/farming/farm_tile.gd")

var farm_tiles_by_id: Dictionary = {}


func _ready() -> void:
	_cache_farm_tiles()

	if not data_manager.is_ready:
		push_error("main_world: cannot start gameplay because required game data failed to load")
		return

	var state_loaded: bool = false
	if save_manager.has_save():
		state_loaded = save_manager.load_game()

	if not state_loaded:
		save_manager.create_new_game()

	game_manager.start_gameplay()


func get_farming_save_state() -> Dictionary:
	var crops: Dictionary = {}
	var crop_growth: Dictionary = {}

	for tile_id_value: Variant in farm_tiles_by_id:
		var tile_id: String = String(tile_id_value)
		var tile: Variant = farm_tiles_by_id[tile_id]
		if bool(tile.call("is_empty")):
			continue

		crops[tile_id] = String(tile.get("crop_id"))
		crop_growth[tile_id] = float(tile.get("growth_elapsed"))

	return {
		"crops": crops,
		"crop_growth": crop_growth
	}


func apply_farming_save_state(state: Dictionary) -> void:
	for tile_value: Variant in farm_tiles_by_id.values():
		tile_value.call("clear_tile")

	var crops_value: Variant = state.get("crops", {})
	var growth_value: Variant = state.get("crop_growth", {})
	if typeof(crops_value) != TYPE_DICTIONARY or typeof(growth_value) != TYPE_DICTIONARY:
		return

	var crops: Dictionary = crops_value as Dictionary
	var crop_growth: Dictionary = growth_value as Dictionary
	for tile_id_value: Variant in crops:
		var tile_id: String = String(tile_id_value)
		if not farm_tiles_by_id.has(tile_id):
			continue

		var saved_crop_id: String = String(crops[tile_id_value])
		var saved_growth: float = float(crop_growth.get(tile_id, 0.0))
		var tile: Variant = farm_tiles_by_id[tile_id]
		if not bool(tile.call("apply_saved_crop", saved_crop_id, saved_growth)):
			push_error("main_world: failed to restore farming state for tile '%s'" % tile_id)


func has_farm_tile(tile_id: String) -> bool:
	return farm_tiles_by_id.has(tile_id)


func _cache_farm_tiles() -> void:
	farm_tiles_by_id.clear()
	for child: Node in $farm.get_children():
		if child.get_script() != farm_tile_script:
			continue

		var tile_id: String = String(child.get("tile_id"))
		if tile_id.is_empty():
			push_error("main_world: farm tile '%s' has no tile_id" % child.name)
			continue
		if farm_tiles_by_id.has(tile_id):
			push_error("main_world: duplicate farm tile id '%s'" % tile_id)
			continue

		farm_tiles_by_id[tile_id] = child


func _exit_tree() -> void:
	if game_manager.gameplay_active:
		save_manager.save_game()
		game_manager.stop_gameplay()
