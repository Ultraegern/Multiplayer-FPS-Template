extends Node3D
class_name AudioOncePlayer3DSpawner

@export var audio_stream: AudioStream

@onready var audio_once_player_3d: PackedScene = preload("res://nodes/audio_once_player_3d.tscn")

func play():
	var node: AudioOncePlayer3D = audio_once_player_3d.instantiate()
	node.stream = audio_stream
	add_child(node)
