@tool
class_name LaHoueZoneGroundVisual
extends Node2D

enum ground_profile {
	WORLD_GRASS,
	FARM,
	ANIMAL,
	AQUACULTURE,
	VILLAGE,
	RESTAURANT,
	LOGISTICS,
	PREMIUM,
}

@export_enum(
	"World Grass", "Farm", "Animal", "Aquaculture",
	"Village", "Restaurant", "Logistics", "Premium"
) var profile: int = ground_profile.WORLD_GRASS:
	set(value):
		profile = value
		queue_redraw()
@export var area_rect: Rect2 = Rect2(0.0, 0.0, 320.0, 240.0):
	set(value):
		area_rect = value
		queue_redraw()
@export var detail_seed: int = 1:
	set(value):
		detail_seed = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if area_rect.size.x <= 0.0 or area_rect.size.y <= 0.0:
		return
	match profile:
		ground_profile.WORLD_GRASS:
			_draw_world_grass()
		ground_profile.FARM:
			_draw_farm_ground()
		ground_profile.ANIMAL:
			_draw_animal_ground()
		ground_profile.AQUACULTURE:
			_draw_aquaculture_ground()
		ground_profile.VILLAGE:
			_draw_village_ground()
		ground_profile.RESTAURANT:
			_draw_restaurant_ground()
		ground_profile.LOGISTICS:
			_draw_logistics_ground()
		ground_profile.PREMIUM:
			_draw_premium_ground()


