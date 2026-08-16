extends Node2D


func _ready() -> void:
	if not data_manager.is_ready:
		push_error("main_world: cannot start gameplay because required game data failed to load")
		return

	var state_loaded: bool = false
	if save_manager.has_save():
		state_loaded = save_manager.load_game()

	if not state_loaded:
		save_manager.create_new_game()

	game_manager.start_gameplay()


func _exit_tree() -> void:
	if game_manager.gameplay_active:
		save_manager.save_game()
		game_manager.stop_gameplay()
