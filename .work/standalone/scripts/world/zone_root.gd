class_name LaHoueZoneRoot
extends Node2D

const required_sections: Array[String] = [
	"Ground",
	"Roads",
	"Props",
	"Buildings",
	"Interactables",
	"NPCMarkers",
	"Paths",
	"ExpansionAnchors",
]

@export var zone_id: String = ""
@export var local_bounds: Rect2 = Rect2()
@export var interaction_id: String = ""


func _ready() -> void:
	add_to_group("world_zones")
	y_sort_enabled = true
	set_meta("world_scale", 1.0)
	set_meta("footprint_convention", "local_rect")
	set_meta("pivot_convention", "ground_contact")
	for section_name: String in required_sections:
		if not has_node(section_name):
			push_error("zone '%s' is missing required section '%s'" % [zone_id, section_name])


func get_world_bounds() -> Rect2:
	if local_bounds.size.x <= 0.0 or local_bounds.size.y <= 0.0:
		return Rect2(global_position, Vector2.ZERO)
	var corners: PackedVector2Array = PackedVector2Array([
		to_global(local_bounds.position),
		to_global(local_bounds.position + Vector2(local_bounds.size.x, 0.0)),
		to_global(local_bounds.position + local_bounds.size),
		to_global(local_bounds.position + Vector2(0.0, local_bounds.size.y)),
	])
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func get_npc_marker(marker_id: String) -> Marker2D:
	return get_node_or_null("NPCMarkers/%s" % marker_id) as Marker2D


func get_expansion_anchor(anchor_id: String) -> Marker2D:
	return get_node_or_null("ExpansionAnchors/%s" % anchor_id) as Marker2D


func get_route(route_id: String) -> Path2D:
	return get_node_or_null("Paths/%s" % route_id) as Path2D


func interact(_player: Node) -> bool:
	if interaction_id.is_empty():
		return false
	var world: Node = get_tree().current_scene
	var ui: Node = world.get_node_or_null("ui") if world != null else null
	if ui != null and ui.has_method("open_hub_panel"):
		ui.call("open_hub_panel", interaction_id)
		return true
	return false
