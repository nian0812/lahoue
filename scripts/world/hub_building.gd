extends Node2D

@export var building_id: String = ""
@export var building_label: String = ""
@export var building_color: Color = Color(0.6, 0.5, 0.4, 1.0)
@export var building_size: Vector2 = Vector2(72, 56)

var interaction_area: Area2D

func _ready() -> void:
    y_sort_enabled = true
    _build_visual()
    _build_interaction()

func _build_visual() -> void:
    var visual_root: Node2D = get_node_or_null("VisualRoot") as Node2D
    if visual_root == null:
        visual_root = Node2D.new()
        visual_root.name = "VisualRoot"
        add_child(visual_root)
    if visual_root.has_node("body"):
        if visual_root.has_method("refresh_artwork"):
            visual_root.call("refresh_artwork")
        return
    var body: ColorRect = ColorRect.new()
    body.name = "body"
    body.size = building_size
    body.position = Vector2(-building_size.x * 0.5, -building_size.y)
    body.color = building_color
    visual_root.add_child(body)
    
    if not building_label.is_empty():
        var lbl: Label = Label.new()
        lbl.text = building_label
        lbl.add_theme_font_size_override("font_size", 11)
        lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.position = Vector2(-building_size.x * 0.5, -building_size.y - 18.0)
        lbl.size = Vector2(building_size.x, 18)
        visual_root.add_child(lbl)
    if visual_root.has_method("refresh_artwork"):
        visual_root.call("refresh_artwork")

func _build_interaction() -> void:
    interaction_area = get_node_or_null("interaction_area") as Area2D
    if interaction_area != null:
        return
    interaction_area = Area2D.new()
    interaction_area.name = "interaction_area"
    interaction_area.collision_layer = 4
    interaction_area.collision_mask = 0
    interaction_area.monitorable = true
    interaction_area.monitoring = false
    interaction_area.position = Vector2(0.0, -building_size.y * 0.5)
    add_child(interaction_area)
    
    var shape: CollisionShape2D = CollisionShape2D.new()
    var circle: CircleShape2D = CircleShape2D.new()
    circle.radius = 52.0
    shape.shape = circle
    interaction_area.add_child(shape)

func interact(_player: Node) -> bool:
    if building_id.is_empty():
        return false
    var ui: Node = get_tree().current_scene.get_node_or_null("ui")
    if ui != null and ui.has_method("open_hub_panel"):
        ui.call("open_hub_panel", building_id)
    return true
