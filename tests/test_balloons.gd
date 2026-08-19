extends AbstractTest


func test_set_default_balloon() -> void:
	var result: Error = DialogueManager.set_default_balloon("not a scene")
	assert(result == ERR_INVALID_DATA, "Should not work for bogus scenes.")

	result = DialogueManager.set_default_balloon("res://addons/dialogue_manager/example_balloon/example_balloon.tscn")
	assert(result == OK, "Should work for path.")

	result = DialogueManager.set_default_balloon(load("res://addons/dialogue_manager/example_balloon/example_balloon.tscn"))
	assert(result == OK, "Should work for scene.")
