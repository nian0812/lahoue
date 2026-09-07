extends Node

signal tutorial_started(tutorial_id: String)
signal tutorial_step_changed(tutorial_id: String, step: int)
signal tutorial_completed(tutorial_id: String)
signal tutorial_skipped()

const state_not_started: String = "NOT_STARTED"
const state_active: String = "ACTIVE"
const state_completed: String = "COMPLETED"
const state_skipped: String = "SKIPPED"
const valid_master_states: Array[String] = [
	state_not_started,
	state_active,
	state_completed,
	state_skipped,
]

const feature_ids: Array[String] = [
	"new_game",
	"market",
	"level_up",
	"animal",
	"aquaculture",
	"cooking",
	"restaurant",
	"truck",
	"staff",
	"achievements",
	"premium_market",
	"premium_recipes",
	"level_10",
]

const hint_ids: Array[String] = [
	"helicopter_upgrade",
]

const milestone_ids: Array[String] = [
	"movement",
	"interaction",
	"farm_reached",
	"rice_selected",
	"crop_planted",
	"crop_harvested",
	"inventory_opened",
	"animal_product_collected",
	"aquaculture_cycle_started",
	"aquaculture_product_collected",
	"cooking_started",
	"food_ready",
	"restaurant_payment",
	"truck_panel_opened",
	"truck_delivery_started",
	"truck_delivery_completed",
	"staff_hired",
	"achievement_unlocked",
	"premium_panel_opened",
	"import_started",
	"import_arrived",
]

