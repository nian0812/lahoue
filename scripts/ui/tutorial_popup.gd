extends Control

const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

signal next_requested()
signal skip_requested()

var panel: PanelContainer
var title_label: Label
var body_label: Label
var objective_label: Label
var progress_label: Label
var next_button: Button
var skip_button: Button


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	visible = false


func show_step(
	title: String,
	body: String,
	step_index: int,
	step_count: int,
	can_continue: bool,
	is_last_step: bool,
	objective_id: String = ""
) -> void:
	title_label.text = title
	body_label.text = body
	if objective_id.is_empty():
		objective_label.text = "Objective: Review this guidance"
		objective_label.theme_type_variation = &"StatusInfo"
	elif can_continue:
		objective_label.text = "Objective complete"
		objective_label.theme_type_variation = &"StatusSuccess"
	else:
		objective_label.text = "Objective: Complete the highlighted action"
		objective_label.theme_type_variation = &"StatusWarning"
	progress_label.text = "Step %d / %d" % [step_index + 1, step_count]
	next_button.disabled = not can_continue
	next_button.text = "Continue" if is_last_step else "Next"
	visible = true
	apply_responsive_layout(get_viewport_rect().size)


func hide_popup() -> void:
	visible = false


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "tutorial_card"
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18.0
	panel.offset_right = 398.0
	panel.offset_top = -298.0
	panel.offset_bottom = -76.0
	add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.74, 0.58, 0.28, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	title_label = Label.new()
	var header: HBoxContainer = HBoxContainer.new()
	header.add_child(ui_style.make_atlas_icon_slot("tutorial_help_shortcut_visual_kit", "help_book", true))
	header.add_child(title_label)
	title_label.theme_type_variation = &"SectionTitle"
	root.add_child(header)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	root.add_child(body_label)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.text = "Objective: Review this guidance"
	root.add_child(objective_label)

	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	root.add_child(progress_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	skip_button = Button.new()
	skip_button.name = "skip_tutorial"
	skip_button.text = "Skip Tutorial"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	buttons.add_child(skip_button)

	next_button = Button.new()
	next_button.name = "tutorial_next"
	next_button.text = "Next"
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(func() -> void: next_requested.emit())
	buttons.add_child(next_button)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	var width: float = minf(380.0, maxf(viewport_size.x - 36.0, 300.0))
	var height: float = minf(222.0, maxf(viewport_size.y - 160.0, 180.0))
	panel.offset_left = 18.0
	panel.offset_right = 18.0 + width
	panel.offset_top = -height - 76.0
	panel.offset_bottom = -76.0
