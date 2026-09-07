extends Node

const premium_market_script: Script = preload("res://scripts/premium_market/premium_market.gd")
const animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")
const upgrade_board_scene: PackedScene = preload("res://scenes/buildings/upgrade_board.tscn")

var failures: int = 0
@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_visual_polish_test"):
		push_error("visual_polish_runtime_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	game_manager.stop_gameplay()
	world.building_ownership["helipad"] = true
	await get_tree().process_frame
	_validate_helicopter_levels_and_route()
	_validate_truck_levels_and_route()
	_validate_crop_scale_categories()
	_validate_labels()
	await _validate_upgrade_board()
	if failures == 0:
		print("visual_polish_runtime_test: PASS")
	else:
		push_error("visual_polish_runtime_test: FAIL (%d failures)" % failures)
	get_tree().quit(failures)


func _validate_helicopter_levels_and_route() -> void:
	var market: Node = world.get_node("hub/premium_market")
	var helicopter: Node2D = market.get_node("helicopter") as Node2D
	var helipad_marker: Marker2D = market.get_node("helipad_marker") as Marker2D
	var outside_marker: Marker2D = market.get_node("outside_marker") as Marker2D
	for level: int in range(1, 6):
		market.set("helicopter_level", level)
		market.set("current_state", premium_market_script.state_ready)
		market.call("_refresh_visual")
		var artwork: Sprite2D = helicopter.get_node("VisualRoot/AssetArtwork") as Sprite2D
		_expect(int(helicopter.get("vehicle_level")) == level, "Helicopter Lv%d visual did not swap" % level)
		_expect(artwork.texture != null and artwork.visible, "Helicopter Lv%d artwork missing" % level)
		_expect(helicopter.position.is_equal_approx(helipad_marker.position), "Helicopter Lv%d is not aligned to the Helipad marker" % level)
		_expect(_sprite_bottom_matches_target(helicopter, artwork), "Helicopter Lv%d ground pivot is inconsistent" % level)
	var flight_duration: float = float(market.call("_get_flight_duration"))
	market.set("current_state", premium_market_script.state_departing)
	market.set("phase_elapsed", flight_duration * 0.35)
	market.call("_refresh_visual")
	_expect(helicopter.visible and helicopter.position.is_equal_approx(market.call("_get_route_position", 0.35)), "Helicopter outbound visual left its existing route")
	market.set("current_state", premium_market_script.state_importing)
	market.call("_refresh_visual")
	_expect(not helicopter.visible and helicopter.position.is_equal_approx(outside_marker.position), "Helicopter outside-map state is misaligned")
	market.set("current_state", premium_market_script.state_returning)
	market.set("phase_elapsed", flight_duration * 0.25)
	market.call("_refresh_visual")
	_expect(helicopter.visible and helicopter.position.is_equal_approx(market.call("_get_route_position", 0.75)), "Helicopter return visual left its existing route")
	market.set("current_state", premium_market_script.state_ready)
	market.set("phase_elapsed", 0.0)
	market.call("_refresh_visual")


func _validate_truck_levels_and_route() -> void:
	var manager: Node = world.get_node("truck_manager")
	manager.call("_init_visuals_if_needed")
	var visuals: Array = manager.get("visual_trucks") as Array
	_expect(visuals.size() == 3, "Truck visuals were not created at the depot")
	if visuals.is_empty():
		return
	var truck: Node2D = visuals[0] as Node2D
	for level: int in range(1, 6):
		manager.set("truck_level", level)
		manager.call("_refresh_visual_levels")
		var artwork: Sprite2D = truck.get_node("VisualRoot/AssetArtwork") as Sprite2D
		_expect(int(truck.get("vehicle_level")) == level, "Truck Lv%d visual did not swap" % level)
		_expect(artwork.texture != null and artwork.visible, "Truck Lv%d artwork missing" % level)
		_expect(_sprite_bottom_matches_target(truck, artwork), "Truck Lv%d ground pivot is inconsistent" % level)
	manager.set("truck_count", 1)
	var travel_time: float = float(manager.call("get_visual_travel_time"))
	var total_time: float = 100.0
	var deliveries: Array = manager.get("deliveries") as Array
	deliveries[0] = {"remaining": total_time - travel_time * 0.4, "total_time": total_time, "payout_done": true}
	manager.call("_process", 0.0)
	_expect(truck.visible and truck.position.is_equal_approx(manager.call("_get_truck_pos", 0.4, 0)), "Truck outbound visual left its existing route")
	deliveries[0] = {"remaining": -travel_time * 0.4, "total_time": total_time, "payout_done": true}
	manager.call("_process", 0.0)
	_expect(truck.visible and truck.position.is_equal_approx(manager.call("_get_truck_pos", 0.6, 0)) and truck.scale.x < 0.0, "Truck return visual or facing is wrong")
	deliveries[0] = {}
	manager.call("_process", 0.0)
	_expect(truck.position.is_equal_approx(manager.call("_get_truck_spawn_position", 0)) and truck.scale.x > 0.0, "Truck depot parking alignment is wrong")


func _validate_crop_scale_categories() -> void:
	var samples: Dictionary = {
		"rice": Rect2(-24.0, -20.0, 48.0, 44.0),
		"tomato": Rect2(-24.0, -31.0, 48.0, 56.0),
		"banana": Rect2(-23.0, -42.0, 46.0, 68.0),
	}
	var crop_ids: Array[String] = ["rice", "tomato", "banana"]
	var tiles: Array[Node] = [world.get_node("farm/tile_01"), world.get_node("farm/tile_02"), world.get_node("farm/tile_03")]
	for index: int in range(tiles.size()):
		var tile: Node = tiles[index]
		var crop_id: String = crop_ids[index]
		tile.call("set_purchased", true)
		var growth_time: float = data_manager.get_crop_growth_time_seconds(crop_id)
		_expect(bool(tile.call("apply_saved_crop", crop_id, growth_time)), "%s visual fixture could not be prepared" % crop_id)
		_expect((tile.call("_get_crop_visual_rect") as Rect2) == samples[crop_id], "%s uses the wrong crop scale category" % crop_id)
		var artwork: Sprite2D = tile.get_node("VisualRoot/CropArtwork") as Sprite2D
		_expect(artwork.texture != null and artwork.visible, "%s world artwork is missing" % crop_id)


func _validate_labels() -> void:
	var animal: Node = animal_scene.instantiate()
	animal.set("animal_instance_id", "chicken_01")
	animal.set("animal_id", "chicken")
	add_child(animal)
	var animal_label: Label = animal.get_node("name_label") as Label
	_expect(animal_label.offset_top >= 30.0, "Animal label still overlaps the sprite body")
	var staff_scene: PackedScene = load("res://scenes/restaurant/staff.tscn") as PackedScene
	var staff_a: Node = staff_scene.instantiate()
	var staff_b: Node = staff_scene.instantiate()
	add_child(staff_a)
	add_child(staff_b)
	staff_a.call("configure", "waiter_01", "waiter", world.get_node("restaurant"), Vector2.ZERO)
	staff_b.call("configure", "waiter_02", "waiter", world.get_node("restaurant"), Vector2.ZERO)
	var label_a: Label = staff_a.get_node("staff_label") as Label
	var label_b: Label = staff_b.get_node("staff_label") as Label
	_expect(label_a.offset_bottom <= -38.0, "Staff label still overlaps the sprite body")
	_expect(not is_equal_approx(label_a.offset_top, label_b.offset_top), "Adjacent staff labels are not staggered")
	animal.queue_free()
	staff_a.queue_free()
	staff_b.queue_free()


func _validate_upgrade_board() -> void:
	var board: Node = upgrade_board_scene.instantiate()
	add_child(board)
	await get_tree().process_frame
	var visual_root: Node = board.get_node("VisualRoot")
	var artwork: Sprite2D = board.get_node_or_null("VisualRoot/AssetArtwork") as Sprite2D
	_expect(String(visual_root.get("atlas_id")) == "building_purchase_upgrade_construction_kit", "Upgrade board does not use the approved construction atlas")
	_expect(String(visual_root.get("semantic_id")) == "building_blueprint_plan_board", "Upgrade board mapping is not the canonical blueprint board")
	_expect(artwork != null and artwork.texture != null, "Upgrade board artwork is missing")
	board.queue_free()


func _sprite_bottom_matches_target(vehicle: Node, artwork: Sprite2D) -> bool:
	var rect: Rect2 = vehicle.get("target_rect") as Rect2
	var texture_height: float = artwork.texture.get_size().y * absf(artwork.scale.y)
	var artwork_bottom: float = artwork.position.y + texture_height * 0.5
	return is_equal_approx(artwork_bottom, rect.end.y)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("visual_polish_runtime_test: %s" % message)
