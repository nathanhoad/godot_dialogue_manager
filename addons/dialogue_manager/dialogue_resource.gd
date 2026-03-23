@tool
@icon("./assets/icon.svg")

## A collection of dialogue lines for use with [code]DialogueManager[/code].
class_name DialogueResource extends Resource


## A list of state shortcuts
@export var using_states: PackedStringArray = []

## A map of cues and the lines they point to.
@export var cues: Dictionary = {}

## A list of character names.
@export var character_names: PackedStringArray = []

## The first cue in the file.
@export var first_cue: String = ""

## A map of the encoded lines of dialogue.
@export var lines: Dictionary = {}


## Get the next printable line of dialogue, starting from a referenced line ([code]cue[/code] can
## be a cues string or a stringified line number). Runs any mutations along the way and then returns
## the first dialogue line encountered.
func get_next_dialogue_line(cue: String = "", extra_game_states: Array = [], mutation_behaviour: DMConstants.MutationBehaviour = DMConstants.MutationBehaviour.Wait) -> DialogueLine:
	return await Engine.get_singleton("DialogueManager").get_next_dialogue_line(self, cue, extra_game_states, mutation_behaviour)


## Get the list of any cues found in the file.
func get_cues() -> PackedStringArray:
	return cues.keys()


func _to_string() -> String:
	if resource_path:
		return "<DialogueResource path=\"%s\">" % [resource_path]
	else:
		return "<DialogueResource>"
