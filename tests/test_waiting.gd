extends AbstractTest


var waiting_count: int = 0
var waited_count: int = 0
var lines: Array[DialogueLine] = []


func _before_each() -> void:
	waiting_count = 0
	waited_count = 0
	lines.clear()
	DialogueManager.waiting_for_input.connect(_on_waiting_for_input)
	DialogueManager.waited_for_input.connect(_on_waited_for_input)


func _after_each() -> void:
	DialogueManager.waiting_for_input.disconnect(_on_waiting_for_input)
	DialogueManager.waited_for_input.disconnect(_on_waited_for_input)


func _on_waiting_for_input() -> void:
	waiting_count += 1


func _on_waited_for_input() -> void:
	waited_count += 1


func _get_line(resource: DialogueResource) -> void:
	lines.append(await resource.get_next_dialogue_line("start"))


func _wait_frames(count: int) -> void:
	for i: int in range(count):
		await Engine.get_main_loop().process_frame


func test_emits_waited_for_input_after_action() -> void:
	var resource: DialogueResource = create_resource("
~ start
do wait(\"ui_accept\")
Nathan: After waiting.
=> END")

	_get_line(resource)
	await _wait_frames(2)

	assert(waiting_count == 1, "Should be waiting for input.")
	assert(waited_count == 0, "Should not have waited yet.")
	assert(lines.size() == 0, "Should not have a line yet.")

	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await _wait_frames(3)

	assert(waited_count == 1, "Should have emitted waited_for_input.")
	assert(lines.size() == 1 and lines[0].text == "After waiting.", "Should continue to the next line.")
	assert(DMWaiter.all_waiters.size() == 0, "Should have no waiters left.")


func test_clearing_waiters_does_not_emit_waited_for_input() -> void:
	var resource: DialogueResource = create_resource("
~ start
do wait(\"ui_accept\")
Nathan: After waiting.
=> END")

	_get_line(resource)
	_get_line(resource)
	await _wait_frames(2)

	assert(waiting_count == 2, "Should have two things waiting for input.")
	assert(DMWaiter.all_waiters.size() == 2, "Should have two waiters.")

	DMWaiter.clear_all()
	await _wait_frames(3)

	assert(waited_count == 0, "Should not emit waited_for_input when cleared.")
	assert(DMWaiter.all_waiters.size() == 0, "Should have cleared every waiter.")
	assert(lines.size() == 2, "Should continue both dialogues.")
