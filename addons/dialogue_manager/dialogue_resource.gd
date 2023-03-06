@icon("./assets/icon.svg")

class_name DialogueResource extends Resource


@export var titles: Dictionary = {}
@export var character_names: PackedStringArray = []
@export var first_title: String = ""
@export var lines: Dictionary = {}


func get_next_dialogue_line(title: String, extra_game_states: Array = []) -> DialogueLine:
	return await Engine.get_singleton("DialogueManager").get_next_dialogue_line(self, title, extra_game_states)


func get_titles() -> PackedStringArray:
	return titles.keys()
