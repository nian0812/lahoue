extends Node

var failures: int = 0
@onready var world: Node = get_parent()
const catalog = preload("res://scripts/visual/lahoue_asset_catalog.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("lahoue_codex_recovery_test"):
		get_tree().quit(1)
		return
	game_manager.stop_gameplay()
	save_manager.create_new_game()
	_expect(game_manager.money == 200000 and game_manager.level == 1, "normal starter profile")
	_expect(inventory_manager.get_amount("rice") == 10 and inventory_manager.get_amount("wheat") == 10, "starter inventory")
	_expect(world.purchased_farm_plots == ["farm_01"] and world.get_node("truck_manager").truck_count == 1, "starter plot and truck")
	game_manager.spend_money(12345)
	inventory_manager.remove_item("rice", 1)
	game_manager.start_gameplay()
	world._process(15.1)
	game_manager.stop_gameplay()
	game_manager.money = 1
	_expect(save_manager.load_game(), "autosave reload")
	_expect(game_manager.money == 187655 and inventory_manager.get_amount("rice") == 9, "player actions persist")
	# Validate the actual pre-debug backup, staging recovery without touching user data.
	var source_path := "D:/Game/LaHoue/.work/recovery_normal_source.json"
	if FileAccess.file_exists(source_path):
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var result: Dictionary = save_manager._validate_save_state(source)
		_expect(result.ok, "pre-debug save validates: " + str(result.get("error", "")))
		if result.ok:
			save_manager._apply_save_state(result.state)
			_expect(save_manager.save_game() and save_manager.load_game(), "real progression recovery round trip")
			_expect(game_manager.level == int(source.level) and game_manager.money == int(source.money), "real level and wallet preserved")
			var file := FileAccess.open("D:/Game/LaHoue/.work/recovered_normal_save.json", FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string("user://savegame.json"))
			file.close()
	save_manager.create_new_game()
	game_manager.level = 55
	game_manager.money = 900000000
	world.upgrade_system("restaurant")
	var rest: Node = world.get_node("restaurant")
	var customer: Node = rest.spawn_customer("recovery_diner", "garlic_egg_rice")
	await get_tree().process_frame
	await get_tree().process_frame
	customer.is_walking_in = false
	customer.walk_path.clear()
	rest._on_customer_arrived_at_table("recovery_diner")
	inventory_manager.add_item("egg",1)
	_expect(rest.start_cooking("recovery_diner"), "cooking begins")
	rest.advance_cooking(1000)
	var player: Node = world.get_node("player")
	_expect(player.begin_food_delivery(rest, "recovery_diner"), "manual pickup starts")
	game_manager.start_gameplay()
	player.global_position = player.delivery_path[0]
	player._advance_delivery(0.02)
	_expect(player.carrying_food, "player carries after pass pickup")
	for i: int in range(12):
		if not player.delivery_path.is_empty(): player.global_position = player.delivery_path[0]
		player._advance_delivery(0.02)
	game_manager.stop_gameplay()
	_expect(customer.current_state == "eating" and not player.carrying_food, "delivered meal begins eating")
	_expect(rest.finish_customer_meal("recovery_diner"), "payment succeeds")
	for who: String in ["player","waiter","chef","customer","customer_woman","vip_customer"]:
		var frames: SpriteFrames = catalog.get_v3_frames(who)
		for clip: String in ["idle","walk","carry","seated_idle","eat","serve","payment"]:
			_expect(frames.has_animation(clip+"_default"), who+" has "+clip)
	for housing: String in ["coop","pig_pen","cow_barn"]:
		for i: int in range(5): world.upgrade_system(housing)
	for species: String in ["chicken","meat_chicken","pig","dairy_cow","cow"]:
		world.purchase_animal("recovery_"+species,species,Vector2.ZERO)
	for animal: Node in world.animals_by_id.values():
		var observer: Node = animal.get_node("animation_presentation")
		var before: Dictionary = animal.get_save_state()
		observer._advance_fallback(0.1)
		var start: Vector2 = animal.get_node("AssetVisualRoot").global_position
		observer._advance_fallback(2.0)
		_expect(animal.get_node("AssetVisualRoot").visible and animal.get_node("AssetVisualRoot").global_position != start, "species visibly roams: "+animal.animal_id)
		_expect(animal.get_save_state() == before, "production unchanged")
	for level: int in range(1,6):
		for direction: String in ["n","s","e","w"]:
			_expect(catalog.get_v3_texture("trucks/truck_%d_%s" % [level,direction]) != null, "truck tier/direction texture")
	_expect(not world.get_node("logistics_zone/Roads/walkway_visual").visible if world.has_node("logistics_zone/Roads/walkway_visual") else true, "legacy walkway hidden")
	print("recovery_runtime_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	get_tree().quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("recovery_runtime_test: " + message)
