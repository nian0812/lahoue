extends Node2D

var _tween: Tween

func _ready() -> void:
	pass

func display(text: String, color: Color = Color.WHITE) -> void:
	var label: Label = get_node_or_null("Label") as Label
	if label == null:
		return

	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	scale = Vector2.ZERO
	position.y -= 10

	_tween = create_tween()
	_tween.set_parallel(true)

	# Pop up
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", position.y - 30, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Fade out
	_tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.6).set_trans(Tween.TRANS_LINEAR)

	_tween.set_parallel(false)
	_tween.tween_callback(queue_free)
