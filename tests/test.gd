class_name AbstractTest extends Node


func parse(text: String) -> DialogueManagerParseResult:
	return DialogueManagerParser.parse_string(text, "")


func create_resource(text: String) -> DialogueResource:
	return DialogueManager.create_resource_from_text(text)
