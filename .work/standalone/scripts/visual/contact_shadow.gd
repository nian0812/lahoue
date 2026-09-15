@tool
class_name LaHoueContactShadow
extends Node2D

@export var shadow_size: Vector2 = Vector2(72.0, 18.0):
	set(value):
		shadow_size = value
		queue_redraw()
@export var shadow_offset: Vector2 = Vector2(0.0, -2.0):
	set(value):
		shadow_offset = value
		queue_redraw()
@export_range(0.0, 0.5, 0.01) var opacity: float = 0.18:
	set(value):
		opacity = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if shadow_size.x <= 0.0 or shadow_size.y <= 0.0 or opacity <= 0.0:
		return
	# A shallow sheared footprint reads as contact grounding in the same 2.5D
	# projection as the artwork, without producing a conspicuous circular patch.
	_draw_sheared_shadow(shadow_offset + Vector2(4.0, 1.5), shadow_size * 0.52, Color(0.025, 0.035, 0.025, opacity * 0.26))
	_draw_sheared_shadow(shadow_offset + Vector2(2.0, 0.5), shadow_size * Vector2(0.38, 0.30), Color(0.02, 0.025, 0.02, opacity * 0.72))


func _draw_sheared_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		var local_y: float = sin(angle) * radii.y
		points.append(center + Vector2(cos(angle) * radii.x + local_y * 0.62, local_y))
	draw_colored_polygon(points, color)
