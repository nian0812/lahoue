class_name LaHoueVehicleVisual
extends Node2D

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const manifest_sprite: GDScript = preload("res://scripts/visual/manifest_sprite.gd")

@export_enum("truck", "helicopter") var vehicle_kind: String = "truck"
@export_range(1, 5, 1) var vehicle_level: int = 1
@export var target_rect: Rect2 = Rect2(-40.0, -24.0, 80.0, 44.0)

@onready var visual_root: Node2D = $VisualRoot
@onready var artwork: Sprite2D = $VisualRoot/AssetArtwork
var presentation_direction: String = "e"
var _rotor: Sprite2D
var _rotor_speed: float = 0.0


func _ready() -> void:
	set_vehicle_level(vehicle_level)


func set_vehicle_level(value: int) -> bool:
	vehicle_level = clampi(value, 1, 5)
	if not is_node_ready():
		return true
	var approved: Texture2D = asset_catalog.get_v3_texture("trucks/truck_%d_%s" % [vehicle_level,presentation_direction] if vehicle_kind == "truck" else "helicopters/body_%d" % vehicle_level)
	if approved != null:
		manifest_sprite.configure_sprite(artwork,approved,target_rect)
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		artwork.visible = true
		_set_fallback_visible(false)
		return true
	var binding_group: String = "%s_levels" % vehicle_kind
	var asset_id: String = asset_catalog.get_bound_id(binding_group, str(vehicle_level))
	# The supplied truck_lv1 PNG is an entire depot. Use the verified isolated
	# Lv2 truck as a presentation fallback; Lv1 capacity/cost/timers stay Lv1.
	if vehicle_kind == "truck" and vehicle_level == 1:
		asset_id = "truck_lv2"
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


func present_vehicle(direction_value: Vector2, phase: String, delta: float) -> void:
	if vehicle_kind == "truck":
		if not direction_value.is_zero_approx():
			var next: String = ("e" if direction_value.x > 0 else "w") if absf(direction_value.x) >= absf(direction_value.y) else ("s" if direction_value.y > 0 else "n")
			if next != presentation_direction:
				presentation_direction = next
				set_vehicle_level(vehicle_level)
	else:
		if _rotor == null:
			_rotor = Sprite2D.new()
			_rotor.name = "ApprovedMainRotor"
			visual_root.add_child(_rotor)
		var active: bool = phase in ["departing","importing","returning"]
		_rotor_speed = move_toward(_rotor_speed,1.0 if active else 0.0,delta*1.4)
		var key: String = "main_%d" % vehicle_level if _rotor_speed < 0.1 else "rotor_slow" if _rotor_speed < 0.4 else "rotor_medium" if _rotor_speed < 0.75 else "rotor_fast"
		_rotor.texture = asset_catalog.get_v3_texture("helicopters/"+key)
		if _rotor.texture != null:
			_rotor.visible = true
			_rotor.texture_filter = artwork.texture_filter
			_rotor.scale = Vector2.ONE * (target_rect.size.x * 0.9 / _rotor.texture.get_width())
			_rotor.position = artwork.position + Vector2(-2,-artwork.texture.get_height()*artwork.scale.y*0.25)
			_rotor.z_index = artwork.z_index + 1


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
