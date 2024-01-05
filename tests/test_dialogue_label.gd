extends AbstractTest


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


var label: DialogueLabel


func _make_line(text: String) -> DialogueLine:
	return DialogueLine.new({
		id = "0",
		next_id = "1",
		type = DialogueConstants.TYPE_DIALOGUE,
		character = "Nathan",
		text = text
	})


func before_each() -> void:
	label = load("res://addons/dialogue_manager/dialogue_label.tscn").instantiate()
	Engine.get_main_loop().current_scene.add_child(label)


func after_each() -> void:
	label.queue_free()


func test_type_out() -> void:
	label.dialogue_line = _make_line("Hello Dr. Coconut. How are you?")

	await label.type_out()

	assert(label.get_parsed_text() == "Hello Dr. Coconut. How are you?", "Text should be Hello.")
	assert(label.visible_characters == 0, "Cursor should be at the start.")

	await label.finished_typing

	assert(label.visible_characters == label.get_parsed_text().length(), "Should be finished typing.")
