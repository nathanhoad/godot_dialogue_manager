extends AbstractTest


# pls work im begging you
func test_translation_vs_mutations() -> void:
	var resource: DialogueResource = load("res://tests/test.dialogue")
	var line: DialogueLine = await resource.get_next_dialogue_line("test")
	while is_instance_valid(line):
		if line.static_id == "DIALOGUETEST":
			assert(not line.inline_mutations.is_empty(), "Inline mutations shouldn't be empty")
		line = await resource.get_next_dialogue_line(line.next_id)
