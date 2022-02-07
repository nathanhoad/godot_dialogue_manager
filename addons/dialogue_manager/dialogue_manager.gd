extends Node


signal dialogue_started
signal dialogue_finished


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const Constants = preload("res://addons/dialogue_manager/constants.gd")
const Line = preload("res://addons/dialogue_manager/dialogue_line.gd")
const Response = preload("res://addons/dialogue_manager/dialogue_response.gd")

const ExampleBalloon = preload("res://addons/dialogue_manager/example_balloon/example_balloon.gd")


var resource: DialogueResource
var game_states: Array = []
var auto_translate: bool = true

var is_dialogue_running := false setget set_is_dialogue_running

var _node_properties: Array = []


func _ready() -> void:
	# Cache the known Node2D properties
	_node_properties = ["Script Variables"]
	var temp_node = Node2D.new()
	for property in temp_node.get_property_list():
		_node_properties.append(property.name)
	temp_node.free()
	
	# Load the config file (if there is one) so we can set up any global state objects
	var config = ConfigFile.new()
	var success = config.load(Constants.CONFIG_PATH)
	if success == OK:
		var states = config.get_value("runtime", "states", [])
		for node_name in states:
			var state = get_node("/root/" + node_name)
			if state:
				game_states.append(state)


# Step through lines and run any mutations until we either 
# hit some dialogue or the end of the conversation
func get_next_dialogue_line(key: String, override_resource: DialogueResource = null) -> Line:
	cleanup()
	
	# Fix up any keys that have spaces in them
	key = key.replace(" ", "_").strip_edges()
	
	# You have to provide a dialogue resource
	assert(resource != null or override_resource != null, "No dialogue resource provided")
	
	var local_resource: DialogueResource = (override_resource if override_resource != null else resource)
	
	assert(local_resource.syntax_version == Constants.SYNTAX_VERSION, "This dialogue resource is older than the runtime expects.")
	
	if local_resource.errors.size() > 0:
		# Store in a local var for debugger convenience
		var errors = local_resource.errors
		printerr("There are %d error(s) in %s" % [errors.size(), local_resource.resource_path])
		for error in errors:
			printerr("\tLine %s: %s" % [error.get("line"), error.get("message")])
		assert(false, "The provided DialogueResource contains errors. See Output for details.")
	
	var dialogue = get_line(key, local_resource)
	
	yield(get_tree(), "idle_frame")
	
	self.is_dialogue_running = true
	
	# If our dialogue is nothing then we hit the end
	if dialogue == null or not is_valid(dialogue):
		self.is_dialogue_running = false
		return null
	
	# Run the mutation if it is one
	if dialogue.type == Constants.TYPE_MUTATION:
		yield(mutate(dialogue.mutation), "completed")
		dialogue.queue_free()
		if dialogue.next_id in [Constants.ID_END_CONVERSATION, Constants.ID_NULL, null]:
			# End the conversation
			self.is_dialogue_running = false
			return null
		else:
			return get_next_dialogue_line(dialogue.next_id, local_resource)
	else:
		return dialogue


func replace_values(line_or_response) -> String:
	if line_or_response is Line:
		var line: Line = line_or_response
		return get_replacements(line.dialogue, line.replacements)
	elif line_or_response is Response:
		var response: Response = line_or_response
		return get_replacements(response.prompt, response.replacements)
	else:
		return ""



func show_example_dialogue_balloon(title: String, resource: DialogueResource = null) -> void:
	var dialogue = yield(get_next_dialogue_line(title, resource), "completed")
	if dialogue != null:
		var balloon = preload("res://addons/dialogue_manager/example_balloon/example_balloon.tscn").instance()
		balloon.dialogue = dialogue
		get_tree().current_scene.add_child(balloon)
		show_example_dialogue_balloon(yield(balloon, "actioned"), resource)
	

### Helpers


