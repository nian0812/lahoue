extends Node

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const warehouse_scene: PackedScene = preload("res://scenes/buildings/warehouse.tscn")
const farm_tile_scene: PackedScene = preload("res://scenes/farming/farm_tile.tscn")
const truck_visual_scene: PackedScene = preload("res://scenes/vehicles/truck_visual.tscn")

const asset_root: String = "res://assets/lahoue_assets/"

var failures: int = 0


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_static_asset_test"):
		push_error("static_asset_integration_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_validate_package_paths()
	_validate_atlas_regions()
	_validate_bindings()
	await _validate_visual_nodes()
	_validate_crop_stages()

	if failures == 0:
		print("static_asset_integration_test: PASS")
	else:
		push_error("static_asset_integration_test: FAIL (%d failures)" % failures)
	get_tree().quit(failures)


func _validate_package_paths() -> void:
	_expect(FileAccess.file_exists(asset_root + "README.md"), "package README missing")
	var package: Dictionary = _read_json(asset_root + "manifests/asset_manifest.json")
	for relative_value: Variant in (package.get("manifests", {}) as Dictionary).values():
		_expect(FileAccess.file_exists(asset_root + String(relative_value)), "manifest missing: %s" % relative_value)

	var world: Dictionary = _read_json(asset_root + "manifests/world_manifest.json")
	for section_id: String in ["buildings", "environment", "farm_plots", "props"]:
		_validate_simple_entries(world.get(section_id, {}) as Dictionary)
	for manifest_file: String in ["character_manifest.json", "animal_manifest.json", "aquaculture_manifest.json", "vehicle_manifest.json", "dish_manifest.json"]:
		var manifest: Dictionary = _read_json(asset_root + "manifests/" + manifest_file)
		for value: Variant in manifest.values():
			if typeof(value) == TYPE_DICTIONARY:
				_validate_simple_entries(value as Dictionary)

	var crops: Dictionary = _read_json(asset_root + "manifests/crop_manifest.json")
	for crop_value: Variant in (crops.get("crops", {}) as Dictionary).values():
		for relative_value: Variant in (crop_value as Dictionary).values():
			_validate_resource_path(String(relative_value))

	var ui: Dictionary = _read_json(asset_root + "manifests/ui_manifest.json")
	for category_value: Variant in (ui.get("categories", {}) as Dictionary).values():
		_validate_simple_entries(category_value as Dictionary)


func _validate_simple_entries(entries: Dictionary) -> void:
	for entry_value: Variant in entries.values():
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var relative_path: String = String((entry_value as Dictionary).get("file", ""))
		if not relative_path.is_empty():
			_validate_resource_path(relative_path)


func _validate_resource_path(relative_path: String) -> void:
	var path: String = asset_root + relative_path
	_expect(FileAccess.file_exists(path), "asset file missing: %s" % relative_path)
	_expect(ResourceLoader.exists(path), "asset was not imported: %s" % relative_path)


func _validate_atlas_regions() -> void:
	var index: Dictionary = _read_json(asset_root + "manifests/atlas_manifest.json")
	var seen_keys: Dictionary = {}
	for atlas_id_value: Variant in (index.get("atlases", {}) as Dictionary):
		var atlas_id: String = String(atlas_id_value)
		var relative_manifest: String = String((index.get("atlases", {}) as Dictionary)[atlas_id_value])
		var manifest: Dictionary = _read_json(asset_root + relative_manifest)
		_expect(String(manifest.get("atlas_id", "")) == atlas_id, "atlas id mismatch: %s" % atlas_id)
		_validate_resource_path(String(manifest.get("image", "")))
		for component_value: Variant in manifest.get("components", []) as Array:
			var component: Dictionary = component_value as Dictionary
			var semantic_id: String = String(component.get("semantic_id", ""))
			var lookup_key: String = "%s::%s" % [atlas_id, semantic_id]
			_expect(not seen_keys.has(lookup_key), "duplicate atlas lookup key: %s" % lookup_key)
			seen_keys[lookup_key] = true
			var texture: Texture2D = asset_catalog.get_atlas_texture(atlas_id, semantic_id)
			_expect(texture is AtlasTexture, "atlas texture missing: %s" % lookup_key)
			if texture is AtlasTexture:
				var expected := Rect2(
					float(component.get("x", 0)), float(component.get("y", 0)),
					float(component.get("width", 0)), float(component.get("height", 0))
				)
				_expect((texture as AtlasTexture).region == expected, "atlas region mismatch: %s" % lookup_key)


func _validate_bindings() -> void:
	var bindings: Dictionary = _read_json("res://data/visual_asset_bindings.json")
	_expect((bindings.get("dish_icons", {}) as Dictionary).size() == 10, "uncertain dish mappings were added")
	for recipe_id_value: Variant in (bindings.get("dish_icons", {}) as Dictionary):
		_expect(asset_catalog.get_dish_texture(String(recipe_id_value)) != null, "dish binding failed: %s" % recipe_id_value)
	for item_id_value: Variant in (bindings.get("planting_icons", {}) as Dictionary):
		_expect(asset_catalog.get_item_texture(String(item_id_value), "planting") != null, "planting icon binding failed: %s" % item_id_value)
	for item_id_value: Variant in (bindings.get("item_icons", {}) as Dictionary):
		_expect(asset_catalog.get_item_texture(String(item_id_value), "inventory") != null, "item icon binding failed: %s" % item_id_value)
	for achievement_id_value: Variant in (bindings.get("achievement_badges", {}) as Dictionary):
		var semantic_id: String = asset_catalog.get_bound_id("achievement_badges", String(achievement_id_value))
		_expect(asset_catalog.get_atlas_texture("achievement_badges_and_emblems_sheet", semantic_id) != null, "achievement badge binding failed")


func _validate_visual_nodes() -> void:
	var warehouse: Node = warehouse_scene.instantiate()
	add_child(warehouse)
	await get_tree().process_frame
	var artwork: Sprite2D = warehouse.get_node_or_null("VisualRoot/AssetArtwork") as Sprite2D
	var fallback: CanvasItem = warehouse.get_node_or_null("VisualRoot/body") as CanvasItem
	_expect(artwork != null and artwork.texture != null, "warehouse artwork was not installed")
	_expect(fallback != null and not fallback.visible, "warehouse placeholder was not hidden")
	warehouse.queue_free()

	var truck: Node = truck_visual_scene.instantiate()
	add_child(truck)
	await get_tree().process_frame
	_expect(bool(truck.call("set_vehicle_level", 5)), "truck Lv5 artwork failed")
	var truck_artwork: Sprite2D = truck.get_node_or_null("VisualRoot/AssetArtwork") as Sprite2D
	_expect(truck_artwork != null and truck_artwork.texture != null, "truck artwork is missing")
	truck.queue_free()


func _validate_crop_stages() -> void:
	save_manager.create_new_game()
	var tile: Node = farm_tile_scene.instantiate()
	tile.set("tile_id", "asset_test_tile")
	add_child(tile)
	_expect(bool(tile.call("plant_seed", "rice")), "test crop could not be planted")
	var crop_artwork: Sprite2D = tile.get_node_or_null("VisualRoot/CropArtwork") as Sprite2D
	_expect(crop_artwork.texture == asset_catalog.get_variant_texture("crops", "crops", "rice", "stage_1"), "crop stage_1 mapping failed")
	var growth_time: float = data_manager.get_crop_growth_time_seconds("rice")
	tile.call("advance_growth", growth_time * 0.3)
	_expect(crop_artwork.texture == asset_catalog.get_variant_texture("crops", "crops", "rice", "stage_2"), "crop stage_2 mapping failed")
	tile.call("advance_growth", growth_time)
	var stage_four: Texture2D = asset_catalog.get_variant_texture("crops", "crops", "rice", "stage_4")
	var harvest: Texture2D = asset_catalog.get_variant_texture("crops", "crops", "rice", "harvest")
	_expect(crop_artwork.texture == stage_four, "ready crop does not use stage_4")
	_expect(crop_artwork.texture != harvest, "world crop incorrectly uses harvest inventory artwork")
	tile.queue_free()
	game_manager.stop_gameplay()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("static_asset_integration_test: %s" % message)
