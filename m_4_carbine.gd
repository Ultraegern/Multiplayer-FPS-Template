extends Node3D

@onready var player: Player = $"../../.."

func shoot() -> void:
	player.shoot()
