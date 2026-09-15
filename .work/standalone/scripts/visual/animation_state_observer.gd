extends "res://scripts/visual/animation_presenter.gd"

const catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")

@export_enum("player", "staff", "customer", "animal", "aquaculture", "truck", "helicopter", "restaurant") var actor_kind: String = "player"

var _actor: Node2D
var _controller: Node
var _previous_position: Vector2
var _direction: String = "s"
var _connections: Array[Dictionary] = []
var _presentation_time: float = 0.0
var _feedback_time: float = 0.0
var _feedback: Label
var _visual_root: Node2D
var _base_visual_position: Vector2
var _staff_route: Array[Vector2] = []
var _staff_start_distance: float = 0.0
var _roam_rng := RandomNumberGenerator.new()
var _roam_target := Vector2.ZERO
var _roam_offset := Vector2.ZERO
var _roam_wait: float = 0.0
var _roam_moving: bool = false
var _carried_meal: Sprite2D


func _ready() -> void:
	_actor = get_parent() as Node2D
	process_priority = 100
	_previous_position = _actor.global_position
	_roam_rng.seed = String(_actor.name).hash()
	_visual_root = _actor.get_node_or_null("AssetVisualRoot") as Node2D
	if _visual_root == null: _visual_root = _actor.get_node_or_null("VisualRoot") as Node2D
	if actor_kind == "aquaculture": _visual_root = _actor.get_node_or_null("VisualRoot/SpeciesArtworkRoot") as Node2D
	if _visual_root != null:
		_base_visual_position = _visual_root.position
	if actor_kind in ["staff", "customer", "animal"]:
		_feedback = Label.new()
		_feedback.name = "PresentationFeedback"
		_feedback.position = Vector2(-24,-54)
		_feedback.add_theme_font_size_override("font_size", 9)
		_feedback.add_theme_constant_override("outline_size", 3)
		_feedback.add_theme_color_override("font_outline_color",Color("#30291d"))
		_feedback.z_index = 6
		_feedback.visible = false
		_actor.add_child.call_deferred(_feedback)
		action_requested.connect(_show_feedback)
	_bind_events.call_deferred()


func _process(delta: float) -> void:
	# Observe paused/stopped state on resume, without replaying gameplay events.
	set_playback_active(game_manager.gameplay_active and not get_tree().paused)
	if not game_manager.gameplay_active or get_tree().paused:
		_previous_position = _actor.global_position
		return
	refresh_snapshot()
	_advance_fallback(delta)


func _show_feedback(action: String, _context: Dictionary) -> void:
	if _feedback == null: return
	var names: Dictionary = {"cook":"Cooking", "serve":"Served", "payment":"Paid", "clean":"Clean", "harvest":"Harvest", "collect_animal":"Collected", "collect_aquaculture":"Collected", "production":"Ready", "collect":"Collected", "sit":"Seated"}
	_feedback.text = names.get(action, action.capitalize())
	_feedback.visible = true
	_feedback_time = 0.85


