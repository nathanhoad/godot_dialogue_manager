extends AbstractTest


func _extract(text: String) -> DMResolvedLineData:
	return DMResolvedLineData.new(text)


func _resolve(text: String) -> DMResolvedLineData:
	return await DialogueManager.get_resolved_line_data(compile(text).lines["0"])


func test_ignores_rich_text_bbcode() -> void:
	var data = _extract("This is [wait=1]some [color=blue]blue[/color] text.")

	assert(data.text == "This is some [color=blue]blue[/color] text.", "It should only contain BBCode.")


func test_can_handle_wait_tags() -> void:
	var data = _extract("Nathan: [wave]Hey![/wave] [wait=1.2]WAIT!")

	assert(data.pauses.size() == 1, "Should have 1 pause.")
	assert(data.pauses[13] == 1.2, "Should be at position 13 for 1.2s.")


func test_can_handle_speed_tags() -> void:
	var data = _extract("Nathan: [wave]Hey![/wave] [speed=0.1]WAIT!")

	assert(data.speeds.size() == 1, "Should have 1 speed change.")
	assert(data.speeds[13] == 0.1, "Should be at position 13 for a speed of 0.1.")


func test_can_handle_inline_mutations() -> void:
	var data = _extract("Nathan: [wave]Hey![/wave] [do something()]DO SOMETHING!")

	assert(data.mutations.size() == 1, "Should have 1 mutation.")

	var mutation = data.mutations[0]

	assert(mutation[0] == 13, "Should be at position 13.")
	assert("expression" in mutation[1], "Should have an expression.")

	data = _extract("Nathan: [wave]Hey![/wave] [do something()][do and_this_too()]DO SOMETHING!")

	assert(data.mutations.size() == 2, "Should have 2 mutations")

	var mutation_1 = data.mutations[0]
	var mutation_2 = data.mutations[1]

	assert(mutation_1[0] == 13, "Should be at position 13.")
	assert("expression" in mutation_1[1], "Should have an expression.")
	assert(mutation_2[0] == 13, "Should be at position 13.")
	assert("expression" in mutation_2[1], "Should have an expression.")


func test_mutations_can_have_errors() -> void:
	var data = _extract("Nathan: [wave]Hey![/wave] [do incomplete(]This is an error?")

	assert("error" in data.mutations[0][1], "Should have an error.")
	assert(data.mutations[0][1].error == DMConstants.ERR_UNEXPECTED_END_OF_EXPRESSION, "Should have an error.")


func test_can_resolve_inline_conditions() -> void:
	var data = await _resolve("Nathan: [if false]I won't say this[/if][if true]I will say this[/if].")
	assert(data.text == "I will say this.", "Should resolve condition.")

	data = await _resolve("Nathan: What I'm saying is [if true]true[else]false[/if].")
	assert(data.text == "What I'm saying is true.", "Should resolve condition with else in it.")


func test_can_handle_escaped_brackets() -> void:
	var data = await _resolve("Nathan: This[wait=1] is a \\[[color=lime]special[/color]\\] thing")
	assert(data.text == "This is a [[color=lime]special[/color]] thing")
