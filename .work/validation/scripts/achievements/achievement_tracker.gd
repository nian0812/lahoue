extends Node

signal progress_changed(achievement_id: String, progress: int, target: int)
signal achievement_unlocked(achievement_id: String)
signal reward_claimed(achievement_id: String)

var definitions: Dictionary = {}
var achievement_states: Dictionary = {}


func _ready() -> void:
	reload_definitions()


func reload_definitions() -> bool:
	return configure_definitions(data_manager.get_dataset("achievements"))


func configure_definitions(dataset: Dictionary) -> bool:
	var result: Dictionary = data_manager.validate_achievement_definitions(dataset)
	if not bool(result.get("ok", false)):
		return false
	var next_definitions: Dictionary = (result.get("definitions", {}) as Dictionary).duplicate(true)
	var next_states: Dictionary = {}
	for achievement_id_value: Variant in next_definitions:
		var achievement_id: String = String(achievement_id_value)
		var previous: Dictionary = achievement_states.get(achievement_id, {}) as Dictionary
		var condition: Dictionary = (next_definitions[achievement_id] as Dictionary).get("condition", {}) as Dictionary
		next_states[achievement_id] = {
			"progress": mini(int(previous.get("progress", 0)), int(condition.get("target", 0))),
			"unlocked": bool(previous.get("unlocked", false)),
			"reward_claimed": bool(previous.get("reward_claimed", false)),
		}
	definitions = next_definitions
	achievement_states = next_states
	return true


func record_increment(metric: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	return _record_metric(metric, amount, false)


func record_maximum(metric: String, value: int) -> bool:
	if value < 0:
		return false
	return _record_metric(metric, value, true)


func _record_metric(metric: String, value: int, maximum_mode: bool) -> bool:
	var changed: bool = false
	for achievement_id_value: Variant in definitions:
		var achievement_id: String = String(achievement_id_value)
		var definition: Dictionary = definitions[achievement_id] as Dictionary
		var condition: Dictionary = definition.get("condition", {}) as Dictionary
		if String(condition.get("metric", "")) != metric:
			continue
		var expected_mode: String = "maximum" if maximum_mode else "increment"
		if String(condition.get("mode", "")) != expected_mode:
			continue
		var state: Dictionary = achievement_states[achievement_id] as Dictionary
		if bool(state.get("unlocked", false)):
			continue
		var previous: int = int(state.get("progress", 0))
		var target: int = int(condition.get("target", 0))
		var next: int = mini(maxi(previous, value), target) if maximum_mode else previous + mini(value, target - previous)
		if next == previous:
			continue
		state["progress"] = next
		progress_changed.emit(achievement_id, next, target)
		changed = true
		if next >= target:
			_unlock(achievement_id)
	return changed


func _unlock(achievement_id: String) -> bool:
	var state: Dictionary = achievement_states.get(achievement_id, {}) as Dictionary
	if state.is_empty() or bool(state.get("unlocked", false)):
		return false
	state["unlocked"] = true
	achievement_unlocked.emit(achievement_id)
	var definition: Dictionary = definitions.get(achievement_id, {}) as Dictionary
	if definition.get("reward", null) == null:
		claim_reward(achievement_id)
	return true


func claim_reward(achievement_id: String) -> bool:
	if not definitions.has(achievement_id) or not achievement_states.has(achievement_id):
		return false
	var state: Dictionary = achievement_states[achievement_id] as Dictionary
	if not bool(state.get("unlocked", false)) or bool(state.get("reward_claimed", false)):
		return false
	var definition: Dictionary = definitions[achievement_id] as Dictionary
	var reward_value: Variant = definition.get("reward", null)
	var granted: bool = reward_value == null
	if typeof(reward_value) == TYPE_DICTIONARY:
		var reward: Dictionary = reward_value as Dictionary
		var amount: int = int(reward.get("amount", 0))
		match String(reward.get("type", "")):
			"money":
				granted = game_manager.add_money(amount)
			"exp":
				granted = game_manager.add_exp(amount)
			"item":
				granted = inventory_manager.add_item(String(reward.get("item_id", "")), amount)
	if not granted:
		return false
	state["reward_claimed"] = true
	reward_claimed.emit(achievement_id)
	return true


func reset_state() -> void:
	for achievement_id_value: Variant in achievement_states:
		achievement_states[achievement_id_value] = {
			"progress": 0,
			"unlocked": false,
			"reward_claimed": false,
		}


func get_save_state() -> Array:
	var saved: Array = []
	var achievement_ids: Array = definitions.keys()
	achievement_ids.sort()
	for achievement_id_value: Variant in achievement_ids:
		var achievement_id: String = String(achievement_id_value)
		var state: Dictionary = achievement_states[achievement_id] as Dictionary
		if int(state.get("progress", 0)) <= 0 and not bool(state.get("unlocked", false)):
			continue
		saved.append({
			"achievement_id": achievement_id,
			"progress": int(state.get("progress", 0)),
			"unlocked": bool(state.get("unlocked", false)),
			"reward_claimed": bool(state.get("reward_claimed", false)),
		})
	return saved


func apply_save_state(saved: Array) -> void:
	reset_state()
	for saved_value: Variant in saved:
		if typeof(saved_value) != TYPE_DICTIONARY:
			continue
		var saved_state: Dictionary = saved_value as Dictionary
		var achievement_id: String = String(saved_state.get("achievement_id", ""))
		if not achievement_states.has(achievement_id):
			continue
		achievement_states[achievement_id] = {
			"progress": int(saved_state.get("progress", 0)),
			"unlocked": bool(saved_state.get("unlocked", false)),
			"reward_claimed": bool(saved_state.get("reward_claimed", false)),
		}


func get_achievement_state(achievement_id: String) -> Dictionary:
	if not achievement_states.has(achievement_id):
		return {}
	return (achievement_states[achievement_id] as Dictionary).duplicate(true)


func get_definitions() -> Dictionary:
	return definitions.duplicate(true)
