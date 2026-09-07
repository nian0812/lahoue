extends Node

signal bounds_changed(bounds: Rect2)

@export var camera_path: NodePath = NodePath("../player/camera")
@export var boundary_body_path: NodePath = NodePath("../world_boundaries")
@export var boundary_thickness: float = 64.0

var current_bounds: Rect2 = Rect2()


func _ready() -> void:
	if not get_tree().node_added.is_connected(_on_tree_node_changed):
		get_tree().node_added.connect(_on_tree_node_changed)
	if not get_tree().node_removed.is_connected(_on_tree_node_removed):
		get_tree().node_removed.connect(_on_tree_node_removed)
	refresh_bounds.call_deferred()


func refresh_bounds() -> Rect2:
	var world: Node = get_parent()
	var combined: Rect2 = Rect2()
	var has_bounds: bool = false
	for zone_value: Variant in get_tree().get_nodes_in_group("world_zones"):
		var zone: Node2D = zone_value as Node2D
		if zone == null or not world.is_ancestor_of(zone):
			continue
		var zone_bounds: Rect2 = _get_zone_bounds(zone)
		if zone_bounds.size.x <= 0.0 or zone_bounds.size.y <= 0.0:
			continue
		combined = zone_bounds if not has_bounds else combined.merge(zone_bounds)
		has_bounds = true
	if not has_bounds:
		return current_bounds
	current_bounds = combined
	_apply_camera_limits(combined)
	_apply_world_boundaries(combined)
	bounds_changed.emit(combined)
	return current_bounds


func _get_zone_bounds(zone: Node2D) -> Rect2:
	if zone.has_method("get_world_bounds"):
		return zone.call("get_world_bounds") as Rect2
	var local_rect: Rect2 = zone.get_meta("local_bounds", Rect2()) as Rect2
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return Rect2()
	var minimum: Vector2 = zone.to_global(local_rect.position)
	var maximum: Vector2 = zone.to_global(local_rect.position + local_rect.size)
	return Rect2(minimum.min(maximum), (maximum - minimum).abs())


func _apply_camera_limits(bounds: Rect2) -> void:
	var camera: Camera2D = get_node_or_null(camera_path) as Camera2D
	if camera == null:
		return
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


func _apply_world_boundaries(bounds: Rect2) -> void:
	var body: StaticBody2D = get_node_or_null(boundary_body_path) as StaticBody2D
	if body == null:
		return
	var half: float = boundary_thickness * 0.5
	_configure_boundary(body, "top", Vector2(bounds.get_center().x, bounds.position.y - half), Vector2(bounds.size.x + boundary_thickness * 2.0, boundary_thickness))
	_configure_boundary(body, "bottom", Vector2(bounds.get_center().x, bounds.end.y + half), Vector2(bounds.size.x + boundary_thickness * 2.0, boundary_thickness))
	_configure_boundary(body, "left", Vector2(bounds.position.x - half, bounds.get_center().y), Vector2(boundary_thickness, bounds.size.y))
	_configure_boundary(body, "right", Vector2(bounds.end.x + half, bounds.get_center().y), Vector2(boundary_thickness, bounds.size.y))


func _configure_boundary(body: StaticBody2D, node_name: String, target_position: Vector2, target_size: Vector2) -> void:
	var collision: CollisionShape2D = body.get_node_or_null(node_name) as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = node_name
		body.add_child(collision)
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = target_size
	collision.global_position = target_position


func _on_tree_node_changed(node: Node) -> void:
	if node != null and node.is_in_group("world_zones"):
		refresh_bounds.call_deferred()


func _on_tree_node_removed(node: Node) -> void:
	if node != null and (
		node.has_method("get_world_bounds")
		or not String(node.get_meta("zone_id", "")).is_empty()
	):
		refresh_bounds.call_deferred()
