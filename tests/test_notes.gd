extends AbstractTest


func test_has_notes() -> void:
	var output: DMCompilerResult = compile("
~ start
## Dialogue comment
Nathan: Some Dialogue
## Multi
## Line
## Comment
Nathan: More dialogue
## Response comment
- Response 1
## Another response
## comment
- Response 2
=> END")

	assert(output.lines["3"].notes == "Dialogue comment", "Comment should match.")
	assert(output.lines["7"].notes == "Multi\nLine\nComment", "Comment should have 3 lines.")
	assert(output.lines["9"].notes == "Response comment", "Response should have comment.")
	assert(output.lines["12"].notes == "Another response\ncomment", "Response comment should have 2 lines.")
