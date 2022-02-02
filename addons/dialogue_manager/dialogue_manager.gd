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
var is_strict: bool = true
var auto_translate: bool = true

var is_dialogue_running := false setget set_is_dialogue_running

var _internal_state: Dictionary = {}
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
	
	# You have to provide a dialogue resource
	assert(resource != null or override_resource != null, "No dialogue resource provided")
	
	var local_resource: DialogueResource = (override_resource if override_resource != null else resource)
	
	if local_resource.errors.size() > 0:
		# Store in a local var for debugger convenience
		var errors = local_resource.errors
		printerr("There are %d error(s) in %s" % [errors.size(), local_resource.resource_path])
		for error in errors:
			printerr("\tLine %s: %s" % [error.get("line"), error.get("message")])
		assert(false, "%s contains %s error(s). See output for details." % [local_resource.resource_path, errors.size()])
	
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
	if key.begins_with("# "):
		key = key.substr(2)
	if local_resource.titles.has(key):
		key = local_resource.titles.get(key)
	
	# Key not found
	assert(local_resource.lines.has(key), "Line for key \"%s\" could not be found in %s" % [key, local_resource.resource_path])
	
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
	
	# Evaulate left hand side
	var lhs
	match condition.get("lhs_type"):
		Constants.TYPE_FUNCTION:
			lhs = get_state_function_value(condition.get("lhs_function"), condition.get("lhs_args"))
		Constants.TYPE_EXPRESSION:
			lhs = get_state_value(condition.get("lhs"))
		Constants.TYPE_ERROR:
			assert(false, "This condition was not exported properly")
	
	# If there is no operator then we just return the value of the lhs
	if not condition.has("operator"):
		return bool(lhs)
	
	# Evaluate right hand side
	var rhs
	match condition.get("rhs_type"):
		Constants.TYPE_FUNCTION:
			rhs = get_state_function_value(condition.get("rhs_function"), condition.get("rhs_args"))
		Constants.TYPE_EXPRESSION:
			rhs = resolve(condition.get("rhs"))
			# Reevaluate lhs with a type hint
			lhs = get_state_value(condition.get("lhs"), typeof(rhs))
		Constants.TYPE_ERROR:
			assert(false, "This condition was not exported properly")
	
	match condition.get("operator"):
		"=", "==":
			return lhs == rhs
		">":
			return lhs > rhs
		">=":
			return lhs >= rhs
		"<":
			return lhs < rhs
		"<=":
			return lhs <= rhs
		"<>", "!=":
			return lhs != rhs
		"in":
			return lhs in rhs
	
	return false


