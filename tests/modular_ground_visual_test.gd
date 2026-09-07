extends Node

var failures: int = 0
@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_ground_visual_test"):
		push_error("modular_ground_visual_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	_validate_ground_architecture()
	_validate_visual_only_nodes()
	_validate_routes_are_unchanged()
	_validate_gameplay_coordinates_are_unchanged()
	_validate_contact_shadows()
	_validate_new_game_and_continue()
	if failures == 0:
		print("modular_ground_visual_test: PASS")
	else:
		push_error("modular_ground_visual_test: FAIL (%d failures)" % failures)
	game_manager.stop_gameplay()
	get_tree().quit(failures)


func _validate_ground_architecture() -> void:
	var ground_paths: Array[String] = [
		"GroundVisual/GroundLayers/WorldGrass",
		"hub/GroundVisual/GroundLayers/VillageGround",
		"hub/premium_market/Ground/GroundLayers/GroundVisual",
		"hub/resort/Ground/GroundLayers/GroundVisual",
		"farm/Ground/GroundLayers/GroundVisual",
		"animals/Ground/GroundLayers/GroundVisual",
		"aquaculture/Ground/GroundLayers/GroundVisual",
		"restaurant/Ground/GroundLayers/GroundVisual",
		"truck_road/Ground/GroundLayers/GroundVisual",
	]
	for path: String in ground_paths:
		var ground: Node = world.get_node_or_null(path)
		_expect(ground != null, "ground component missing: %s" % path)
		_expect(ground is LaHoueZoneGroundVisual, "ground component has the wrong script: %s" % path)
	_expect(world.get_node_or_null("farm/Ground/world_ground") == null, "legacy flat-green world_ground still exists")
	var ground_count: int = 0
	for node: Node in _get_descendants(world):
		if node is LaHoueZoneGroundVisual:
			ground_count += 1
	_expect(ground_count == ground_paths.size(), "ground components are duplicated or incomplete")
	var farm_ground: CanvasItem = world.get_node("farm/Ground/GroundLayers/GroundVisual") as CanvasItem
	var animal_ground: CanvasItem = world.get_node("animals/Ground/GroundLayers/GroundVisual") as CanvasItem
	_expect(farm_ground.z_index > animal_ground.z_index, "Farm soil does not win the existing Farm/Animal overlap")


func _validate_visual_only_nodes() -> void:
	for node: Node in _get_descendants(world):
		if node is LaHoueZoneGroundVisual or node is LaHoueRouteSurfaceVisual or node is LaHoueContactShadow:
			_expect(not (node is CollisionObject2D), "visual ground component owns gameplay collision: %s" % node.get_path())
			_expect(bool(node.get_meta("visual_only", false)), "visual component lacks visual_only metadata: %s" % node.get_path())


func _validate_routes_are_unchanged() -> void:
	var truck_route: Node = world.get_node("truck_road/Paths/TruckRoute")
	var truck_surface: LaHoueRouteSurfaceVisual = world.get_node("truck_road/Roads/TruckRouteSurface") as LaHoueRouteSurfaceVisual
	var truck_expected: Array[Vector2] = [
		Vector2(460, 740), Vector2(1300, 740), Vector2(1300, 950), Vector2(1920, 950),
	]
	_validate_route_markers(truck_route, truck_surface, truck_expected, "Truck")
	var customer_route: Node = world.get_node("restaurant/Paths/CustomerEntryRoute")
	var customer_surface: LaHoueRouteSurfaceVisual = world.get_node("restaurant/Roads/CustomerPathSurface") as LaHoueRouteSurfaceVisual
	var customer_expected: Array[Vector2] = [
		Vector2(280, 170), Vector2(-180, 170), Vector2(-180, 0),
	]
	_validate_route_markers(customer_route, customer_surface, customer_expected, "Customer")


func _validate_route_markers(
	route: Node,
	surface: LaHoueRouteSurfaceVisual,
	expected: Array[Vector2],
	label: String
) -> void:
	var visual_points: PackedVector2Array = surface.get_visual_points()
	_expect(route.get_child_count() == expected.size(), "%s route marker count changed" % label)
	_expect(visual_points.size() == expected.size(), "%s visual route is incomplete" % label)
	for index: int in range(mini(route.get_child_count(), expected.size())):
		var marker: Marker2D = route.get_child(index) as Marker2D
		_expect(marker != null and marker.position == expected[index], "%s route marker %d moved" % [label, index + 1])
		if index < visual_points.size() and marker != null:
			_expect(visual_points[index].is_equal_approx(surface.to_local(marker.global_position)), "%s road surface does not follow marker %d" % [label, index + 1])


func _validate_gameplay_coordinates_are_unchanged() -> void:
	_expect((world.get_node("farm/tile_01") as Node2D).position == Vector2(590, 370), "Farm plot #1 moved")
	_expect((world.get_node("farm/tile_40") as Node2D).position == Vector2(1010, 610), "Farm plot #40 moved")
	_expect((world.get_node("farm/farm_expansion_point") as Node2D).position == Vector2(780, 680), "Farm Expansion moved")
	_expect((world.get_node("farm/NPCMarkers/FarmWorkerHome01") as Node2D).position == Vector2(550, 680), "Farm staff marker moved")
	_expect((world.get_node("animals/NPCMarkers/AnimalWorkerHome01") as Node2D).position == Vector2(980, 470), "Animal staff marker moved")
	_expect((world.get_node("aquaculture/NPCMarkers/AquacultureWorkerHome01") as Node2D).position == Vector2(1200, 400), "Aquaculture staff marker moved")
	var market: Node = world.get_node("hub/premium_market")
	_expect((market.get_node("helipad_marker") as Node2D).position == Vector2(130, 0), "Helipad marker moved")
	_expect((market.get_node("takeoff_marker") as Node2D).position == Vector2(130, -100), "Helicopter takeoff marker moved")
	_expect((market.get_node("outside_marker") as Node2D).position == Vector2(130, -400), "Helicopter outside marker moved")


func _validate_contact_shadows() -> void:
	var shadow_paths: Array[String] = [
		"hub/market/ContactShadow",
		"hub/warehouse/ContactShadow",
		"hub/premium_market/ContactShadow",
		"hub/premium_market/VisualRoot/helipad/ContactShadow",
		"hub/resort/ContactShadow",
		"animals/coop/ContactShadow",
		"animals/pig_pen/ContactShadow",
		"animals/cow_barn/ContactShadow",
		"restaurant/ContactShadow",
	]
	for path: String in shadow_paths:
		var shadow: Node = world.get_node_or_null(path)
		_expect(shadow is LaHoueContactShadow, "contact shadow missing: %s" % path)
		if shadow is CanvasItem:
			_expect((shadow as CanvasItem).z_index < 0, "contact shadow is above its visual: %s" % path)
	var manager: Node = world.get_node("truck_manager")
	manager.call("_init_visuals_if_needed")
	var trucks: Array = manager.get("visual_trucks") as Array
	_expect(not trucks.is_empty() and (trucks[0] as Node).get_node_or_null("ContactShadow") is LaHoueContactShadow, "moving Truck contact shadow missing")
	_expect(world.get_node("hub/premium_market/helicopter/ContactShadow") is LaHoueContactShadow, "moving Helicopter contact shadow missing")


func _validate_new_game_and_continue() -> void:
	var marker_before: Vector2 = (world.get_node("truck_road/Paths/TruckRoute/RoutePoint02") as Node2D).position
	_expect(save_manager.save_game(), "New Game state could not be saved with modular ground")
	_expect(save_manager.load_game(), "Continue failed with modular ground")
	_expect((world.get_node("truck_road/Paths/TruckRoute/RoutePoint02") as Node2D).position == marker_before, "Continue changed a route marker")
	_expect(world.get_node_or_null("farm/Ground/GroundLayers/GroundVisual") != null, "Continue removed Farm ground")


func _get_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		result.append(child)
		result.append_array(_get_descendants(child))
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("modular_ground_visual_test: %s" % message)
