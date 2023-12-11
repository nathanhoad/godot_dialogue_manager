extends AbstractTest


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


func test_can_parse_responses() -> void:
	var output = parse("
~ start
Nathan: Here are some options.
- Simple
- Nested
	Nathan: Nested dialogue.
- Jump => start
- Condition [if true]
Nathan: Line after.")

	assert(output.errors.is_empty(), "Should be no errors.")

	var responses = output.lines.values().filter(func(line): return line.type == DialogueConstants.TYPE_RESPONSE)

	assert(responses.size() == 4, "Should have 4 responses.")
	assert(responses[0].text == "Simple", "Should match text")
	assert(responses[1].text == "Nested", "Should match text")
	assert(responses[2].text == "Jump", "Should match text")
	assert(responses[2].next_id == "3", "Should jump to start")
	assert(responses[3].text == "Condition", "Should match text")
	assert("expression" in responses[3].condition, "Should match text")


func test_can_have_responses_without_dialogue() -> void:
	var output = parse("
Nathan: Hello.
do StateForTests.noop()
- First
- Second
- Third")

	assert(output.errors.size() == 0, "Should have no errors.")
	assert(output.lines["3"].next_id == "4", "Mutation should point to first response.")

	var resource = create_resource("
~ start
Nathan: Hello.
do StateForTests.noop()
- First
- Second
- Third")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Hello.", "Should start with hello.")
	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.type == DialogueConstants.TYPE_RESPONSE, "Should point to the response")
	assert(line.responses.size() == 3, "Should have 3 responses.")


func test_can_run_responses() -> void:
	var resource = create_resource("
~ start
Nathan: Here are some options.
- Empty one
- Nested
	Nathan: Nested dialogue.
- Jump => start
- Pass condition [if true]
- Fail condition [if false]
Nathan: Line after.")

	ProjectSettings.set_setting("dialogue_manager/general/include_all_responses", false)
	var line = await resource.get_next_dialogue_line("start")
	assert(line.responses.size() == 4, "Failed conditions are not included.")

	ProjectSettings.set_setting("dialogue_manager/general/include_all_responses", true)
	line = await resource.get_next_dialogue_line("start")
	assert(line.responses.size() == 5, "Failed conditions are included.")

	assert(line.responses[3].is_allowed == true, "Passed condition is allowed.")
	assert(line.responses[4].is_allowed == false, "Failed condition is not allowed.")

	var responses = line.responses.duplicate()

	line = await resource.get_next_dialogue_line(responses[0].next_id)
	assert(line.text == "Line after.", "First response points to the line after.")

	line = await resource.get_next_dialogue_line(responses[1].next_id)
	assert(line.text == "Nested dialogue.", "Second response points to nested dialogue.")

	line = await resource.get_next_dialogue_line(responses[2].next_id)
	assert(line.text == "Here are some options.", "Third response starts again.")
