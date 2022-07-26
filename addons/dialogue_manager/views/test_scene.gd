extends Node2D


onready var settings = $Settings


func _ready():
#	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, Vector2(1920, 1080))
#	OS.window_size = Vector2(1920, 1080)
#	OS.window_position = (OS.get_screen_size() - OS.window_size) * 0.5
#	OS.window_fullscreen = false
	
	DialogueManager.connect("dialogue_finished", self, "_on_dialogue_finished")
	
#	var title = settings.get_editor_value("run_title")
	var full_path = settings.get_editor_value("run_resource")
	var dialogue_resource = load(full_path)
	SaveGame.current_id = "start"
	State.switch_scene(full_path.get_basename().get_file())
#	DialogueManager.show_example_dialogue_balloon(title, dialogue_resource)


### Signals


func _on_dialogue_finished():
#	get_tree().quit()
	pass
