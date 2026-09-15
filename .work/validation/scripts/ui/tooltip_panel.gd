extends PanelContainer

var title_lbl: Label
var desc_lbl: Label
var cost_lbl: Label
var req_lbl: Label

func _ready() -> void:
	visible = false
	z_index = 100
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.25, 0.2)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(vbox)

	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(title_lbl)

	desc_lbl = Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(desc_lbl)

	cost_lbl = Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	vbox.add_child(cost_lbl)

	req_lbl = Label.new()
	req_lbl.add_theme_font_size_override("font_size", 14)
	req_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	vbox.add_child(req_lbl)


func show_tooltip(data: Dictionary, pos: Vector2) -> void:
	if data.has("title"):
		title_lbl.text = String(data["title"])
		title_lbl.visible = true
	else:
		title_lbl.visible = false

	if data.has("description") and String(data["description"]) != "":
		desc_lbl.text = String(data["description"])
		desc_lbl.visible = true
	else:
		desc_lbl.visible = false

	if data.has("cost") and String(data["cost"]) != "":
		cost_lbl.text = "Cost: " + String(data["cost"])
		cost_lbl.visible = true
	else:
		cost_lbl.visible = false

	if data.has("req") and String(data["req"]) != "":
		req_lbl.text = String(data["req"])
		req_lbl.visible = true
	else:
		req_lbl.visible = false

	# Setup position to not overflow screen
	global_position = pos + Vector2(15, 15)

	# Delay visible calculation
	call_deferred("_adjust_position")
	visible = true

func _adjust_position() -> void:
	var vp: Rect2 = get_viewport_rect()
	var sz: Vector2 = size
	if global_position.x + sz.x > vp.size.x:
		global_position.x = vp.size.x - sz.x - 10
	if global_position.y + sz.y > vp.size.y:
		global_position.y = vp.size.y - sz.y - 10

func hide_tooltip() -> void:
	visible = false