const tutorial_steps: Dictionary = {
	"new_game": [
		{"title": "Welcome to LaHoue", "text": "Build your farm one real action at a time. This guide never changes your items, money, or progress.", "objective": ""},
		{"title": "Movement", "text": "Move around the world to continue.", "objective": "movement"},
		{"title": "Interact", "text": "Press E near a usable object or building.", "objective": "interaction"},
		{"title": "Go to the Farm", "text": "Walk to the crop plots in the Farm area.", "objective": "farm_reached"},
		{"title": "Select Rice", "text": "Select Rice with R if it is not already selected.", "objective": "rice_selected"},
		{"title": "Plant", "text": "Press E at an empty crop plot to plant one Rice.", "objective": "crop_planted"},
		{"title": "Crop Growing", "text": "Crops grow with game time. The tutorial does not speed them up or create harvests.", "objective": ""},
		{"title": "Harvest", "text": "When the crop is ready, press E to harvest it.", "objective": "crop_harvested"},
		{"title": "Inventory", "text": "Press I to open Inventory and review the real harvest.", "objective": "inventory_opened"},
	],
	"market": [
		{"title": "Normal Market", "text": "The Market sells basic domestic items. Locked items show Requires Level X; buying is optional.", "objective": ""},
	],
	"level_up": [
		{"title": "Level Up!", "text": "New crops, recipes, and features may now be available.", "objective": ""},
	],
	"animal": [
		{"title": "Animals", "text": "At Level 3, buy a Coop before buying Layer or Meat Chickens. Housing and animals both cost money.", "objective": ""},
		{"title": "Collect a Product", "text": "Collect one ready animal product. You never need to buy another animal if you already own one.", "objective": "animal_product_collected"},
	],
	"aquaculture": [
		{"title": "Aquaculture", "text": "At Level 10, buy the Fish Pond first. Press E again to start its production cycle.", "objective": ""},
		{"title": "Start Cycle", "text": "Start one real aquaculture cycle.", "objective": "aquaculture_cycle_started"},
		{"title": "Wait for Product", "text": "The container grows with normal game time. Product not ready means the cycle is still active.", "objective": ""},
		{"title": "Collect", "text": "Collect one ready aquaculture product.", "objective": "aquaculture_product_collected"},
	],
	"cooking": [
		{"title": "Cooking", "text": "Unlocked recipes require their listed ingredients. Starting Cook consumes those ingredients.", "objective": ""},
		{"title": "Start Cooking", "text": "Start one valid unlocked recipe through the Restaurant flow.", "objective": "cooking_started"},
		{"title": "Dish Ready", "text": "Finish cooking one real dish for Restaurant service.", "objective": "food_ready"},
	],
	"restaurant": [
		{"title": "Restaurant", "text": "Customer arrives → Order → Cook → Serve → Collect Payment. Manual play and Staff automation both count.", "objective": ""},
		{"title": "Complete an Order", "text": "Complete one customer order through successful payment.", "objective": "restaurant_payment"},
	],
	"truck": [
		{"title": "Truck", "text": "Truck sells domestic goods. It does not buy imported ingredients, and no upgrade is required.", "objective": ""},
		{"title": "Open Truck", "text": "Open the Truck panel from the depot or toolbar.", "objective": "truck_panel_opened"},
		{"title": "Select Cargo", "text": "Add Selected Cargo, then review Load / Capacity and Expected Revenue before confirming.", "objective": ""},
		{"title": "Confirm Shipment", "text": "Confirm a shipment with goods you choose. The Truck departs immediately.", "objective": "truck_delivery_started"},
		{"title": "Delivery Payment", "text": "Wait for delivery to finish and receive the real sale revenue.", "objective": "truck_delivery_completed"},
	],
	"staff": [
		{"title": "Staff Roles", "text": "Waiter: Serve / Payment / Clean. Chef: Cook. Farm Worker: Harvest. Animal Worker: Collect products. Aquaculture Worker: Collect aquaculture.", "objective": ""},
		{"title": "Hire First Staff", "text": "Press F to review Staff, then hire one role with your own money. Manual gameplay remains available.", "objective": "staff_hired"},
	],
	"achievements": [
		{"title": "Achievements", "text": "Press J to open Achievements. A completed achievement can be Claimed once; its reward cannot be duplicated.", "objective": ""},
	],
	"premium_market": [
		{"title": "Premium & International Market", "text": "Level 35 grants purchase rights only. Buy the International License and Helipad + Helicopter before importing ingredients.", "objective": ""},
		{"title": "Open Premium Market", "text": "Press E at Premium Market or use its existing UI entry.", "objective": "premium_panel_opened"},
		{"title": "Select Import Cargo", "text": "After both required purchases, choose cargo and review Load / Capacity plus Total Import Cost.", "objective": ""},
		{"title": "Confirm Import", "text": "Confirm one paid order. The Helicopter departs and imports the selected cargo.", "objective": "import_started"},
		{"title": "Warehouse Arrival", "text": "Wait for the Helicopter to return the imported cargo to Warehouse.", "objective": "import_arrived"},
	],
	"premium_recipes": [
		{"title": "Premium Recipes", "text": "Imported ingredients can be used in Premium Recipes. Press C to review unlocked recipes.", "objective": ""},
	],
	"level_10": [
		{"title": "LaHoue Empire", "text": "Level 55 reached. EXP is MAX, while farming, restaurant, deliveries, imports, and resort gameplay continue endlessly.", "objective": ""},
	],
}

var master_state: String = state_not_started
var current_tutorial: String = ""
var current_step: int = 0
var completed_features: Dictionary = {}
var one_time_hints: Dictionary = {}
var milestones: Dictionary = {}
var tutorial_queue: Array[String] = []

var initialized: bool = false
var save_state_applied: bool = false
var observed_level: int = 1
var initial_player_position: Vector2 = Vector2.ZERO
var last_context_hint: String = ""
var last_context_hint_msec: int = -10000

@onready var world: Node = get_parent()

var popup: Control
var ui_manager: Node
var notification: Node
var player: Node2D
var restaurant: Node
var truck_manager: Node
var premium_market: Node
var achievement_tracker: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_set_default_flags()
	set_process(false)
	_initialize.call_deferred()


func _process(_delta: float) -> void:
	if not initialized or player == null or not is_instance_valid(player):
		return
	if not bool(milestones.get("movement", false)) and player.global_position.distance_to(initial_player_position) > 4.0:
		_mark_milestone("movement")
	if not bool(milestones.get("farm_reached", false)):
		for tile_value: Variant in (world.get("farm_tiles_by_id") as Dictionary).values():
			if tile_value is Node2D and player.global_position.distance_to((tile_value as Node2D).global_position) <= 135.0:
				_mark_milestone("farm_reached")
				break