func _advance_fallback(delta: float) -> void:
	_presentation_time += delta
	_feedback_time = maxf(_feedback_time - delta, 0.0)
	if _feedback != null:
		_feedback.visible = _feedback_time > 0.0
	if _visual_root == null: return
	if actor_kind in ["player", "staff"]: _present_carried_meal()
	match actor_kind:
		"aquaculture":
			var seed_phase: float = float(String(_actor.get("container_id")).hash() % 100) * 0.1
			var sideways: bool = String(_actor.get("aquaculture_id")) == "crab"
			# The pond artwork is bottom-anchored; swim around its authored water
			# center, with enough inset for the entire species sprite to stay wet.
			_visual_root.position = _base_visual_position + Vector2(sin(_presentation_time * 0.45 + seed_phase), sin(_presentation_time * 0.65 + seed_phase) * (0.25 if sideways else 0.5))
		"animal":
			_roam_wait -= delta
			if _roam_wait <= 0.0:
				_roam_target = Vector2(_roam_rng.randf_range(-5,5),_roam_rng.randf_range(-3,3))
				_roam_wait = _roam_rng.randf_range(3,8)
			_roam_moving = _roam_offset.distance_to(_roam_target) > 0.15
			_roam_offset = _roam_offset.move_toward(_roam_target,delta*2.5)
			_present_animal()
		"helicopter":
			_actor.present_vehicle(Vector2.ZERO,state,delta)
			var progress: float = float(snapshot.get("progress", 0.0))
			var altitude: float = 0.0
			if state == "departing": altitude = smoothstep(0.0, 0.3, progress) * 24.0
			elif state == "returning": altitude = smoothstep(0.0, 0.3, 1.0-progress) * 24.0
			elif state == "importing": altitude = 24.0
			_visual_root.position = _base_visual_position + Vector2(0,-altitude)
			var shadow: Node2D = _actor.get_node_or_null("ContactShadow") as Node2D
			if shadow != null:
				shadow.scale = Vector2.ONE * (1.0 + altitude * 0.015)
				shadow.modulate.a = 1.0 - altitude * 0.02
		"staff":
			_present_staff_route()
			# Small acknowledgement gesture only; this is not a fabricated frame loop.
			_visual_root.rotation = sin(_feedback_time / 0.85 * PI) * 0.04 if _feedback_time > 0.0 else 0.0
			if _feedback_time <= 0.0 and String(snapshot.get("gameplay_state", "")) == "cleaning_table":
				_feedback.text = "Cleaning"
				_feedback.visible = true
		"customer":
			var table_id: String = String(_actor.get("table_id"))
			if is_instance_valid(_controller) and _controller.get("tables_by_id") is Dictionary and _controller.tables_by_id.has(table_id):
				_actor.z_index = _controller.tables_by_id[table_id].z_index + 1
			if _feedback_time <= 0.0:
				var label: String = ""
				_feedback.text = label
				_feedback.visible = not label.is_empty()


func _present_carried_meal() -> void:
	var controller: Node = _actor.get_parent().get_node_or_null("restaurant") if actor_kind == "player" else _actor.get("restaurant")
	var target: String = String(_actor.get("delivery_customer_id")) if actor_kind == "player" else String((_actor.get("active_job") as Dictionary).get("target_id", ""))
	if _carried_meal != null: _carried_meal.visible = false
	if state != "carry" or controller == null or target.is_empty(): return
	var job: Dictionary = controller.get_cooking_job(target)
	if job.is_empty(): return
	var texture: Texture2D = catalog.get_dish_texture(String(job.get("recipe_id", "")))
	if texture == null: return
	if _carried_meal == null:
		_carried_meal = Sprite2D.new()
		_carried_meal.name = "CarriedMeal"
		_carried_meal.z_index = 2
		_visual_root.add_child(_carried_meal)
	_carried_meal.visible = true
	preload("res://scripts/visual/manifest_sprite.gd").configure_sprite(_carried_meal,texture,Rect2(0,-15,14,12))


