extends AbstractTest


func test_serializing_dialogue_line() -> void:
	var resource: DialogueResource = load("res://tests/main.dialogue")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	line = await resource.get_next_dialogue_line(line.next_id)

	assert(line.text == "This is a snippet.", "Should fetch dialogue after a jump.")

	var serialized: String = line.to_serialized()

	assert(serialized == "m7wueb1et2an@1=>m7wueb1et2an@2|bnnha7rqiubty@7", "Should have a valid serialized string.")

	var restored_line: DialogueLine = await DialogueLine.new_from_serialized(serialized)

	assert(restored_line.text == line.text, "Should match the first line.")
	assert(restored_line.next_id == line.next_id, "Should match next ID.")
