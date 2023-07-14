@icon("./assets/icon.svg")

class_name DialogueResource extends Resource


const DialogueManager = preload("res://addons/dialogue_manager/dialogue_manager.gd")


@export var titles: Dictionary = {}
@export var character_names: PackedStringArray = []
@export var first_title: String = ""
@export var lines: Dictionary = {}


func get_next_dialogue_line(title: String, extra_game_states: Array = [], mutation_behaviour: DialogueManager.MutationBehaviour = DialogueManager.MutationBehaviour.Wait) -> DialogueLine:
	return await Engine.get_singleton("DialogueManager").get_next_dialogue_line(self, title, extra_game_states, mutation_behaviour)


func get_titles() -> PackedStringArray:
	return titles.keys()
