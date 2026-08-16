extends CharacterBody2D

signal interaction_requested(target: Node)

@export var movement_speed: float = 240.0
@export var interaction_offset: float = 32.0

@onready var interaction_area: Area2D = $interaction_area

var facing_direction: Vector2 = Vector2.DOWN


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if not input_direction.is_zero_approx():
		facing_direction = input_direction.normalized()
		interaction_area.position = facing_direction * interaction_offset

	velocity = input_direction * movement_speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	_try_interact()
	get_viewport().set_input_as_handled()


func _try_interact() -> void:
	var closest_target: Node = null
	var closest_distance_squared: float = INF

	for area: Area2D in interaction_area.get_overlapping_areas():
		var target: Node = _resolve_interactable(area)
		if target == null:
			continue

		var target_position: Vector2 = area.global_position
		if target is Node2D:
			target_position = (target as Node2D).global_position

		var distance_squared: float = global_position.distance_squared_to(target_position)
		if distance_squared < closest_distance_squared:
			closest_target = target
			closest_distance_squared = distance_squared

	if closest_target == null:
		return

	interaction_requested.emit(closest_target)
	closest_target.call("interact", self)


func _resolve_interactable(area: Area2D) -> Node:
	if area.has_method("interact"):
		return area

	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent

	return null