func _initialize() -> void:
	popup = world.get_node_or_null("ui/tutorial_popup") as Control
	ui_manager = world.get_node_or_null("ui")
	notification = world.get_node_or_null("ui/notification_popup")
	player = world.get_node_or_null("player") as Node2D
	restaurant = world.get_node_or_null("restaurant")
	truck_manager = world.get_node_or_null("truck_manager")
	premium_market = world.get_node_or_null("hub/premium_market")
	achievement_tracker = world.get_node_or_null("achievement_tracker")
	if popup == null or ui_manager == null or player == null:
		push_error("tutorial_controller: required world/UI nodes are missing")
		return

	_connect_signals()
	initialized = true
	observed_level = game_manager.level
	initial_player_position = player.global_position
	_recover_live_milestones()

	if master_state == state_not_started and current_tutorial.is_empty() and tutorial_queue.is_empty():
		if game_manager.level <= 1:
			trigger_tutorial("new_game")
		else:
			_recover_legacy_progression()
	_queue_unlocked_tutorials(game_manager.level)
	_recover_active_steps()
	_refresh_popup()
	set_process(true)


func get_save_state() -> Dictionary:
	return {
		"state": master_state,
		"current_tutorial": current_tutorial,
		"current_step": current_step,
		"completed_features": completed_features.duplicate(true),
		"one_time_hints": one_time_hints.duplicate(true),
		"milestones": milestones.duplicate(true),
		"queue": tutorial_queue.duplicate(),
	}


func apply_save_state(value: Dictionary) -> void:
	save_state_applied = true
	_set_default_flags()
	if value.is_empty():
		master_state = state_not_started
		current_tutorial = ""
		current_step = 0
		tutorial_queue.clear()
		if initialized:
			_start_from_empty_state()
		return
	master_state = String(value.get("state", state_not_started))
	current_tutorial = String(value.get("current_tutorial", ""))
	current_step = int(value.get("current_step", 0))
	var saved_completed: Dictionary = value.get("completed_features", {}) as Dictionary
	for feature_id: String in feature_ids:
		completed_features[feature_id] = bool(saved_completed.get(feature_id, false))
	var saved_hints: Dictionary = value.get("one_time_hints", {}) as Dictionary
	for hint_id: String in hint_ids:
		one_time_hints[hint_id] = bool(saved_hints.get(hint_id, false))
	var saved_milestones: Dictionary = value.get("milestones", {}) as Dictionary
	for milestone_id: String in milestone_ids:
		milestones[milestone_id] = bool(saved_milestones.get(milestone_id, false))
	tutorial_queue.clear()
	for queued_value: Variant in value.get("queue", []) as Array:
		var queued_id: String = String(queued_value)
		if feature_ids.has(queued_id) and not tutorial_queue.has(queued_id):
			tutorial_queue.append(queued_id)
	if initialized:
		_recover_live_milestones()
		_recover_active_steps()
		_refresh_popup()


func reset_state() -> void:
	apply_save_state({})


func skip_tutorial() -> void:
	if master_state == state_skipped:
		return
	master_state = state_skipped
	current_tutorial = ""
	current_step = 0
	tutorial_queue.clear()
	if popup != null:
		popup.call("hide_popup")
	tutorial_skipped.emit()


func trigger_tutorial(tutorial_id: String) -> bool:
	if not feature_ids.has(tutorial_id) or master_state == state_skipped or master_state == state_completed:
		return false
	if bool(completed_features.get(tutorial_id, false)) or current_tutorial == tutorial_id or tutorial_queue.has(tutorial_id):
		return false
	if master_state == state_not_started:
		master_state = state_active
	tutorial_queue.append(tutorial_id)
	if current_tutorial.is_empty():
		_start_next_tutorial()
	return true


func is_feature_completed(tutorial_id: String) -> bool:
	return bool(completed_features.get(tutorial_id, false))


func is_hint_shown(hint_id: String) -> bool:
	return bool(one_time_hints.get(hint_id, false))


func mark_milestone_for_test(milestone_id: String) -> void:
	_mark_milestone(milestone_id)


