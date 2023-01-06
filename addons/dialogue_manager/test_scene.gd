class_name BaseDialogueTestScene extends Node2D


const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")


@onready var title: String = DialogueSettings.get_user_value("run_title")
@onready var resource: DialogueResource = load(DialogueSettings.get_user_value("run_resource_path"))


func _ready():
	DisplayServer.window_set_position((DisplayServer.screen_get_size() - DisplayServer.window_get_size()) * 0.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	DialogueManager.show_example_dialogue_balloon(resource, title)


func _enter_tree() -> void:
	DialogueSettings.set_user_value("is_running_test_scene", false)


### Signals


func _on_dialogue_finished():
	get_tree().quit()
