extends AbstractTest


func test_custom_load_function_is_called() -> void:
	var original_load: Callable = DialogueManager.load_from_within_dialogue
	DialogueManager.load_from_within_dialogue = func(path: String) -> String:
		return "loaded:" + path

	var resource: DialogueResource = create_resource("
~ start
Nathan: {{load(\"my_resource\")}}")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "loaded:my_resource", "Should use custom load function.")

	DialogueManager.load_from_within_dialogue = original_load


func test_custom_load_function_with_capital_l() -> void:
	var original_load: Callable = DialogueManager.load_from_within_dialogue
	DialogueManager.load_from_within_dialogue = func(path: String) -> String:
		return "capital:" + path

	var resource: DialogueResource = create_resource("
~ start
Nathan: {{Load(\"other_resource\")}}")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "capital:other_resource", "Should use custom load function with capital L.")

	DialogueManager.load_from_within_dialogue = original_load


func test_invalid_callable_prevents_load_from_resolving() -> void:
	var original_load: Callable = DialogueManager.load_from_within_dialogue
	DialogueManager.load_from_within_dialogue = Callable()
	var original_ignore: bool = DialogueManager.ignore_missing_state_values
	DialogueManager.ignore_missing_state_values = true

	var resource: DialogueResource = create_resource("
~ start
Nathan: {{load(\"anything\")}}")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line != null, "Should not crash with invalid callable.")
	assert(line.text != "loaded:anything", "Custom callable should not be used.")

	DialogueManager.ignore_missing_state_values = original_ignore
	DialogueManager.load_from_within_dialogue = original_load
