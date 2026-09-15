extends Node

var failures: int = 0
var menu: Control
var save_before: String


func _ready() -> void:
	if not ProjectSettings.globalize_path("user://").to_lower().contains("lahoue_codex_settings_test"):
		push_error("resolution_settings_test: isolated user directory required")
		get_tree().quit(1)
		return
	save_before = FileAccess.get_sha256("user://savegame.json") if FileAccess.file_exists("user://savegame.json") else ""
	menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	menu.call("_on_settings_pressed")
	_run.call_deferred()


func _settle() -> void:
	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame


func _run() -> void:
	await _settle()
	print("SETTINGS_USER_DIR: ", ProjectSettings.globalize_path("user://"))
	_expect(DisplayServer.get_name() != "headless", "real window backend required")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("read-windowed"):
		_expect(not settings_manager.fullscreen, "restart restores windowed mode")
		_check_size(Vector2i(1600, 900))
		_check_volumes()
		menu.fullscreen_check.button_pressed = true
		await _settle()
		_select_resolution(Vector2i(1366, 768))
		_check_fullscreen()
	elif args.has("read-fullscreen"):
		_expect(settings_manager.fullscreen, "restart restores fullscreen")
		_expect(settings_manager.resolution == Vector2i(1366, 768), "restart retains separate windowed size")
		_check_volumes()
		_check_fullscreen()
		menu.fullscreen_check.button_pressed = false
		await _settle()
		_check_size(Vector2i(1366, 768))
	else:
		menu.fullscreen_check.button_pressed = false
		for size: Vector2i in settings_manager.resolution_presets:
			_select_resolution(size)
			await _settle()
			_check_size(size)
			_check_layout()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://settings_%dx%d.png" % [size.x, size.y])
		var desktop: Vector2i = settings_manager.get_desktop_resolution()
		var matches: int = 0
		for size: Vector2i in settings_manager.get_resolutions():
			if size == desktop:
				matches += 1
		_expect(matches == 1, "desktop resolution appears exactly once")
		_select_resolution(Vector2i(1280, 720))
		menu.fullscreen_check.button_pressed = true
		await _settle()
		_check_fullscreen()
		_select_resolution(Vector2i(1600, 900))
		await _settle()
		_check_fullscreen()
		menu.fullscreen_check.button_pressed = false
		await _settle()
		_check_size(Vector2i(1600, 900))
		menu.master_slider.value = 0.65
		menu.music_slider.value = 0.4
		menu.sfx_slider.value = 0.25
		_check_volumes()
		# Missing buses do not discard preferences; a later bus layout receives them.
		for bus_name: String in ["Music", "SFX"]:
			if AudioServer.get_bus_index(bus_name) < 0:
				AudioServer.add_bus()
				AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		settings_manager.apply_audio_preferences()
		_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.4), "music bus receives saved level")
		_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.25), "sfx bus receives saved level")
	var save_after: String = FileAccess.get_sha256("user://savegame.json") if FileAccess.file_exists("user://savegame.json") else ""
	_expect(save_before == save_after, "gameplay save untouched")
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "stretch preserved")
	_expect(get_window().content_scale_size == Vector2i(1280, 720), "logical viewport preserved")
	print("resolution_settings_test: %s (%s)" % ["PASS" if failures == 0 else "FAIL", str(args)])
	get_tree().quit(0 if failures == 0 else 1)


func _select_resolution(size: Vector2i) -> void:
	for index: int in menu.resolution_option.item_count:
		if menu.resolution_option.get_item_metadata(index) == size:
			menu.resolution_option.select(index)
			menu.resolution_option.item_selected.emit(index)
			return
	_expect(false, "missing resolution %s" % str(size))


func _check_size(size: Vector2i) -> void:
	_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "windowed mode")
	_expect(DisplayServer.window_get_size() == size, "client resolution %s; actual %s" % [str(size), str(DisplayServer.window_get_size())])
	_expect(settings_manager.resolution == size, "selected resolution %s" % str(size))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var outer_size: Vector2i = DisplayServer.window_get_size_with_decorations()
	if outer_size.x <= usable.size.x and outer_size.y <= usable.size.y:
		var center: Vector2i = DisplayServer.window_get_position_with_decorations() + outer_size / 2
		_expect(Vector2(center).distance_to(Vector2(usable.get_center())) <= 2.0, "window centered in usable monitor area")


func _check_fullscreen() -> void:
	_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "native fullscreen mode")
	var difference: Vector2i = (DisplayServer.window_get_size() - settings_manager.get_desktop_resolution()).abs()
	_expect(difference.x <= 1 and difference.y <= 1, "fullscreen uses desktop resolution")
	_check_layout()


func _check_volumes() -> void:
	_expect(is_equal_approx(menu.master_slider.value, 0.65), "master preference restored")
	_expect(is_equal_approx(menu.music_slider.value, 0.4), "music preference restored")
	_expect(is_equal_approx(menu.sfx_slider.value, 0.25), "sfx preference restored")
	_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.65), "master bus applied")


func _check_layout() -> void:
	var panel: Rect2 = menu.settings_panel.get_global_rect()
	_expect(menu.get_global_rect().encloses(panel), "settings panel fits viewport")
	for node: Node in menu.settings_panel.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.get_window() != get_window():
			continue
		_expect(panel.grow(1.0).encloses(control.get_global_rect()), "settings control fits panel: %s" % control.name)
	_expect(menu.resolution_option.size.x >= menu.resolution_option.get_combined_minimum_size().x, "resolution text fits selector")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("resolution_settings_test: " + message)
