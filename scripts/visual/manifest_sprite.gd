class_name LaHoueManifestSprite
extends Node2D

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")

@export var manifest_id: String = "world"
@export var section_id: String = "buildings"
@export var semantic_id: String = ""
@export var atlas_id: String = ""
@export var target_rect: Rect2 = Rect2(-32.0, -64.0, 64.0, 64.0)
@export var placeholder_paths: PackedStringArray = PackedStringArray()
@export var artwork_z_index: int = 0
@export var modulate_when_disabled: Color = Color(0.55, 0.55, 0.55, 1.0)

var artwork: Sprite2D


func _ready() -> void:
	refresh_artwork()


func refresh_artwork() -> bool:
	var resolved_id: String = semantic_id
	if resolved_id.is_empty() and get_parent() != null:
		var parent_id: Variant = get_parent().get("building_id")
		if parent_id != null:
			resolved_id = String(parent_id)
	var texture: Texture2D = (
		asset_catalog.get_atlas_texture(atlas_id, resolved_id)
		if not atlas_id.is_empty()
		else asset_catalog.get_manifest_texture(manifest_id, section_id, resolved_id)
	)
	if texture == null:
		return false
	artwork = get_node_or_null("AssetArtwork") as Sprite2D
	if artwork == null:
		artwork = Sprite2D.new()
		artwork.name = "AssetArtwork"
		add_child(artwork)
	artwork.texture = texture
	artwork.centered = true
	artwork.z_index = artwork_z_index
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var resolved_rect: Rect2 = target_rect
	if resolved_rect.size.x <= 0.0 or resolved_rect.size.y <= 0.0:
		var parent_size: Variant = get_parent().get("building_size") if get_parent() != null else null
		if parent_size is Vector2:
			var size: Vector2 = parent_size as Vector2
			resolved_rect = Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	_fit_bottom_centered(artwork, resolved_rect)
	for placeholder_path: String in placeholder_paths:
		var placeholder: CanvasItem = get_node_or_null(NodePath(placeholder_path)) as CanvasItem
		if placeholder != null:
			placeholder.visible = false
	return true


func set_artwork_enabled(enabled: bool) -> void:
	if artwork == null:
		return
	artwork.modulate = Color.WHITE if enabled else modulate_when_disabled


func set_artwork_modulate(color: Color) -> void:
	if artwork != null:
		artwork.modulate = color


func set_semantic_id(value: String) -> bool:
	semantic_id = value
	return refresh_artwork()


func set_artwork_visible(value: bool) -> void:
	if artwork != null:
		artwork.visible = value


static func configure_sprite(sprite: Sprite2D, texture: Texture2D, rect: Rect2) -> bool:
	if sprite == null or texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	sprite.texture = texture
	sprite.centered = true
	_fit_bottom_centered(sprite, rect)
	return true


static func _fit_bottom_centered(sprite: Sprite2D, rect: Rect2) -> void:
	var texture_size: Vector2 = sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var uniform_scale: float = minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	sprite.scale = Vector2.ONE * uniform_scale
	var scaled_height: float = texture_size.y * uniform_scale
	sprite.position = Vector2(rect.get_center().x, rect.end.y - scaled_height * 0.5)