func _draw_world_grass() -> void:
	draw_rect(area_rect, Color("#31583a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	var patch_count: int = clampi(int(area_rect.get_area() / 21000.0), 36, 120)
	for index: int in range(patch_count):
		var center := Vector2(
			rng.randf_range(area_rect.position.x, area_rect.end.x),
			rng.randf_range(area_rect.position.y, area_rect.end.y)
		)
		var patch_size := Vector2(rng.randf_range(28.0, 76.0), rng.randf_range(8.0, 20.0))
		var patch_color: Color = (
			Color(0.12, 0.24, 0.14, rng.randf_range(0.025, 0.060))
			if index % 2 == 0
			else Color(0.46, 0.58, 0.30, rng.randf_range(0.018, 0.045))
		)
		_draw_irregular_iso_patch(center, patch_size, patch_color, index)
	for index: int in range(patch_count):
		var blade_base := Vector2(
			rng.randf_range(area_rect.position.x + 10.0, area_rect.end.x - 10.0),
			rng.randf_range(area_rect.position.y + 10.0, area_rect.end.y - 10.0)
		)
		var blade_color := Color(0.48, 0.62, 0.31, rng.randf_range(0.10, 0.22))
		draw_line(blade_base, blade_base + Vector2(-2.0, -rng.randf_range(3.0, 7.0)), blade_color, 1.0, true)
		draw_line(blade_base, blade_base + Vector2(2.0, -rng.randf_range(2.0, 6.0)), blade_color, 1.0, true)


func _draw_farm_ground() -> void:
	# The gameplay grid remains rectangular, but each visible bed is an independent
	# isometric soil cell. Grass between rows breaks up the former brown panel.
	for row: int in range(5):
		for column: int in range(8):
			var center := area_rect.position + Vector2(65.0 + float(column * 60), 45.0 + float(row * 60))
			var variation: float = float((row * 8 + column + detail_seed) % 4) * 0.018
			_draw_iso_cell(
				center,
				Vector2(37.0, 19.0),
				Color(0.39 + variation, 0.29 + variation * 0.55, 0.18, 0.88),
				Color(0.25, 0.20, 0.12, 0.28)
			)
			if (row + column) % 3 == 0:
				draw_line(
					center + Vector2(-22.0, 4.0),
					center + Vector2(18.0, -7.0),
					Color(0.77, 0.62, 0.39, 0.15),
					1.2,
					true
				)
	# Short diagonal worn links preserve a cultivated rhythm without exposing a box.
	for row: int in range(4):
		var y: float = area_rect.position.y + 75.0 + float(row * 60)
		for column: int in range(7):
			var x: float = area_rect.position.x + 96.0 + float(column * 60)
			draw_line(Vector2(x - 8.0, y + 4.0), Vector2(x + 8.0, y - 4.0), Color(0.55, 0.43, 0.26, 0.16), 3.0, true)
	_draw_edge_details(area_rect, Color("#7f9060"), 18)


func _draw_animal_ground() -> void:
	var centers: Array[Vector2] = [
		area_rect.position + area_rect.size * Vector2(0.43, 0.33),
		area_rect.position + area_rect.size * Vector2(0.73, 0.64),
		area_rect.position + area_rect.size * Vector2(0.43, 0.78),
	]
	for index: int in range(centers.size()):
		_draw_irregular_iso_patch(centers[index], Vector2(82.0, 39.0), Color(0.30, 0.23, 0.14, 0.42), index + 11)
		_draw_irregular_iso_patch(centers[index] + Vector2(5.0, 4.0), Vector2(52.0, 23.0), Color(0.24, 0.19, 0.12, 0.20), index + 23)
	if centers.size() == 3:
		_draw_isometric_surface_segment(centers[0] + Vector2(10.0, 16.0), centers[2] - Vector2(4.0, 18.0), 17.0, Color(0.28, 0.23, 0.15, 0.20), Color(0.43, 0.35, 0.22, 0.28))
		_draw_isometric_surface_segment(centers[2] + Vector2(28.0, -4.0), centers[1] - Vector2(32.0, 2.0), 15.0, Color(0.28, 0.23, 0.15, 0.18), Color(0.43, 0.35, 0.22, 0.24))
	_draw_hay_strokes(area_rect.position + Vector2(60.0, 78.0), 12)
	_draw_hay_strokes(area_rect.position + Vector2(area_rect.size.x - 76.0, area_rect.size.y - 58.0), 10)
	_draw_edge_details(area_rect, Color("#89935a"), 12)


func _draw_aquaculture_ground() -> void:
	var pond_centers: Array[Vector2] = [
		area_rect.position + Vector2(110.0, 110.0),
		area_rect.position + Vector2(220.0, 110.0),
		area_rect.position + Vector2(220.0, 210.0),
		area_rect.position + Vector2(110.0, 310.0),
		area_rect.position + Vector2(220.0, 310.0),
	]
	for index: int in range(pond_centers.size()):
		var center: Vector2 = pond_centers[index]
		_draw_irregular_iso_patch(center, Vector2(61.0, 34.0), Color(0.18, 0.31, 0.23, 0.38), index + 31)
		_draw_iso_cell(center + Vector2(1.0, 2.0), Vector2(48.0, 26.0), Color(0.30, 0.39, 0.28, 0.18), Color(0.20, 0.29, 0.20, 0.18))
		_draw_reed_cluster(center + Vector2(-43.0, 5.0), 3 + index % 2)
		_draw_stone_cluster(center + Vector2(39.0, 20.0), 3)
	_draw_edge_details(area_rect, Color("#6d8052"), 10)


func _draw_village_ground() -> void:
	var center_x: float = area_rect.get_center().x
	var path_color := Color("#82745a")
	var edge_color := Color(0.23, 0.27, 0.19, 0.50)
	_draw_iso_tile_path(
		Vector2(center_x, area_rect.position.y + 24.0),
		Vector2(center_x, area_rect.end.y - 18.0),
		34.0,
		edge_color,
		path_color
	)
	for row: int in range(4):
		var y: float = area_rect.position.y + 90.0 + float(row * 140)
		_draw_iso_tile_path(
			Vector2(center_x - area_rect.size.x * 0.27, y),
			Vector2(center_x + area_rect.size.x * 0.27, y),
			28.0,
			edge_color,
			path_color
		)
		_draw_iso_cell(Vector2(center_x, y), Vector2(28.0, 14.0), path_color.lightened(0.04), edge_color)
	_draw_edge_details(area_rect, Color("#81995b"), 12)


func _draw_iso_tile_path(
	start: Vector2,
	end: Vector2,
	width: float,
	edge: Color,
	surface: Color
) -> void:
	var length: float = start.distance_to(end)
	if is_zero_approx(length):
		return
	var softened_edge: Color = edge
	softened_edge.a *= 0.42
	var underlay: Color = surface.darkened(0.10)
	underlay.a = 0.68
	_draw_isometric_surface_segment(start, end, width * 0.58, softened_edge, underlay)
	var tile_edge: Color = edge
	tile_edge.a *= 0.20
	var step_size: float = maxf(width * 0.66, 14.0)
	var steps: int = maxi(1, ceili(length / step_size))
	for index: int in range(steps + 1):
		var ratio: float = float(index) / float(steps)
		var center: Vector2 = start.lerp(end, ratio)
		var tile_color: Color = surface.darkened(0.025) if index % 2 == 0 else surface.lightened(0.018)
		tile_color.a = 0.72
		_draw_iso_cell(center, Vector2(width * 0.48, width * 0.27), tile_color, tile_edge)


func _draw_restaurant_ground() -> void:
	var building_apron := Rect2(
		area_rect.position + Vector2(62.0, 28.0),
		Vector2(area_rect.size.x - 124.0, 165.0)
	)
	var dining_terrace := Rect2(
		area_rect.position + Vector2(105.0, 175.0),
		Vector2(area_rect.size.x - 210.0, area_rect.size.y - 188.0)
	)
	_draw_iso_platform(building_apron, Color("#716957"), Color(0.25, 0.27, 0.20, 0.32))
	_draw_iso_slab(dining_terrace, Color("#83755f"), Color(0.27, 0.27, 0.21, 0.30), dining_terrace.size.y * 0.48)
	_draw_iso_pavers_in_diamond(building_apron.grow(-10.0), 38.0, 27.0)
	_draw_iso_pavers(dining_terrace.grow(-8.0), 34.0, 25.0)
	_draw_edge_details(area_rect, Color("#82975c"), 10)


func _draw_logistics_ground() -> void:
	var loading_pad := area_rect.grow(-15.0)
	# Overlapping compacted-earth patches form a loading yard without exposing
	# the rectangular gameplay area as a single slab.
	for index: int in range(7):
		var center := Vector2(
			loading_pad.position.x + 45.0 + float(index) * (loading_pad.size.x - 90.0) / 6.0,
			loading_pad.get_center().y + float((index % 3) - 1) * 8.0
		)
		var yard_color := Color(0.43, 0.40, 0.33, 0.58 if index % 2 == 0 else 0.50)
		_draw_irregular_iso_patch(center, Vector2(77.0, 58.0), yard_color, detail_seed + index * 5)
		_draw_irregular_iso_patch(center + Vector2(8.0, 5.0), Vector2(55.0, 38.0), Color(0.38, 0.35, 0.29, 0.26), detail_seed + index * 7)
	for index: int in range(5):
		var y: float = loading_pad.position.y + 24.0 + float(index * 27)
		for section: int in range(5):
			var x: float = loading_pad.position.x + 24.0 + float(section) * (loading_pad.size.x - 48.0) / 5.0
			draw_line(Vector2(x, y + 2.0), Vector2(x + 52.0, y - 5.0), Color(0.25, 0.22, 0.17, 0.12), 2.0, true)
	for index: int in range(14):
		var dust_x: float = loading_pad.position.x + 18.0 + float((index * 79) % maxi(int(loading_pad.size.x - 36.0), 1))
		var dust_y: float = loading_pad.position.y + 16.0 + float((index * 43) % maxi(int(loading_pad.size.y - 32.0), 1))
		_draw_irregular_iso_patch(Vector2(dust_x, dust_y), Vector2(15.0, 5.0), Color(0.68, 0.59, 0.43, 0.10), index + 47)


func _draw_premium_ground() -> void:
	var paved := area_rect.grow(-17.0)
	_draw_iso_platform(paved, Color("#867b62"), Color(0.24, 0.30, 0.20, 0.34))
	_draw_iso_pavers_in_diamond(paved.grow(-5.0), 30.0, 22.0)
	for side: int in [-1, 1]:
		var planter_center := Vector2(
			area_rect.get_center().x + float(side) * area_rect.size.x * 0.38,
			area_rect.end.y - 17.0
		)
		_draw_irregular_iso_patch(planter_center, Vector2(25.0, 10.0), Color(0.20, 0.31, 0.16, 0.55), side + 61)
		_draw_reed_cluster(planter_center, 4)


func _draw_iso_cell(center: Vector2, half_size: Vector2, color: Color, edge: Color) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0.0, -half_size.y - 3.0),
		center + Vector2(half_size.x + 4.0, 0.0),
		center + Vector2(0.0, half_size.y + 3.0),
		center + Vector2(-half_size.x - 4.0, 0.0),
	])
	draw_colored_polygon(outer, edge)
	var inner := PackedVector2Array([
		center + Vector2(0.0, -half_size.y),
		center + Vector2(half_size.x, 0.0),
		center + Vector2(0.0, half_size.y),
		center + Vector2(-half_size.x, 0.0),
	])
	draw_colored_polygon(inner, color)


