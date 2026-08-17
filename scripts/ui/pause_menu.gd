extends Control

var overlay: ColorRect
var menu_panel: PanelContainer
var active_tween: Tween


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_menu()
	game_manager.game_state_changed.connect(_on_game_state_changed)
	visible = false


func _build_menu() -> void:
	# Dark overlay background
	overlay = ColorRect.new()
	overlay.name = "overlay"
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = MOUSE_FILTER_STOP

	# Center container
	var center: CenterContainer = CenterContainer.new()
	center.name = "center"
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE

	# Menu panel
	menu_panel = PanelContainer.new()
	menu_panel.name = "panel"
	center.add_child(menu_panel)
	menu_panel.custom_minimum_size = Vector2(260, 0)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "content"
	menu_panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 10)

	# Title
	var title: Label = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Divider
	var divider: HSeparator = HSeparator.new()
	divider.modulate = Color(1, 1, 1, 0.3)
	vbox.add_child(divider)

	# Buttons
	_add_menu_button(vbox, "Resume", _on_resume)
	_add_menu_button(vbox, "Save Game", _on_save)

	# Spacer before quit
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	_add_menu_button(vbox, "Quit", _on_quit)


func _add_menu_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 38)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _on_game_state_changed(state: Variant) -> void:
	if String(state) == "paused":
		_show_menu()
	else:
		_hide_menu()


func _show_menu() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	visible = true
	modulate.a = 0.0
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_property(self, "modulate:a", 1.0, 0.12)


func _hide_menu() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.1)
	active_tween.tween_callback(func() -> void: visible = false)


func _on_resume() -> void:
	game_manager.toggle_pause()


func _on_save() -> void:
	save_manager.save_game()


func _on_quit() -> void:
	get_tree().quit()
