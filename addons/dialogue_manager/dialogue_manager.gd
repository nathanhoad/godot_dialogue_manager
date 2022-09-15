extends Node


signal dialogue()
signal mutation()
signal dialogue_finished()


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")
const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")


# The list of globals that dialogue can query
var game_states: Array = []

# Auto tr() lines
var auto_translate: bool = true

var _node_properties: Array = []
var _extra_game_states: Array = []


func _ready() -> void:
	# Cache the known Node2D properties
	_node_properties = ["Script Variables"]
	var temp_node: Node2D = Node2D.new()
	for property in temp_node.get_property_list():
		_node_properties.append(property.name)
	temp_node.free()
	
	# Add any autoloads to a generic state so we can refer to them by name
	var autoloads: Dictionary = {}
	for child in get_tree().root.get_children():
		if not child.name in [StringName("DialogueManager"), get_tree().current_scene.name]:
			autoloads[child.name] = child
	game_states = [autoloads]
	
	# Add any other state shortcuts from settings
	for node_name in DialogueSettings.get_setting("states", []):
		var state: Node = get_node("/root/" + node_name)
		if state:
			game_states.append(state)


## Step through lines and run any mutations until we either hit some dialogue or the end of the conversation
func get_next_dialogue_line(resource: Resource, key: String = "0", extra_game_states: Array = []) -> Dictionary:
	# You have to provide a valid dialogue resource
	assert(resource != null, "No dialogue resource provided")
	assert(resource.get_meta("lines").size() > 0, "Dialogue file has no content.")
	
	# Temporarily add any extra game states that were passed in
	_extra_game_states = extra_game_states
	
	var dialogue: Dictionary = await get_line(resource, key)
	
	await get_tree().process_frame
	
	# If our dialogue is nothing then we hit the end
	if not is_valid(dialogue):
		emit_signal("dialogue_finished")
		return create_empty_dialogue_line()
	
	# Run the mutation if it is one
	if dialogue.type == DialogueConstants.TYPE_MUTATION:
		await mutate(dialogue.mutation)
		var actual_next_id: String = dialogue.next_id.split(",")[0]
		if actual_next_id in [DialogueConstants.ID_END_CONVERSATION, DialogueConstants.ID_NULL, null]:
			# End the conversation
			emit_signal("dialogue_finished")
			return create_empty_dialogue_line()
		else:
			return await get_next_dialogue_line(resource, dialogue.next_id, extra_game_states)
	else:
		emit_signal("dialogue")
		return dialogue


## Replace any variables, etc in the dialogue with their state values
func get_resolved_text(text: String, replacements: Array) -> String:
	# Resolve variables
	for replacement in replacements:
		var value = await resolve(replacement.expression.duplicate(true))
		text = text.replace(replacement.value_in_text, str(value))
	
	# Resolve random groups
	var random_regex: RegEx = RegEx.new()
	random_regex.compile("\\[\\[(?<options>.*?)\\]\\]")
	for found in random_regex.search_all(text):
		var options = found.get_string("options").split("|")
		text = text.replace("[[%s]]" % found.get_string("options"), options[randi_range(0, options.size() - 1)])
	
	return text


## Generate a dialogue resource on the fly from some text
func create_resource_from_text(text: String) -> Resource:
	var parser: DialogueParser = DialogueParser.new()
	parser.parse(text)
	var results: Dictionary = parser.get_data()
	var errors: Array[Dictionary] = parser.get_errors()
	parser.free()
	
	if errors.size() > 0:
		printerr("You have errors in your dialogue text.")
		for error in errors:
			printerr("Line %d: %s" % [error.line_number + 1, DialogueConstants.get_error_message(error.error)])
		assert(false, "You have errors in your dialogue text. See Output for details.")
	
	var resource: Resource = Resource.new()
	resource.set_meta("titles", results.titles)
	resource.set_meta("lines", results.lines)
	
	return resource


## Show the example balloon
func show_example_dialogue_balloon(resource: Resource, title: String = "0", extra_game_states: Array = []) -> void:
	var ExampleBalloonScene = load("res://addons/dialogue_manager/example_balloon/example_balloon.tscn")
	var SmallExampleBalloonScene = load("res://addons/dialogue_manager/example_balloon/small_example_balloon.tscn")
	
	var is_small_window: bool = ProjectSettings.get_setting("display/window/size/viewport_width") < 400
	var balloon: Node = (SmallExampleBalloonScene if is_small_window else ExampleBalloonScene).instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(resource, title, extra_game_states)