func _present_animal() -> void:
	var world: Node = get_tree().current_scene
	if world == null or not world.get("animals_by_id") is Dictionary: return
	var entry: Dictionary = data_manager.get_entry("animals", String(_actor.get("animal_id")))
	var housing: String = String(entry.get("housing", ""))
	var building: Node2D = world.get_node_or_null("animals/" + housing) as Node2D
	if building == null: return
	var peers: Array[String] = []
	for id: String in world.animals_by_id:
		var other: Node = world.animals_by_id[id]
		var other_entry: Dictionary = data_manager.get_entry("animals", String(other.get("animal_id")))
		if String(other_entry.get("housing", "")) == housing and String(other.get("current_state")) != "completed": peers.append(id)
	peers.sort()
	# Show at least one of every owned species before filling remaining slots.
	var representatives: Array[String] = []
	var seen_species: Dictionary = {}
	for id: String in peers:
		var species: String = String(world.animals_by_id[id].animal_id)
		if not seen_species.has(species):
			seen_species[species] = true
			representatives.append(id)
	for id: String in peers:
		if not representatives.has(id): representatives.append(id)
	peers = representatives
	var index: int = peers.find(String(_actor.get("animal_instance_id")))
	var limit: int = 5 if housing == "coop" else 3
	var represented: bool = index >= 0 and index < limit
	_visual_root.visible = represented
	_visual_root.z_index = 3
	var shadow: Node2D = _actor.get_node_or_null("ContactShadow") as Node2D
	if shadow != null: shadow.visible = represented
	if not represented:
		if _feedback != null: _feedback.visible = false
		_actor.get_node("product_indicator").visible = false
		return
	var phase: float = _presentation_time * 0.35 + index * 1.7
	var offset := Vector2((index % 3 - 1) * 10.0, (index / 3) * 10.0) + _roam_offset
	var center: Vector2 = building.global_position + Vector2(-6,-31 if housing == "pig_pen" else -23)
	_visual_root.global_position = center + offset
	_visual_root.scale = Vector2.ONE * (0.38 if housing == "coop" else 0.5)
	if shadow != null:
		shadow.z_index = 2
		shadow.global_position = center + offset
		shadow.scale = _visual_root.scale
	var marker: Node2D = _actor.get_node("product_indicator")
	marker.visible = index == 0 and peers.any(func(id: String): return not (world.animals_by_id[id].get("pending_products") as Array).is_empty())
	marker.global_position = building.global_position + Vector2(30,-55)
	marker.scale = Vector2.ONE * 0.55
	if _feedback != null: _feedback.global_position = center + offset + Vector2(-12,-24)


func refresh_snapshot() -> void:
	var displacement: Vector2 = _actor.global_position - _previous_position
	_previous_position = _actor.global_position
	var value: Dictionary = {"identity": "", "state": "idle", "direction": _direction, "progress": 0.0}
	var motion: Vector2 = displacement
	if actor_kind == "truck": _actor.present_vehicle(displacement,state,0.0)
	match actor_kind:
		"player":
			value.identity = "player"
			motion = _actor.get("facing_direction")
			value.state = "walk" if not (_actor as CharacterBody2D).get_real_velocity().is_zero_approx() else "idle"
			if bool(_actor.get("carrying_food")): value.state = "carry"
		"staff":
			value.identity = catalog.get_bound_id("staff", String(_actor.get("staff_type_id")))
			var staff_state: String = String(_actor.get("current_state"))
			value.gameplay_state = staff_state
			value.job = (_actor.get("active_job") as Dictionary).duplicate(true)
			if staff_state in ["moving", "returning"]:
				motion = (_actor.get("destination") as Vector2) - _actor.position
				value.state = "walk" if not motion.is_zero_approx() else "idle"
				if staff_state == "moving" and String(value.job.get("job_type", "")) == "serve":
					value.state = "carry"
			elif staff_state == "delivering_food":
				value.state = "carry"
			elif staff_state == "cleaning_table":
				value.state = "clean"
			elif staff_state == "off_duty":
				value.state = "off_duty"
		"customer":
			value.identity = catalog.get_bound_id("customers", String(_actor.get("customer_type_id")))
			if value.identity == "customer" and String(_actor.get("customer_id")).hash() % 2 == 0: value.identity = "customer_woman"
			var customer_state: String = String(_actor.get("current_state"))
			value.gameplay_state = customer_state
			if bool(_actor.get("is_walking_in")) or bool(_actor.get("is_walking_out")):
				value.state = "walk"
			elif customer_state == "eating":
				value.state = "eat"
			elif customer_state in ["seated", "ordering", "waiting_food"]:
				value.state = "seated_idle"
			elif customer_state == "leaving":
				value.state = "idle"
		"animal":
			value.identity = catalog.get_bound_id("animals", String(_actor.get("animal_id")))
			value.gameplay_state = String(_actor.get("current_state"))
			value.state = "completed" if value.gameplay_state == "completed" else "walk" if _roam_moving else "eat" if _roam_wait < 2.0 else "idle"
		"aquaculture":
			value.identity = catalog.get_bound_id("aquaculture", String(_actor.get("aquaculture_id")))
			value.gameplay_state = String(_actor.get("current_state"))
			value.state = "empty" if int(_actor.get("pond_level")) <= 0 or value.gameplay_state == "empty" else "walk"
		"helicopter":
			value.identity = "helicopter_lv%d" % int(_actor.get("vehicle_level"))
			if is_instance_valid(_controller):
				value.state = String(_controller.get("current_state"))
				value.phase_elapsed = float(_controller.get("phase_elapsed"))
				var duration: float = float(_controller.call("_get_flight_duration"))
				value.progress = clampf(value.phase_elapsed / duration, 0.0, 1.0) if duration > 0.0 else 0.0
		"truck":
			value.identity = "truck_lv%d" % int(_actor.get("vehicle_level"))
			if is_instance_valid(_controller):
				var index: int = (_controller.get("visual_trucks") as Array).find(_actor)
				if index >= 0:
					value.state = String(_controller.call("get_truck_phase", index)).to_lower()
					value.delivery = (_controller.call("get_truck_delivery_info", index) as Dictionary).duplicate(true)
		"restaurant":
			value.identity = "kitchen"
			value.jobs = (_actor.get("cooking_jobs") as Dictionary).duplicate(true)
			for job: Dictionary in value.jobs.values():
				if String(job.get("state", "")) == "cooking":
					value.state = "cook"
	if not motion.is_zero_approx():
		_direction = direction_from_vector(motion)
	value.direction = _direction
	present(value)


