extends Node2D

## Empty, open-ended loading shelter. Doors face the existing eastbound road.
func _ready() -> void:
	get_parent().target_rect = Rect2(-90,-150,180,150)
	if get_parent().use_approved("buildings/depot"):
		get_parent().call("set_artwork_visible",true)
		set_meta("road_facing", Vector2.RIGHT)
		return
	get_parent().call("set_artwork_visible", false)
	z_index = -1
	set_meta("road_facing", Vector2.RIGHT)
	queue_redraw()


func _draw() -> void:
	if get_parent().approved_id == "buildings/depot": return
	draw_colored_polygon(PackedVector2Array([Vector2(-80,-26),Vector2(-28,-48),Vector2(34,-13),Vector2(-18,12)]),Color("#a89370"))
	draw_colored_polygon(PackedVector2Array([Vector2(-80,-26),Vector2(-80,-76),Vector2(-28,-98),Vector2(-28,-48)]),Color("#66533f"))
	draw_colored_polygon(PackedVector2Array([Vector2(-28,-98),Vector2(34,-63),Vector2(34,-13),Vector2(-28,-48)]),Color("#7c6549"))
	draw_line(Vector2(-80,-26),Vector2(-80,-76),Color("#40372b"),5.0,true)
	draw_line(Vector2(-18,12),Vector2(-18,-38),Color("#40372b"),5.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-88,-76),Vector2(-30,-103),Vector2(42,-63),Vector2(-17,-36)]),Color("#787267"))
	for index: int in range(7):
		var start := Vector2(-86,-75).lerp(Vector2(-29,-100),index/6.0)
		draw_line(start,start+Vector2(67,36),Color("#a69c88"),1.0,true)
	# Loading chevrons join the real route to the right; no baked truck.
	for index: int in range(3):
		var center := Vector2(10 + index*18,19)
		draw_polyline(PackedVector2Array([center+Vector2(-4,-4),center+Vector2(4,0),center+Vector2(-4,4)]),Color("#c6aa70"),2.0,true)
