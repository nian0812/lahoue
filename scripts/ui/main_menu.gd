extends Control

@onready var continue_btn: Button = $VBoxContainer/ContinueBtn
@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var settings_btn: Button = $VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var settings_panel: Panel = $SettingsPanel

func _on_settings_pressed() -> void:
	settings_panel.show()

# Settings Panel Code

@onready var master_slider: HSlider = $SettingsPanel/VBoxContainer/MasterVolume/Slider
@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/MusicVolume/Slider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXVolume/Slider
@onready var fullscreen_check: CheckBox = $SettingsPanel/VBoxContainer/Fullscreen/CheckBox
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
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
		master_slider.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(master_idx, linear_to_db(v)))
	else:
		master_slider.editable = false

	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
		music_slider.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(music_idx, linear_to_db(v)))
	else:
		music_slider.editable = false

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
		sfx_slider.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(v)))
	else:
		sfx_slider.editable = false
	
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	fullscreen_check.toggled.connect(func(pressed: bool): 
		if pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)

func _on_continue_pressed() -> void:
	save_manager.clear_new_game_request()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_new_game_pressed() -> void:
	save_manager.request_new_game()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
