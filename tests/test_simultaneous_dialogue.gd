extends AbstractTest


func test_can_parse_simultaneous_dialogue() -> void:
	var output = compile("
~ start
Nathan: I'm saying this.
| Coco: While I'm saying this.
| Lilly: And I'm saying this simultaneously too.
Nathan: Then I say this.
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["2"].text == "I'm saying this.", "Should have the correct text.")
	assert(output.lines["2"].next_id == "5", "Should point to the next line after the concurrent lines.")
	assert(output.lines["2"].has("concurrent_lines"), "Should have concurrent lines.")
	assert(output.lines[output.lines["2"].concurrent_lines[0]].text == "While I'm saying this.", "Should be the correct line.")
	assert(output.lines[output.lines["2"].concurrent_lines[1]].text == "And I'm saying this simultaneously too.", "Should be the correct line.")
	assert(not output.lines["5"].has("concurrent_lines"))

	output = compile("
~ start
| Nathan: This line has no origin!
=> END")

	assert(output.errors[0].error == DMConstants.ERR_CONCURRENT_LINE_WITHOUT_ORIGIN, "Should have concurrent line error.")

	output = compile("
~ start
Nathan: First I'll say this.
if true
	Nathan: Then I'm saying this.
	| Coco: While I'm saying this.
	| Lilly: And I'm saying this simultaneously too.
Nathan: Lastly, I say this.
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["4"].next_id == "7", "Concurrent origin line should point to line after concurrency.")


func test_can_run_simultaneous_dialogue() -> void:
	var resource = create_resource("
~ start
Nathan: I'm saying this.
| Coco: While I'm saying this.
| Lilly: And I'm saying this simultaneously too.
Nathan: Then I say this.
=> END")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "I'm saying this.", "Should have the correct text.")
	assert(line.concurrent_lines.size() == 2, "Should have two concurrent lines.")
	assert(line.concurrent_lines[0].text == "While I'm saying this.", "Should have concurrent line.")
	assert(line.concurrent_lines[1].text == "And I'm saying this simultaneously too.", "Should have concurrent line.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Then I say this.", "Should have correct text.")
	assert(line.concurrent_lines.size() == 0, "Should have no concurrent lines.")
