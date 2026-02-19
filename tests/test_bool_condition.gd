extends AbstractTest


func test_can_evaluate_empty_string_condition_as_falsy() -> void:
	var resource: DialogueResource = create_resource("
~ start
if empty_flag
	Nathan: FAIL.
else
	Nathan: PASS.
=> END")

	var line: DialogueLine = await resource.get_next_dialogue_line("start", [{ empty_flag = "" }])
	assert(line.text == "PASS.", "Empty string condition should be falsy.")


func test_can_evaluate_nonempty_string_condition_as_truthy() -> void:
	var resource: DialogueResource = create_resource("
~ start
if nonempty_flag
	Nathan: PASS.
else
	Nathan: FAIL.
=> END")

	var line: DialogueLine = await resource.get_next_dialogue_line("start", [{ nonempty_flag = "hello" }])
	assert(line.text == "PASS.", "Non-empty string condition should be truthy.")


func test_can_evaluate_color_condition() -> void:
	var resource: DialogueResource = create_resource("
~ start
if color_val
	Nathan: Truthy.
else
	Nathan: Falsy.
=> END")

	# In Godot 4, Variant::booleanize() returns true for all value types not
	# explicitly listed (NIL/BOOL/INT/FLOAT/STRING/OBJECT), so Color is always
	# truthy regardless of its component values.
	var line: DialogueLine = await resource.get_next_dialogue_line("start", [{ color_val = Color.RED }])
	assert(line.text == "Truthy.", "Color should be truthy and not crash.")

	line = await resource.get_next_dialogue_line("start", [{ color_val = Color(0.0, 0.0, 0.0, 0.0) }])
	assert(line.text == "Truthy.", "Zero Color is still truthy (value type, no falsy zero in GDScript).")


func test_can_evaluate_vector2_condition() -> void:
	var resource: DialogueResource = create_resource("
~ start
if vec_val
	Nathan: Truthy.
else
	Nathan: Falsy.
=> END")

	# Unlike Color, Godot 4's Variant::booleanize() has an explicit case for Vector2:
	# zero vector is falsy, non-zero is truthy.
	var line: DialogueLine = await resource.get_next_dialogue_line("start", [{ vec_val = Vector2.UP }])
	assert(line.text == "Truthy.", "Non-zero Vector2 should be truthy and not crash.")

	line = await resource.get_next_dialogue_line("start", [{ vec_val = Vector2.ZERO }])
	assert(line.text == "Falsy.", "Zero Vector2 should be falsy.")
