extends AbstractTest


# pls work im begging you
func test_translation_vs_mutations() -> void:
	var resource: DialogueResource = load("res://tests/test.dialogue")
	var line: DialogueLine = await resource.get_next_dialogue_line("test")
	while is_instance_valid(line):
		if line.static_id == "DIALOGUETEST":
			var my_id: String= line.id.get_slice("@", 1)
			var my_line: Variant= resource.lines.get(my_id)
			assert(line.text != my_line.text, "[next] is treated as normal text.")
			# Dunno how to directly compare DMResolvedLineData.line to the static id so I did this instead. :/
		line = await resource.get_next_dialogue_line(line.next_id)
