## An intermediate representation of a dialogue line before it gets compiled.
class_name DMTreeLine extends RefCounted


## The line number where this dialogue was found (after imported files have had their content imported).
var line_number: int = 0
## The parent [DMTreeLine] of this line
var parent: DMTreeLine
## The ID of this line.
var id: String
## The type of this line (as a [String] defined in [DMConstants].
var type: String = ""
## Is this line part of a randomised group?
var is_random: bool = false
## The indent count for this line.
var indent: int = 0
## The text of this line.
var text: String = ""
## The child [DMTreeLine]s of this line.
var children: Array[DMTreeLine] = []
## Any doc comments attached to this line.
var notes: String = ""


func _init(initial_id: String) -> void:
	id = initial_id


func _to_string() -> String:
	var tabs = []
	tabs.resize(indent)
	tabs.fill("\t")
	tabs = "".join(tabs)

	return tabs.join([tabs + "{\n",
		"\tid: %s\n" % [id],
		"\ttype: %s\n" % [type],
		"\tis_random: %s\n" % ["true" if is_random else "false"],
		"\ttext: %s\n" % [text],
		"\tnotes: %s\n" % [notes],
		"\tchildren: []\n" if children.size() == 0 else "\tchildren: [\n" + ",\n".join(children.map(func(child): return str(child))) + "]\n",
	"}"])