static func validate_save_state(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "state": {}, "error": ""}
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "state": {}, "error": "field 'tutorial' must be a dictionary"}
	var saved: Dictionary = value as Dictionary
	if saved.is_empty():
		return {"ok": true, "state": {}, "error": ""}
	var saved_master_value: Variant = saved.get("state", state_not_started)
	if typeof(saved_master_value) != TYPE_STRING or not valid_master_states.has(String(saved_master_value)):
		return {"ok": false, "state": {}, "error": "tutorial master state is invalid"}
	var saved_master: String = String(saved_master_value)
	var current_value: Variant = saved.get("current_tutorial", "")
	if typeof(current_value) != TYPE_STRING:
		return {"ok": false, "state": {}, "error": "tutorial current id must be a string"}
	var current_id: String = String(current_value)
	if not current_id.is_empty() and not feature_ids.has(current_id):
		return {"ok": false, "state": {}, "error": "tutorial current id is unknown"}
	var step_value: Variant = saved.get("current_step", 0)
	if typeof(step_value) != TYPE_INT and typeof(step_value) != TYPE_FLOAT:
		return {"ok": false, "state": {}, "error": "tutorial current step must be an integer"}
	var saved_step: int = int(step_value)
	if float(step_value) != float(saved_step) or saved_step < 0:
		return {"ok": false, "state": {}, "error": "tutorial current step is invalid"}
	if not current_id.is_empty() and saved_step >= (tutorial_steps[current_id] as Array).size():
		return {"ok": false, "state": {}, "error": "tutorial current step is outside its definition"}

	var completed_result: Dictionary = _normalize_bool_flags(saved.get("completed_features", {}), feature_ids, "tutorial completed_features")
	if not bool(completed_result.get("ok", false)):
		return completed_result
	var hints_result: Dictionary = _normalize_bool_flags(saved.get("one_time_hints", {}), hint_ids, "tutorial one_time_hints")
	if not bool(hints_result.get("ok", false)):
		return hints_result
	var milestones_result: Dictionary = _normalize_bool_flags(saved.get("milestones", {}), milestone_ids, "tutorial milestones")
	if not bool(milestones_result.get("ok", false)):
		return milestones_result

	var queue_value: Variant = saved.get("queue", [])
	if typeof(queue_value) != TYPE_ARRAY:
		return {"ok": false, "state": {}, "error": "tutorial queue must be an array"}
	var normalized_queue: Array[String] = []
	for queued_value: Variant in queue_value as Array:
		if typeof(queued_value) != TYPE_STRING:
			return {"ok": false, "state": {}, "error": "tutorial queue ids must be strings"}
		var queued_id: String = String(queued_value)
		if not feature_ids.has(queued_id) or normalized_queue.has(queued_id):
			return {"ok": false, "state": {}, "error": "tutorial queue contains an invalid or duplicate id"}
		normalized_queue.append(queued_id)
	var normalized_completed: Dictionary = completed_result.get("state", {}) as Dictionary
	if not current_id.is_empty() and bool(normalized_completed.get(current_id, false)):
		return {"ok": false, "state": {}, "error": "completed tutorial cannot remain current"}
	if saved_master == state_skipped or saved_master == state_completed:
		current_id = ""
		saved_step = 0
		normalized_queue.clear()
	return {
		"ok": true,
		"state": {
			"state": saved_master,
			"current_tutorial": current_id,
			"current_step": saved_step,
			"completed_features": normalized_completed,
			"one_time_hints": hints_result.get("state", {}),
			"milestones": milestones_result.get("state", {}),
			"queue": normalized_queue,
		},
		"error": "",
	}


static func _normalize_bool_flags(value: Variant, allowed_ids: Array[String], field_name: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "state": {}, "error": "%s must be a dictionary" % field_name}
	var normalized: Dictionary = {}
	for allowed_id: String in allowed_ids:
		normalized[allowed_id] = false
	for key_value: Variant in value as Dictionary:
		if typeof(key_value) != TYPE_STRING or not allowed_ids.has(String(key_value)):
			return {"ok": false, "state": {}, "error": "%s contains an unknown id" % field_name}
		var flag_value: Variant = (value as Dictionary)[key_value]
		if typeof(flag_value) != TYPE_BOOL:
			return {"ok": false, "state": {}, "error": "%s values must be booleans" % field_name}
		normalized[String(key_value)] = bool(flag_value)
	return {"ok": true, "state": normalized, "error": ""}


