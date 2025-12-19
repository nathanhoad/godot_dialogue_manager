extends AbstractTest


var label: DialogueLabel


func _make_line(text: String) -> DialogueLine:
	return DialogueLine.new({
		id = "0",
		next_id = "1",
		type = DMConstants.TYPE_DIALOGUE,
		character = "Nathan",
		text = text
	})


func _before_each() -> void:
	label = load("res://addons/dialogue_manager/dialogue_label.tscn").instantiate()
	Engine.get_main_loop().current_scene.add_child(label)


func _after_each() -> void:
	label.queue_free()


func test_type_out() -> void:
	label.dialogue_line = _make_line("Hello Dr. Coconut. How are you?")

	await label.type_out()

	assert(label.get_parsed_text() == "Hello Dr. Coconut. How are you?", "Text should be Hello.")
	assert(label.visible_characters == 0, "Cursor should be at the start.")

	await label.finished_typing

	assert(label.visible_characters == label.get_parsed_text().length(), "Should be finished typing.")


func test_inline_mutations() -> void:
	var data: Dictionary = {
		counter = 0
	}

	var resource: DialogueResource = create_resource("
~ start
Nathan: This line has[set counter += 1][set counter += 10] two mutations.
=> END")

	var dialogue_line: DialogueLine = await resource.get_next_dialogue_line("start", [data])
	label.dialogue_line = dialogue_line

	assert(data.counter == 0, "Counter should initially be zero.")

	label.type_out()
	await label.finished_typing

	assert(data.counter == 11, "Both mutations should have run.")