func _draw_irregular_iso_patch(center: Vector2, half_size: Vector2, color: Color, variant: int) -> void:
	var jitter_a: float = float((variant * 7) % 9) - 4.0
	var jitter_b: float = float((variant * 11) % 7) - 3.0
	var points := PackedVector2Array([
		center + Vector2(-half_size.x * 0.42 + jitter_a, -half_size.y),
		center + Vector2(half_size.x * 0.34, -half_size.y * 0.78 + jitter_b),
		center + Vector2(half_size.x, -half_size.y * 0.10),
		center + Vector2(half_size.x * 0.48 + jitter_b, half_size.y * 0.86),
		center + Vector2(-half_size.x * 0.30, half_size.y),
		center + Vector2(-half_size.x, half_size.y * 0.08 + jitter_a * 0.25),
	])
	draw_colored_polygon(points, color)


func _draw_iso_slab(rect: Rect2, color: Color, edge: Color, bevel: float) -> void:
	var safe_bevel: float = minf(bevel, minf(rect.size.x, rect.size.y) * 0.28)
	var outer := _make_chamfered_polygon(rect.grow(5.0), safe_bevel + 4.0)
	draw_colored_polygon(outer, edge)
	var slab := _make_chamfered_polygon(rect, safe_bevel)
	draw_colored_polygon(slab, color)
	draw_polyline(PackedVector2Array([slab[0], slab[1], slab[2], slab[3]]), Color(0.92, 0.86, 0.70, 0.10), 1.2, true)


