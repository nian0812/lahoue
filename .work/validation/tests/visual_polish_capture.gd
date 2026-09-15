extends Node

const staff_scene: PackedScene = preload("res://scenes/restaurant/staff.tscn")
const animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")

@onready var world: Node = get_parent()


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_visual_capture"):
		push_error("visual_polish_capture: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return
	var capture_size := Vector2i(1280, 720)
	var capture_path: String = "res://.tmp/visual_polish_1280x720.png"
	var capture_focus: String = "default"
	for argument: String in OS.get_cmdline_user_args():
		var normalized_argument: String = argument.trim_prefix("--")
		if normalized_argument.begins_with("capture_size="):
			var parts: PackedStringArray = normalized_argument.trim_prefix("capture_size=").split("x")
			if parts.size() == 2:
				capture_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif normalized_argument.begins_with("capture_path="):
			capture_path = normalized_argument.trim_prefix("capture_path=")
		elif normalized_argument.begins_with("capture_focus="):
			capture_focus = normalized_argument.trim_prefix("capture_focus=")
	get_window().size = capture_size
	game_manager.stop_gameplay()
	_setup_visual_showcase()
	_apply_capture_focus(capture_focus)
	await get_tree().process_frame
	await get_tree().process_frame
	_close_transient_ui()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(capture_path)
	print("visual_polish_capture: %s %dx%d (%s)" % ["PASS" if error == OK else "FAIL", image.get_width(), image.get_height(), capture_path])
	get_tree().quit(0 if error == OK else 1)


func _setup_visual_showcase() -> void:
	game_manager.level = 55
	var plots: Array[String] = []
	for index: int in range(1, 41):
		plots.append("farm_%02d" % index)
	world.call("apply_progression_save_state", {
		"coop_level": 1,
		"pig_pen_level": 1,
		"cow_barn_level": 1,
		"aquaculture_level": 1,
		"resort_level": 1,
		"purchased_farm_plots": plots,
		"building_ownership": {
			"warehouse": true, "coop": true, "pig_pen": true, "cow_barn": true,
			"restaurant": true, "vip_area": true, "international_license": true,
			"helipad": true, "resort": true,
		},
		"pond_levels": {
			"aquaculture_fish": 1, "aquaculture_shrimp": 1, "aquaculture_crab": 1,
			"aquaculture_squid": 1, "aquaculture_octopus": 1,
		},
	})
	var crop_samples: Array[String] = ["rice", "tomato", "banana", "wheat", "coffee", "coconut"]
	for index: int in range(crop_samples.size()):
		var crop_id: String = crop_samples[index]
		var tile: Node = world.get_node("farm/tile_%02d" % (index + 1))
		tile.call("apply_saved_crop", crop_id, data_manager.get_crop_growth_time_seconds(crop_id))
	var market: Node = world.get_node("hub/premium_market")
	market.set("helicopter_level", 5)
	market.call("_refresh_visual")
	var truck_manager: Node = world.get_node("truck_manager")
	truck_manager.set("truck_level", 5)
	truck_manager.set("truck_count", 3)
	truck_manager.call("_init_visuals_if_needed")
	truck_manager.call("_refresh_visual_levels")
	var travel_time: float = float(truck_manager.call("get_visual_travel_time"))
	var deliveries: Array = truck_manager.get("deliveries") as Array
	deliveries[1] = {"remaining": 100.0 - travel_time * 0.55, "total_time": 100.0, "payout_done": true}
	deliveries[2] = {"remaining": -travel_time * 0.45, "total_time": 100.0, "payout_done": true}
	truck_manager.call("_process", 0.0)
	_add_label_fixtures()


func _add_label_fixtures() -> void:
	var restaurant: Node = world.get_node("restaurant")
	for index: int in range(2):
		var staff: Node2D = staff_scene.instantiate() as Node2D
		staff.name = "VisualLabelStaff%02d" % (index + 1)
		staff.position = Vector2(900.0 + float(index * 52), 245.0)
		world.add_child(staff)
		staff.call("configure", "waiter_%02d" % (index + 1), "waiter", restaurant, staff.position)
	var animal_ids: Array[String] = ["chicken", "pig"]
	for index: int in range(animal_ids.size()):
		var animal: Node2D = animal_scene.instantiate() as Node2D
		animal.name = "VisualLabelAnimal%02d" % (index + 1)
		animal.set("animal_instance_id", "%s_%02d" % [animal_ids[index], index + 1])
		animal.set("animal_id", animal_ids[index])
		animal.position = Vector2(1020.0 + float(index * 60), 245.0)
		world.add_child(animal)


func _apply_capture_focus(focus_id: String) -> void:
	if focus_id != "logistics":
		return
	var player: Node2D = world.get_node("player") as Node2D
	player.position = Vector2(1000.0, 850.0)
	var camera: Camera2D = player.get_node("camera") as Camera2D
	camera.reset_smoothing()


func _close_transient_ui() -> void:
	var ui: CanvasLayer = world.get_node("ui") as CanvasLayer
	if ui.has_method("_close_active_panel"):
		ui.call("_close_active_panel")
	for node_name: String in ["tutorial_popup", "interaction_prompt", "notification_popup", "level_up_popup", "day_summary_panel"]:
		var control: CanvasItem = ui.get_node_or_null(node_name) as CanvasItem
		if control != null:
			control.visible = false
