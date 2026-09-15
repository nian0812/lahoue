extends Node2D

## V3 materials and separate runtime furniture; every visible table is purchased.
const catalog = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const sprite_tools = preload("res://scripts/visual/manifest_sprite.gd")
var restaurant: Node2D
var floor_level: int = -1
var ready_dishes: Dictionary = {}
var served_dishes: Dictionary = {}
var food_root: Node2D
var bar: Label
var pass_label: Label
var shell: Sprite2D
var kitchen: Sprite2D
var architecture: Node2D


func _ready() -> void:
	restaurant = get_parent().get_parent()
	z_index = -1
	food_root = Node2D.new()
	food_root.name = "ReadyDishes"
	food_root.z_index = 4
	add_child(food_root)
	bar = _label("Bar", Vector2(-115, -78))
	pass_label = _label("Food Pass", Vector2(-22, -78))
	shell = Sprite2D.new()
	shell.name = "ApprovedRestaurantShell"
	shell.z_index = -2
	shell.visible = false
	architecture = Node2D.new()
	architecture.name = "ApprovedArchitecture"
	add_child(architecture)
	add_child(shell)
	kitchen = _approved_prop("kitchen",Rect2(75,-106,80,65))
	_approved_prop("food_pass",Rect2(-35,-86,72,60))
	_approved_prop("bar",Rect2(-145,-110,80,65))
	_label("Kitchen",Vector2(88,-82))
	restaurant.food_ready.connect(func(_id: String, _recipe: String): refresh())
	restaurant.order_served.connect(func(_id: String, _recipe: String): refresh())
	restaurant.cooking_canceled.connect(func(_id: String, _recipe: String): refresh())
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(restaurant): return
	# The supplied whole-building artwork contains baked tables and food.
	var root: Node = get_parent()
	root.call("set_artwork_visible", false)
	root.get_node("building_visual").visible = false
	visible = restaurant.is_available()
	var next_level: int = restaurant.restaurant_level
	if floor_level != next_level:
		floor_level = next_level
		_rebuild_architecture()
		queue_redraw()
	var cooking: bool = restaurant.cooking_jobs.values().any(func(job: Dictionary): return job.get("state","") == "cooking")
	if kitchen != null:
		kitchen.texture = catalog.get_v3_texture("restaurant/kitchen_work" if cooking else "restaurant/kitchen")
	var expected: Dictionary = {}
	for id: String in restaurant.cooking_jobs:
		var job: Dictionary = restaurant.cooking_jobs[id]
		if String(job.get("state", "")) != "ready": continue
		expected[id] = true
		if not ready_dishes.has(id):
			var dish := Sprite2D.new()
			dish.name = id
			dish.set_meta("recipe_id", String(job.recipe_id))
			dish.texture = catalog.get_dish_texture(String(job.recipe_id))
			food_root.add_child(dish)
			if dish.texture != null:
				sprite_tools.configure_sprite(dish, dish.texture, Rect2(-10, -16, 20, 18))
			else:
				var fallback := Label.new()
				fallback.text = "DISH"
				fallback.add_theme_font_size_override("font_size", 8)
				fallback.position = Vector2(-10, -14)
				dish.add_child(fallback)
			ready_dishes[id] = dish
	for id: String in ready_dishes.keys():
		if not expected.has(id):
			ready_dishes[id].queue_free()
			ready_dishes.erase(id)
	var index: int = 0
	for dish: Node2D in ready_dishes.values():
		dish.visible = not _in_transit(String(dish.name))
		dish.position = Vector2(-22 + (index % 3) * 22, -55 + (index / 3) * 12)
		index += 1
	var eating: Dictionary = {}
	for id: String in restaurant.customers_by_id:
		var customer: Node = restaurant.customers_by_id[id]
		if customer.current_state != "eating" or not restaurant.tables_by_id.has(customer.table_id): continue
		eating[id] = true
		var table: Node2D = restaurant.tables_by_id[customer.table_id]
		if not served_dishes.has(id):
			var meal := Sprite2D.new()
			meal.texture = catalog.get_dish_texture(String(customer.order.get("recipe_id", "")))
			meal.set_meta("recipe_id", String(customer.order.get("recipe_id", "")))
			add_child(meal)
			if meal.texture != null:
				sprite_tools.configure_sprite(meal, meal.texture, Rect2(-9,-13,18,16))
			else:
				var label := Label.new()
				label.text = "DISH"
				label.add_theme_font_size_override("font_size", 8)
				label.position = Vector2(-9,-8)
				meal.add_child(label)
			served_dishes[id] = meal
		served_dishes[id].position = table.position + Vector2(0,-4)
		served_dishes[id].z_index = table.z_index + 2
	for id: String in served_dishes.keys():
		if not eating.has(id):
			served_dishes[id].queue_free()
			served_dishes.erase(id)


