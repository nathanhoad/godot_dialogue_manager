extends AbstractTest


func test_can_parse_titles() -> void:
	var output = compile("~ some_title\nNathan: Hello.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.titles.size() == 1, "Should have one title.")
	assert(output.titles.has("some_title"), "Should have known title.")
	assert(output.titles["some_title"] == "1", "Should point to the next line.")

	output = compile("
~ start
if StateForTests.some_property
	Nathan: Some unrelated but indented line.
	=> title_directly_after_dedent
~ title_directly_after_dedent")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.titles.size() == 2, "Should have two titles.")
	assert(output.titles.keys()[1] == "title_directly_after_dedent", "Should have second title.")

	output = compile("
~ start
if true
	~ indented_title
	Nathan: Some unrelated but indented line.
Nathan: After.
=> indented_title")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.titles.size() == 2, "Should have two titles.")
	assert(output.titles["indented_title"] == "4", "Should have second title.")

	output = compile("~ t")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert("t" in output.titles.keys(), "Should include title.")


func test_can_parse_basic_dialogue() -> void:
	var output = compile("Nathan: This is dialogue with a name.\nThis is dialogue without a name")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines.values()[0].character == "Nathan", "First line should have a character.")
	assert(not output.lines.values()[1].has("character"), "Second line should not have a character.")


func test_can_parse_dialogue_with_static_ids() -> void:
	var output = compile("
~ start
Nathan: Hello [ID:HELLO]
Nathan: Something[if true] conditional[/if] [ID:SOMETHING]
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["2"].translation_key == "HELLO", "Should have correct translation key.")
	assert(output.lines["3"].translation_key == "SOMETHING", "Should have correct translation key.")


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
	var output = compile("
~ start
Nathan: This is the first line.
	This is the second line.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["2"].text == "This is the first line.\nThis is the second line.", "Should concatenate the lines.")

	output = compile("
~ start
Nathan: This is the first line.

	This is the third line with a gap line above it.")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["2"].text == "This is the first line.\n\nThis is the third line with a gap line above it.", "Should concatenate the lines.")

	output = compile("
~ start
Nathan: This is the first line.
	This is the second line.
	do something()")

	assert(output.errors.size() == 1, "Should have 1 error.")
	assert(output.errors[0].line_number == 5, "Error on line 5.")
	assert(output.errors[0].error == DMConstants.ERR_INVALID_INDENTATION, "Error on line 5.")

	output = compile("
~ start
Nathan: First line [ID:FIRST]
	Second line
	Third line")

	assert(output.errors.size() == 0, "Should have no errors.")
	assert(output.lines["2"].text == "First line\nSecond line\nThird line", "Should concatenate text.")


func test_can_parse_variables() -> void:
	var output = compile("{{character_name}}: Hi! I'm {{character_name}}.")

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

	StateForTests.character_name = "Coco"

	var line = await resource.get_next_dialogue_line("start")
	assert(line.character == "Coco", "Character should be Coco.")
	assert(line.text == "Hi! I'm Coco.", "Character should be Coco.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Your name is changed?", "Name should have changed.")


func test_can_parse_tags() -> void:
	var output = compile("Nathan: This is some dialogue [#tag1, #tag2]")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["0"].tags.size() == 2, "Should have 2 tags")
	assert(output.lines["0"].tags[0] == "tag1", "Should have tag1 tag.")
	assert(output.lines["0"].tags[1] == "tag2", "Should have tag2 tag.")


func test_can_parse_random_lines() -> void:
	var output = compile("
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
	assert(output.lines["1"].siblings.size() == 3, "Should have 3 random siblings.")
	assert(output.lines["1"].siblings[0].weight == 1, "Undefined weight should be 1.")
	assert(output.lines["1"].siblings[1].weight == 2, "Weight of 2 should be 2.")

	assert(output.lines["5"].siblings.size() == 3, "Should have 3 random siblings.")
	assert(output.lines["5"].siblings[0].weight == 1, "Undefined weight should be 1.")
	assert(output.lines["5"].siblings[2].weight == 3, "Weight of 3 should be 3.")

	output = compile("
~ start
% First
%
	Second (block)
	Second of Second
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["1"].next_id == "2", "Title should point to first random line.")
	assert(output.lines["2"].type == DMConstants.TYPE_DIALOGUE, "Should be a dialogue line.")
	assert(output.lines["2"].siblings.size() == 2, "Should have two siblings")


func test_can_parse_random_conditional_lines() -> void:
	var output = compile("
% Nathan: Random 1.
%2 [if false] Nathan: Random 2.
% Nathan: Random 3.

% [if false] => jump_1
% [if true] => jump_2
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
	assert(output.lines["2"].siblings[1].condition.expression[0].value == "false", "Should parse expression.")

	assert(output.lines["5"].siblings.size() == 3, "Should have 3 random siblings.")
	assert(output.lines["5"].siblings[0].weight == 1, "Undefined weight should be 1.")
	assert(output.lines["5"].siblings[1].condition.expression[0].value == "true", "Should parse expression.")
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


func test_can_resolve_static_line_id() -> void:
	var resource = create_resource("
~ start
Nathan: First line [ID:FIRST]
Nathan: Second line [ID:SECOND]
Nathan: Third line [ID:THIRD]")

	var id = DialogueManager.static_id_to_line_id(resource, "SECOND")
	var line = await resource.get_next_dialogue_line(id)
	assert(line.text == "Second line", "Should match second line")
