extends Node

## Standalone evidence capture. PASS means fixture/texture checks succeeded;
## visual production sign-off is reported separately and may remain BLOCKED.
const output_dir := "D:/Game/LaHoue/reports/visual_completion_v3/captures"
var failures: int = 0
var captures: Array[Dictionary] = []
@onready var world: Node = get_parent()
@onready var player: Node2D = world.get_node("player")
@onready var camera: Camera2D = player.get_node("camera")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("lahoue_codex_visual_v2_capture") or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	settings_manager.set_fullscreen(false)
	settings_manager.set_resolution(Vector2i(1280,720))
	world.get_node("ui").visible = false
	camera.set_as_top_level(true)
	await get_tree().create_timer(0.4).timeout
	await _capture_display("standalone_1280x720", Vector2(1000,580),0.65,Vector2i(1280,720))
	settings_manager.set_resolution(Vector2i(1920,1080))
	await get_tree().create_timer(0.4).timeout
	await _capture_display("standalone_1920x1080", Vector2(1000,580),0.65,Vector2i(1920,1080))
	_check(world.farm_tiles_by_id.size() == 28, "exactly 28 individual farm nodes")
	_check(world.purchased_farm_plots == ["farm_01"], "starter one owned plot")
	await _capture("starter_one_plot", Vector2(800,440), 1.0)
	game_manager.level = 55
	game_manager.money = 9000000000
	world.upgrade_system("restaurant")
	var rest: Node2D = world.get_node("restaurant")
	_check(rest.tables_by_id.size() == 2 and rest.purchased_table_count == 2, "Lv1 two purchased table slots")
	await _capture("restaurant_lv1", rest.global_position + Vector2(0,-55), 1.4)
	for tier: int in range(4): rest.upgrade_system("restaurant")
	_check(rest.tables_by_id.size() == 15 and rest.purchased_table_count == 2, "Lv5 expansion does not buy tables")
	await _capture("restaurant_lv5_two_purchased", rest.global_position + Vector2(0,-70), 1.4)
	while rest.purchased_table_count < 15: rest.purchase_next_table()
	var rooftop: int = 0
	for table: Node2D in rest.tables_by_id.values():
		if table.get_meta("floor") == "rooftop": rooftop += 1
		_check(table.position.x < 145, "clear stair corridor")
	_check(rooftop == 9, "Lv5 nine rooftop tables")
	for i: int in range(15): rest.spawn_customer("visual_guest_%02d" % i, "garlic_egg_rice")
	await get_tree().process_frame
	await get_tree().process_frame
	for id: String in rest.customers_by_id:
		var customer: Node2D = rest.customers_by_id[id]
		customer.is_walking_in = false
		customer.walk_path.clear()
		customer.position = rest.to_local(rest.tables_by_id[customer.table_id].get_node("seat_marker").global_position)
		rest._on_customer_arrived_at_table(id)
		var observer: Node = customer.get_node("animation_presentation")
		observer.cancel_action()
		observer.refresh_snapshot()
		observer._advance_fallback(1.0)
	var presentation: Node = rest.get_node("VisualRoot/ModularRestaurant")
	presentation.refresh()
	_check(presentation.ready_dishes.is_empty(), "Food Pass empty before cooking")
	await _capture("food_pass_empty_lv5", rest.global_position + Vector2(0,-70), 1.4)
	inventory_manager.add_item("egg", 1)
	_check(rest.start_cooking("visual_guest_00"), "known recipe cooking starts")
	presentation.refresh()
	await _capture("chef_cooking_lv5", rest.global_position + Vector2(0,-70), 1.4)
	rest.advance_cooking(100.0)
	_check(presentation.ready_dishes.has("visual_guest_00"), "Food Pass uses actual ready job")
	await _capture("food_pass_ready_lv5", rest.global_position + Vector2(0,-70), 1.4)
	# Exercise the actual player's physical pickup and delivery, with a fixed
	# camera and no teleports along the service route.
	rest.set_process(false)
	player.global_position = rest.to_global(Vector2(-150,-40))
	_check(player.begin_food_delivery(rest,"visual_guest_00"), "manual delivery requested")
	game_manager.start_gameplay()
	for frame: int in range(360):
		await get_tree().physics_frame
		if player.carrying_food: break
	await get_tree().create_timer(0.25).timeout
	game_manager.stop_gameplay()
	_check(player.carrying_food, "player physically reaches Food Pass")
	var player_observer: Node = player.get_node("animation_presentation")
	player_observer.refresh_snapshot()
	player_observer._advance_fallback(0.05)
	await _capture("player_carrying_meal",rest.global_position + Vector2(0,-70),1.4,true)
	game_manager.start_gameplay()
	for frame: int in range(600):
		await get_tree().physics_frame
		if player.delivery_customer_id.is_empty(): break
	game_manager.stop_gameplay()
	_check(player.delivery_customer_id.is_empty(), "player physically reaches purchased table")
	presentation.refresh()
	_check(presentation.ready_dishes.is_empty() and presentation.served_dishes.has("visual_guest_00"), "pickup moves meal to table")
	var diner: Node = rest.get_customer("visual_guest_00").get_node("animation_presentation")
	diner.cancel_action()
	diner.refresh_snapshot()
	diner._advance_fallback(1.0)
	await _capture("food_pass_picked_up_lv5", rest.global_position + Vector2(0,-70), 1.4)
	_check(rest.finish_customer_meal("visual_guest_00"), "real payment collected")
	await _capture("customer_paying",rest.global_position+Vector2(0,-70),1.4)
	game_manager.start_gameplay()
	await get_tree().create_timer(0.4).timeout
	game_manager.stop_gameplay()
	diner.cancel_action()
	diner.refresh_snapshot()
	await _capture("customer_leaving",rest.global_position+Vector2(0,-70),1.4)
	inventory_manager.add_item("egg",1)
	_check(rest.start_cooking("visual_guest_01"),"waiter meal cooking")
	rest.advance_cooking(100)
	var waiter: Node = rest.hire_staff("visual_waiter","waiter")
	await get_tree().process_frame
	_check(rest.assign_staff_job("visual_waiter","serve","visual_guest_01"),"waiter delivery dispatched")
	game_manager.start_gameplay()
	await get_tree().create_timer(0.18).timeout
	waiter.advance(0.70)
	game_manager.stop_gameplay()
	waiter.get_node("animation_presentation").refresh_snapshot()
	waiter.get_node("animation_presentation")._advance_fallback(0.05)
	await _capture("waiter_carrying_meal",rest.global_position+Vector2(0,-70),1.4)
	waiter.advance(10.0)
	_check(rest.get_customer("visual_guest_01").current_state == "eating", "waiter physically finishes service")
	for i: int in range(27): world.purchase_next_farm_plot()
	for id: String in world.farm_tiles_by_id:
		var tile: Node = world.farm_tiles_by_id[id]
		tile.apply_saved_crop("rice",30.0)
		var artwork: Sprite2D = tile.get_node("VisualRoot/AssetArtwork")
		_check(artwork.is_visible_in_tree() and _texture_path(artwork.texture).ends_with("lahoue_v3/terrain/plot.png"), "single production plot texture: " + id)
	for housing: String in ["coop","pig_pen","cow_barn"]:
		for tier: int in range(5): world.upgrade_system(housing)
	for species: String in ["chicken","meat_chicken","pig","dairy_cow","cow"]:
		for i: int in range(3): world.purchase_animal("visual_%s_%d" % [species,i],species,Vector2.ZERO)
	for id: String in world.aquaculture_containers_by_id:
		world.upgrade_pond(id)
		world.aquaculture_containers_by_id[id].start_cycle()
	for sample: int in range(2):
		for animal: Node in world.animals_by_id.values(): animal.get_node("animation_presentation")._advance_fallback(4.0)
		for pond: Node in world.aquaculture_containers_by_id.values(): pond.get_node("animation_presentation")._advance_fallback(4.0)
		await _capture("creatures_motion_%d" % sample, Vector2(1130,440), 1.3)
	await _capture("farm_28_normal_scale",Vector2(810,455),1.0)
	await _capture("world_overview_zoom_065",Vector2(1000,580),0.65)
	await _capture("world_west_normal_scale",Vector2(750,550),1.0)
	await _capture("world_east_normal_scale",Vector2(1430,660),1.0)
	var truck: Node = world.get_node("truck_manager")
	truck.set_process(false)
	truck.truck_count = 3
	truck._process(0.0)
	await _capture("depot_three_parked",Vector2(500,765),1.6)
	var travel: float = truck.get_visual_travel_time()
	for direction: String in ["e","s","w","n"]:
		var returning: bool = direction in ["w","n"]
		var progress: float = {"e":0.25,"s":0.54,"w":0.75,"n":0.46}[direction]
		for step: float in [progress - 0.01,progress]:
			truck.deliveries[0] = {"remaining":-travel*step if returning else 50.0-travel*step,"total_time":50.0,"payout_done":returning}
			truck._process(0.0)
			truck.visual_trucks[0].get_node("animation_presentation").refresh_snapshot()
		_check(truck.get_truck_phase(0) == ("Returning" if returning else "Outbound"), "real truck phase: " + direction)
		await _capture("truck_route_" + direction,truck.visual_trucks[0].global_position + Vector2(0,-20),1.6)
	truck._init_deliveries()
	truck._process(0.0)
	world.purchase_building("international_license")
	world.purchase_building("helipad")
	var market: Node = world.get_node("hub/premium_market")
	market.set_process(false)
	for phase: String in ["ready","departing","returning"]:
		market.current_state = phase
		market.phase_elapsed = market._get_flight_duration() * {"ready":0.0,"departing":0.12,"returning":0.75}[phase]
		market._refresh_visual()
		var helicopter: Node = market.get_node("helicopter")
		helicopter.get_node("animation_presentation").refresh_snapshot()
		helicopter.get_node("animation_presentation")._advance_fallback(0.1)
		_check(helicopter.visible, "helicopter visible in fixture: " + phase)
		await _capture("helicopter_" + phase,Vector2(630,230),1.6)
	var report := {"functional_capture_checks": "PASS" if failures == 0 else "FAIL", "failures":failures, "visual_signoff":"REQUIRES_VISUAL_REVIEW", "captures":captures}
	var file := FileAccess.open(output_dir + "/runtime_texture_evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("visual_completion_capture: %s; %d screenshots; inspect images for visual sign-off" % ["PASS" if failures == 0 else "FAIL",captures.size()])
	get_tree().quit.call_deferred(0 if failures == 0 else 1)

func _capture(id: String, focus: Vector2, zoom: float, show_player: bool = false) -> void:
	for child: Node in world.get_children():
		if child.get_script() == preload("res://scripts/ui/floating_text.gd"): child.hide()
	camera.global_position = focus
	player.visible = show_player or id == "starter_one_plot"
	camera.zoom = Vector2.ONE * zoom
	camera.reset_smoothing()
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	_check(frame.save_png(output_dir + "/" + id + ".png") == OK,"capture saved: " + id)
	var sprites: Array[Dictionary] = []
	var placeholders: Array[String] = []
	for node: Node in world.find_children("*","Polygon2D",true,false):
		if node.is_visible_in_tree() and node.texture == null and String(node.name) != "product_indicator":
			placeholders.append(String(world.get_path_to(node)))
	_check(placeholders.is_empty(),"no visible placeholder polygons: "+str(placeholders))
	for node: Node in world.find_children("*","Sprite2D",true,false):
		var sprite: Sprite2D = node as Sprite2D
		if sprite.is_visible_in_tree() and sprite.texture != null:
			sprites.append({"node":String(world.get_path_to(sprite)),"texture":_texture_path(sprite.texture),"position":str(sprite.global_position)})
	captures.append({"id":id,"path":output_dir + "/" + id + ".png","camera_zoom":zoom,"visible_sprite_sources":sprites,"visible_placeholder_polygons":placeholders})


func _capture_display(id: String, focus: Vector2, zoom: float, expected_size: Vector2i) -> void:
	await _capture(id, focus, zoom)
	var image: Image = get_viewport().get_texture().get_image()
	_check(image.get_size() == expected_size, "standalone render size: " + str(expected_size))

func _texture_path(texture: Texture2D) -> String:
	while texture is AtlasTexture: texture = (texture as AtlasTexture).atlas
	return texture.resource_path if texture != null else ""

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("visual_completion_capture: " + message)
