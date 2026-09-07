extends Control

var toolbar_panel: PanelContainer
var is_visible: bool = true
var ui_mgr: Node = null
var toolbar_buttons: Array[Button] = []
var button_entries: Array = [
    ["Inventory", "Inv", "inventory_panel"],
    ["Market", "Shop", "shop_panel"],
    ["Upgrades", "Upg", "upgrade_panel"],
    ["Recipes", "Cook", "recipe_panel"],
    ["Restaurant", "Rest", "restaurant_panel"],
    ["Truck", "Truck", "truck_panel"],
    ["Staff", "Staff", "staff_panel"],
    ["Achievements", "Ach", "achievement_panel"],
]

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = MOUSE_FILTER_IGNORE
    process_mode = PROCESS_MODE_ALWAYS
    _build_ui()

func set_ui_manager(mgr: Node) -> void:
    ui_mgr = mgr

func _build_ui() -> void:
    toolbar_panel = PanelContainer.new()
    toolbar_panel.mouse_filter = MOUSE_FILTER_PASS
    add_child(toolbar_panel)
    
    # Position bottom center
    toolbar_panel.anchor_left = 0.5
    toolbar_panel.anchor_right = 0.5
    toolbar_panel.anchor_top = 1.0
    toolbar_panel.anchor_bottom = 1.0
    toolbar_panel.grow_horizontal = GROW_DIRECTION_BOTH
    toolbar_panel.grow_vertical = GROW_DIRECTION_BEGIN
    toolbar_panel.offset_left = -430
    toolbar_panel.offset_right = 430
    toolbar_panel.offset_top = -80
    toolbar_panel.offset_bottom = -42
    
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.10, 0.08, 0.75)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.content_margin_left = 8.0
    style.content_margin_top = 4.0
    style.content_margin_right = 8.0
    style.content_margin_bottom = 4.0
    toolbar_panel.add_theme_stylebox_override("panel", style)
    
    var hbox: HBoxContainer = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 4)
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    toolbar_panel.add_child(hbox)
    
    for entry in button_entries:
        var btn: Button = Button.new()
        btn.text = entry[0]
        btn.custom_minimum_size = Vector2(98, 28)
        btn.add_theme_font_size_override("font_size", 11)
        btn.pressed.connect(_on_toolbar_btn.bind(entry[2]))
        hbox.add_child(btn)
        toolbar_buttons.append(btn)

    apply_responsive_layout(get_viewport_rect().size)

func _on_toolbar_btn(panel_name: String) -> void:
    if ui_mgr == null:
        return
    var panel: Control = ui_mgr.get(panel_name)
    if panel != null:
        ui_mgr.call("_toggle_panel", panel)

func toggle_visibility() -> void:
    is_visible = not is_visible
    toolbar_panel.visible = is_visible

func set_toolbar_visible(value: bool) -> void:
    is_visible = value
    toolbar_panel.visible = value

func apply_responsive_layout(viewport_size: Vector2) -> void:
    if toolbar_panel == null:
        return
    var compact: bool = viewport_size.x < 1120.0
    var width: float = minf(860.0, maxf(viewport_size.x - 32.0, 320.0))
    toolbar_panel.offset_left = -width * 0.5
    toolbar_panel.offset_right = width * 0.5
    for index: int in toolbar_buttons.size():
        var button: Button = toolbar_buttons[index]
        var entry: Array = button_entries[index]
        button.text = String(entry[1] if compact else entry[0])
        button.custom_minimum_size = Vector2(56.0 if compact else 98.0, 28.0)