func _draw_iso_platform(rect: Rect2, color: Color, edge: Color) -> void:
	var center: Vector2 = rect.get_center()
	var half_size: Vector2 = rect.size * 0.5
	var outer := PackedVector2Array([
		center + Vector2(0.0, -half_size.y - 5.0),
		center + Vector2(half_size.x + 7.0, 0.0),
		center + Vector2(0.0, half_size.y + 5.0),
		center + Vector2(-half_size.x - 7.0, 0.0),
	])
	draw_colored_polygon(outer, edge)
	var platform := PackedVector2Array([
		center + Vector2(0.0, -half_size.y),
		center + Vector2(half_size.x, 0.0),
		center + Vector2(0.0, half_size.y),
		center + Vector2(-half_size.x, 0.0),
	])
	draw_colored_polygon(platform, color)
	draw_line(platform[0], platform[1], Color(0.94, 0.89, 0.74, 0.12), 1.2, true)
	draw_line(platform[0], platform[3], Color(0.94, 0.89, 0.74, 0.08), 1.0, true)


func _make_chamfered_polygon(rect: Rect2, bevel: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + bevel, rect.position.y),
		Vector2(rect.end.x - bevel, rect.position.y),
		Vector2(rect.end.x, rect.position.y + bevel * 0.55),
		Vector2(rect.end.x - bevel * 0.35, rect.end.y - bevel * 0.35),
		Vector2(rect.end.x - bevel, rect.end.y),
		Vector2(rect.position.x + bevel, rect.end.y),
		Vector2(rect.position.x, rect.end.y - bevel * 0.55),
		Vector2(rect.position.x + bevel * 0.35, rect.position.y + bevel * 0.35),
	])


