extends AudioStreamPlayer3D
class_name AudioOncePlayer3D

func _on_finished() -> void:
	queue_free()