### Helpers


# Get a line by its ID
func get_line(resource: Resource, key: String) -> Dictionary:
	key = key.strip_edges()
	
	# See if we were given a stack instead of just the one key
	var stack: Array = key.split("|")
	key = stack.pop_front()
	var id_trail: String = "" if stack.size() == 0 else "|" + "|".join(stack)
	
	# See if we just ended the conversation
	if key in [DialogueConstants.ID_END, DialogueConstants.ID_NULL, null]:
		if stack.size() > 0:
			return await get_line(resource, "|".join(stack))
		else:
			return create_empty_dialogue_line()
	elif key == DialogueConstants.ID_END_CONVERSATION:
		return create_empty_dialogue_line()
	
	# See if it is a title
	if key.begins_with("~ "):
		key = key.substr(2)
	if resource.get_meta("titles", {}).has(key):
		key = resource.get_meta("titles").get(key)
	
	# Key not found, just use the first title
	if not resource.get_meta("lines").has(key):
		key = resource.get_meta("first_title")
	
	var data: Dictionary = resource.get_meta("lines").get(key)
	
	# Check for weighted random lines
	if data.has("siblings"):
		var result = randi() % data.siblings.reduce(func(total, sibling): return total + sibling.weight, 0)
		var cummulative_weight = 0
		for sibling in data.siblings:
			if result < cummulative_weight + sibling.weight:
				data = resource.get_meta("lines").get(sibling.id)
				break
			else:
				cummulative_weight += sibling.weight
	
	# Check condtiions
	elif data.type == DialogueConstants.TYPE_CONDITION:
		# "else" will have no actual condition
		if await check_condition(data):
			return await get_line(resource, data.next_id + id_trail)
		else:
			return await get_line(resource, data.next_conditional_id + id_trail)
	
	# Evaluate jumps
	elif data.type == DialogueConstants.TYPE_GOTO:
		if data.is_snippet:
			id_trail = "|" + data.next_id_after + id_trail
		return await get_line(resource, data.next_id + id_trail)
	
	# Set up a line object
	var line: Dictionary = await create_dialogue_line(data)
	
	# If we are the first of a list of responses then get the other ones
	if data.type == DialogueConstants.TYPE_RESPONSE:
		line.responses = await get_responses(data.responses, resource, id_trail)
		return line
	
	# Inject the next node's responses if they have any
	if resource.get_meta("lines").has(line.next_id):
		var next_line: Dictionary = resource.get_meta("lines").get(line.next_id)
		if next_line != null and next_line.type == DialogueConstants.TYPE_RESPONSE:
			line.responses = await get_responses(next_line.responses, resource, id_trail)
	
	line.next_id += id_trail
	return line


# Create a line of dialogue
func create_dialogue_line(data: Dictionary) -> Dictionary:
	match data.type:
		DialogueConstants.TYPE_DIALOGUE:
			# Our bbcodes need to be process after text has been resolved so that the markers are at the correct index
			var text = await get_resolved_text(tr(data.translation_key) if auto_translate else data.text, data.text_replacements)
			var parser = DialogueParser.new()
			var markers = parser.extract_markers(text)
			parser.free()
			
			return {
				type = DialogueConstants.TYPE_DIALOGUE,
				next_id = data.next_id,
				character = await get_resolved_text(data.character, data.character_replacements),
				character_replacements = data.character_replacements,
				text = markers.text,
				text_replacements = data.text_replacements,
				translation_key = data.translation_key,
				pauses = markers.pauses,
				speeds = markers.speeds,
				inline_mutations = markers.mutations,
				time = markers.time,
				responses = []
			}
		DialogueConstants.TYPE_MUTATION:
			return {
				type = DialogueConstants.TYPE_MUTATION,
				next_id = data.next_id,
				mutation = data.mutation
			}
		
		_:
			return create_empty_dialogue_line()


# Create a response
func create_response(data: Dictionary) -> Dictionary:
	return {
		type = DialogueConstants.TYPE_RESPONSE,
		next_id = data.next_id,
		is_allowed = await check_condition(data),
		text = await get_resolved_text(tr(data.translation_key) if auto_translate else data.text, data.text_replacements),
		text_replacements = data.text_replacements,
		translation_key = data.translation_key
	}


