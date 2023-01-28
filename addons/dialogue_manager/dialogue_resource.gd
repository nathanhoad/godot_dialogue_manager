@icon("./assets/icon.svg")

class_name DialogueResource extends Resource


const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")


func get_next_dialogue_line(title: String, extra_game_states: Array = []) -> DialogueLine:
	return await Engine.get_singleton("DialogueManager").get_next_dialogue_line(self, title, extra_game_states)


func get_titles() -> PackedStringArray:
	return get_meta("titles").keys()
