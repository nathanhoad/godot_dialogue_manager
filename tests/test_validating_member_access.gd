extends AbstractTest


func test_can_deny_member() -> void:
	var resource: DialogueResource = create_resource("
~ start
Nathan: The value is {{StateForTests.some_property}}!
Nathan: The other value is {{StateForTests.character_name}}.
=> END")

	DialogueManager.ignore_missing_state_values = true

	StateForTests.some_property = 27
	StateForTests.character_name = "Coco"

	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert(line.text == "The value is 27!", "Access is allowed.")

	DialogueManager.validate_member_access = func(_thing: Variant, member: StringName, _member_kind: StringName) -> String:
		if member == "some_property":
			return "Denied!"
		else:
			return ""

	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "The value is <null>!", "Access is denied.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "The other value is Coco.", "Other member access is still allowed.")

	DialogueManager.ignore_missing_state_values = false
	DialogueManager.validate_member_access = func(_thing: Variant, _member: StringName, _member_kind: StringName) -> String:
		return ""
