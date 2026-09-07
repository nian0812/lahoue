class_name LaHoueVehicleVisual
extends Node2D

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const manifest_sprite: GDScript = preload("res://scripts/visual/manifest_sprite.gd")

@export_enum("truck", "helicopter") var vehicle_kind: String = "truck"
@export_range(1, 5, 1) var vehicle_level: int = 1
@export var target_rect: Rect2 = Rect2(-40.0, -24.0, 80.0, 44.0)

@onready var visual_root: Node2D = $VisualRoot
@onready var artwork: Sprite2D = $VisualRoot/AssetArtwork


func _ready() -> void:
	set_vehicle_level(vehicle_level)


func set_vehicle_level(value: int) -> bool:
	vehicle_level = clampi(value, 1, 5)
	if not is_node_ready():
		return true
	var binding_group: String = "%s_levels" % vehicle_kind
	var asset_id: String = asset_catalog.get_bound_id(binding_group, str(vehicle_level))
	var manifest_section: String = "trucks" if vehicle_kind == "truck" else "helicopters"
	var texture: Texture2D = asset_catalog.get_manifest_texture("vehicles", manifest_section, asset_id)
	if texture == null:
		artwork.visible = false
		_set_fallback_visible(true)
		return false
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var normalized_texture: Texture2D = _get_opaque_region_texture(texture)
	manifest_sprite.configure_sprite(artwork, normalized_texture, target_rect)
	artwork.visible = true
	_set_fallback_visible(false)
	return true


func _get_opaque_region_texture(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return texture
	if used_rect.position == Vector2i.ZERO and used_rect.size == image.get_size():
		return texture
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(used_rect)
	return atlas_texture


func _set_fallback_visible(value: bool) -> void:
	for child: Node in visual_root.get_children():
		if child == artwork:
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = value
