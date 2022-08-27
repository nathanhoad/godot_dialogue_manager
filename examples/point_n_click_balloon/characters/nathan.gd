extends AnimatedSprite2D


func _ready() -> void:
	Events.character_started_talking.connect(_on_character_started_talking)
	Events.character_finished_talking.connect(_on_character_finished_talking)


### Signals


func _on_character_started_talking(character_name: String) -> void:
	if character_name == "Nathan":
		play("Talking")


func _on_character_finished_talking(character_name: String) -> void:
	if character_name == "Nathan":
		play("Default")
