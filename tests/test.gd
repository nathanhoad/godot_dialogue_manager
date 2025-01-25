class_name AbstractTest extends Node


func _before_all() -> void:
	pass


func _before_each() -> void:
	pass


func _after_all() -> void:
	pass


func _after_each() -> void:
	pass


func compile(text: String) -> DMCompilerResult:
	return DMCompiler.compile_string(text, "")


func create_resource(text: String) -> DialogueResource:
	return DialogueManager.create_resource_from_text(text)
