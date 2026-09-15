extends Control

@onready var continue_btn: Button = $VBoxContainer/ContinueBtn
@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var settings_btn: Button = $VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var settings_panel: Panel = $SettingsPanel

func _on_settings_pressed() -> void:
	_refresh_resolution_options()
	settings_panel.show()

# Settings Panel Code

@onready var master_slider: HSlider = $SettingsPanel/VBoxContainer/MasterVolume/Slider
@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/MusicVolume/Slider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXVolume/Slider
@onready var fullscreen_check: CheckBox = $SettingsPanel/VBoxContainer/Fullscreen/CheckBox
@onready var resolution_option: OptionButton = $SettingsPanel/VBoxContainer/Resolution/OptionButton
@onready var close_settings_btn: Button = $SettingsPanel/VBoxContainer/CloseSettingsBtn

func _ready() -> void:
	if not save_manager.has_save():
		continue_btn.disabled = true
	
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_settings_btn.pressed.connect(func(): settings_panel.hide())
	
	_setup_settings()
	settings_panel.hide()

func _setup_settings() -> void:
	master_slider.value = settings_manager.volumes["master"]
	music_slider.value = settings_manager.volumes["music"]
	sfx_slider.value = settings_manager.volumes["sfx"]
	master_slider.value_changed.connect(func(v: float): settings_manager.set_volume("master", v))
	music_slider.value_changed.connect(func(v: float): settings_manager.set_volume("music", v))
	sfx_slider.value_changed.connect(func(v: float): settings_manager.set_volume("sfx", v))
	fullscreen_check.set_pressed_no_signal(settings_manager.fullscreen)
	fullscreen_check.toggled.connect(settings_manager.set_fullscreen)
	_refresh_resolution_options()
	resolution_option.item_selected.connect(_on_resolution_selected)


func _refresh_resolution_options() -> void:
	resolution_option.clear()
	var desktop: Vector2i = settings_manager.get_desktop_resolution()
	for size: Vector2i in settings_manager.get_resolutions():
		var label: String = "%d x %d" % [size.x, size.y]
		if size == desktop:
			label += " (Desktop)"
		resolution_option.add_item(label)
		var index: int = resolution_option.item_count - 1
		resolution_option.set_item_metadata(index, size)
		if size == settings_manager.resolution:
			resolution_option.select(index)


func _on_resolution_selected(index: int) -> void:
	settings_manager.set_resolution(resolution_option.get_item_metadata(index))

func _on_continue_pressed() -> void:
	save_manager.clear_new_game_request()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_new_game_pressed() -> void:
	save_manager.request_new_game()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