# Make a change to game state or run a method
func mutate(mutation: Dictionary) -> void:
	if mutation == null: return
	
	# Evaulate left hand side
	var lhs
	match mutation.get("lhs_type"):
		Constants.TYPE_FUNCTION:
			# If lhs is a function then we run it and return because you can't assign to a function
			var function_name = mutation.get("lhs_function")
			var args = parse_args(mutation.get("lhs_args"))
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
						printable[mutation.get("lhs_args")[i]] = args[i]
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
					if not found and is_strict:
						assert(false, "'" + function_name + "' is not a method on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
			
			# Wait one frame to give the dialogue handler a chance to yield
			yield(get_tree(), "idle_frame")
			return
			
		Constants.TYPE_EXPRESSION:
			# lhs is the name of a state property
			lhs = mutation.get("lhs")
		Constants.TYPE_ERROR:
			assert(false, "This mutation was not exported properly")
	
	# If there is no operator then we don't do anything
	if not mutation.has("operator"):
		return
	
	# Evaluate right hand side
	var rhs
	match mutation.get("rhs_type"):
		Constants.TYPE_FUNCTION:
			rhs = get_state_function_value(mutation.get("rhs_function"), mutation.get("rhs_args"))
		Constants.TYPE_EXPRESSION:
			rhs = resolve(mutation.get("rhs"))
		Constants.TYPE_ERROR:
			assert(false, "This condition was not exported properly")
	
	match mutation.get("operator"):
		"=":
			set_state_value(lhs, rhs)
		"+=":
			set_state_value(lhs, get_state_value(lhs, typeof(rhs)) + rhs)
		"-=":
			set_state_value(lhs, get_state_value(lhs, typeof(rhs)) - rhs)
		"*=":
			set_state_value(lhs, get_state_value(lhs, typeof(rhs)) * rhs)
		"/=":
			set_state_value(lhs, get_state_value(lhs, typeof(rhs)) / rhs)
	
	# Wait one frame to give the dialogue handler a chance to yield
	yield(get_tree(), "idle_frame")


# Replace any variables, etc in the dialogue with their state values
func get_replacements(text: String, replacements: Array) -> String:
	for replacement in replacements:
		var value = ""
		match replacement.get("type"):
			Constants.TYPE_FUNCTION:
				value = get_state_function_value(replacement.get("function"), replacement.get("args"))
			Constants.TYPE_EXPRESSION:
				value = resolve(replacement.get("value"))
		
		text = text.replace(replacement.get("value_in_text"), value)
	
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
func get_state_value(arg, type_hint = null):
	match typeof(arg):
		TYPE_INT, \
		TYPE_REAL, \
		TYPE_BOOL:
			return arg
	
	if arg.begins_with("\"") and arg.ends_with("\""):
		# A literal string
		return arg.substr(1, arg.length() - 2)
		
	elif arg.to_lower() == "true" or arg.to_lower() == "yes":
		return true
	elif arg.to_lower() == "false" or arg.to_lower() == "no":
		return false
	
	elif str(arg.to_float()) == arg:
		# A float
		return arg.to_float()
	elif str(arg.to_int()) == arg:
		# An integer
		return arg.to_int()
		
	else:
		# It's a variable
		var current_scene = get_tree().current_scene
		var states = [current_scene] + game_states
		for state in states:
			if has_property(state, arg):
				return state.get(arg)
		
		if is_strict:
			assert(false, "'" + arg + "' is not a property on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
		else:
			if _internal_state.has(arg):
				return _internal_state.get(arg)
			else:
				match type_hint:
					TYPE_REAL:
						return 0.0
					TYPE_INT:
						return 0
					TYPE_STRING:
						return ""
					_:
						return false


# Set a value on the current scene or game state
func set_state_value(key: String, value) -> void:
	var current_scene = get_tree().current_scene
	var states = [current_scene] + game_states
	for state in states:
		if has_property(state, key):
			state.set(key, value)
			return
	
	if is_strict:
		assert(false, "'" + key + "' is not a property on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
	else:
		_internal_state[key] = value


# Run a function with args and get its return value
func get_state_function_value(function_name: String, args: Array):
	args = parse_args(args)
	
	var current_scene = get_tree().current_scene
	var states = [current_scene] + game_states
	for state in states:
		if state.has_method(function_name):
			return state.callv(function_name, args)
	if is_strict:
		assert(false, "'" + function_name + "' is not a method on the current scene (" + current_scene.name + ") or on any game states (" + str(game_states) + ").")
	else:
		# Unknown functions in non-strict mode are falsey
		return false


# Evaluate an array of args from their state values
func parse_args(args: Array) -> Array:
	var next_args = []
	for i in range(0, args.size()):
		next_args.append(get_state_value(args[i]))
	return next_args

# Collapse any expressions
func resolve(tokens: Array, type_hint = null):
	# Handle groups first
	for token in tokens:
		if token.get("type") == "group":
			token["type"] = "value"
			token["value"] = resolve(token.get("value"))
	
	# Then multiply and divide
	var i = 0
	while i < tokens.size():
		var token = tokens[i]
		if token.get("type") == "operator":
			if token.get("value") == "*":
				token["type"] = "value"
				token["value"] = get_state_value(tokens[i-1].get("value"), type_hint) * get_state_value(tokens[i+1].get("value"), type_hint)
				tokens.remove(i+1)
				tokens.remove(i-1)
				i -= 1
			elif token.get("value") == "/":
				token["type"] = "value"
				token["value"] = get_state_value(tokens[i-1].get("value"), type_hint) / get_state_value(tokens[i+1].get("value"), type_hint)
				tokens.remove(i+1)
				tokens.remove(i-1)
				i -= 1
		i += 1
	
	# Then addition and subtraction
	i = 0
	while i < tokens.size():
		var token = tokens[i]
		if token.get("type") == "operator":
			if token.get("value") == "+":
				token["type"] = "value"
				var lhs = tokens[i-1].get("value")
				var rhs = tokens[i+1].get("value")
				token["value"] = get_state_value(lhs, type_hint) + get_state_value(rhs, type_hint)
				# if its a string then re-add the quotes
				if lhs.begins_with("\"") or rhs.begins_with("\""):
					token["value"] = "\"" + token["value"] + "\""
				tokens.remove(i+1)
				tokens.remove(i-1)
				i -= 1
			elif token.get("value") == "-":
				token["type"] = "value"
				token["value"] = get_state_value(tokens[i-1].get("value"), type_hint) - get_state_value(tokens[i+1].get("value"), type_hint)
				tokens.remove(i+1)
				tokens.remove(i-1)
				i -= 1
		i += 1
	
	return get_state_value(tokens[0].get("value"))


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
