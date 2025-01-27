extends AbstractTest


func test_can_parse_jumps() -> void:
	var output = compile("
~ start
Nathan: Responses?
- Simple => start
- Snippet =>< snippet
=>< snippet
=> start
~ snippet
Nathan: Snippet.")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["3"].next_id == "2", "Simple jump should point to start.")

	assert(output.lines["4"].next_id == "4.1", "Snippet response jump should point to snippet via sub line.")
	assert(output.lines["4.1"].is_snippet == true, "Snippet response jump should be a snippet.")
	assert(output.lines["4.1"].next_id == "8", "Snippet response jump should point to snippet.")

	assert(output.lines["5"].next_id == "8", "Snippet jump should point to snippet.")
	assert(output.lines["5"].is_snippet == true, "Snippet jump should be a snippet.")

	assert(output.lines["6"].next_id == "2", "Simple jump should point to start.")

	output = compile("
~ start
Nathan: Responses?
- Restart => {{\"sta\" + \"rt\"}}
- Continue
Nathan: After
=> {{\"st\" + \"art\"}}
")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["3"].next_id_expression.size() > 0, "Jump should be expression.")
	assert(output.lines["6"].next_id_expression.size() > 0, "Jump should be expression.")


func test_can_run_jumps() -> void:
	var resource = create_resource("
~ start
Nathan: Start.
- Simple => start
- Snippet =>< snippet
Nathan: After 1.
=>< snippet
Nathan: After 2.
=> start
~ snippet
Nathan: Snippet.")

	var line = await resource.get_next_dialogue_line("start")

	line = await resource.get_next_dialogue_line(line.responses[0].next_id)
	assert(line.text == "Start.", "Simple jump should point back to start.")

	line = await resource.get_next_dialogue_line(line.responses[1].next_id)
	assert(line.text == "Snippet.", "Snippet jump should point to snippet.")
	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After 1.", "Snippet jump should return to where it jumped from.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Snippet.", "Snippet jump should point to snippet.")
	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After 2.", "Snippet jump should return to where it jumped from.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Start.", "Simple jump should point to start.")

	resource = create_resource("
~ start
Nathan: Responses?
- Restart => {{\"sta\" + \"rt\"}}
- Continue
Nathan: After
=> {{\"st\" + \"art\"}}
")

	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Responses?", "First line should be responses.")
	line = await resource.get_next_dialogue_line(line.responses[0].next_id)
	assert(line.text == "Responses?", "Should be back at responses.")
	line = await resource.get_next_dialogue_line(line.responses[1].next_id)
	assert(line.text == "After", "Should be after responses.")
	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Responses?", "Should be back at responses.")


func test_can_parse_expression_jumps() -> void:
	var output = compile("
~ start
Nathan: Restart?
=> {{StateForTests.jump_target}}")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["3"].has("next_id_expression"), "Jump should have expression.")
	assert(output.lines["3"].next_id_expression.size() > 0, "Jump should have expression.")

	output = compile("
~ start
Nathan: Restart?
=> {{error + }}")

	assert(output.errors.size() > 0, "Should have errors.")
	assert(output.errors[0].error == DMConstants.ERR_UNEXPECTED_END_OF_EXPRESSION, "Error should be bad expression.")


func test_can_run_expression_jumps() -> void:
	var resource = create_resource("
~ start
Nathan: Start.
Nathan: Restart?
=> {{StateForTests.jump_target}}")

	StateForTests.jump_target = "start"

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Start.", "Line should be first line.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Restart?", "Line should be second line.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Start.", "Line should be back to first line.")
