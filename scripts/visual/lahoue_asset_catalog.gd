class_name LaHoueAssetCatalog
extends RefCounted

const asset_root: String = "res://assets/lahoue_assets/"
const manifest_root: String = asset_root + "manifests/"
const binding_path: String = "res://data/visual_asset_bindings.json"

const manifest_paths: Dictionary = {
	"world": "world_manifest.json",
	"characters": "character_manifest.json",
	"animals": "animal_manifest.json",
	"aquaculture": "aquaculture_manifest.json",
	"crops": "crop_manifest.json",
	"vehicles": "vehicle_manifest.json",
	"dishes": "dish_manifest.json",
	"ui": "ui_manifest.json",
}

static var _json_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _atlas_manifest_paths: Dictionary = {}
static var _atlas_texture_cache: Dictionary = {}


static func get_manifest_texture(manifest_id: String, section_id: String, semantic_id: String) -> Texture2D:
	var manifest: Dictionary = _get_named_manifest(manifest_id)
	var section_value: Variant = manifest.get(section_id, {})
	if typeof(section_value) != TYPE_DICTIONARY:
		return null
	var entry_value: Variant = (section_value as Dictionary).get(semantic_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return null
	var relative_path: String = String((entry_value as Dictionary).get("file", ""))
	return _load_texture(relative_path)


static func get_atlas_texture(atlas_id: String, semantic_id: String) -> Texture2D:
	var lookup_key: String = "%s::%s" % [atlas_id, semantic_id]
	if _atlas_texture_cache.has(lookup_key):
		return _atlas_texture_cache[lookup_key] as Texture2D
	var atlas_manifest: Dictionary = _get_atlas_manifest(atlas_id)
	if atlas_manifest.is_empty() or String(atlas_manifest.get("atlas_id", "")) != atlas_id:
		return null
	var component: Dictionary = {}
	var components_value: Variant = atlas_manifest.get("components", [])
	if typeof(components_value) == TYPE_ARRAY:
		for component_value: Variant in components_value:
			if typeof(component_value) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = component_value as Dictionary
			if String(candidate.get("semantic_id", "")) == semantic_id:
				component = candidate
				break
	if component.is_empty():
		return null
	var source_texture: Texture2D = _load_texture(String(atlas_manifest.get("image", "")))
	if source_texture == null:
		return null
	var region := Rect2(
		float(component.get("x", 0)),
		float(component.get("y", 0)),
		float(component.get("width", 0)),
		float(component.get("height", 0))
	)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return null
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = source_texture
	atlas_texture.region = region
	_atlas_texture_cache[lookup_key] = atlas_texture
	return atlas_texture


static func get_variant_texture(
	manifest_id: String,
	section_id: String,
	semantic_id: String,
	variant_id: String
) -> Texture2D:
	var manifest: Dictionary = _get_named_manifest(manifest_id)
	var section_value: Variant = manifest.get(section_id, {})
	if typeof(section_value) != TYPE_DICTIONARY:
		return null
	var entry_value: Variant = (section_value as Dictionary).get(semantic_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return null
	var variant_value: Variant = (entry_value as Dictionary).get(variant_id)
	var relative_path: String = ""
	if typeof(variant_value) == TYPE_STRING:
		relative_path = String(variant_value)
	elif typeof(variant_value) == TYPE_DICTIONARY:
		relative_path = String((variant_value as Dictionary).get("file", ""))
	return _load_texture(relative_path)


static func get_ui_texture(category_id: String, semantic_id: String) -> Texture2D:
	var manifest: Dictionary = _get_named_manifest("ui")
	var categories_value: Variant = manifest.get("categories", {})
	if typeof(categories_value) != TYPE_DICTIONARY:
		return null
	var category_value: Variant = (categories_value as Dictionary).get(category_id, {})
	if typeof(category_value) != TYPE_DICTIONARY:
		return null
	var entry_value: Variant = (category_value as Dictionary).get(semantic_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return null
	return _load_texture(String((entry_value as Dictionary).get("file", "")))


static func get_item_texture(item_id: String, context: String = "inventory") -> Texture2D:
	if context == "planting":
		var planting_id: String = get_bound_id("planting_icons", item_id)
		return get_ui_texture("planting_icons", planting_id)
	var crop_id: String = get_bound_id("harvest_items", item_id)
	if not crop_id.is_empty():
		return get_variant_texture("crops", "crops", crop_id, "harvest")
	var icon_id: String = get_bound_id("item_icons", item_id)
	return get_ui_texture("item_icons", icon_id)


static func get_dish_texture(recipe_id: String) -> Texture2D:
	var dish_id: String = get_bound_id("dish_icons", recipe_id)
	return get_manifest_texture("dishes", "dishes", dish_id)


static func has_manifest_asset(manifest_id: String, section_id: String, semantic_id: String) -> bool:
	return get_manifest_texture(manifest_id, section_id, semantic_id) != null


static func get_bound_id(binding_group: String, gameplay_id: String) -> String:
	var bindings: Dictionary = _load_json(binding_path)
	var group_value: Variant = bindings.get(binding_group, {})
	if typeof(group_value) != TYPE_DICTIONARY:
		return ""
	return String((group_value as Dictionary).get(gameplay_id, ""))


static func clear_runtime_cache() -> void:
	_json_cache.clear()
	_texture_cache.clear()
	_atlas_manifest_paths.clear()
	_atlas_texture_cache.clear()


static func _get_named_manifest(manifest_id: String) -> Dictionary:
	var filename: String = String(manifest_paths.get(manifest_id, ""))
	if filename.is_empty():
		return {}
	return _load_json(manifest_root + filename)


static func _get_atlas_manifest(atlas_id: String) -> Dictionary:
	if _atlas_manifest_paths.is_empty():
		var atlas_index: Dictionary = _load_json(manifest_root + "atlas_manifest.json")
		var atlas_paths_value: Variant = atlas_index.get("atlases", {})
		if typeof(atlas_paths_value) == TYPE_DICTIONARY:
			_atlas_manifest_paths = (atlas_paths_value as Dictionary).duplicate(true)
	var relative_path: String = String(_atlas_manifest_paths.get(atlas_id, ""))
	if relative_path.is_empty():
		return {}
	return _load_json(asset_root + relative_path)


static func _load_json(path: String) -> Dictionary:
	if _json_cache.has(path):
		return _json_cache[path] as Dictionary
	if not FileAccess.file_exists(path):
		push_warning("LaHoue asset manifest is missing: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LaHoue asset manifest is invalid: %s" % path)
		return {}
	var result: Dictionary = parsed as Dictionary
	_json_cache[path] = result
	return result


static func _load_texture(relative_path: String) -> Texture2D:
	if relative_path.is_empty():
		return null
	var resource_path: String = relative_path if relative_path.begins_with("res://") else asset_root + relative_path
	if _texture_cache.has(resource_path):
		return _texture_cache[resource_path] as Texture2D
	if not ResourceLoader.exists(resource_path):
		push_warning("LaHoue texture is missing: %s" % resource_path)
		return null
	var texture: Texture2D = load(resource_path) as Texture2D
	if texture != null:
		_texture_cache[resource_path] = texture
	return texture
