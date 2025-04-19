extends AbstractTest


func test_can_parse_responses() -> void:
	var output = compile("
~ start
Nathan: Here are some options.
- Simple
- Nested
	Nathan: Nested dialogue.
- Jump => start
- Condition [if 25 > 10]
Nathan: Line after.")

	assert(output.errors.is_empty(), "Should be no errors.")

	var responses = output.lines.values().filter(func(line): return line.type == DMConstants.TYPE_RESPONSE)

	assert(responses.size() == 4, "Should have 4 responses.")
	assert(responses[0].text == "Simple", "Should match text")
	assert(responses[1].text == "Nested", "Should match text")
	assert(responses[2].text == "Jump", "Should match text")
	assert(responses[2].next_id == "2", "Should jump to start")
	assert(responses[3].text == "Condition", "Should match text")
	assert(responses[3].condition_as_text == "25 > 10", "Should give the original condition text")
	assert("expression" in responses[3].condition, "Should match text")

	output = compile("
~ start
Nathan: All of these responses should count.
- First
- Second

- Third
	Nathan: Nested

- Fourth

=> END")

	assert(output.errors.is_empty(), "Should be no errors.")
	assert(output.lines["3"].responses.size() == 4, "Should have four responses in group.")
	assert(output.lines["3"].next_id == "11", "Should point to END after.")

	output = compile("
~ start
Nathan: Responses.
- First
	# Comment on first line
	Nathan: You picked the first one.
- Second
=> END")

	assert(output.errors.is_empty(), "Should be no errors.")
	assert(output.lines["3"].next_id == "4", "Should point to next line.")
	assert(output.lines["4"].next_id == "5", "Should point to next line.")
	assert(output.lines["5"].next_id == "7", "Should point to next line.")


func test_can_parse_responses_with_static_ids() -> void:
	var output = compile("
~ start
Nathan: Here are some responses. [ID:HERE]
- First [ID:FIRST]
- Second [if true] [ID:SECOND]
- Third [if false] [ID:THIRD] => start
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")


func test_can_have_responses_without_dialogue() -> void:
	var output = compile("
Nathan: Hello.
do StateForTests.noop()
- First
- Second
- Third")

	assert(output.errors.size() == 0, "Should have no errors.")
	assert(output.lines["2"].next_id == "3", "Mutation should point to first response.")

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
	assert(line.type == DMConstants.TYPE_RESPONSE, "Should point to the response")
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

	var line = await resource.get_next_dialogue_line("start")
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

	resource = create_resource("
~ start
Nathan: Responses.
- First
	# Comment on first line
	Nathan: You picked the first one.
- Second
=> END")

	line = await resource.get_next_dialogue_line("start")
	line = await resource.get_next_dialogue_line(line.responses[0].next_id)
	assert(line.text == "You picked the first one.", "Should go to the first nested line.")