func _set_default_flags() -> void:
	completed_features.clear()
	one_time_hints.clear()
	milestones.clear()
	for feature_id: String in feature_ids:
		completed_features[feature_id] = false
	for hint_id: String in hint_ids:
		one_time_hints[hint_id] = false
	for milestone_id: String in milestone_ids:
		milestones[milestone_id] = false


func _connect_signals() -> void:
	popup.connect("next_requested", _on_next_requested)
	popup.connect("skip_requested", skip_tutorial)
	if ui_manager.has_signal("panel_opened"):
		ui_manager.connect("panel_opened", _on_panel_opened)
	if not game_manager.level_changed.is_connected(_on_level_changed):
		game_manager.level_changed.connect(_on_level_changed)
	if player.has_signal("selected_seed_changed"):
		player.connect("selected_seed_changed", _on_selected_seed_changed)
	if player.has_signal("interaction_completed"):
		player.connect("interaction_completed", _on_interaction_completed)
	for signal_spec: Array in [
		[world, "tutorial_crop_planted", _on_crop_planted],
		[world, "tutorial_crop_harvested", _on_crop_harvested],
		[world, "tutorial_animal_product_collected", _on_animal_product_collected],
		[world, "tutorial_aquaculture_product_collected", _on_aquaculture_product_collected],
		[restaurant, "cooking_started", _on_cooking_started],
		[restaurant, "food_ready", _on_food_ready],
		[restaurant, "payment_collected", _on_restaurant_payment],
		[restaurant, "staff_hired", _on_staff_hired],
		[truck_manager, "delivery_started", _on_truck_delivery_started],
		[truck_manager, "delivery_completed", _on_truck_delivery_completed],
		[achievement_tracker, "achievement_unlocked", _on_achievement_unlocked],
		[premium_market, "shipment_started", _on_import_started],
		[premium_market, "shipment_arrived", _on_import_arrived],
	]:
		var source: Object = signal_spec[0] as Object
		var signal_name: StringName = StringName(signal_spec[1])
		var callback: Callable = signal_spec[2]
		if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
			source.connect(signal_name, callback)
	for container_value: Variant in (world.get("aquaculture_containers_by_id") as Dictionary).values():
		var container: Node = container_value as Node
		if container != null and not container.is_connected("state_changed", _on_aquaculture_state_changed):
			container.connect("state_changed", _on_aquaculture_state_changed)


func _on_next_requested() -> void:
	if current_tutorial.is_empty() or not tutorial_steps.has(current_tutorial):
		return
	var steps: Array = tutorial_steps[current_tutorial] as Array
	if current_step < 0 or current_step >= steps.size():
		_complete_current_tutorial()
		return
	var objective: String = String((steps[current_step] as Dictionary).get("objective", ""))
	if not objective.is_empty() and not bool(milestones.get(objective, false)):
		return
	current_step += 1
	if current_step >= steps.size():
		_complete_current_tutorial()
	else:
		tutorial_step_changed.emit(current_tutorial, current_step)
		_recover_active_steps()
		_refresh_popup()


func _start_next_tutorial() -> void:
	while not tutorial_queue.is_empty():
		var next_id: String = tutorial_queue.pop_front()
		if bool(completed_features.get(next_id, false)):
			continue
		current_tutorial = next_id
		current_step = 0
		tutorial_started.emit(current_tutorial)
		tutorial_step_changed.emit(current_tutorial, current_step)
		_recover_active_steps()
		_refresh_popup()
		return
	current_tutorial = ""
	current_step = 0
	_refresh_popup()


func _complete_current_tutorial() -> void:
	if current_tutorial.is_empty():
		return
	var completed_id: String = current_tutorial
	completed_features[completed_id] = true
	current_tutorial = ""
	current_step = 0
	tutorial_completed.emit(completed_id)
	if completed_id == "level_10":
		master_state = state_completed
		tutorial_queue.clear()
		_refresh_popup()
		return
	_start_next_tutorial()


