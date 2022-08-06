extends Resource
class_name DialogueResource


const DialogueLine := preload("res://addons/dialogue_manager/dialogue_line.gd")
const DialogueConstants := preload("res://addons/dialogue_manager/constants.gd")


export(int) var resource_version
export(int) var syntax_version
export(String) var raw_text
export(Array, Dictionary) var errors
export(Dictionary) var titles
export(Dictionary) var lines


func _init():
	resource_version = 1
	syntax_version = DialogueConstants.SYNTAX_VERSION
	raw_text = "~ this_is_a_node_title\n\nNathan: This is some dialogue.\nNathan: Here are some choices.\n- First one\n\tNathan: You picked the first one.\n- Second one\n\tNathan: You picked the second one.\n- Start again => this_is_a_node_title\n- End the conversation => END\nNathan: For more information about conditional dialogue, mutations, and all the fun stuff, see the online documentation."
	errors = []
	titles = {}
	lines = {}


func get_next_dialogue_line(title: String, extra_game_states: Array = []) -> DialogueLine:
	# NOTE: For some reason get_singleton doesn't work here so we have to get creative
	var tree: SceneTree = Engine.get_main_loop()
	if tree:
		var dialogue_manager = tree.current_scene.get_node_or_null("/root/DialogueManager")
		if dialogue_manager != null:
			return dialogue_manager.get_next_dialogue_line(title, self, extra_game_states)

	assert(false, "The \"DialogueManager\" autoload does not appear to be loaded.")
	return null