# Get a line by its ID
func get_line(key: String, local_resource: DialogueResource) -> Line:
	# End of conversation
	if key in [Constants.ID_NULL, Constants.ID_END_CONVERSATION, null]:
		return null
	
	# See if it is a title
	if key.begins_with("~ "):
		key = key.substr(2)
	if local_resource.titles.has(key):
		key = local_resource.titles.get(key)
	
	# Key not found
	if not local_resource.lines.has(key):
		printerr("Line for key \"%s\" could not be found in %s" % [key, local_resource.resource_path])
		assert(false, "The provided DialogueResource does not contain that line key. See Output for details.")
	
	var data = local_resource.lines.get(key)
	
	# Check condtiions
	if data.get("type") == Constants.TYPE_CONDITION:
		# "else" will have no actual condition
		if data.get("condition") == null or check(data.get("condition")):
			return get_line(data.get("next_id"), local_resource)
		else:
			return get_line(data.get("next_conditional_id"), local_resource)
	
	# Evaluate early exits
	if data.get("type") == Constants.TYPE_GOTO:
		return get_line(data.get("next_id"), local_resource)
	
	# Set up a line object
	var line = Line.new(data, auto_translate)
	line.dialogue_manager = self
	
	# No dialogue and only one node is the same as an early exit
	if data.get("type") == Constants.TYPE_RESPONSE:
		line.responses = get_responses(data.get("responses"), local_resource)
		return line
	
	# Add as a child so that it gets cleaned up automatically
	add_child(line)
	
	# Replace any variables in the dialogue text
	if data.get("type") == Constants.TYPE_DIALOGUE and data.has("replacements"):
		line.dialogue = replace_values(line)
	
	# Inject the next node's responses if they have any
	var next_line = local_resource.lines.get(line.next_id)
	if next_line != null and next_line.get("type") == Constants.TYPE_RESPONSE:
		line.responses = get_responses(next_line.get("responses"), local_resource)
		# If there is only one response then it has to point to the next node
		if line.responses.size() == 1:
			line.next_id = line.responses[0].next_id
	
	return line


func set_is_dialogue_running(value: bool) -> void:
	if is_dialogue_running != value:
		if value:
			emit_signal("dialogue_started")
		else:
			emit_signal("dialogue_finished")
			
	is_dialogue_running = value


# Check if a condition is met
func check(condition: Dictionary) -> bool:
	if condition.size() == 0: return true
	
	return resolve(condition.get("expression").duplicate(true))