func _recover_active_steps() -> void:
	var guard: int = 0
	while not current_tutorial.is_empty() and guard < 32:
		guard += 1
		var steps: Array = tutorial_steps.get(current_tutorial, []) as Array
		if current_step >= steps.size():
			_complete_current_tutorial()
			continue
		var objective: String = String((steps[current_step] as Dictionary).get("objective", ""))
		if objective.is_empty() or not bool(milestones.get(objective, false)):
			break
		current_step += 1
		if current_step >= steps.size():
			_complete_current_tutorial()
		else:
			tutorial_step_changed.emit(current_tutorial, current_step)


func _refresh_popup() -> void:
	if popup == null:
		return
	if master_state == state_skipped or master_state == state_completed or current_tutorial.is_empty():
		popup.call("hide_popup")
		return
	var steps: Array = tutorial_steps.get(current_tutorial, []) as Array
	if current_step < 0 or current_step >= steps.size():
		popup.call("hide_popup")
		return
	var step: Dictionary = steps[current_step] as Dictionary
	var objective: String = String(step.get("objective", ""))
	var can_continue: bool = objective.is_empty() or bool(milestones.get(objective, false))
	popup.call(
		"show_step",
		String(step.get("title", "Tutorial")),
		String(step.get("text", "")),
		current_step,
		steps.size(),
		can_continue,
		current_step == steps.size() - 1,
		objective
	)


func _mark_milestone(milestone_id: String) -> void:
	if (
		master_state == state_skipped
		or master_state == state_completed
		or not milestone_ids.has(milestone_id)
		or bool(milestones.get(milestone_id, false))
	):
		return
	milestones[milestone_id] = true
	_recover_active_steps()
	_refresh_popup()


func _queue_unlocked_tutorials(level: int) -> void:
	if master_state == state_skipped or master_state == state_completed:
		return
	if level >= 3:
		trigger_tutorial("animal")
	if level >= 10:
		trigger_tutorial("aquaculture")
	if level >= data_manager.get_restaurant_unlock_level():
		trigger_tutorial("cooking")
		trigger_tutorial("restaurant")
		trigger_tutorial("staff")
	if level >= data_manager.get_premium_market_unlock_level():
		trigger_tutorial("premium_market")
	if level >= data_manager.get_max_player_level():
		trigger_tutorial("level_10")


func _recover_legacy_progression() -> void:
	master_state = state_active
	var level: int = game_manager.level
	if level >= 2:
		for early_id: String in ["new_game", "market", "level_up", "truck"]:
			completed_features[early_id] = true
	if level >= 4:
		completed_features["animal"] = true
	if level >= 11:
		completed_features["aquaculture"] = true
	if level >= 6:
		for mid_id: String in ["cooking", "restaurant", "staff"]:
			completed_features[mid_id] = true
	if level >= 36:
		completed_features["premium_market"] = true
		completed_features["premium_recipes"] = true
	if _has_any_completed_achievement():
		completed_features["achievements"] = true


func _start_from_empty_state() -> void:
	_recover_live_milestones()
	if game_manager.level <= 1:
		trigger_tutorial("new_game")
	else:
		_recover_legacy_progression()
	_queue_unlocked_tutorials(game_manager.level)
	_recover_active_steps()
	_refresh_popup()


