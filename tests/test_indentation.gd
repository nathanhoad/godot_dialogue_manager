extends AbstractTest


func test_indent_with_spaces() -> void:
	var result: DMCompilerResult = compile("
~ start
if true
    Nathan: Indented with 4 spaces.
=> END")

	assert(result.errors.is_empty(), "Should have no errors.")

	result = compile("
~ start
if true
  Nathan: Indented with 2 spaces.
=> END")

	assert(result.errors.is_empty(), "Should have no errors.")


func test_mixed_indentation() -> void:
	var result: DMCompilerResult = compile("
~ start
if true
	Nathan: Indented with a tab.
else
    Nathan: Now with 4 spaces.
=> END")

	assert(result.errors.size() == 0, "Should have no errors.")
