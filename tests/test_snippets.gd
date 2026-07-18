extends AbstractTest


func test_can_run_snippets() -> void:
	var resource: DialogueResource = load("res://tests/main.dialogue")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "Testing a snippet.", "Text should match.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "This is a snippet.", "Text should be from the snippets file.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "...and back again.")


func test_can_return_from_snippet_to_response() -> void:
	# When a snippet's final line ends and we jump back to a line that only has responses, those
	# responses are attached to the snippet's final line. Choosing one should continue past the response
	# rather than looping back.
	var resource: DialogueResource = create_resource("
~ start
Nathan: Before snippet.
=>< snippet
- First
	Nathan: You picked first.
- Second
	Nathan: You picked second.
After responses.
=> END

~ snippet
Nathan: Inside snippet.
=> END")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before snippet.", "Should start before the snippet.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Inside snippet.", "Should show the snippet's final line.")
	assert(line.responses.size() == 2, "Returned to responses should be attached.")

	line = await resource.get_next_dialogue_line(line.responses[0].next_id)


func test_can_return_from_nested_snippet_to_responses() -> void:
	# Like the above but nested: an inner snippet returns to an outer snippet that
	# only has responses, which in turn must return to the outermost caller. The
	# deeper return address must survive being grafted onto the inner snippet's line.
	var resource: DialogueResource = create_resource("
~ start
Nathan: Start.
=>< outer
Nathan: After everything.
=> END

~ outer
=>< inner
- Outer first
	Nathan: Outer picked first.
- Outer second
=> END

~ inner
Nathan: Inside inner.
=> END")

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "Start.", "Should start at the beginning.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Inside inner.", "Should show the inner snippet's final line.")
	assert(line.responses.size() == 2, "Outer responses should be grafted onto the inner snippet line.")

	line = await resource.get_next_dialogue_line(line.responses[0].next_id)
	assert(line.text == "Outer picked first.", "Choosing a response should follow it.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After everything.", "Should still return to the outermost caller.")
