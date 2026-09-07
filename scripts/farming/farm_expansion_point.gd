extends Node2D

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")
const manifest_sprite: GDScript = preload("res://scripts/visual/manifest_sprite.gd")

@export var expansion_id: String = "farm_expansion"

var interaction_area: Area2D


func _ready() -> void:
	_build_visual()
	_build_interaction()


func interact(_player: Node) -> bool:
	var world: Node = _get_world()
	if world == null or not world.has_method("purchase_next_farm_plot"):
		return false
	if is_fully_expanded():
		_notify("Farm fully expanded", "info")
		return false
	if _is_level_limited(world):
		var next_level: int = int(world.call("get_next_farm_plot_expansion_level"))
		_notify("Next expansion available at Level %d" % next_level, "info")
		return false
	var cost: int = data_manager.get_farm_plot_purchase_cost()
	if cost <= 0 or not game_manager.can_afford(cost):
		_notify("Not enough money", "warning")
		return false
	if not bool(world.call("purchase_next_farm_plot")):
		return false
	var purchased_count: int = (world.get("purchased_farm_plots") as Array).size()
	_notify("Farm plot #%d unlocked" % purchased_count, "success")
	return true


func is_fully_expanded() -> bool:
	var world: Node = _get_world()
	return world != null and world.has_method("get_next_farm_plot_id") and String(world.call("get_next_farm_plot_id")).is_empty()


func get_interaction_prompt_text() -> String:
	var world: Node = _get_world()
	var purchased_count: int = _get_purchased_count(world)
	if is_fully_expanded():
		return "Farm Plots: %d/%d\nFarm fully expanded" % [purchased_count, data_manager.get_farm_plot_maximum()]
	if _is_level_limited(world):
		var current_limit: int = maxi(int(world.call("get_current_farm_plot_limit")), purchased_count)
		var next_level: int = int(world.call("get_next_farm_plot_expansion_level"))
		return "Farm Plots: %d/%d\nNext expansion available at Level %d" % [purchased_count, current_limit, next_level]
	var formatted_cost: String = vnd_format.format_vnd(data_manager.get_farm_plot_purchase_cost())
	return "[E] Mở rộng đất — %s" % formatted_cost


func _is_level_limited(world: Node) -> bool:
	return (
		world != null
		and world.has_method("get_current_farm_plot_limit")
		and _get_purchased_count(world) >= int(world.call("get_current_farm_plot_limit"))
	)


func _get_purchased_count(world: Node) -> int:
	if world == null:
		return 0
	var plots_value: Variant = world.get("purchased_farm_plots")
	return (plots_value as Array).size() if typeof(plots_value) == TYPE_ARRAY else 0


func _get_world() -> Node:
	return get_tree().current_scene


func _notify(text: String, type: String) -> void:
	var world: Node = _get_world()
	if world == null:
		return
	var notification: Node = world.get_node_or_null("ui/notification_popup")
	if notification != null and notification.has_method("show_notification"):
		notification.call("show_notification", text, type)


func _build_visual() -> void:
	var visual_root := Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	var board_texture: Texture2D = asset_catalog.get_atlas_texture(
		"map_zone_expansion_visual_kit",
		"blank_zone_information_board"
	)
	if board_texture != null:
		var board_artwork := Sprite2D.new()
		board_artwork.name = "board_artwork"
		board_artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		visual_root.add_child(board_artwork)
		manifest_sprite.configure_sprite(board_artwork, board_texture, Rect2(-78.0, -42.0, 156.0, 84.0))
	else:
		var board := Polygon2D.new()
		board.name = "board"
		board.polygon = PackedVector2Array([
			Vector2(-78.0, -26.0), Vector2(78.0, -26.0),
			Vector2(78.0, 26.0), Vector2(-78.0, 26.0),
		])
		board.color = Color(0.38, 0.27, 0.14, 1.0)
		visual_root.add_child(board)

	var label: Label = Label.new()
	label.name = "label"
	label.text = "Farm Expansion\n100.000 VNĐ"
	label.position = Vector2(-78.0, -21.0)
	label.size = Vector2(156.0, 42.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	visual_root.add_child(label)


func _build_interaction() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "interaction_area"
	interaction_area.collision_layer = 4
	interaction_area.collision_mask = 0
	interaction_area.monitorable = true
	interaction_area.monitoring = false
	add_child(interaction_area)

	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "collision_shape"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 52.0
	collision.shape = shape
	interaction_area.add_child(collision)
