extends Resource
class_name DialogueResource


const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")


export(int) var syntax_version
export(String) var raw_text
export(Array, Dictionary) var errors
export(Dictionary) var titles
export(Dictionary) var lines


func get_next_dialogue_line(title: String) -> DialogueLine:
	# NOTE: For some reason get_singleton doesn't work here so we have to get creative
	var tree: SceneTree = Engine.get_main_loop()
	if tree != null:
		var dialogue_manager = tree.current_scene.get_node_or_null("/root/DialogueManager")
		if dialogue_manager != null:
			return dialogue_manager.get_next_dialogue_line(title, self)
	
	assert(false, "The \"DialogueManager\" autoload does not appear to be loaded.")
	return null