func _recover_live_milestones() -> void:
	if player != null and String(player.get("selected_seed_item_id")) == "rice":
		milestones["rice_selected"] = true
	for tile_value: Variant in (world.get("farm_tiles_by_id") as Dictionary).values():
		if not bool(tile_value.call("is_empty")):
			milestones["crop_planted"] = true
			break
	if _achievement_progress("first_harvest") > 0:
		milestones["crop_harvested"] = true
	if ui_manager != null and ui_manager.get("active_panel") == ui_manager.get("inventory_panel"):
		milestones["inventory_opened"] = true
	if _has_any_animal_product():
		milestones["animal_product_collected"] = true
	for container_value: Variant in (world.get("aquaculture_containers_by_id") as Dictionary).values():
		if ["growing", "ready"].has(String(container_value.get("current_state"))):
			milestones["aquaculture_cycle_started"] = true
	if _has_any_aquaculture_product():
		milestones["aquaculture_product_collected"] = true
	if restaurant != null:
		for job_value: Variant in (restaurant.get("cooking_jobs") as Dictionary).values():
			var job_state: String = String((job_value as Dictionary).get("state", ""))
			if ["cooking", "ready", "served", "paid"].has(job_state):
				milestones["cooking_started"] = true
			if ["ready", "served", "paid"].has(job_state):
				milestones["food_ready"] = true
			if job_state == "paid":
				milestones["restaurant_payment"] = true
		if _get_total_staff_count() > 0:
			milestones["staff_hired"] = true
	if truck_manager != null:
		for delivery_value: Variant in truck_manager.get("deliveries") as Array:
			if typeof(delivery_value) == TYPE_DICTIONARY and not (delivery_value as Dictionary).is_empty():
				milestones["truck_delivery_started"] = true
	if _achievement_progress("first_shipment") > 0:
		milestones["truck_delivery_completed"] = true
	if premium_market != null and not (premium_market.get("active_shipment") as Dictionary).is_empty():
		milestones["import_started"] = true
	if _has_any_imported_item() or _achievement_progress("first_import") > 0:
		milestones["import_arrived"] = true
	if _has_any_completed_achievement():
		milestones["achievement_unlocked"] = true


func _on_level_changed(new_level: int) -> void:
	if initialized and new_level > observed_level:
		trigger_tutorial("level_up")
	observed_level = new_level
	_queue_unlocked_tutorials(new_level)


func _on_selected_seed_changed(seed_item_id: String) -> void:
	if seed_item_id == "rice":
		_mark_milestone("rice_selected")


func _on_interaction_completed(target: Node, succeeded: bool) -> void:
	if succeeded:
		_mark_milestone("interaction")
	if target == null:
		return
	if target.get("tile_id") != null:
		_mark_milestone("farm_reached")
		var farm_state: int = int(target.get("current_state"))
		if farm_state == 1:
			_show_context_hint("Crop Growing")
		elif farm_state == 2 and not succeeded and inventory_manager.get_free_space() <= 0:
			_show_context_hint("Inventory Full")
		elif farm_state == 0 and not succeeded:
			var selected_seed: String = String(player.get("selected_seed_item_id"))
			var crop_id: String = data_manager.get_crop_id_for_seed(selected_seed)
			var required_level: int = data_manager.get_crop_required_level(crop_id)
			if required_level > game_manager.level:
				_show_context_hint("Requires Level %d" % required_level)
		return
	if target.get("animal_instance_id") != null:
		if (target.call("get_pending_products") as Array).is_empty():
			_show_context_hint("Product not ready")
		elif not succeeded and inventory_manager.get_free_space() <= 0:
			_show_context_hint("Inventory Full")
		return
	if target.get("container_id") != null and target.get("aquaculture_id") != null:
		var aqua_state: String = String(target.get("current_state"))
		if aqua_state == "growing":
			_show_context_hint("Product not ready")
		elif aqua_state == "ready" and not succeeded and inventory_manager.get_free_space() <= 0:
			_show_context_hint("Inventory Full")
		elif aqua_state == "empty" and not succeeded:
			_show_context_hint("Requires Level %d" % data_manager.get_aquaculture_required_level(String(target.get("aquaculture_id"))))


func _on_panel_opened(panel_id: String) -> void:
	match panel_id:
		"inventory":
			_mark_milestone("inventory_opened")
		"shop":
			trigger_tutorial("market")
		"recipe":
			if game_manager.level >= data_manager.get_restaurant_unlock_level():
				trigger_tutorial("cooking")
		"restaurant":
			if game_manager.level >= data_manager.get_restaurant_unlock_level():
				trigger_tutorial("cooking")
				trigger_tutorial("restaurant")
		"truck":
			_mark_milestone("truck_panel_opened")
			trigger_tutorial("truck")
		"staff":
			if game_manager.level >= data_manager.get_restaurant_unlock_level():
				trigger_tutorial("staff")
		"premium_market":
			_mark_milestone("premium_panel_opened")
			if game_manager.level >= data_manager.get_premium_market_unlock_level():
				trigger_tutorial("premium_market")


