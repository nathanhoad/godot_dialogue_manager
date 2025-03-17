extends AbstractTest


var dialogue_label: DialogueLabel = DialogueLabel.new()


func _before_all() -> void:
	Engine.get_main_loop().current_scene.add_child(dialogue_label)


func _after_all() -> void:
	dialogue_label.queue_free()


func test_can_parse_conditions() -> void:
	var output = compile("
if StateForTests.some_property == 0:
	Nathan: It is 0.
elif StateForTests.some_property == 10:
	Nathan: It is 10.
else:
	Nathan: It is something else.
Nathan: After.")

	assert(output.errors.is_empty(), "Should have no errors.")

	# if
	var condition = output.lines["1"]
	assert(condition.type == DMConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "2", "Should point to next line.")
	assert(condition.next_sibling_id == "3", "Should reference elif.")
	assert(condition.next_id_after == "7", "Should reference after conditions.")

	# elif
	condition = output.lines["3"]
	assert(condition.type == DMConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "4", "Should point to next line.")
	assert(condition.next_sibling_id == "5", "Should reference else.")
	assert(condition.next_id_after == "7", "Should reference after conditions.")

	# else
	condition = output.lines["5"]
	assert(condition.type == DMConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "6", "Should point to next line.")
	assert(condition.has("next_sibling_id") == false, "Should not reference further conditions.")
	assert(condition.next_id_after == "7", "Should reference after conditions.")

	output = compile("
if StateForTests.some_property == 1
	Nathan: True
Nathan: After")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(output.lines["1"].type == DMConstants.TYPE_CONDITION, "Condition should be condition.")
	assert(output.lines["1"].has("next_sibling_id") == false, "Condition should have no sibling.")


func test_can_group_conditions() -> void:
	var output = compile("
~ start
if false
	Nathan: False
if true
	Nathan: True
else
	Nathan: Else
=> END")

	assert(output.errors.is_empty(), "Should have no errors.")
	assert(not output.lines["2"].has("next_sibling_id"), "Should not have a sibling.")
	assert(output.lines["4"].has("next_sibling_id"), "Should have no sibling.")
	assert(output.lines["4"].next_sibling_id == "6", "Should have else as sibling.")


func test_ignore_escaped_conditions() -> void:
	var output = compile("
\\if this is dialogue.
\\elif this too.
\\else and this one.")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["1"].type == DMConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["1"].text == "if this is dialogue.", "Should escape slash.")

	assert(output.lines["2"].type == DMConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["2"].text == "elif this too.", "Should escape slash.")

	assert(output.lines["3"].type == DMConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["3"].text == "else and this one.", "Should escape slash.")


func test_can_run_conditions() -> void:
	var resource = create_resource("
~ start
if StateForTests.some_property == 0:
	Nathan: It is 0.
elif StateForTests.some_property > 10:
	Nathan: It is more than 10.
else:
	Nathan: It is something else.")

	StateForTests.some_property = 0
	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is 0.", "Should match if condition.")

	StateForTests.some_property = 11
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is more than 10.", "Should match elif condition.")

	StateForTests.some_property = 5
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is something else.", "Should match else.")


func test_can_parse_while_loops() -> void:
	var output = compile("
Before
while true
	During 1
	During 2
After")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["2"].type == DMConstants.TYPE_WHILE, "While should be while.")
	assert(output.lines["2"].next_id == "3", "While should point to first child.")
	assert("expression" in output.lines["2"].condition, "While should have a condition.")
	assert(output.lines["4"].next_id == "2", "Last child should loop back to while.")


func test_can_run_while_loops() -> void:
	var resource = create_resource("
~ start
Before
while StateForTests.some_property < 2
	Value is {{StateForTests.some_property}}
	set StateForTests.some_property += 1
After")

	StateForTests.some_property = 0
	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before", "Should be before while loop.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Value is 0", "Value should be 0.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "Value is 1", "Value should be 1.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After", "Should be after the while loop.")


func test_can_parse_match_statements() -> void:
	var output = compile("
Before
match StateForTests.some_property
	when 1
		It was 1!
	when < 5
		It was less than 5
	else
		It was neither of those!
After")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["2"].type == DMConstants.TYPE_MATCH, "Match should be match.")
	assert(output.lines["2"].next_id_after == "9", "Should go to After next.")
	assert(output.lines["2"].cases.size() == 3, "Should have 3 cases.")
	assert("expression" in output.lines["2"].cases[0].condition, "Case should have expression.")
	assert(output.lines["2"].cases[0].next_id == "4", "Case should point to first child.")
	assert(not "expression" in output.lines["2"].cases[2], "Else case should have no condition.")
	assert(output.lines["2"].cases[2].next_id == "8", "Else case points to After.")
	assert(output.lines["4"].next_id == "9", "End of body should point to after match.")
	assert(output.lines["8"].next_id == "9", "End of body should point to after match.")


func test_can_run_match_cases() -> void:
	var resource = create_resource("
~ start
Before
match StateForTests.some_property + 1
	when 0
		It's zero.
	when 1 + 1
		It's two.
	when 42
		It's 42.
	else
		I don't know.
After")

	StateForTests.some_property = 1
	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before", "Should be before match.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "It's two.", "Should match two case.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After", "Should be after match.")

	StateForTests.some_property = 100
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before", "Should be before match.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "I don't know.", "Should match else.")

	resource = create_resource("
~ start
Before
match StateForTests.some_property + 1
	when 1
		It's one.
	when < 5
		It's less than 5 but not one.
	else
		It's something else.
After")

	StateForTests.some_property = 3
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before", "Should be before match.")
	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "It's less than 5 but not one.", "Should match comparison.")

	resource = create_resource("
~ start
Before
match StateForTests.some_property + 1
	when 0
		It's zero.
	when 1 + 1
		It's two.
	when 42
		It's 42.
After")

	StateForTests.some_property = 100
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Before", "Should be before match.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(line.text == "After", "Should go to After if nothing matches and no else.")


func test_can_parse_mutations() -> void:
	var output = compile("
set StateForTests.some_property = StateForTests.some_method(-10, \"something\")
do long_mutation()")

	assert(output.errors.is_empty(), "Should have no errors.")

	var mutation = output.lines["1"]
	assert(mutation.type == DMConstants.TYPE_MUTATION, "Should be a mutation.")

	mutation = output.lines["2"]
	assert(mutation.type == DMConstants.TYPE_MUTATION, "Should be a mutation.")


func test_can_run_mutations() -> void:
	var resource = create_resource("
~ start
set StateForTests.some_property = StateForTests.some_method(-10, \"something\")
set StateForTests.some_property += 5-10
set StateForTests.some_property *= 2
set StateForTests.some_property /= 2
Nathan: Pause the test.
do StateForTests.long_mutation()
Nathan: Done.")

	StateForTests.some_property = 0

	var line = await resource.get_next_dialogue_line("start")
	assert(StateForTests.some_property == StateForTests.some_method(-10, "something") + 5-10, "Should have updated the property.")

	var started_at: float = Time.get_unix_time_from_system()
	line = await resource.get_next_dialogue_line(line.next_id)
	var duration: float = Time.get_unix_time_from_system() - started_at
	assert(duration > 0.2, "Mutation should take some time.")


func test_can_run_non_blocking_mutations() -> void:
	var resource = create_resource("
~ start
Nathan: This mutation should not wait.
do! StateForTests.long_mutation()
Nathan: Done.")

	var line = await resource.get_next_dialogue_line("start")

	var started_at: float = Time.get_unix_time_from_system()
	line = await resource.get_next_dialogue_line(line.next_id)
	var duration: float = Time.get_unix_time_from_system() - started_at
	assert(duration < 0.1, "Mutation should not take any time.")


func test_can_run_non_blocking_inline_mutations() -> void:
	var resource = create_resource("
~ start
Nathan: This mutation [do StateForTests.long_mutation()]should wait.
Nathan: This one [do! StateForTests.long_mutation()] won't.")

	var line = await resource.get_next_dialogue_line("start")
	dialogue_label.dialogue_line = line
	var started_at: float = Time.get_unix_time_from_system()
	dialogue_label.type_out()
	await dialogue_label.finished_typing
	var duration: float = Time.get_unix_time_from_system() - started_at
	assert(duration >= 0.6, "Mutation should take some time.")

	line = await resource.get_next_dialogue_line(line.next_id)
	dialogue_label.dialogue_line = line
	started_at = Time.get_unix_time_from_system()
	dialogue_label.type_out()
	await dialogue_label.finished_typing
	duration = Time.get_unix_time_from_system() - started_at
	assert(duration <= 0.3, "Mutation should not take any time.")


func test_can_run_mutations_with_typed_arrays() -> void:
	var resource = create_resource("
~ start
Nathan: {{StateForTests.typed_array_method([-1, 27], [\"something\"], [{ \"key\": \"value\" }])}}")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "[-1, 27][\"something\"][{ \"key\": \"value\" }]", "Should match output.")


func test_can_run_expressions() -> void:
	var resource = create_resource("
~ start
set StateForTests.some_property = 10 * 2-1.5 / 2 + (5 * 5)
Nathan: Done.")

	StateForTests.some_property = 0

	await resource.get_next_dialogue_line("start")
	assert(StateForTests.some_property == int(10 * 2-1.5 / 2 + (5 * 5)), "Should have updated the property.")



func test_can_use_extra_state() -> void:
	var resource = create_resource("
~ start
Nathan: {{extra_value}}
set extra_value = 10")

	var extra_state = { extra_value = 5 }

	var line = await resource.get_next_dialogue_line("start", [extra_state])
	assert(line.text == "5", "Should have initial value.")

	line = await  resource.get_next_dialogue_line(line.next_id, [extra_state])
	assert(extra_state.extra_value == 10, "Should have updated value.")


func test_can_use_using_clause() -> void:
	var resource = create_resource("
using StateForTests
~ start
Nathan: {{some_property}}")

	StateForTests.some_property = 27

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "27", "Should match property.")


func test_can_use_color_constants() -> void:
	var resource = create_resource("
~ start
Nathan: {{Color.BLUE}} == {{Color(0,0,1)}}")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "%s == %s" % [Color.BLUE, Color(0, 0, 1)], "Should match blue.")


func test_can_use_vector_constants() -> void:
	var resource = create_resource("
~ start
Nathan: {{Vector2.UP}} == {{Vector2(0, -1)}}")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "%s == %s" % [str(Vector2.UP), str(Vector2(0, -1))], "Should match up.")


func test_can_use_lua_dictionary_syntax() -> void:
	var resource = create_resource("
~ start
set StateForTests.dictionary = { key = \"value\" }
Nathan: Stop!
set StateForTests.dictionary = { \"key2\": \"value2\" }
Nathan: Stop!
set StateForTests.dictionary.key3 = \"value3\"")

	assert(StateForTests.dictionary.is_empty(), "Dictionary is empty")

	var line = await resource.get_next_dialogue_line("start")
	assert(StateForTests.dictionary.size() == 1, "Dictionary has one entry")
	assert(StateForTests.dictionary.has("key") and StateForTests.dictionary.get("key") == "value", "Dictionary should be updated.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(StateForTests.dictionary.size() == 1, "Dictionary has one entry")
	assert(StateForTests.dictionary.has("key2") and StateForTests.dictionary.get("key2") == "value2", "Dictionary should be updated.")

	line = await resource.get_next_dialogue_line(line.next_id)
	assert(StateForTests.dictionary.size() == 2, "Dictionary has two entries")
	assert(StateForTests.dictionary.has("key3") and StateForTests.dictionary.get("key3") == "value3", "Dictionary should be updated.")


func test_can_use_callable() -> void:
	var resource = create_resource("
~ start
Nathan: The number is {{Callable(StateForTests, \"some_method\").bind(\"blah\").call(10)}}.")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "The number is 40.", "Should resolve callable.")


func test_can_warn_about_conflicts() -> void:
	var resource = create_resource("
using StateForTests
~ start
set some_property = 1
Value is {{some_property}}")

	ProjectSettings.set_setting("dialogue_manager/runtime/warn_about_method_property_or_signal_name_conflicts", true)

	var line = await resource.get_next_dialogue_line("start", [{ some_property = 1000 }])
	assert(line.text == "Value is 1", "Should process first occurance of property.")


func test_can_use_self() -> void:
	var resource = create_resource("
~ start
set what_is_self = self
Nathan: That should not be null.
=> END")

	var extra_state = {
		what_is_self = null
	}

	await resource.get_next_dialogue_line("start", [extra_state])
	assert(extra_state.what_is_self == resource, "Self should be the given DialogueResource.")


func test_can_parse_null_coalesce() -> void:
	var output = compile("
~ start
if StateForTests.something_null?.begins_with(\"value\") == true:
	Nathan: Should not be here.
else:
	Nathan: Should be here.
=> END")

	assert(output.errors.size() == 0, "Should have no errors.")


func test_can_handle_null_coalesce() -> void:
	var resource = create_resource("
~ start
if StateForTests.something_null?.begins_with(\"value\") == true:
	Nathan: Should not be here.
else:
	Nathan: Should be here.
=> END")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Should be here.", "Should coalesce to null and not pass condition.")

	StateForTests.something_null = "value is not null"
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "Should not be here.", "Should now pass condition.")
