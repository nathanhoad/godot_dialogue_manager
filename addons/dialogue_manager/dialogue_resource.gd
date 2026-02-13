@tool
@icon("./assets/icon.svg")

## A collection of dialogue lines for use with [code]DialogueManager[/code].
class_name DialogueResource extends Resource


const DialogueLine = preload("./dialogue_line.gd")

## A list of state shortcuts
@export var using_states: PackedStringArray = []

## A map of labels and the lines they point to.
@export var labels: Dictionary = {}

## A list of character names.
@export var character_names: PackedStringArray = []

## The first label in the file.
@export var first_label: String = ""

## A map of the encoded lines of dialogue.
@export var lines: Dictionary = {}

## raw version of the text
@export var raw_text: String


## Get the next printable line of dialogue, starting from a referenced line ([code]label[/code] can
## be a labels string or a stringified line number). Runs any mutations along the way and then returns
## the first dialogue line encountered.
func get_next_dialogue_line(label: String = "", extra_game_states: Array = [], mutation_behaviour: DMConstants.MutationBehaviour = DMConstants.MutationBehaviour.Wait) -> DialogueLine:
	return await Engine.get_singleton("DialogueManager").get_next_dialogue_line(self, label, extra_game_states, mutation_behaviour)


## Get the list of any labels found in the file.
func get_labels() -> PackedStringArray:
	return labels.keys()


func _to_string() -> String:
	if resource_path:
		return "<DialogueResource path=\"%s\">" % [resource_path]
	else:
		return "<DialogueResource>"
