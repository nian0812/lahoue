extends Node

const settings_path: String = "user://settings.cfg"
const resolution_presets: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const volume_buses: Dictionary = {"master": "Master", "music": "Music", "sfx": "SFX"}

var resolution: Vector2i = Vector2i(1280, 720)
var fullscreen: bool = false
var volumes: Dictionary = {"master": 1.0, "music": 1.0, "sfx": 1.0}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	load_preferences()
	apply_display_preferences()
	apply_audio_preferences()
	AudioServer.bus_layout_changed.connect(apply_audio_preferences)


func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved_resolution: Variant = config.get_value("graphics", "resolution", resolution)
	if saved_resolution is Vector2i and _valid_resolution(saved_resolution):
		resolution = saved_resolution
	var saved_fullscreen: Variant = config.get_value("graphics", "fullscreen", false)
	if saved_fullscreen is bool:
		fullscreen = saved_fullscreen
	for channel: String in volume_buses:
		var value: Variant = config.get_value("audio", channel, 1.0)
		if (value is float or value is int) and is_finite(float(value)):
			volumes[channel] = clampf(float(value), 0.0, 1.0)


func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("graphics", "resolution", resolution)
	config.set_value("graphics", "fullscreen", fullscreen)
	for channel: String in volume_buses:
		config.set_value("audio", channel, volumes[channel])
	var result: Error = config.save(settings_path)
	if result != OK:
		push_warning("Could not save graphics/audio settings: %s" % error_string(result))
	return result


func get_desktop_resolution() -> Vector2i:
	if DisplayServer.get_name() == "headless" or DisplayServer.get_screen_count() <= 0:
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


func get_resolutions() -> Array[Vector2i]:
	var choices: Array[Vector2i] = resolution_presets.duplicate()
	for size: Vector2i in [get_desktop_resolution(), resolution]:
		if _valid_resolution(size) and not choices.has(size):
			choices.append(size)
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	return choices


func set_resolution(value: Vector2i) -> void:
	if not _valid_resolution(value):
		return
	resolution = value
	if not fullscreen:
		apply_display_preferences()
	save_preferences()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display_preferences()
	save_preferences()


func apply_display_preferences() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		# Borderless fullscreen uses the current monitor's desktop resolution.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_windowed_size()
		# Reapply after the platform processes a fullscreen/windowed transition.
		_apply_windowed_size.call_deferred()


func _apply_windowed_size() -> void:
	if fullscreen or DisplayServer.get_name() == "headless":
		return
	var screen: int = DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(resolution)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var decoration_offset: Vector2i = DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	var outer_size: Vector2i = DisplayServer.window_get_size_with_decorations()
	var centered := Vector2i(maxi((usable.size.x - outer_size.x) / 2, 0), maxi((usable.size.y - outer_size.y) / 2, 0))
	DisplayServer.window_set_position(usable.position + centered + decoration_offset)


func set_volume(channel: String, value: float) -> void:
	if not volume_buses.has(channel) or not is_finite(value):
		return
	volumes[channel] = clampf(value, 0.0, 1.0)
	apply_audio_preferences()
	save_preferences()


func apply_audio_preferences() -> void:
	for channel: String in volume_buses:
		var bus_index: int = AudioServer.get_bus_index(volume_buses[channel])
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(volumes[channel])))


func _valid_resolution(value: Vector2i) -> bool:
	return value.x >= 320 and value.y >= 240 and value.x <= 16384 and value.y <= 16384
