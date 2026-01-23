extends AbstractTest


func test_can_run_snippets() -> void:
	var resource: DialogueResource = load("res://tests/main.dialogue")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "Testing a snippet.", "Text should match.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "This is a snippet.", "Text should be from the snippets file.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "...and back again.")
