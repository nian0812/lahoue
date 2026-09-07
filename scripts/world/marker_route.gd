extends Path2D

@export var close_route: bool = false


func _ready() -> void:
	rebuild_curve()


func rebuild_curve() -> void:
	var rebuilt: Curve2D = Curve2D.new()
	for child: Node in get_children():
		if child is Marker2D:
			rebuilt.add_point((child as Marker2D).position)
	if close_route and rebuilt.point_count > 1:
		rebuilt.add_point(rebuilt.get_point_position(0))
	curve = rebuilt