static func direction_from_vector(value: Vector2) -> String:
	var directions: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	return directions[posmod(roundi(value.angle() / (PI / 4.0)), 8)]


func _bind_events() -> void:
	_connect(save_manager, "game_loaded", func(_path: String):
		cancel_action()
		if actor_kind == "staff": _configure_staff_route(_actor.get("active_job"), false)
		_previous_position = _actor.global_position
		refresh_snapshot())
	match actor_kind:
		"staff":
			_connect(_actor, "job_started", func(_id: String, job: Dictionary): _configure_staff_route(job, false))
			_connect(_actor, "job_finished", func(_id: String, job: Dictionary):
				_configure_staff_route(job, true)
				refresh_snapshot()
				request_action(String(job.get("job_type", "")), job))
			_connect(_actor, "job_failed", func(_id: String, _job: Dictionary):
				_reset_staff_route()
				cancel_action())
			_configure_staff_route(_actor.get("active_job"), false)
		"customer":
			_controller = _actor.get("restaurant") as Node
			_connect(_actor, "arrived_at_table", func(_id: String):
				refresh_snapshot()
				request_action("sit"))
			_connect(_controller, "payment_collected", _on_payment)
			_connect(_actor, "order_failed", func(_id: String, _order: Dictionary, _reason: String): cancel_action())
		"animal":
			_connect(_actor, "product_created", func(_id: String, item: String, amount: int, kind: String):
				request_action("production", {"item_id": item, "amount": amount, "kind": kind}))
			_connect(_actor, "product_collected", func(_id: String, item: String, amount: int):
				request_action("collect", {"item_id": item, "amount": amount}))
		"aquaculture":
			_connect(_actor, "product_received", func(_id: String, item: String, amount: int):
				request_action("collect", {"item_id": item, "amount": amount}))
		"helicopter":
			_controller = _actor.get_parent()
		"truck":
			var ancestor: Node = _actor.get_parent()
			while ancestor != null:
				_controller = ancestor.get_node_or_null("truck_manager")
				if _controller != null:
					break
				ancestor = ancestor.get_parent()
		"restaurant":
			_connect(_actor, "cooking_started", func(id: String, recipe: String): request_action("cooking_started", {"customer_id": id, "recipe_id": recipe}))
			_connect(_actor, "food_ready", func(id: String, recipe: String): request_action("food_ready", {"customer_id": id, "recipe_id": recipe}))
			_connect(_actor, "cooking_canceled", func(id: String, recipe: String): request_action("cooking_canceled", {"customer_id": id, "recipe_id": recipe}))
	refresh_snapshot()


