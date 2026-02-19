class_name BaseDialogueTestScene extends Node2D


@onready var key: String = DMSettings.get_user_value("run_key")
@onready var resource: DialogueResource = load(DMSettings.get_user_value("run_resource_path"))


func _ready() -> void:
	if not Engine.is_embedded_in_editor:
		var window: Window = get_viewport()
		var screen_index: int = DisplayServer.get_primary_screen()
		window.position = Vector2(DisplayServer.screen_get_position(screen_index)) + (DisplayServer.screen_get_size(screen_index) - window.size) * 0.5
		window.mode = Window.MODE_WINDOWED

	# Normally you can just call DialogueManager directly but doing so before the plugin has been
	# enabled in settings will throw a compiler error here so I'm using `get_singleton` instead.
	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_manager.show_dialogue_balloon(resource, key if not key.is_empty() else resource.first_label)


func _enter_tree() -> void:
	DMSettings.set_user_value("is_running_test_scene", false)


#region Signals


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	get_tree().quit()


#endregion
