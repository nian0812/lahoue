class_name LaHoueAnimationPresenter
extends Node

## Presentation only. Empty frame libraries leave the integrated artwork untouched.
signal loop_changed(state: String, direction: String)
signal action_requested(action: String, context: Dictionary)

@export var artwork_path: NodePath
@export var frame_library: Dictionary[String, SpriteFrames] = {}
@export var foot_anchors: Dictionary[String, Vector2] = {}

var identity: String = ""
var state: String = "idle"
var direction: String = "s"
var snapshot: Dictionary = {}
var _animated: AnimatedSprite2D
var _static: Sprite2D
var _static_color: Color = Color.WHITE
var _action_active: bool = false
var _active_identity: String = ""
var _playback_active: bool = true


func present(value: Dictionary) -> void:
	var next_identity: String = String(value.get("identity", ""))
	var next_state: String = String(value.get("state", "idle"))
	var next_direction: String = String(value.get("direction", direction))
	var changed: bool = next_identity != identity or next_state != state or next_direction != direction
	if next_identity != identity or (next_state != state and next_state in ["empty", "completed", "off_duty"]):
		cancel_action()
	identity = next_identity
	state = next_state
	direction = next_direction
	snapshot = value.duplicate(true)
	if changed:
		loop_changed.emit(state, direction)
	if not _action_active:
		_play_clip(state)
	_sync_artwork_style()


func request_action(action: String, context: Dictionary = {}) -> void:
	action_requested.emit(action, context.duplicate(true))
	if not _has_clip(action):
		return
	# One-shot playback never calls back into gameplay or delays its transitions.
	if _get_frames().get_animation_loop(_clip_name(action)):
		return
	_action_active = _play_clip(action, true)
	_sync_artwork_style()


func cancel_action() -> void:
	_action_active = false
	_restore_static()


func set_playback_active(value: bool) -> void:
	_playback_active = value
	if is_instance_valid(_animated):
		_animated.speed_scale = 1.0 if value else 0.0


func _get_frames() -> SpriteFrames:
	if frame_library.has(identity): return frame_library.get(identity) as SpriteFrames
	return load("res://scripts/visual/lahoue_asset_catalog.gd").get_v3_frames(identity)


func _clip_name(action: String) -> StringName:
	# A directionless clip must be explicitly supplied. Walk always needs its direction.
	var directional := StringName("%s_%s" % [action, direction])
	var frames: SpriteFrames = _get_frames()
	if frames != null and not frames.has_animation(directional) and (action != "walk" or frames.has_animation("walk_default")):
		return StringName("%s_default" % action)
	return directional


func _has_clip(action: String) -> bool:
	var frames: SpriteFrames = _get_frames()
	return frames != null and frames.has_animation(_clip_name(action)) and frames.get_frame_count(_clip_name(action)) > 0


func _play_clip(action: String, restart: bool = false) -> bool:
	if not _has_clip(action) or artwork_path.is_empty():
		_restore_static()
		return false
	var artwork := get_node_or_null(artwork_path) as Sprite2D
	if artwork == null or artwork.texture == null:
		_restore_static()
		return false
	if _static != artwork:
		_restore_static()
		_static = artwork
		_static_color = artwork.self_modulate
	if _animated == null:
		_animated = AnimatedSprite2D.new()
		_animated.name = "animation_artwork"
		artwork.get_parent().add_child(_animated)
		_animated.animation_finished.connect(_on_animation_finished)
	var frames: SpriteFrames = _get_frames()
	var clip: StringName = _clip_name(action)
	var texture: Texture2D = frames.get_frame_texture(clip, 0)
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		_restore_static()
		return false
	if restart or not _animated.is_playing() or _animated.sprite_frames != frames or _animated.animation != clip or _active_identity != identity:
		_animated.sprite_frames = frames
		_animated.play(clip)
		if restart:
			_animated.set_frame_and_progress(0, 0.0)
	_active_identity = identity
	_animated.speed_scale = 1.0 if _playback_active else 0.0
	# Fit the entire authored canvas once, never trim/refit individual frames.
	var size: Vector2 = texture.get_size()
	var original_size: Vector2 = artwork.texture.get_size() * artwork.scale.abs()
	var uniform_scale: float = original_size.y / size.y
	_animated.scale = Vector2.ONE * uniform_scale
	_animated.centered = false
	_animated.offset = -size * foot_anchors.get(identity, Vector2(0.5, 1.0))
	_animated.position = artwork.position + Vector2(0.0, original_size.y * 0.5)
	_animated.visible = artwork.visible
	_static.self_modulate = Color(_static_color.r, _static_color.g, _static_color.b, 0.0)
	return true


func _sync_artwork_style() -> void:
	if is_instance_valid(_animated) and is_instance_valid(_static):
		_animated.modulate = _static.modulate * _static_color
		_animated.visible = _static.visible
		_animated.texture_filter = _static.texture_filter
		_animated.z_index = _static.z_index


func _restore_static() -> void:
	if is_instance_valid(_animated):
		_animated.visible = false
		_animated.stop()
	if is_instance_valid(_static):
		_static.self_modulate = _static_color
	_static = null


func _on_animation_finished() -> void:
	_action_active = false
	_play_clip(state)


func _exit_tree() -> void:
	_restore_static()
	if is_instance_valid(_animated):
		_animated.queue_free()