func _on_crop_planted(_tile_id: String, crop_id: String) -> void:
	if crop_id == "rice":
		_mark_milestone("crop_planted")


func _on_crop_harvested(_tile_id: String, _crop_id: String, _item_id: String, _amount: int) -> void:
	_mark_milestone("crop_harvested")


func _on_animal_product_collected(_instance_id: String, _item_id: String, _amount: int) -> void:
	_mark_milestone("animal_product_collected")


func _on_aquaculture_state_changed(_container_id: String, state: String) -> void:
	if state == "growing":
		_mark_milestone("aquaculture_cycle_started")


func _on_aquaculture_product_collected(_container_id: String, _item_id: String, _amount: int) -> void:
	_mark_milestone("aquaculture_product_collected")


func _on_cooking_started(_customer_id: String, _recipe_id: String) -> void:
	_mark_milestone("cooking_started")


func _on_food_ready(_customer_id: String, _recipe_id: String) -> void:
	_mark_milestone("food_ready")


func _on_restaurant_payment(_customer_id: String, _recipe_id: String, _revenue: int) -> void:
	_mark_milestone("restaurant_payment")


func _on_staff_hired(_staff_id: String, _staff_type_id: String, _cost: int) -> void:
	_mark_milestone("staff_hired")


func _on_truck_delivery_started(_truck_index: int, _item_id: String, _amount: int) -> void:
	_mark_milestone("truck_delivery_started")


func _on_truck_delivery_completed(_truck_index: int, _item_id: String, _amount: int, _payout: int) -> void:
	_mark_milestone("truck_delivery_completed")


func _on_achievement_unlocked(_achievement_id: String) -> void:
	_mark_milestone("achievement_unlocked")
	trigger_tutorial("achievements")


func _on_import_started(_cargo: Dictionary, _total_cost: int) -> void:
	_mark_milestone("import_started")


func _on_import_arrived(_cargo: Dictionary) -> void:
	_mark_milestone("import_arrived")
	trigger_tutorial("premium_recipes")
	_show_one_time_hint("helicopter_upgrade", "Upgrade the Helicopter to increase capacity and reduce shipping time.")


func _show_one_time_hint(hint_id: String, text: String) -> void:
	if not hint_ids.has(hint_id) or bool(one_time_hints.get(hint_id, false)):
		return
	one_time_hints[hint_id] = true
	if notification != null and notification.has_method("show_notification"):
		notification.call("show_notification", text, "info")


func _show_context_hint(text: String) -> void:
	var now: int = Time.get_ticks_msec()
	if text == last_context_hint and now - last_context_hint_msec < 1500:
		return
	last_context_hint = text
	last_context_hint_msec = now
	if notification != null and notification.has_method("show_notification"):
		notification.call("show_notification", text, "warning")


func _achievement_progress(achievement_id: String) -> int:
	if achievement_tracker == null:
		return 0
	return int((achievement_tracker.call("get_achievement_state", achievement_id) as Dictionary).get("progress", 0))


func _has_any_completed_achievement() -> bool:
	if achievement_tracker == null:
		return false
	for state_value: Variant in (achievement_tracker.get("achievement_states") as Dictionary).values():
		if typeof(state_value) == TYPE_DICTIONARY and bool((state_value as Dictionary).get("unlocked", false)):
			return true
	return false


func _has_any_animal_product() -> bool:
	for item_id: String in ["egg", "chicken_meat", "cow_milk", "beef"]:
		if inventory_manager.get_amount(item_id) > 0:
			return true
	return false


func _has_any_aquaculture_product() -> bool:
	for item_id: String in ["fish", "shrimp", "crab", "squid", "octopus"]:
		if inventory_manager.get_amount(item_id) > 0:
			return true
	return false


func _has_any_imported_item() -> bool:
	for item_id: String in data_manager.get_premium_import_item_ids():
		if inventory_manager.get_amount(item_id) > 0:
			return true
	return false


func _get_total_staff_count() -> int:
	var total: int = 0
	for feature_id: String in ["waiter", "chef", "farm_worker", "animal_worker", "aquaculture_worker"]:
		total += int(restaurant.call("get_staff_type_count", feature_id))
	return total
