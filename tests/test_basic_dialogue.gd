extends AbstractTest


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


func test_can_parse_titles() -> void:
	var output = parse("~ some_title\nNathan: Hello.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.titles.size() == 1, "Should have one title.")
	assert(output.titles.has("some_title"), "Should have known title.")
	assert(output.titles["some_title"] == "2", "Should point to the next line.")

	output = parse(" ~ indented_title\nNathan: Oh no!")

	assert(output.errors.size() > 0, "Should have an error.")
	assert(output.errors[0].line_number == 0, "Should be an indentation error.")
	assert(output.errors[0].error == DialogueConstants.ERR_NESTED_TITLE, "Should be an indentation error.")


func test_can_parse_basic_dialogue() -> void:
	var output = parse("Nathan: This is dialogue with a name.\nThis is dialogue without a name")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines.size() == 2, "Should have 2 lines.")
	assert(output.lines.values()[0].character == "Nathan", "First line should have a character.")
	assert(output.lines.values()[1].character == "", "Second line should not have a character.")


func test_can_run_basic_dialogue() -> void:
	var resource = create_resource("
~ start
Nathan: This is dialogue with a name.
Coco: Meow.
This is dialogue without a name.")

	var line = await resource.get_next_dialogue_line("start")

	assert(line.character == "Nathan", "Nathan is talking")
	assert(line.text == "This is dialogue with a name.", "Should match dialogue.")

	line = await resource.get_next_dialogue_line(line.next_id)

	assert(line.character == "Coco", "Coco is talking")
	assert(line.text == "Meow.", "Should match dialogue.")

	line = await resource.get_next_dialogue_line(line.next_id)

	assert(line.character == "", "Nobody is talking.")
	assert(line.text == "This is dialogue without a name.", "Should match dialogue.")


func test_can_parse_multiline_dialogue() -> void:
	var output = parse("
~ start
Nathan: This is the first line.
	This is the second line.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["3"].text == "This is the first line.\nThis is the second line.", "Should concatenate the lines.")

	output = parse("
~ start
Nathan: This is the first line.
	This is the second line.
	do something()")

	assert(output.errors.size() == 1, "Should have 1 error.")
	assert(output.errors[0].line_number == 4, "Error on line 5.")
	assert(output.errors[0].error == DialogueConstants.ERR_INVALID_INDENTATION, "Error on line 5.")


func test_can_parse_jumps() -> void:
	var output = parse("
~ start
Nathan: Responses?
- Simple => start
- Snippet =>< snippet
=>< snippet
=> start
~ snippet
Nathan: Snippet.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines.size() == 9, "Should have 9 lines.")

	assert(output.lines["4"].next_id == "3", "Simple jump should point to start.")

	assert(output.lines["5"].next_id == "5.1", "Snippet response jump should point to snippet via sub line.")
	assert(output.lines["5.1"].is_snippet == true, "Snippet response jump should be a snippet.")
	assert(output.lines["5.1"].next_id == "9", "Snippet response jump should point to snippet.")

	assert(output.lines["6"].next_id == "9", "Snippet jump should point to snippet.")
	assert(output.lines["6"].is_snippet == true, "Snippet jump should be a snippet.")

	assert(output.lines["7"].next_id == "3", "Simple jump should point to start.")


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

	var jump = await resource.get_next_dialogue_line(line.responses[0].next_id)
	assert(jump.text == "Start.", "Simple jump should point back to start.")

	jump = await resource.get_next_dialogue_line(line.responses[1].next_id)
	assert(jump.text == "Snippet.", "Snippet jump should point to snippet.")
	jump = await resource.get_next_dialogue_line(jump.next_id)
	assert(jump.text == "After 1.", "Snippet jump should return to where it jumped from.")

	jump = await resource.get_next_dialogue_line(jump.next_id)
	assert(jump.text == "Snippet.", "Snippet jump should point to snippet.")
	jump = await resource.get_next_dialogue_line(jump.next_id)
	assert(jump.text == "After 2.", "Snippet jump should return to where it jumped from.")

	jump = await resource.get_next_dialogue_line(jump.next_id)
	assert(jump.text == "Start.", "Simple jump should point to start.")


func test_can_parse_variables() -> void:
	var output = parse("{{character_name}}: Hi! I'm {{character_name}}.")

	assert(output.errors.is_empty(), "Should have no errors.")

	var line = output.lines.values()[0]

	assert(line.character_replacements.size() == 1, "Should be 1 character name replacement.")
	assert("character_name" in line.character_replacements[0].value_in_text, "Should replace \"character_name\"")
	assert("expression" in line.character_replacements[0], "Should have an expression.")


func test_can_resolve_variables() -> void:
	var resource = create_resource("
~ start
{{StateForTests.character_name}}: Hi! I'm {{StateForTests.character_name}}.
do StateForTests.character_name = \"changed\"
Nathan: Your name is {{StateForTests.character_name}}?")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.character == "Coco", "Character should be Coco.")
	assert(line.text == "Hi! I'm Coco.", "Character should be Coco.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Your name is changed?", "Name should have changed.")


func test_can_parse_tags() -> void:
	var output = parse("Nathan: This is some dialogue [#tag1, #tag2]")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["1"].tags.size() == 2, "Should have 2 tags")
	assert(output.lines["1"].tags[0] == "tag1", "Should have tag1 tag.")
	assert(output.lines["1"].tags[1] == "tag2", "Should have tag2 tag.")


func test_can_parse_random_lines() -> void:
	var output = parse("
% Nathan: Random 1.
%2 Nathan: Random 2.
% Nathan: Random 3.
% => jump_1
% => jump_2
%3 => jump_3
~ jump_1
Nathan: Jump 1.
~ jump_2
Nathan: Jump 2.
~ jump_3
Nathan: Jump 3.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["2"].siblings.size() == 3, "Should have 3 random siblings.")
	assert(output.lines["2"].siblings[0].weight == 1, "Undefined weight should be 1.")
	assert(output.lines["2"].siblings[1].weight == 2, "Weight of 2 should be 2.")

	assert(output.lines["5"].siblings.size() == 3, "Should have 3 random siblings.")
	assert(output.lines["5"].siblings[0].weight == 1, "Undefined weight should be 1.")
	assert(output.lines["5"].siblings[2].weight == 3, "Weight of 3 should be 3.")


class TestClass:
	var string: String = ""
	var number: int = -1

	func set_values(s: String, i: int = 0):
		string = s
		number = i


func test_can_run_methods() -> void:
	var resource = create_resource("
~ start
do set_values(\"foo\")
Nathan: Without optional arguments.
do set_values(\"bar\", 1)
Nathan: With optional arguments.
")

	var test = TestClass.new()

	var line = await resource.get_next_dialogue_line("start", [test])
	assert(test.string == "foo", "Method call should set required argument")
	assert(test.number == 0, "Method call should set optional argument to default value")

	line = await resource.get_next_dialogue_line(line.next_id, [test])
	assert(test.string == "bar", "Method call should set required argument")
	assert(test.number == 1, "Method call should set optional argument")


func test_can_have_subsequent_titles() -> void:
	var resource = create_resource("
~ start
~ another_title
~ third_title
Nathan: Hello.")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Hello.", "Should jump to dialogue.")