func _draw_isometric_surface_segment(
	start: Vector2,
	end: Vector2,
	width: float,
	edge: Color,
	surface: Color
) -> void:
	var direction: Vector2 = start.direction_to(end)
	if direction == Vector2.ZERO:
		return
	var normal := Vector2(-direction.y, direction.x)
	var half_width: float = width * 0.5
	var cap: Vector2 = direction * minf(width * 0.42, 12.0)
	var outer_points := PackedVector2Array([
		start - normal * (half_width + 5.0) + cap,
		end - normal * (half_width + 5.0) - cap,
		end + direction * 5.0,
		end + normal * (half_width + 5.0) - cap,
		start + normal * (half_width + 5.0) + cap,
		start - direction * 5.0,
	])
	draw_colored_polygon(outer_points, edge)
	var inner_points := PackedVector2Array([
		start - normal * half_width + cap,
		end - normal * half_width - cap,
		end,
		end + normal * half_width - cap,
		start + normal * half_width + cap,
		start,
	])
	draw_colored_polygon(inner_points, surface)
	draw_line(start + normal * half_width * 0.55, end + normal * half_width * 0.55, Color(0.93, 0.86, 0.70, 0.07), 1.2, true)


func _draw_iso_pavers(rect: Rect2, cell_width: float, cell_height: float) -> void:
	var paver_color := Color(0.28, 0.27, 0.23, 0.13)
	var row: int = 0
	var y: float = rect.position.y + cell_height * 0.5
	while y < rect.end.y - cell_height * 0.35:
		var x_offset: float = cell_width * 0.5 if row % 2 == 1 else 0.0
		var x: float = rect.position.x + cell_width * 0.5 + x_offset
		while x < rect.end.x - cell_width * 0.5:
			var cell := PackedVector2Array([
				Vector2(x, y - cell_height * 0.28),
				Vector2(x + cell_width * 0.38, y),
				Vector2(x, y + cell_height * 0.28),
				Vector2(x - cell_width * 0.38, y),
				Vector2(x, y - cell_height * 0.28),
			])
			draw_polyline(cell, paver_color, 1.0, true)
			x += cell_width
		y += cell_height * 0.72
		row += 1


func _draw_iso_pavers_in_diamond(rect: Rect2, cell_width: float, cell_height: float) -> void:
	var paver_color := Color(0.28, 0.27, 0.23, 0.14)
	var center: Vector2 = rect.get_center()
	var half_size: Vector2 = rect.size * 0.5
	var row: int = 0
	var y: float = rect.position.y + cell_height * 0.5
	while y < rect.end.y - cell_height * 0.35:
		var x_offset: float = cell_width * 0.5 if row % 2 == 1 else 0.0
		var x: float = rect.position.x + cell_width * 0.5 + x_offset
		while x < rect.end.x - cell_width * 0.5:
			var normalized_distance: float = absf(x - center.x) / maxf(half_size.x, 1.0) + absf(y - center.y) / maxf(half_size.y, 1.0)
			if normalized_distance < 0.83:
				var cell := PackedVector2Array([
					Vector2(x, y - cell_height * 0.28),
					Vector2(x + cell_width * 0.38, y),
					Vector2(x, y + cell_height * 0.28),
					Vector2(x - cell_width * 0.38, y),
					Vector2(x, y - cell_height * 0.28),
				])
				draw_polyline(cell, paver_color, 1.0, true)
			x += cell_width
		y += cell_height * 0.72
		row += 1


func _draw_soft_rect(rect: Rect2, color: Color, radius: float) -> void:
	for layer: int in range(4, 0, -1):
		var outer_color: Color = color
		outer_color.a = 0.045 + float(4 - layer) * 0.055
		_draw_rounded_rect(rect.grow(float(layer * 6)), outer_color, radius + float(layer * 4))
	var center_color: Color = color
	center_color.a = minf(maxf(color.a, 0.78), 0.92)
	_draw_rounded_rect(rect, center_color, radius)


