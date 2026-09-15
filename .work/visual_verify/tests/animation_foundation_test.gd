extends Node

const observer_script: GDScript = preload("res://scripts/visual/animation_state_observer.gd")
const staff_scene: PackedScene = preload("res://scenes/restaurant/staff.tscn")
const customer_scene: PackedScene = preload("res://scenes/restaurant/customer.tscn")
const animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")
const aquaculture_scene: PackedScene = preload("res://scenes/aquaculture/aquaculture_container.tscn")

var failures: int = 0
var payments: int = 0
var completed_jobs: Array[String] = []
@onready var world: Node = get_parent()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").to_lower().contains("lahoue_codex_animation_test"):
		push_error("animation_foundation_test: isolated user directory required")
		get_tree().quit(1)
		return
	game_manager.stop_gameplay()
	var restaurant: Node = world.get_node("restaurant")
	var staff: Node2D = staff_scene.instantiate()
	restaurant.get_node("staffs").add_child(staff)
	staff.call("configure", "animation_waiter", "waiter", restaurant, Vector2.ZERO)
	var customer: Node2D = customer_scene.instantiate()
	restaurant.get_node("customers").add_child(customer)
	customer.call("configure", "animation_customer", "regular", restaurant)
	var animal: Node2D = animal_scene.instantiate()
	animal.set("animal_instance_id", "animation_chicken")
	animal.set("animal_id", "chicken")
	world.add_child(animal)
	var pond: Node2D = aquaculture_scene.instantiate()
	pond.set("container_id", "animation_fish")
	pond.set("aquaculture_id", "fish")
	world.add_child(pond)
	await get_tree().process_frame
	await get_tree().process_frame
	var staff_observer: Node = staff.get_node("animation_presentation")
	var customer_observer: Node = customer.get_node("animation_presentation")
	customer_observer.action_requested.connect(func(action: String, _context: Dictionary):
		if action == "payment": payments += 1)
	staff_observer.action_requested.connect(func(action: String, _context: Dictionary): completed_jobs.append(action))
	# Seated is assigned before the physical walk has completed.
	customer.set("current_state", "seated")
	customer.set("is_walking_in", true)
	customer_observer.refresh_snapshot()
	_expect(customer_observer.state == "walk", "walking flags override early seated state")
	customer.set("is_walking_in", false)
	customer.set("current_state", "eating")
	customer_observer.refresh_snapshot()
	_expect(customer_observer.state == "eat", "eating state observed")
	customer.set("current_state", "leaving")
	customer_observer.refresh_snapshot()
	_expect(payments == 0, "leaving alone never invents payment")
	restaurant.payment_collected.emit("unrelated_customer", "garlic_egg_rice", 100)
	_expect(payments == 0, "other customers' payments ignored")
	restaurant.payment_collected.emit("animation_customer", "garlic_egg_rice", 100)
	_expect(payments == 1, "successful payment event forwarded once")
	staff.set("current_state", "returning")
	staff.set("destination", Vector2(20, 0))
	staff_observer.refresh_snapshot()
	_expect(staff_observer.state == "walk" and staff_observer.direction == "e", "staff return direction observed")
	staff.job_finished.emit("animation_waiter", {"job_type": "serve", "target_id": "animation_customer"})
	_expect(completed_jobs == ["serve"], "instant job completion remains observable")
	var staff_saved: Dictionary = staff.call("get_save_state")
	var customer_saved: Dictionary = customer.call("get_save_state")
	for actor: Node in [world.get_node("player"), staff, customer, animal, pond, restaurant]:
		var observer: Node = actor.get_node("animation_presentation")
		_expect(observer.frame_library.is_empty(), "%s has no fabricated animation resources" % actor.name)
		var before: Transform2D = actor.transform
		observer.refresh_snapshot()
		observer.request_action("missing_action")
		_expect(actor.transform == before, "%s transform unchanged" % actor.name)
		if not observer.artwork_path.is_empty():
			var artwork: Sprite2D = observer.get_node_or_null(observer.artwork_path)
			if artwork != null:
				var animated: AnimatedSprite2D = artwork.get_parent().get_node_or_null("animation_artwork")
				var renders_v3: bool = animated != null and animated.visible and animated.sprite_frames != null
				_expect((renders_v3 and artwork.self_modulate.a == 0.0) or (not renders_v3 and artwork.self_modulate == Color.WHITE), "%s renders exactly one authored actor layer" % actor.name)
	_expect(staff.call("get_save_state") == staff_saved, "staff saved fields unchanged")
	_expect(customer.call("get_save_state") == customer_saved, "customer saved fields unchanged")
	var manager: Node = world.get_node("truck_manager")
	manager.call("_init_visuals_if_needed")
	await get_tree().process_frame
	for truck: Node2D in manager.visual_trucks:
		var position_before: Vector2 = truck.position
		truck.get_node("animation_presentation").refresh_snapshot()
		_expect(truck.position == position_before, "truck route position untouched")
	var market: Node = world.get_node("hub/premium_market")
	var helicopter: Node2D = market.get_node("helicopter")
	var market_before: Dictionary = market.call("get_save_state")
	var helicopter_before: Transform2D = helicopter.transform
	helicopter.get_node("animation_presentation").refresh_snapshot()
	_expect(helicopter.transform == helicopter_before and market.call("get_save_state") == market_before, "helicopter route and shipment state untouched")
	for vector: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		_expect(observer_script.direction_from_vector(vector) in ["e", "s", "w", "n"], "cardinal direction contract")
	var expected_character_directions: Dictionary = {
		Vector2(1, -1): "ne", Vector2(-1, -1): "nw",
		Vector2(1, 1): "se", Vector2(-1, 1): "sw",
	}
	for motion: Vector2 in expected_character_directions:
		var direction: String = expected_character_directions[motion]
		_expect(observer_script.character_direction_from_vector(motion) == direction, "isometric character direction: %s" % direction)
		customer_observer.present({"identity":"customer", "state":"walk", "direction":direction})
		var animated: AnimatedSprite2D = customer.get_node("AssetVisualRoot/animation_artwork") as AnimatedSprite2D
		_expect(animated != null and animated.animation == StringName("walk_" + direction), "customer walk clip: %s" % direction)
		_expect(animated != null and animated.flip_h == (direction in ["nw", "sw"]), "customer facing: %s" % direction)
		var player_observer: Node = world.get_node("player/animation_presentation")
		player_observer.present({"identity":"player", "state":"walk", "direction":direction})
		var player_animated: AnimatedSprite2D = world.get_node("player/AssetVisualRoot/animation_artwork") as AnimatedSprite2D
		_expect(player_animated != null and player_animated.animation == StringName("walk_" + direction), "player walk clip: %s" % direction)
		_expect(player_animated != null and player_animated.flip_h == (direction in ["nw", "sw"]), "player facing: %s" % direction)
	# Save restoration refreshes state without replaying one-shot success events.
	save_manager.game_loaded.emit("test_fixture")
	_expect(payments == 1, "load does not replay payment")
	get_tree().paused = true
	var frozen: Dictionary = customer_observer.snapshot.duplicate(true)
	await get_tree().process_frame
	_expect(customer_observer.snapshot == frozen, "presentation pauses with the scene tree")
	get_tree().paused = false
	await _test_playback_contract()
	staff.queue_free()
	customer.queue_free()
	animal.queue_free()
	pond.queue_free()
	await get_tree().process_frame
	restaurant.payment_collected.emit("animation_customer", "garlic_egg_rice", 100)
	_expect(payments == 1, "freed observers disconnect external signals")
	print("animation_foundation_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(0 if failures == 0 else 1)


func _test_playback_contract() -> void:
	# Reuse a real static texture only as a playback probe, never as a production walk/pose.
	var fixture := Node2D.new()
	add_child(fixture)
	var artwork := Sprite2D.new()
	artwork.name = "artwork"
	artwork.texture = (world.get_node("player/AssetVisualRoot/AssetArtwork") as Sprite2D).texture
	artwork.scale = Vector2(0.05, 0.05)
	fixture.add_child(artwork)
	var presenter: Node = preload("res://scripts/visual/animation_presenter.gd").new()
	presenter.artwork_path = NodePath("../artwork")
	fixture.add_child(presenter)
	var frames := SpriteFrames.new()
	frames.add_animation("probe_default")
	frames.set_animation_loop("probe_default", false)
	frames.set_animation_speed("probe_default", 20.0)
	frames.add_frame("probe_default", artwork.texture)
	presenter.frame_library["probe"] = frames
	presenter.present({"identity": "probe", "state": "idle", "direction": "e"})
	var original_transform: Transform2D = artwork.transform
	presenter.set_playback_active(false)
	presenter.request_action("probe")
	var animated: AnimatedSprite2D = fixture.get_node("animation_artwork")
	_expect(animated.visible and artwork.self_modulate.a == 0.0, "explicit frame resource can render without duplicate static artwork")
	_expect(artwork.transform == original_transform, "frame renderer preserves normalized static transform")
	await get_tree().create_timer(0.1).timeout
	_expect(animated.visible and animated.speed_scale == 0.0, "playback freezes when gameplay is stopped")
	artwork.visible = false
	presenter.present({"identity": "probe", "state": "idle", "direction": "e"})
	_expect(not animated.visible, "gameplay visibility remains authoritative")
	artwork.visible = true
	presenter.set_playback_active(true)
	await get_tree().create_timer(0.15).timeout
	_expect(artwork.self_modulate == Color.WHITE and not animated.visible, "one-shot completion restores fallback without gameplay callbacks")
	presenter.present({"identity": "probe", "state": "walk", "direction": "nw"})
	_expect(artwork.self_modulate == Color.WHITE and not animated.visible, "missing walk direction retains static artwork")
	frames.add_animation("off_duty_default")
	frames.set_animation_loop("off_duty_default", true)
	frames.add_frame("off_duty_default", artwork.texture)
	presenter.present({"identity": "probe", "state": "off_duty", "direction": "e"})
	await get_tree().create_timer(0.08).timeout
	var progress_before: float = animated.frame_progress
	presenter.present({"identity": "probe", "state": "off_duty", "direction": "e"})
	_expect(animated.is_playing() and is_equal_approx(animated.frame_progress, progress_before), "repeated passive state does not restart or stop a loop")
	presenter.present({"identity": "probe", "state": "missing", "direction": "e"})
	presenter.present({"identity": "probe", "state": "off_duty", "direction": "e"})
	_expect(animated.is_playing(), "provided clip resumes after missing-clip fallback")
	fixture.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("animation_foundation_test: " + message)
