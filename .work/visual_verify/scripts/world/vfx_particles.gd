extends CPUParticles2D

func _ready() -> void:
	emitting = true
	
	var tw: Tween = create_tween()
	tw.tween_interval(lifetime * 2.0)
	tw.tween_callback(queue_free)
