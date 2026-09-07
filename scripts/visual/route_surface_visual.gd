@tool
class_name LaHoueRouteSurfaceVisual
extends Node2D

@export var route_path: NodePath
@export var surface_width: float = 48.0:
	set(value):
		surface_width = value
		queue_redraw()
@export var edge_color: Color = Color("#4c493d"):
	set(value):
		edge_color = value
		queue_redraw()
@export var surface_color: Color = Color("#736b59"):
	set(value):
		surface_color = value
		queue_redraw()
@export var wear_color: Color = Color(0.20, 0.18, 0.15, 0.18)
@export var tire_wear: bool = false


func _ready() -> void:
	queue_redraw.call_deferred()


func _draw() -> void:
	var points: PackedVector2Array = get_visual_points()
	if points.size() < 2:
		return
	for index: int in range(points.size() - 1):
		_draw_isometric_ribbon(points[index], points[index + 1])
	for point: Vector2 in points:
		_draw_isometric_junction(point)
	if tire_wear:
		_draw_tire_wear(points)


func _draw_isometric_ribbon(start: Vector2, end: Vector2) -> void:
	var direction: Vector2 = start.direction_to(end)
	if direction == Vector2.ZERO:
		return
	var normal := Vector2(-direction.y, direction.x)
	var half_width: float = surface_width * 0.5
	var edge_half: float = half_width + 6.0
	var edge_points: PackedVector2Array = _make_worn_ribbon(start, end, normal, edge_half, 48.0, 3.0)
	draw_colored_polygon(edge_points, edge_color)
	var surface_points: PackedVector2Array = _make_worn_ribbon(start, end, normal, half_width, 44.0, 1.8)
	draw_colored_polygon(surface_points, surface_color)
	draw_line(
		start + normal * half_width * 0.62,
		end + normal * half_width * 0.62,
		Color(0.92, 0.86, 0.72, 0.07),
		1.2,
		true
	)
	var length: float = start.distance_to(end)
	var wear_step: float = 76.0
	var offset: float = wear_step * 0.5
	while offset < length:
		var center: Vector2 = start + direction * offset
		draw_line(center - direction * 11.0 - normal * 3.0, center + direction * 11.0 + normal * 3.0, Color(0.23, 0.21, 0.17, 0.10), 1.2, true)
		offset += wear_step


func _make_worn_ribbon(
	start: Vector2,
	end: Vector2,
	normal: Vector2,
	half_width: float,
	step_size: float,
	jitter: float
) -> PackedVector2Array:
	var distance: float = start.distance_to(end)
	var steps: int = maxi(2, ceili(distance / step_size))
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for index: int in range(steps + 1):
		var ratio: float = float(index) / float(steps)
		var point: Vector2 = start.lerp(end, ratio)
		var edge_jitter: float = (float((index * 7) % 5) - 2.0) * jitter * 0.5
		top.append(point - normal * (half_width + edge_jitter))
		bottom.append(point + normal * (half_width - edge_jitter * 0.7))
	var polygon := PackedVector2Array()
	for point: Vector2 in top:
		polygon.append(point)
	for index: int in range(bottom.size() - 1, -1, -1):
		polygon.append(bottom[index])
	return polygon


func _draw_isometric_junction(point: Vector2) -> void:
	var edge_half := Vector2(surface_width * 0.68, surface_width * 0.35)
	var edge_diamond := PackedVector2Array([
		point + Vector2(0.0, -edge_half.y - 4.0),
		point + Vector2(edge_half.x + 5.0, 0.0),
		point + Vector2(0.0, edge_half.y + 4.0),
		point + Vector2(-edge_half.x - 5.0, 0.0),
	])
	draw_colored_polygon(edge_diamond, edge_color)
	var diamond := PackedVector2Array([
		point + Vector2(0.0, -edge_half.y),
		point + Vector2(edge_half.x, 0.0),
		point + Vector2(0.0, edge_half.y),
		point + Vector2(-edge_half.x, 0.0),
	])
	draw_colored_polygon(diamond, surface_color)


func get_visual_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var route: Node = get_node_or_null(route_path)
	if route == null:
		return points
	for child: Node in route.get_children():
		if child is Marker2D:
			points.append(to_local((child as Marker2D).global_position))
	if points.size() >= 2:
		return points
	if route is Path2D and (route as Path2D).curve != null:
		for point: Vector2 in (route as Path2D).curve.get_baked_points():
			points.append(to_local((route as Path2D).to_global(point)))
	return points


func _draw_tire_wear(points: PackedVector2Array) -> void:
	for index: int in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var direction: Vector2 = start.direction_to(end)
		if direction == Vector2.ZERO:
			continue
		var normal := Vector2(-direction.y, direction.x)
		for side: float in [-1.0, 1.0]:
			draw_line(
				start + normal * side * surface_width * 0.18,
				end + normal * side * surface_width * 0.18,
				wear_color,
				1.5,
				true
			)
