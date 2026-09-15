extends Node

@onready var world: Node = get_parent()

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("lahoue_codex_final_visual_capture"):
		get_tree().quit(1)
		return
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	game_manager.level = 55
	game_manager.money = 9000000000
	for system: String in ["restaurant","coop","pig_pen","cow_barn"]:
		for tier: int in range(5): world.upgrade_system(system)
	var rest: Node = world.get_node("restaurant")
	while rest.purchased_table_count < 15: rest.purchase_next_table()
	for i: int in range(15): rest.spawn_customer("capture_guest_%02d" % i,"garlic_egg_rice")
	await get_tree().process_frame
	await get_tree().process_frame
	for id: String in rest.customers_by_id:
		var customer: Node2D = rest.customers_by_id[id]
		customer.is_walking_in = false
		customer.walk_path.clear()
		var table: Node2D = rest.tables_by_id[customer.table_id]
		customer.position = rest.to_local(table.get_node("seat_marker").global_position)
		rest._on_customer_arrived_at_table(id)
		customer.get_node("animation_presentation").refresh_snapshot()
		customer.get_node("animation_presentation")._advance_fallback(0.1)
	inventory_manager.add_item("egg",2)
	for id: String in ["capture_guest_00","capture_guest_01"]: rest.start_cooking(id)
	rest.advance_cooking(100.0)
	rest.serve_order("capture_guest_00")
	rest.get_customer("capture_guest_00").get_node("animation_presentation").refresh_snapshot()
	rest.get_customer("capture_guest_00").get_node("animation_presentation")._advance_fallback(1.0)
	for i: int in range(27): world.purchase_next_farm_plot()
	for id: String in world.farm_tiles_by_id:
		var tile: Node = world.farm_tiles_by_id[id]
		tile.call("apply_saved_crop", "rice", 30.0)
	for species: String in ["chicken","pig","cow"]:
		for i: int in range(3): world.purchase_animal("capture_%s_%d" % [species,i],species,Vector2.ZERO)
	for id: String in world.aquaculture_containers_by_id:
		world.upgrade_pond(id)
		world.aquaculture_containers_by_id[id].start_cycle()
	var observer: Node
	for animal: Node in world.animals_by_id.values():
		observer = animal.get_node("animation_presentation")
		observer.refresh_snapshot()
		observer._advance_fallback(0.1)
	var player: Node2D = world.get_node("player")
	var camera: Camera2D = world.get_node("player/camera")
	world.get_node("ui").visible = false
	await get_tree().create_timer(2.0).timeout
	for focus: String in ["restaurant","farm","animals","truck_road"]:
		player.position = {"restaurant":rest.global_position + Vector2(0,-70), "farm":Vector2(780,430), "animals":Vector2(1110,435), "truck_road":Vector2(800,745)}[focus]
		player.reset_physics_interpolation()
		camera.reset_smoothing()
		camera.zoom = Vector2(1.4,1.4) if focus == "restaurant" else Vector2.ONE
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		if not OS.get_cmdline_user_args().has("--no-screenshots"):
			var capture: Image = get_viewport().get_texture().get_image()
			capture.save_png("D:/Game/LaHoue/.work/final_%s.png" % focus)
	# Exercise actual physics movement while rendering at uncapped idle cadence.
	camera.zoom = Vector2.ONE
	player.position = Vector2(720,580)
	player.reset_physics_interpolation()
	Engine.physics_ticks_per_second = 20
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.3).timeout
	var last_x: float = get_viewport().get_canvas_transform().origin.x
	var interpolated_frames: int = 0
	var backward_frames: int = 0
	var samples: Array[float] = []
	Input.action_press("move_right")
	for frame: int in range(120):
		await RenderingServer.frame_post_draw
		var x: float = get_viewport().get_canvas_transform().origin.x
		var travel: float = last_x - x
		if travel > 0.01 and travel < 11.99: interpolated_frames += 1
		if travel < -0.01: backward_frames += 1
		samples.append(travel)
		last_x = x
	Input.action_release("move_right")
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().has("--no-screenshots"):
		var capture: Image = get_viewport().get_texture().get_image()
		capture.save_png("D:/Game/LaHoue/.work/final_camera_motion.png")
	var motion_ok: bool = interpolated_frames >= 40 and backward_frames == 0 and player.position.x > 820
	var metrics := {"physics_hz":20, "render_limit":120, "samples":samples, "interpolated_frames":interpolated_frames, "backward_frames":backward_frames, "pass":motion_ok}
	var file := FileAccess.open("D:/Game/LaHoue/reports/final_camera_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("final_visual_capture: %s; camera: %d/120 sub-tick movements, %d reverse frames" % ["PASS" if motion_ok else "FAIL",interpolated_frames,backward_frames])
	# Let deferred scene teardown finish outside the capture coroutine.
	get_tree().quit.call_deferred(0 if motion_ok else 1)
