extends Control

var _tween: Tween

func _ready() -> void:
	visible = false

func show_level_up(old_lvl: int, new_lvl: int) -> void:
	var label: Label = get_node_or_null("VBox/LevelLabel") as Label
	if label:
		if old_lvl > 0:
			label.text = "Level %d -> %d!" % [old_lvl, new_lvl]
		else:
			label.text = "Level %d Reached!" % new_lvl

	visible = true
	modulate.a = 0
	scale = Vector2.ONE * 0.8

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.set_parallel(false)
	_tween.tween_interval(2.0)

	_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: visible = false)
