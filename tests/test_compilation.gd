extends AbstractTest


var compilation: DMCompilation


func _before_each() -> void:
	compilation = DMCompilation.new()


func test_get_line_type() -> void:
	assert(compilation.get_line_type("~ some_title") == DMConstants.TYPE_TITLE, "Title should be title.")

	assert(compilation.get_line_type("=> title") == DMConstants.TYPE_GOTO, "Goto should be goto.")
	assert(compilation.get_line_type("=>< title") == DMConstants.TYPE_GOTO, "Goto should be goto.")

	assert(compilation.get_line_type("if condition") == DMConstants.TYPE_CONDITION, "If should be condition.")
	assert(compilation.get_line_type("elif condition") == DMConstants.TYPE_CONDITION, "Elif should be condition.")
	assert(compilation.get_line_type("else if condition") == DMConstants.TYPE_CONDITION, "Else if should be condition.")
	assert(compilation.get_line_type("else") == DMConstants.TYPE_CONDITION, "Else should be condition.")

	assert(compilation.get_line_type("while condition") == DMConstants.TYPE_WHILE, "While should be while.")

	assert(compilation.get_line_type("match condition") == DMConstants.TYPE_MATCH, "Match should be match.")
	assert(compilation.get_line_type("when condition") == DMConstants.TYPE_WHEN, "When should be when.")

	assert(compilation.get_line_type("do mutation()") == DMConstants.TYPE_MUTATION, "Do should be mutation.")
	assert(compilation.get_line_type("set variable = value") == DMConstants.TYPE_MUTATION, "Set should be mutation.")

	assert(compilation.get_line_type("- prompt") == DMConstants.TYPE_RESPONSE, "Response should be response.")
	assert(compilation.get_line_type("- prompt [if condition /]") == DMConstants.TYPE_RESPONSE, "Response should be response.")
	assert(compilation.get_line_type("- prompt [if condition /] => title") == DMConstants.TYPE_RESPONSE, "Response should be response.")
	assert(compilation.get_line_type("- prompt => title") == DMConstants.TYPE_RESPONSE, "Response should be response.")

	assert(compilation.get_line_type("%") == DMConstants.TYPE_RANDOM, "Random block should be random.")
	assert(compilation.get_line_type("%3") == DMConstants.TYPE_RANDOM, "Random block should be random.")
	assert(compilation.get_line_type("% [if false /]") == DMConstants.TYPE_RANDOM, "Random block should be random.")

	assert(compilation.get_line_type("Dialogue") == DMConstants.TYPE_DIALOGUE, "Dialogue should be dialogue.")
	assert(compilation.get_line_type("Character: Dialogue") == DMConstants.TYPE_DIALOGUE, "Dialogue should be dialogue.")
	assert(compilation.get_line_type("Character: Dialogue => title") == DMConstants.TYPE_DIALOGUE, "Dialogue should be dialogue.")
	assert(compilation.get_line_type("% Character: Dialogue") == DMConstants.TYPE_DIALOGUE, "Dialogue should be dialogue.")
	assert(compilation.get_line_type("%4 Character: Dialogue") == DMConstants.TYPE_DIALOGUE, "Dialogue should be dialogue.")

	assert(compilation.get_line_type("") == DMConstants.TYPE_UNKNOWN, "Empty should be unknown.")
	assert(compilation.get_line_type(" ") == DMConstants.TYPE_UNKNOWN, "Empty should be unknown.")


func test_can_use_processor() -> void:
	compilation.processor = TestProcessor.new()

	compilation.compile("
~ start
Nathan: {macro}.
Nathan: Or is it Coco?
=> END")

	assert(compilation.lines["2"].text == "SOMETHING.", "Should replace macro.")
	assert(compilation.lines["2"].character == "Coco", "Should replace character.")
	assert(compilation.lines["3"].character == "Coco", "Should replace character.")


class TestProcessor extends DMDialogueProcessor:
	func _preprocess_line(raw_line: String) -> String:
		return raw_line.replace("{macro}", "SOMETHING")

	func _process_line(line: DMCompiledLine) -> void:
		line.character = "Coco"
