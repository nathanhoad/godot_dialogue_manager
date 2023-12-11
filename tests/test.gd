class_name AbstractTest extends Node


func before_all() -> void:
	pass


func before_each() -> void:
	pass


func after_all() -> void:
	pass


func after_each() -> void:
	pass


func parse(text: String) -> DialogueManagerParseResult:
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	parser.parse(text, "")
	var data: DialogueManagerParseResult = parser.get_data()
	parser.free()

	return data


func create_resource(text: String) -> DialogueResource:
	return DialogueManager.create_resource_from_text(text)