func _draw_surface_segment(
	start: Vector2,
	end: Vector2,
	width: float,
	edge_color: Color,
	surface_color: Color
) -> void:
	draw_line(start, end, edge_color, width + 10.0, true)
	draw_line(start, end, surface_color, width, true)
	draw_line(start, end, Color(0.92, 0.84, 0.67, 0.08), maxf(width - 8.0, 1.0), true)


func _draw_paver_grid(rect: Rect2, cell_width: float, cell_height: float) -> void:
	var grid_color := Color(0.30, 0.28, 0.23, 0.16)
	var y: float = rect.position.y + cell_height
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), grid_color, 1.0, true)
		y += cell_height
	var column: int = 0
	var x: float = rect.position.x + cell_width
	while x < rect.end.x:
		var offset: float = cell_height * 0.5 if column % 2 == 1 else 0.0
		draw_line(Vector2(x, rect.position.y + offset), Vector2(x, rect.end.y), grid_color, 1.0, true)
		x += cell_width
		column += 1


func _draw_edge_details(rect: Rect2, color: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed * 997 + profile * 31
	for index: int in range(count):
		var use_horizontal: bool = index % 2 == 0
		var point := Vector2(
			rng.randf_range(rect.position.x + 10.0, rect.end.x - 10.0),
			rng.randf_range(rect.position.y + 10.0, rect.end.y - 10.0)
		)
		if use_horizontal:
			point.y = rect.position.y + 8.0 if index % 4 == 0 else rect.end.y - 8.0
		else:
			point.x = rect.position.x + 8.0 if index % 4 == 1 else rect.end.x - 8.0
		var detail_color: Color = color
		detail_color.a = rng.randf_range(0.20, 0.38)
		draw_line(point, point + Vector2(-2.0, -rng.randf_range(3.0, 8.0)), detail_color, 1.0, true)
		draw_line(point, point + Vector2(2.0, -rng.randf_range(2.0, 6.0)), detail_color, 1.0, true)
		if index % 5 == 0:
			_draw_ellipse(point + Vector2(5.0, 1.0), Vector2(3.0, 1.8), Color(0.34, 0.34, 0.27, 0.40), 8)


func _draw_hay_strokes(center: Vector2, count: int) -> void:
	for index: int in range(count):
		var offset := Vector2(float((index * 7) % 31) - 15.0, float((index * 11) % 19) - 9.0)
		draw_line(center + offset, center + offset + Vector2(8.0, 3.0), Color(0.80, 0.65, 0.32, 0.42), 1.3, true)


func _draw_reed_cluster(center: Vector2, count: int) -> void:
	for index: int in range(count):
		var base := center + Vector2(float(index * 4), float(index % 2) * 2.0)
		draw_line(base, base + Vector2(-1.5, -8.0 - float(index % 3) * 2.0), Color(0.50, 0.60, 0.28, 0.60), 1.2, true)


func _draw_stone_cluster(center: Vector2, count: int) -> void:
	for index: int in range(count):
		_draw_ellipse(
			center + Vector2(float(index * 5), float(index % 2) * 2.0),
			Vector2(3.2 + float(index % 2), 2.0),
			Color(0.42, 0.43, 0.37, 0.55),
			8
		)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var safe_radius: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var centers: Array[Vector2] = [
		rect.position + Vector2(safe_radius, safe_radius),
		Vector2(rect.end.x - safe_radius, rect.position.y + safe_radius),
		rect.end - Vector2(safe_radius, safe_radius),
		Vector2(rect.position.x + safe_radius, rect.end.y - safe_radius),
	]
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for corner: int in range(4):
		for step: int in range(5):
			var angle: float = start_angles[corner] + PI * 0.5 * float(step) / 4.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * safe_radius)
	draw_colored_polygon(points, color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int) -> void:
	var points := PackedVector2Array()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
