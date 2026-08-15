extends Node2D


func _ready() -> void:
	if save_manager.has_save():
		save_manager.load_game()
	else:
		save_manager.create_new_game()

	game_manager.start_gameplay()


func _exit_tree() -> void:
	if game_manager.gameplay_active:
		save_manager.save_game()
		game_manager.stop_gameplay()