func _in_transit(id: String) -> bool:
	var player: Node = restaurant.get_parent().get_node_or_null("player")
	if player != null and player.delivery_customer_id == id and player.carrying_food: return true
	for staff: Node in restaurant.staffs_by_id.values():
		if staff.active_job.get("job_type", "") == "serve" and staff.active_job.get("target_id", "") == id: return true
	return false


func _draw() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_material_face([Vector2(-220,-25),Vector2(0,-120),Vector2(220,-25),Vector2(0,165)], "floor_material")
	_material_face([Vector2(-220,-25),Vector2(0,165),Vector2(0,174),Vector2(-220,-16)], "wall_material")
	_material_face([Vector2(0,165),Vector2(220,-25),Vector2(220,-16),Vector2(0,174)], "wall_material")
	if floor_level >= 3:
		for at: Vector2 in [Vector2(-160,-162),Vector2(172,-138),Vector2(0,-224)]:
			_material_face([at,at+Vector2(10,4),at+Vector2(10,170),at+Vector2(0,166)], "wall_material")
		_material_face([Vector2(-165,-170),Vector2(0,-233),Vector2(185,-145),Vector2(20,-82)], "floor_material")
		_material_face([Vector2(-165,-170),Vector2(20,-82),Vector2(20,-70),Vector2(-165,-158)], "wall_material")
		_material_face([Vector2(20,-82),Vector2(185,-145),Vector2(185,-133),Vector2(20,-70)], "wall_material")


func _material_face(points: Array, material: String) -> void:
	var texture: Texture2D = catalog.get_v3_texture("restaurant/"+material)
	if texture == null: return
	var polygon := PackedVector2Array(points)
	var uv := PackedVector2Array()
	for p: Vector2 in polygon: uv.append(p / texture.get_size())
	draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, texture)


func _rebuild_architecture() -> void:
	for child: Node in architecture.get_children(): child.free()
	# Authored railings and planters frame the open service aisle and terrace.
	for at: Vector2 in [Vector2(-185,-20),Vector2(172,18),Vector2(-25,132)]:
		_arch_prop("planter",Rect2(at-Vector2(15,40),Vector2(30,40)))
	if floor_level < 3:
		for i: int in range(3):
			_arch_prop("railing_back",Rect2(-185+i*62,-111-i*18,70,45))
		return
	for i: int in range(3):
		_arch_prop("railing_back",Rect2(-170+i*53,-224-i*20,70,52))
	for i: int in range(3):
		var rail: Sprite2D = _arch_prop("railing_back",Rect2(2+i*54,-272+i*26,72,54))
		rail.flip_h = true
	for at: Vector2 in [Vector2(-161,-176),Vector2(-3,-235),Vector2(177,-150)]:
		_arch_prop("planter",Rect2(at-Vector2(12,31),Vector2(24,31)))
	var stair: Sprite2D = _arch_prop("stair",Rect2(145,-144,85,195))
	stair.scale = Vector2(85,195) / stair.texture.get_size()
	stair.position = Vector2(187.5,-46.5)


func _arch_prop(id: String, rect: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = id
	architecture.add_child(sprite)
	sprite_tools.configure_sprite(sprite,catalog.get_v3_texture("restaurant/"+id),rect)
	return sprite


func _label(text_value: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.z_index = 5
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#fff1d1"))
	label.add_theme_color_override("font_outline_color", Color("#342c21"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


func _prop(id: String, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = catalog.get_atlas_texture("restaurant_kitchen_cooking_station_module_set", id)
	if sprite.texture == null: return
	sprite.z_index = 3
	add_child(sprite)
	sprite_tools.configure_sprite(sprite, sprite.texture, rect)


func _approved_prop(id: String, rect: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Approved_"+id
	sprite.z_index = 3
	add_child(sprite)
	sprite_tools.configure_sprite(sprite,catalog.get_v3_texture("restaurant/"+id),rect)
	return sprite