# Create an empty line
func create_empty_dialogue_line() -> Dictionary:
	return {}


# Get the current game states
func get_game_states() -> Array:
	var current_scene: Node = get_tree().current_scene
	var unique_states: Array = []
	for state in _extra_game_states + [current_scene] + game_states:
		if not unique_states.has(state):
			unique_states.append(state)
	return unique_states


# Check if a condition is met
func check_condition(data: Dictionary) -> bool:
	if data.get("condition", null) == null: return true
	if data.condition.size() == 0: return true
	
	return await resolve(data.condition.expression.duplicate(true))


# Make a change to game state or run a method
func mutate(mutation: Dictionary) -> void:
	var expression: Array[Dictionary] = mutation.expression
	
	# Handle built in mutations
	if expression[0].type == DialogueConstants.TOKEN_FUNCTION and expression[0].function in ["wait", "emit", "debug"]:
		var args: Array = await resolve_each(expression[0].value)
		match expression[0].function:
			"wait":
				emit_signal("mutation")
				await get_tree().create_timer(float(args[0])).timeout
				return
				
			"emit":
				for state in get_game_states():
					if state.has_signal(args[0]):
						match args.size():
							1:
								state.emit_signal(args[0])
							2:
								state.emit_signal(args[0], args[1])
							3:
								state.emit_signal(args[0], args[1], args[2])
							4:
								state.emit_signal(args[0], args[1], args[2], args[3])
							5:
								state.emit_signal(args[0], args[1], args[2], args[3], args[4])
							6:
								state.emit_signal(args[0], args[1], args[2], args[3], args[4], args[5])
							7:
								state.emit_signal(args[0], args[1], args[2], args[3], args[4], args[5], args[6])
							8:
								state.emit_signal(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
						
			"debug":
				prints("Debug:", args)
	
	# Or pass through to the resolver
	else:
		if not mutation_contains_assignment(mutation.expression):
			emit_signal("mutation")
		
		return await resolve(mutation.expression.duplicate(true))
		
	# Wait one frame to give the dialogue handler a chance to yield
	await get_tree().process_frame


func mutation_contains_assignment(mutation: Array) -> bool:
	for token in mutation:
		if token.type == DialogueConstants.TOKEN_ASSIGNMENT:
			return true
	return false


func resolve_each(array: Array) -> Array:
	var results: Array = []
	for item in array:
		results.append(await resolve(item.duplicate(true)))
	return results


# Replace an array of line IDs with their response prompts
func get_responses(ids: Array, resource: Resource, id_trail: String) -> Array:
	var responses: Array = []
	for id in ids:
		var data: Dictionary = resource.get_meta("lines").get(id)
		if DialogueSettings.get_setting("include_all_responses", false) or await check_condition(data):
			var response: Dictionary = await create_response(data)
			response.next_id += id_trail
			responses.append(response)
	
	return responses


# Get a value on the current scene or game state
func get_state_value(property: String):
	var expression = Expression.new()
	if expression.parse(property) != OK:
		printerr("'%s' is not a valid expression: %s" % [property, expression.get_error_text()])
		assert(false, "Invalid expression. See Output for details.")
	
	for state in get_game_states():
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				return state.get(property)
		else:
			var result = expression.execute([], state, false)
			if not expression.has_execute_failed():
				return result

	printerr("'%s' is not a property on any game states (%s)." % [property, str(get_game_states())])
	assert(false, "Missing property on current scene or game state. See Output for details.")


# Set a value on the current scene or game state
func set_state_value(property: String, value) -> void:
	for state in get_game_states():
		if has_property(state, property):
			state.set(property, value)
			return
	
	printerr("'%s' is not a property on any game states (%s)." % [property, str(get_game_states())])
	assert(false, "Missing property on current scene or game state. See Output for details.")


# Collapse any expressions
func resolve(tokens: Array):
	# Handle groups first
	for token in tokens:
		if token.type == DialogueConstants.TOKEN_GROUP:
			token["type"] = "value"
			token["value"] = await resolve(token.value)
	
	# Then variables/methods
	var i: int = 0
	var limit: int = 0
	while i < tokens.size() and limit < 1000:
		var token: Dictionary = tokens[i]
		
		if token.type == DialogueConstants.TOKEN_FUNCTION:
			var function_name: String = token.function
			var args = await resolve_each(token.value)
			if function_name == "str":
				token["type"] = "value"
				token["value"] = str(args[0])
			elif tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				# If we are calling a deeper function then we need to collapse the
				# value into the thing we are calling the function on
				var caller: Dictionary = tokens[i - 2]
				if typeof(caller.value) == TYPE_DICTIONARY:
					caller["type"] = "value"
					match function_name:
						"has":
							caller["value"] = caller.value.has(args[0])
						"get":
							caller["value"] = caller.value.get(args[0])
						_:
							caller["value"] = null
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				elif caller.value.has_method(function_name):
					caller["type"] = "value"
					caller["value"] = await caller.value.callv(function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				else:
					printerr("\"%s\" is not a callable method on \"%s\"" % [function_name, str(caller)])
					assert(false, "Missing callable method on calling object. See Output for details.")
			else:
				var found: bool = false
				for state in get_game_states():
					if typeof(state) == TYPE_DICTIONARY:
						match function_name:
							"has":
								token["type"] = "value"
								token["value"] = state.has(args[0])
								found = true
							"get":
								token["type"] = "value"
								token["value"] = state.get(args[0])
								found = true
					elif state.has_method(function_name):
						token["type"] = "value"
						token["value"] = await state.callv(function_name, args)
						found = true
				
				if not found:
					printerr("\"%s\" is not a method on any game states (%s)" % [function_name, str(get_game_states())])
					assert(false, "Missing function on current scene or game state. See Output for details.")
		
		elif token.type == DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
			var value = get_state_value(token.variable)
			var index = await resolve(token.value)
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					token["type"] = "dictionary"
					token["value"] = value
					token["key"] = index
				else:
					if value.has(index):
						token["type"] = "value"
						token["value"] = value[index]
					else:
						printerr("Key \"%s\" not found in dictionary \"%s\"" % [str(index), token.variable])
						assert(false, "Key not found in dictionary. See Output for details.")
			elif typeof(value) == TYPE_ARRAY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					token["type"] = "array"
					token["value"] = value
					token["key"] = index
				else:
					if index >= 0 and index < value.size():
						token["type"] = "value"
						token["value"] = value[index]
					else:
						printerr("Index %d out of bounds of array \"%s\"" % [index, token.variable])
						assert(false, "Index out of bounds of array. See Output for details.")
		
		elif token.type == DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE:
			var dictionary: Dictionary = tokens[i - 1]
			var index = await resolve(token.value)
			var value = dictionary.value
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary["type"] = "dictionary"
					dictionary["key"] = index
					dictionary["value"] = value
					tokens.remove_at(i)
					i -= 1
				else:
					if dictionary.value.has(index):
						dictionary["value"] = value.get(index)
						tokens.remove_at(i)
						i -= 1
					else:
						printerr("Key \"%s\" not found in dictionary \"%s\"" % [str(index), value])
						assert(false, "Key not found in dictionary. See Output for details.")
			elif typeof(value) == TYPE_ARRAY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary["type"] = "array"
					dictionary["value"] = value
					dictionary["key"] = index
					tokens.remove_at(i)
					i -= 1
				else:
					if index >= 0 and index < value.size():
						dictionary["value"] = value[index]
						tokens.remove_at(i)
						i -= 1
					else:
						printerr("Index %d out of bounds of array \"%s\"" % [index, value])
						assert(false, "Index out of bounds of array. See Output for details.")
		
		elif token.type == DialogueConstants.TOKEN_ARRAY:
			token["type"] = "value"
			token["value"] = await resolve_each(token.value)
			
		elif token.type == DialogueConstants.TOKEN_DICTIONARY:
			token["type"] = "value"
			var dictionary = {}
			for key in token.value.keys():
				var resolved_key = await resolve([key])
				var resolved_value = await resolve([token.value.get(key)])
				dictionary[resolved_key] = resolved_value
			token["value"] = dictionary
			
		elif token.type == DialogueConstants.TOKEN_VARIABLE:
			if token.value == "null":
				token["type"] = "value"
				token["value"] = null
			elif tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				var caller: Dictionary = tokens[i - 2]
				var property = token.value
				if tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					caller["type"] = "property"
					caller["property"] = property
				else:
					# If we are requesting a deeper property then we need to collapse the
					# value into the thing we are referencing from
					caller["type"] = "value"
					caller["value"] = caller.value.get(property)
				tokens.remove_at(i)
				tokens.remove_at(i-1)
				i -= 2
			elif tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
				# It's a normal variable but we will be assigning to it so don't resolve
				# it until everything after it has been resolved
				token["type"] = "variable"
			else:
				token["type"] = "value"
				token["value"] = get_state_value(token.value)
		
		i += 1
	
	# Then multiply and divide
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_OPERATOR and token.value in ["*", "/", "%"]:
			token["type"] = "value"
			token["value"] = apply_operation(token.value, tokens[i-1].value, tokens[i+1].value)
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then addition and subtraction
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_OPERATOR and token.value in ["+", "-"]:
			token["type"] = "value"
			token["value"] = apply_operation(token.value, tokens[i-1].value, tokens[i+1].value)
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then negations
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_NOT:
			token["type"] = "value"
			token["value"] = not tokens[i+1].value
			tokens.remove_at(i+1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then comparisons
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_COMPARISON:
			token["type"] = "value"
			token["value"] = compare(token.value, tokens[i-1].value, tokens[i+1].value)
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then and/or
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_AND_OR:
			token["type"] = "value"
			token["value"] = apply_operation(token.value, tokens[i-1].value, tokens[i+1].value)
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1
				
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Lastly, resolve any assignments
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DialogueConstants.TOKEN_ASSIGNMENT:
			var lhs: Dictionary = tokens[i - 1]
			var value
			
			match lhs.type:
				"variable":
					value = apply_operation(token.value, get_state_value(lhs.value), tokens[i+1].value)
					set_state_value(lhs.value, value)
				"property":
					value = apply_operation(token.value, lhs.value.get(lhs.property), tokens[i+1].value)
					if typeof(lhs.value) == TYPE_DICTIONARY:
						lhs.value[lhs.property] = value
					else:
						lhs.value.set(lhs.property, value)
				"dictionary", "array":
					value = apply_operation(token.value, lhs.value[lhs.key], tokens[i+1].value)
					lhs.value[lhs.key] = value
				_:
					assert(false, "Left hand side of expression cannot be assigned to.")
			
			token["type"] = "value"
			token["value"] = value
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1
	
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	return tokens[0].value


func compare(operator: String, first_value, second_value) -> bool:
	match operator:
		"in":
			if first_value == null or second_value == null:
				return false
			else:
				return first_value in second_value
		"<":
			if first_value == null:
				return true
			elif second_value == null:
				return false
			else:
				return first_value < second_value
		">":
			if first_value == null:
				return false
			elif second_value == null:
				return true
			else:
				return first_value > second_value
		"<=":
			if first_value == null:
				return true
			elif second_value == null:
				return false
			else:
				return first_value <= second_value
		">=":
			if first_value == null:
				return false
			elif second_value == null:
				return true
			else:
				return first_value >= second_value
		"==":
			if first_value == null:
				if typeof(second_value) == TYPE_BOOL:
					return second_value == false
				else:
					return false
			else:
				return first_value == second_value
		"!=":
			if first_value == null:
				if typeof(second_value) == TYPE_BOOL:
					return second_value == true
				else:
					return false
			else:
				return first_value != second_value
		_:
			return false


func apply_operation(operator: String, first_value, second_value):
	match operator:
		"=":
			return second_value
		"+", "+=":
			return first_value + second_value
		"-", "-=":
			return first_value - second_value
		"/", "/=":
			return first_value / second_value
		"*", "*=":
			return first_value * second_value
		"%":
			return first_value % second_value
		"and":
			return first_value and second_value
		"or":
			return first_value or second_value
		_:
			assert(false, "Unknown operator")


# Check if a dialogue line contains meaningful information
func is_valid(line: Dictionary) -> bool:
	if line.size() == 0:
		return false
	if line.type == DialogueConstants.TYPE_MUTATION and line.mutation == null:
		return false
	if line.type == DialogueConstants.TYPE_RESPONSE and line.responses.size() == 0:
		return false
	return true


# Check if a given property exists
func has_property(thing: Object, name: String) -> bool:
	if thing == null:
		return false

	for p in thing.get_property_list():
		if _node_properties.has(p.name):
			# Ignore any properties on the base Node
			continue
		if p.name == name:
			return true
	
	return false
