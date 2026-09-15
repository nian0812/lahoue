extends Node

var failures: int = 0
@onready var world: Node = get_parent()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("lahoue_codex_final_scope_test"):
		get_tree().quit(1)
		return
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	await get_tree().process_frame
	_expect(world.farm_tiles_by_id.size() == 28, "exactly 28 individual plots")
	_expect(world.purchased_farm_plots == ["farm_01"], "one starter owned plot")
	_expect(game_manager.money == 200000 and inventory_manager.get_amount("rice") == 10, "starter wallet/items")
	for housing: String in ["coop", "pig_pen", "cow_barn"]:
		for tier: int in range(1,6):
			_expect(data_manager.get_animal_housing_capacity(housing,tier) == tier * (4 if housing == "coop" else 2), "%s tier %d capacity" % [housing,tier])
	_expect(data_manager.get_progression_max_level("warehouse") == 7, "seven warehouse levels")
	_expect(data_manager.get_warehouse_capacity(7) == 1500, "warehouse final capacity")
	var restaurant: Node = world.get_node("restaurant")
	game_manager.level = 55
	game_manager.money = 1000000000
	_expect(world.upgrade_system("restaurant"), "purchase restaurant")
	var capacities: Array[int] = [2,4,7,11,15]
	var floor_counts: Array[int] = [0,0,3,6,9]
	for tier: int in range(1,6):
		if tier > 1: _expect(restaurant.upgrade_system("restaurant"), "upgrade restaurant")
		_expect(restaurant.tables_by_id.size() == capacities[tier-1], "restaurant slot capacity %d" % tier)
		while restaurant.purchased_table_count < capacities[tier-1]:
			var balance: int = game_manager.money
			_expect(restaurant.purchase_next_table(), "purchase next fixed table")
			_expect(game_manager.money == balance - restaurant.get_table_purchase_cost(), "table charged once")
		var rooftop_count: int = 0
		for table: Node2D in restaurant.tables_by_id.values():
			if table.get_meta("floor") == "rooftop": rooftop_count += 1
			_expect(table.position.x < 145, "stairs and landing clear")
		_expect(rooftop_count == floor_counts[tier-1], "rooftop count %d" % tier)
	_expect(not restaurant.purchase_next_table(), "15-table maximum enforced")
	var presentation: Node = restaurant.get_node("VisualRoot/ModularRestaurant")
	presentation.refresh()
	_expect(presentation.ready_dishes.is_empty(), "Food Pass starts empty")
	var customer: Node = restaurant.spawn_customer("final_diner", "garlic_egg_rice")
	await get_tree().process_frame
	await get_tree().process_frame
	customer.is_walking_in = false
	customer.walk_path.clear()
	restaurant._on_customer_arrived_at_table("final_diner")
	inventory_manager.add_item("rice",1)
	inventory_manager.add_item("egg",1)
	_expect(restaurant.start_cooking("final_diner"), "manual cooking")
	_expect(presentation.ready_dishes.is_empty(), "no food before ready")
	restaurant.advance_cooking(1000.0)
	_expect(presentation.ready_dishes.has("final_diner"), "ready dish appears")
	if presentation.ready_dishes.has("final_diner"):
		_expect(presentation.ready_dishes.final_diner.get_meta("recipe_id") == "garlic_egg_rice", "correct recipe bound on pass")
	_expect(restaurant.serve_order("final_diner"), "manual serve without waiter")
	_expect(presentation.ready_dishes.is_empty(), "pickup empties pass immediately")
	_expect(presentation.served_dishes.has("final_diner"), "served meal is visible on its table")
	_expect(restaurant.finish_customer_meal("final_diner"), "payment and leave")
	await get_tree().process_frame
	# Snapshot before migration. No mutation of the real user's save is possible.
	var legacy_customer: Node = restaurant.spawn_customer("legacy_diner", "garlic_egg_rice")
	await get_tree().process_frame
	await get_tree().process_frame
	legacy_customer.is_walking_in = false
	legacy_customer.walk_path.clear()
	restaurant._on_customer_arrived_at_table("legacy_diner")
	inventory_manager.add_item("rice",1)
	inventory_manager.add_item("egg",1)
	_expect(restaurant.start_cooking("legacy_diner"), "legacy in-progress meal fixture")
	var original: Dictionary = save_manager._build_save_state()
	var legacy: Dictionary = original.duplicate(true)
	legacy.erase("layout_version")
	legacy.erase("purchased_restaurant_tables")
	legacy["restaurant_level"] = 10
	legacy["kitchen_level"] = 10
	legacy["restaurant_customers"] = {}
	legacy["restaurant_cooking"] = {}
	legacy["restaurant_tables"] = {}
	for i: int in range(1,21): legacy.restaurant_tables["table_%02d" % i] = {"state":"available", "occupant_id":""}
	legacy.restaurant_customers["legacy_diner"] = original.restaurant_customers.legacy_diner.duplicate(true)
	legacy.restaurant_customers.legacy_diner.table_id = "table_20"
	legacy.restaurant_tables.table_20 = {"state":"occupied", "occupant_id":"legacy_diner"}
	legacy.restaurant_cooking.legacy_diner = original.restaurant_cooking.legacy_diner.duplicate(true)
	legacy.purchased_farm_plots = []
	for i: int in range(1,41): legacy.purchased_farm_plots.append("farm_%02d" % i)
	legacy.crops = {"farm_40":"rice"}
	legacy.crop_growth = {"farm_40":30.0}
	var migrated: Dictionary = save_manager._validate_save_state(legacy)
	_expect(migrated.ok, "40 plots / 20 tables legacy save validates: " + str(migrated.get("error", "")))
	if migrated.ok:
		var state: Dictionary = migrated.state
		_expect(state.money == original.money + 211200000, "retired tiers/plots refunded exactly once")
		_expect(state.inventory == original.inventory and state.migration_inventory.rice == 4 and state.migration_inventory.egg == 1, "inventory preserved; retired crop and interrupted cooking ingredients recovered")
		_expect(not state.restaurant_customers.has("legacy_diner") and not state.restaurant_cooking.has("legacy_diner"), "retired table has no dangling customer/job")
		_expect(state.purchased_farm_plots.size() == 28 and state.restaurant_level == 5, "old layout normalized")
		_expect(save_manager._validate_save_state(state).state == state, "migration idempotent")
		save_manager._apply_save_state(state)
		_expect(save_manager.save_game(), "migrated state saves")
		_expect(save_manager.load_game(), "migrated state continues")
		_expect(restaurant.purchased_table_count == 15, "purchased tables persist")
		var reserve_before: int = int(inventory_manager.migration_inventory.get("rice",0)) + int(inventory_manager.migration_inventory.get("egg",0))
		_expect(inventory_manager.claim_migration_items() == reserve_before, "recovered crop claim available")
	var invalid: Dictionary = legacy.duplicate(true)
	var old_five: Dictionary = legacy.duplicate(true)
	old_five.restaurant_level = 5
	old_five.kitchen_level = 5
	old_five.restaurant_tables = {}
	old_five.restaurant_customers = {}
	old_five.restaurant_cooking = {}
	for i: int in range(1,11): old_five.restaurant_tables["table_%02d" % i] = {"state":"available", "occupant_id":""}
	var old_five_result: Dictionary = save_manager._validate_save_state(old_five)
	_expect(old_five_result.ok and old_five_result.state.purchased_restaurant_tables == 10, "legacy ten owned tables preserved when capacity expands to fifteen")
	invalid.purchased_farm_plots.append("farm_40")
	_expect(not save_manager._validate_save_state(invalid).ok, "duplicate retired plot rejected before refund")
	invalid = legacy.duplicate(true)
	invalid.layout_version = "bad"
	_expect(not save_manager._validate_save_state(invalid).ok, "malformed layout rejected safely")
	var waiter: Node = restaurant.hire_staff("final_waiter", "waiter")
	await get_tree().process_frame
	await get_tree().process_frame
	restaurant.tables_by_id.table_05._set_state("needs_cleanup")
	_expect(restaurant.assign_staff_job("final_waiter", "clean", "table_05"), "rooftop cleaning dispatched")
	var waiter_observer: Node = waiter.get_node("animation_presentation")
	_expect(waiter_observer._staff_route.size() >= 5, "staff presentation uses stair corridor")
	waiter.advance(0.05)
	var staff_before: Dictionary = waiter.get_save_state()
	waiter_observer._advance_fallback(0.1)
	_expect(waiter.get_save_state() == staff_before, "stair presentation does not mutate gameplay or saved travel")
	waiter_observer._reset_staff_route()
	_expect(waiter.get_node("AssetVisualRoot").position == waiter_observer._base_visual_position, "cancel/load restores staff presentation offset")
	for housing: String in ["coop", "pig_pen", "cow_barn"]:
		for tier: int in range(5): world.upgrade_system(housing)
		var species: String = {"coop":"chicken","pig_pen":"pig","cow_barn":"cow"}[housing]
		for i: int in range(8): world.purchase_animal("final_%s_%d" % [species,i], species, Vector2.ZERO)
		var represented: int = 0
		for animal: Node in world.animals_by_id.values():
			if animal.animal_id != species: continue
			var visual: Node2D = animal.get_node("AssetVisualRoot")
			var animal_observer: Node = animal.get_node("animation_presentation")
			var animal_before: Dictionary = animal.get_save_state()
			for i: int in range(12):
				animal_observer._advance_fallback(5.0)
				if visual.visible:
					var enclosure: Node2D = world.get_node("animals/" + housing)
					var relative: Vector2 = visual.global_position - enclosure.global_position
					_expect(absf(relative.x) <= 22 and relative.y >= -34 and relative.y <= -10, "representative animal remains inside enclosure")
			if visual.visible: represented += 1
			_expect(animal.get_save_state() == animal_before, "roaming does not alter production/save state")
		_expect(represented == (5 if housing == "coop" else 3), "restrained representative population")
	var camera: Camera2D = world.get_node("player/camera")
	_expect(not camera.position_smoothing_enabled and camera.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS, "camera cadence matches physics, no double smoothing")
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation",false)), "physics interpolation enabled")
	var truck: Node = world.get_node("truck_manager")
	truck._init_visuals_if_needed()
	var travel: float = truck.get_visual_travel_time()
	truck.deliveries[0] = {"remaining":-travel*0.5,"total_time":50.0,"payout_done":true}
	truck._process(0.0)
	_expect(truck.visual_trucks[0].scale.x > 0.0, "return never mirrors isometric perspective")
	_expect(truck.get_truck_phase(0) == "Returning", "return phase preserved")
	# Water interior sampled from the production pond texture (1536 x 1024).
	# Check rendered species corners in source-image space, not distance from
	# the logical pond origin, which lies over the rear building in this artwork.
	var water_interiors: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(75,230),Vector2(159,195),Vector2(244,235),Vector2(158,278)]),
		PackedVector2Array([Vector2(458,184),Vector2(586,120),Vector2(663,150),Vector2(550,222)]),
		PackedVector2Array([Vector2(953,164),Vector2(1071,115),Vector2(1150,151),Vector2(1041,210)]),
		PackedVector2Array([Vector2(166,510),Vector2(285,450),Vector2(367,486),Vector2(250,550)]),
		PackedVector2Array([Vector2(918,641),Vector2(1000,602),Vector2(1070,640),Vector2(992,684)])]
	var approved_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lahoue_v3/manifest.json"))
	for container: Node in world.aquaculture_containers_by_id.values():
		var observer: Node = container.get_node("animation_presentation")
		var saved: Dictionary = container.get_save_state()
		var pond: Sprite2D = container.get_node("VisualRoot/AssetArtwork")
		var species: Sprite2D = container.get_node("VisualRoot/SpeciesArtworkRoot/AssetArtwork")
		var rect: Rect2 = species.get_rect()
		var tier: int = maxi(1,container.pond_level)
		var entry: Dictionary = approved_manifest["buildings/pond_%d" % tier]
		var source_offset := Vector2(entry.crop[0]+entry.trim[0],entry.crop[1]+entry.trim[1])
		for i: int in range(300):
			observer._advance_fallback(0.1)
			for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var source_point: Vector2 = pond.to_local(species.to_global(corner)) + pond.texture.get_size() * 0.5 + source_offset
				_expect(Geometry2D.is_point_in_polygon(source_point, water_interiors[tier-1]), "entire species artwork stays inside production water surface")
		_expect(container.get_save_state() == saved, "swim targets not saved")
	print("final_scope_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	get_tree().quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("final_scope_test: " + message)