# Make a change to game state or run a method
func mutate(mutation: Dictionary) -> void:
	if mutation == null: return
	
	if mutation.has("function"):
		# If lhs is a function then we run it and return because you can't assign to a function
		var function_name = mutation.get("function")
		var args = resolve_each(mutation.get("args"))
		match function_name:
			"wait":
				yield(get_tree().create_timer(float(args[0])), "timeout")
			"emit":
				var current_scene = get_tree().current_scene
				var states = [current_scene] + game_states
				for state in states:
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
				var printable = {}
				for i in range(args.size()):
					printable[mutation.get("args")[i][0].get("value")] = args[i]
				print(printable)
			_:
				var current_scene = get_tree().current_scene
				var states = [current_scene] + game_states
				var found = false
				for state in states:
					if state.has_method(function_name):
						found = true
						var result = state.callv(function_name, args)
						if result is GDScriptFunctionState and result.is_valid():
							yield(result, "completed")
				if not found:
					printerr("'" + function_name + "' is not a method on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
					assert(false, "Missing function on current scene or game state. See Output for details.")
		
		# Wait one frame to give the dialogue handler a chance to yield
		yield(get_tree(), "idle_frame")
		return
	
	elif mutation.has("variable"):
		var lhs = mutation.get("variable")
		var rhs = resolve(mutation.get("expression").duplicate(true))
	
		match mutation.get("operator"):
			"=":
				set_state_value(lhs, rhs)
			"+=":
				set_state_value(lhs, apply_operation("+", get_state_value(lhs), rhs))
			"-=":
				set_state_value(lhs, apply_operation("-", get_state_value(lhs), rhs))
			"*=":
				set_state_value(lhs, apply_operation("*", get_state_value(lhs), rhs))
			"/=":
				set_state_value(lhs, apply_operation("/", get_state_value(lhs), rhs))
		
		# Wait one frame to give the dialogue handler a chance to yield
		yield(get_tree(), "idle_frame")


func resolve_each(array: Array) -> Array:
	var results = []
	for item in array:
		results.append(resolve(item.duplicate(true)))
	return results
	

# Replace any variables, etc in the dialogue with their state values
func get_replacements(text: String, replacements: Array) -> String:
	for replacement in replacements:
		var value = resolve(replacement.get("expression").duplicate(true))
		text = text.replace(replacement.get("value_in_text"), str(value))
	
	return text


# Replace an array of line IDs with their response prompts
func get_responses(ids: Array, local_resource: DialogueResource) -> Array:
	var responses: Array = []
	for id in ids:
		var data = local_resource.lines.get(id)
		if data.get("condition") == null or check(data.get("condition")):
			var response = Response.new(data, auto_translate)
			response.prompt = replace_values(response)
			# Add as a child so that it gets cleaned up automatically
			add_child(response)
			responses.append(response)
	
	return responses


# Get a value on the current scene or game state
func get_state_value(property: String):
	# It's a variable
	var current_scene = get_tree().current_scene
	var states = [current_scene] + game_states
	for state in states:
		if has_property(state, property):
			return state.get(property)

	printerr("'" + property + "' is not a property on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
	assert(false, "Missing property on current scene or game state. See Output for details.")


# Set a value on the current scene or game state
func set_state_value(property: String, value) -> void:
	var current_scene = get_tree().current_scene
	var states = [current_scene] + game_states
	for state in states:
		if has_property(state, property):
			state.set(property, value)
			return
	
	printerr("'" + property + "' is not a property on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
	assert(false, "Missing property on current scene or game state. See Output for details.")


# Collapse any expressions
func resolve(tokens: Array):
	# Handle functions and state values first
	for token in tokens:
		if token.get("type") == Constants.TOKEN_FUNCTION:
			var function_name = token.get("function")
			var args = resolve_each(token.get("value"))
			var current_scene = get_tree().current_scene
			var states = [current_scene] + game_states
			for state in states:
				if state.has_method(function_name):
					token["type"] = "value"
					token["value"] = state.callv(function_name, args)
			
			printerr("'" + function_name + "' is not a method on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
			assert(false, "Missing function on current scene or game state. See Output for details.")
		
		elif token.get("type") == Constants.TOKEN_DICTIONARY_REFERENCE:
			token["type"] = "value"
			var value = get_state_value(token.get("variable"))
			var index = resolve(token.get("value"))
			if typeof(value) == TYPE_DICTIONARY:
				if value.has(index):
					token["value"] = value[index]
				else:
					printerr("Key \"%s\" not found in dictionary \"%s\"" % [str(index), token.get("variable")])
					assert(false, "Key not found in dictionary. See Output for details.")
			elif typeof(value) == TYPE_ARRAY:
				if index >= 0 and index < value.size():
					token["value"] = value[index]
				else:
					printerr("Index %d out of bounds of array \"%s\"" % [index, token.get("variable")])
					assert(false, "Index out of bounds of array. See Output for details.")
		
		elif token.get("type") == Constants.TOKEN_ARRAY:
			token["type"] = "value"
			token["value"] = resolve_each(token.get("value"))
			
		elif token.get("type") == Constants.TOKEN_DICTIONARY:
			token["type"] = "value"
			var dictionary = {}
			for key in token.get("value").keys():
				var resolved_key = resolve([key])
				var resolved_value = resolve([token.get("value").get(key)])
				dictionary[resolved_key] = resolved_value
			token["value"] = dictionary
			
		elif token.get("type") == Constants.TOKEN_VARIABLE:
			token["type"] = "value"
			if token.get("value") == "null":
				token["value"] = null
			else:
				token["value"] = get_state_value(token.get("value"))
	
	# Then groups
	for token in tokens:
		if token.get("type") == Constants.TOKEN_GROUP:
			token["type"] = "value"
			token["value"] = resolve(token.get("value"))
	
	# Then multiply and divide
	var i = 0
	var limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == Constants.TOKEN_OPERATOR and token.get("value") in ["*", "/"]:
			token["type"] = "value"
			token["value"] = apply_operation(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then addition and subtraction
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == Constants.TOKEN_OPERATOR and token.get("value") in ["+", "-"]:
			token["type"] = "value"
			token["value"] = apply_operation(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then comparisons
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == Constants.TOKEN_COMPARISON:
			token["type"] = "value"
			token["value"] = compare(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then and/or
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == Constants.TOKEN_AND_OR:
			token["type"] = "value"
			token["value"] = apply_operation(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
				
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	return tokens[0].get("value")


func compare(operator: String, first_value, second_value):
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


func apply_operation(operator: String, first_value, second_value):
	if first_value == null:
		if typeof(second_value) == TYPE_BOOL and second_value == true:
			return false
		else:
			return second_value
	elif second_value == null:
		if typeof(first_value) == TYPE_BOOL and first_value == true:
			return false
		else:
			return first_value
	
	match operator:
		"+":
			return first_value + second_value
		"-":
			return first_value - second_value
		"/":
			return first_value / second_value
		"*":
			return first_value * second_value
		"and":
			return first_value and second_value
		"or":
			return first_value or second_value


# Check if a dialogue line contains meaninful information
func is_valid(line: Line) -> bool:
	if line.type == Constants.TYPE_DIALOGUE and line.dialogue == "":
		return false
	if line.type == Constants.TYPE_MUTATION and line.mutation == null:
		return false
	if line.type == Constants.TYPE_RESPONSE and line.responses.size() == 0:
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


func cleanup() -> void:
	for line in get_children():
		line.queue_free()
