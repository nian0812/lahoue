extends Control

var hint_panel: PanelContainer
var is_visible: bool = true

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = MOUSE_FILTER_IGNORE
    process_mode = PROCESS_MODE_ALWAYS
    _build_ui()

func _build_ui() -> void:
    hint_panel = PanelContainer.new()
    hint_panel.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(hint_panel)
    
    # Position top-right
    hint_panel.anchor_left = 1.0
    hint_panel.anchor_right = 1.0
    hint_panel.anchor_top = 0.0
    hint_panel.anchor_bottom = 0.0
    hint_panel.offset_left = -140
    hint_panel.offset_right = -8
    hint_panel.offset_top = 48
    hint_panel.offset_bottom = 280
    hint_panel.grow_horizontal = GROW_DIRECTION_BEGIN
    hint_panel.grow_vertical = GROW_DIRECTION_END
    
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.06, 0.04, 0.5)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.content_margin_left = 10.0
    style.content_margin_top = 8.0
    style.content_margin_right = 10.0
    style.content_margin_bottom = 8.0
    hint_panel.add_theme_stylebox_override("panel", style)
    
    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.mouse_filter = MOUSE_FILTER_IGNORE
    vbox.add_theme_constant_override("separation", 2)
    hint_panel.add_child(vbox)
    
    var shortcuts: Array = [
        ["E", "Interact"],
        ["R", "Next Crop"],
        ["I", "Inventory"],
        ["U", "Upgrade"],
        ["C", "Recipes"],
        ["T", "Restaurant"],
        ["F", "Staff"],
        ["J", "Achievements"],
        ["Esc", "Pause"],
    ]
    
    for entry in shortcuts:
        var hbox: HBoxContainer = HBoxContainer.new()
        hbox.mouse_filter = MOUSE_FILTER_IGNORE
        vbox.add_child(hbox)
        
        var key_lbl: Label = Label.new()
        key_lbl.text = entry[0]
        key_lbl.custom_minimum_size = Vector2(32, 0)
        key_lbl.add_theme_font_size_override("font_size", 12)
        key_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.9))
        key_lbl.mouse_filter = MOUSE_FILTER_IGNORE
        hbox.add_child(key_lbl)
        
        var desc_lbl: Label = Label.new()
        desc_lbl.text = entry[1]
        desc_lbl.add_theme_font_size_override("font_size", 12)
        desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8, 0.7))
        desc_lbl.mouse_filter = MOUSE_FILTER_IGNORE
        hbox.add_child(desc_lbl)

func toggle_visibility() -> void:
    is_visible = not is_visible
    hint_panel.visible = is_visible

func set_hints_visible(value: bool) -> void:
    is_visible = value
    hint_panel.visible = value