func _configure_staff_route(job: Dictionary, returning: bool) -> void:
	_reset_staff_route()
	var controller: Node = _actor.get("restaurant")
	if not is_instance_valid(controller): return
	var table_id: String = ""
	var kind: String = String(job.get("job_type", ""))
	if kind == "clean": table_id = String(job.get("target_id", ""))
	elif kind in ["serve","payment"]:
		var customer: Node = controller.get_customer(String(job.get("target_id", "")))
		if customer != null: table_id = String(customer.get("table_id"))
	if returning and table_id.is_empty():
		for id: String in controller.tables_by_id:
			var table: Node2D = controller.tables_by_id[id]
			if _actor.position.distance_to(table.position) < 35.0:
				table_id = id
				break
	# Keep job completion governed by the existing logical travel/timer. Only
	# the presentation follows the food-pass and stair corridor over that interval.
	if not controller.rooftop_tables.has(table_id.trim_prefix("table_").to_int()):
		if kind == "serve" and not returning:
			_staff_route = [_actor.position, controller.get_node("serving_counter_marker").position, _actor.get("destination")]
			_staff_start_distance = _actor.position.distance_to(_actor.get("destination"))
		return
	_staff_route.append(_actor.position)
	var approach: Array[Vector2] = controller.get_table_approach(table_id)
	if returning: approach.reverse()
	elif kind == "serve": _staff_route.append(controller.get_node("serving_counter_marker").position)
	_staff_route.append_array(approach)
	_staff_route.append(_actor.get("destination"))
	_staff_start_distance = _actor.position.distance_to(_actor.get("destination"))


func _reset_staff_route() -> void:
	_staff_route.clear()
	if _visual_root == null: return
	_visual_root.position = _base_visual_position
	_visual_root.z_index = 0
	if _feedback != null: _feedback.position = Vector2(-24,-54)
	var shadow: Node2D = _actor.get_node_or_null("ContactShadow") as Node2D
	if shadow != null: shadow.position = Vector2.ZERO


func _present_staff_route() -> void:
	if _staff_route.is_empty() or _staff_start_distance <= 0.0: return
	var state_name: String = String(_actor.get("current_state"))
	if not state_name in ["moving","returning"]:
		_reset_staff_route()
		return
	var progress: float = clampf(1.0 - _actor.position.distance_to(_actor.get("destination")) / _staff_start_distance, 0.0, 1.0)
	var length: float = 0.0
	for i: int in range(1,_staff_route.size()): length += _staff_route[i-1].distance_to(_staff_route[i])
	var remaining: float = progress * length
	var point: Vector2 = _staff_route[-1]
	for i: int in range(1,_staff_route.size()):
		var segment: float = _staff_route[i-1].distance_to(_staff_route[i])
		if remaining <= segment and segment > 0.0:
			point = _staff_route[i-1].lerp(_staff_route[i],remaining/segment)
			break
		remaining -= segment
	_visual_root.position = _base_visual_position + point - _actor.position
	_visual_root.z_index = 3 if point.y < -80 else 0
	if _feedback != null: _feedback.position = Vector2(-24,-54) + point - _actor.position
	var shadow: Node2D = _actor.get_node_or_null("ContactShadow") as Node2D
	if shadow != null: shadow.position = point - _actor.position
	if progress >= 1.0:
		_reset_staff_route()


func _on_payment(id: String, recipe: String, revenue: int) -> void:
	if id == String(_actor.get("customer_id")):
		refresh_snapshot()
		request_action("payment", {"customer_id": id, "recipe_id": recipe, "revenue": revenue})


func _connect(source: Node, event: StringName, callback: Callable) -> void:
	if source != null and source.has_signal(event):
		source.connect(event, callback)
		_connections.append({"source": source, "event": event, "callback": callback})


func _exit_tree() -> void:
	# A New Game/load can retire a template before its deferred child attachment.
	if is_instance_valid(_feedback) and _feedback.get_parent() == null:
		_feedback.free()
	for connection: Dictionary in _connections:
		var source: Variant = connection.source
		if is_instance_valid(source) and source.is_connected(connection.event, connection.callback):
			source.disconnect(connection.event, connection.callback)
	super._exit_tree()
