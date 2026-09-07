extends Control

const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

const max_visible: int = 3
const display_duration: float = 2.8

var notification_container: VBoxContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_container()


func show_notification(text: String, type: String = "info") -> void:
	# Remove oldest if at capacity
	while notification_container.get_child_count() >= max_visible:
		var oldest: Node = notification_container.get_child(0)
		notification_container.remove_child(oldest)
		oldest.queue_free()

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	_apply_notification_style(panel, type)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(content)
	var icon_id: String = "info_ping_bar"
	match type:
		"success": icon_id = "success_check_bar"
		"warning": icon_id = "warning_alert_bar"
		"error": icon_id = "error_close_bar"
	content.add_child(ui_style.make_ui_icon_slot("notifications", icon_id, false))

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(label)

	notification_container.add_child(panel)

	# Fade-in animation (avoid position tweening inside VBoxContainer)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

	# Schedule auto-dismiss
	_schedule_dismiss(panel)


func _build_container() -> void:
	notification_container = VBoxContainer.new()
	notification_container.name = "container"
	add_child(notification_container)
	notification_container.anchor_left = 1.0
	notification_container.anchor_right = 1.0
	notification_container.offset_left = -332
	notification_container.offset_top = 78
	notification_container.offset_right = -12
	notification_container.add_theme_constant_override("separation", 4)
	notification_container.mouse_filter = MOUSE_FILTER_IGNORE


func _schedule_dismiss(panel: PanelContainer) -> void:
	await get_tree().create_timer(display_duration).timeout
	if not is_instance_valid(panel) or not is_inside_tree():
		return
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)


func _apply_notification_style(panel: PanelContainer, type: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	match type:
		"success":
			style.bg_color = Color(0.2, 0.35, 0.18, 0.92)
		"warning":
			style.bg_color = Color(0.42, 0.33, 0.13, 0.92)
		"error":
			style.bg_color = Color(0.42, 0.16, 0.13, 0.92)
		_:  # info
			style.bg_color = Color(0.16, 0.14, 0.11, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
