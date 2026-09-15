extends Node

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_modular_world_test"):
		push_error("modular_world_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	await get_tree().process_frame
	world.call("refresh_world_bounds")

	var expected_zones: Array[String] = [
		"farm",
		"animal",
		"aquaculture",
		"restaurant",
		"logistics",
		"premium",
		"resort",
	]
	var seen_zone_ids: Dictionary = {}
	for zone_id: String in expected_zones:
		var zone: Node2D = world.call("get_zone", zone_id) as Node2D
		_expect(zone != null, "zone '%s' is not loaded" % zone_id)
		if zone == null:
			continue
		_expect(not seen_zone_ids.has(zone_id), "duplicate zone id '%s'" % zone_id)
		seen_zone_ids[zone_id] = true
		for section_name: String in LaHoueZoneRoot.required_sections:
			_expect(
				zone.has_node(section_name),
				"zone '%s' is missing %s" % [zone_id, section_name]
			)
		_expect(
			zone.get_node("ExpansionAnchors").get_child_count() > 0,
			"zone '%s' has no expansion anchor" % zone_id
		)
	_expect(seen_zone_ids.size() == expected_zones.size(), "base world did not load exactly seven zone ids")

	_expect(world.get_node_or_null("farm/tile_01") != null, "legacy Farm node path changed")
	_expect(world.get_node_or_null("animals/coop") != null, "legacy Animal building path changed")
	_expect(world.get_node_or_null("aquaculture/fish_container") != null, "legacy pond path changed")
	_expect(world.get_node_or_null("restaurant/customers") != null, "legacy Restaurant path changed")
	_expect(world.get_node_or_null("truck_road/Paths/TruckRoute") != null, "Truck route Path2D is missing")
	_expect(world.get_node_or_null("hub/premium_market/helipad_marker") != null, "Helicopter route marker is missing")
	_validate_independent_building_scenes()

	var farm_tile_ids: Dictionary = {}
	for child: Node in world.get_node("farm").get_children():
		var tile_id_value: Variant = child.get("tile_id")
		if tile_id_value == null or String(tile_id_value).is_empty():
			continue
		var tile_id: String = String(tile_id_value)
		_expect(not farm_tile_ids.has(tile_id), "duplicate fixed Farm plot '%s'" % tile_id)
		farm_tile_ids[tile_id] = true
	_expect(farm_tile_ids.size() == 40, "Farm Zone does not contain exactly 40 fixed plots")
	_expect((world.get("purchased_farm_plots") as Array).size() == 1, "New Game Farm ownership changed")

	var customer_route: Path2D = world.get_node("restaurant/Paths/CustomerEntryRoute") as Path2D
	var truck_route: Path2D = world.get_node("truck_road/Paths/TruckRoute") as Path2D
	_expect(customer_route.curve != null and customer_route.curve.point_count == 3, "Customer marker route was not built")
	_expect(truck_route.curve != null and truck_route.curve.point_count == 4, "Truck marker route was not built")
	_expect(
		world.get_node("hub/premium_market/helipad_marker") is Marker2D
		and world.get_node("hub/premium_market/outside_marker") is Marker2D,
		"Helicopter route is not marker-driven"
	)
	var truck_manager: Node = world.get_node("truck_manager")
	truck_manager.call("_init_visuals_if_needed")
	var truck_visuals: Array = truck_manager.get("visual_trucks") as Array
	_expect(truck_visuals.size() == 3, "Truck visuals were not attached to the Logistics route")
	if truck_visuals.size() == 3:
		_expect(
			(truck_visuals[0] as Node2D).position.is_equal_approx(
				truck_manager.call("_get_truck_pos", 0.0, 0) as Vector2
			),
			"Truck did not spawn at its Logistics marker"
		)
		_expect(
			(truck_manager.call("_get_truck_pos", 1.0, 0) as Vector2).is_equal_approx(
				truck_route.curve.get_point_position(3)
			),
			"Truck route does not end at the Path2D destination"
		)

	game_manager.level = 5
	game_manager.money = 2000000
	_expect(world.call("upgrade_system", "restaurant"), "Restaurant route fixture could not unlock")
	var restaurant: Node = world.get_node("restaurant")
	var route_customer: Node = restaurant.call(
		"spawn_customer",
		"modular_route_customer",
		"garlic_egg_rice"
	) as Node
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(route_customer != null, "Customer route fixture could not spawn")
	if route_customer != null:
		var walk_path: Array = route_customer.get("walk_path") as Array
		_expect(walk_path.size() == 4, "Customer did not receive marker route plus table destination")
		if walk_path.size() == 4:
			for point_index: int in range(3):
				_expect(
					(walk_path[point_index] as Vector2).is_equal_approx(
						customer_route.curve.get_point_position(point_index)
					),
					"Customer route point %d did not come from Path2D" % point_index
				)
		restaurant.call("remove_customer", "modular_route_customer")

	var initial_bounds: Rect2 = world.call("get_world_bounds") as Rect2
	_expect(initial_bounds.position.is_equal_approx(Vector2.ZERO), "initial world bounds origin changed")
	_expect(initial_bounds.size.is_equal_approx(Vector2(1920, 1080)), "initial world bounds size changed")
	var camera: Camera2D = world.get_node("player/camera") as Camera2D
	_expect(camera.limit_right == 1920 and camera.limit_bottom == 1080, "camera did not consume zone bounds")

	var logistics_anchor: Marker2D = world.call("get_expansion_anchor", "logistics", "East") as Marker2D
	var dummy_zone: Node2D = _make_dummy_zone()
	_expect(
		world.call("attach_zone_to_expansion_anchor", dummy_zone, "logistics", "East", "West"),
		"dummy zone could not attach through ExpansionAnchor"
	)
	await get_tree().process_frame
	var expanded_bounds: Rect2 = world.call("refresh_world_bounds") as Rect2
	_expect(
		dummy_zone.global_position.is_equal_approx(logistics_anchor.global_position - Vector2(0, 100)),
		"dummy zone was not aligned to the selected anchors"
	)
	_expect(expanded_bounds.end.x == 2220.0, "zone bounds did not expand for dummy zone")
	_expect(camera.limit_right == 2220, "camera bounds did not expand for dummy zone")
	dummy_zone.queue_free()
	await get_tree().process_frame
	var restored_bounds: Rect2 = world.call("refresh_world_bounds") as Rect2
	_expect(restored_bounds.end.x == 1920.0, "camera bounds did not shrink after dummy zone removal")

	game_manager.level = 10
	game_manager.money = 5000000
	_expect(world.call("purchase_next_farm_plot"), "modular Farm plot purchase failed")
	_expect(world.call("upgrade_system", "coop"), "modular Animal building upgrade failed")
	_expect(save_manager.save_game(), "modular world state could not be saved")
	(world.get("purchased_farm_plots") as Array).resize(1)
	world.set("coop_level", 0)
	world.call("_refresh_economy_world_state")
	_expect(save_manager.load_game(), "modular world state could not be loaded")
	_expect((world.get("purchased_farm_plots") as Array).size() == 2, "Farm ownership did not survive Continue")
	_expect(int(world.get("coop_level")) == 1, "building ownership did not survive Continue")

	if failures == 0:
		print("modular_world_test: PASS")
	else:
		push_error("modular_world_test: %d failure(s)" % failures)

	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _make_dummy_zone() -> Node2D:
	var zone: LaHoueZoneRoot = LaHoueZoneRoot.new()
	zone.name = "dummy_zone"
	zone.zone_id = "dummy"
	zone.local_bounds = Rect2(0, 0, 300, 200)
	for section_name: String in LaHoueZoneRoot.required_sections:
		var section: Node2D = Node2D.new()
		section.name = section_name
		zone.add_child(section)
	var anchors: Node2D = zone.get_node("ExpansionAnchors") as Node2D
	var west: Marker2D = Marker2D.new()
	west.name = "West"
	west.position = Vector2(0, 100)
	anchors.add_child(west)
	var east: Marker2D = Marker2D.new()
	east.name = "East"
	east.position = Vector2(300, 100)
	anchors.add_child(east)
	return zone


func _validate_independent_building_scenes() -> void:
	var building_scene_paths: Array[String] = [
		"res://scenes/buildings/warehouse.tscn",
		"res://scenes/restaurant/restaurant.tscn",
		"res://scenes/buildings/coop.tscn",
		"res://scenes/buildings/pig_pen.tscn",
		"res://scenes/buildings/cow_barn.tscn",
		"res://scenes/aquaculture/aquaculture_container.tscn",
		"res://scenes/buildings/truck_depot.tscn",
		"res://scenes/premium_market/premium_market.tscn",
		"res://scenes/buildings/helipad.tscn",
		"res://scenes/world/zones/resort_zone.tscn",
	]
	for scene_path: String in building_scene_paths:
		var packed: PackedScene = load(scene_path) as PackedScene
		_expect(packed != null, "independent building scene is missing: %s" % scene_path)
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		_expect(
			instance.has_node("VisualRoot"),
			"building does not separate LogicRoot/VisualRoot: %s" % scene_path
		)
		instance.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("modular_world_test: %s" % message)


func _cleanup_save_files() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return
	user_directory.list_dir_begin()
	var file_name: String = user_directory.get_next()
	while not file_name.is_empty():
		if not user_directory.current_is_dir() and file_name.begins_with("savegame"):
			user_directory.remove(file_name)
		file_name = user_directory.get_next()
	user_directory.list_dir_end()
