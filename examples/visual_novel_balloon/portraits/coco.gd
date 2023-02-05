extends Node2D


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func meow() -> void:
	animation_player.play("Meow")
