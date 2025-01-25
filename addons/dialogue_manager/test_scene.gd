class_name BaseDialogueTestScene extends Node2D


const DialogueSettings = preload("./settings.gd")
const DialogueResource = preload("./dialogue_resource.gd")


@onready var title: String = DialogueSettings.get_user_value("run_title")
@onready var resource: DialogueResource = load(DialogueSettings.get_user_value("run_resource_path"))


func _ready():
	# Is this running in Godot >=4.4?
	if Engine.has_method("is_embedded_in_editor"):
		if not Engine.call("is_embedded_in_editor"):
			var window: Window = get_viewport()
			var screen_index: int = DisplayServer.get_primary_screen()
			window.position = Vector2(DisplayServer.screen_get_position(screen_index)) + (DisplayServer.screen_get_size(screen_index) - window.size) * 0.5
			window.mode = Window.MODE_WINDOWED
	else:
		var screen_index: int = DisplayServer.get_primary_screen()
		DisplayServer.window_set_position(Vector2(DisplayServer.screen_get_position(screen_index)) + (DisplayServer.screen_get_size(screen_index) - DisplayServer.window_get_size()) * 0.5)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Normally you can just call DialogueManager directly but doing so before the plugin has been
	# enabled in settings will throw a compiler error here so I'm using `get_singleton` instead.
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_manager.show_dialogue_balloon(resource, title if not title.is_empty() else resource.first_title)


func _enter_tree() -> void:
	DialogueSettings.set_user_value("is_running_test_scene", false)


#region Signals


func _on_dialogue_ended(_resource: DialogueResource):
	get_tree().quit()


#endregion
