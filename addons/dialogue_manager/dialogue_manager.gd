extends Node


signal dialogue_started
signal dialogue_finished


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")
const DialogueResponse = preload("res://addons/dialogue_manager/dialogue_response.gd")

const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")
const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")

const ExampleBalloon = preload("res://addons/dialogue_manager/example_balloon/example_balloon.gd")


var resource: DialogueResource
var game_states: Array = []
var auto_translate: bool = true
var settings: DialogueSettings = DialogueSettings.new()

var is_dialogue_running := false setget set_is_dialogue_running

var _node_properties: Array = []
var _extra_game_states: Array = []
var _resource_cache: Array = []
var _trash: Node = Node.new()


func _ready() -> void:
	randomize()
	
	# Cache the known Node2D properties
	_node_properties = ["Script Variables"]
	var temp_node = Node2D.new()
	for property in temp_node.get_property_list():
		_node_properties.append(property.name)
	temp_node.free()
	
	# Load the config file (if there is one) so we can set up any global state objects
	add_child(settings)
	for node_name in settings.get_runtime_value("states", []):
		var state = get_node("/root/" + node_name)
		if state:
			game_states.append(state)
	
	# Add a node for cleaning up
	add_child(_trash)


# Step through lines and run any mutations until we either 
# hit some dialogue or the end of the conversation
func get_next_dialogue_line(key: String, override_resource: DialogueResource = null, extra_game_states: Array = []) -> DialogueLine:
	cleanup()
	
	# Fix up any keys that have spaces in them
	key = key.replace(" ", "_").strip_edges()
	
	# You have to provide a dialogue resource
	assert(resource != null or override_resource != null, "No dialogue resource provided")
	
	var local_resource: DialogueResource = (override_resource if override_resource != null else resource)
	
	assert(local_resource.syntax_version == DialogueConstants.SYNTAX_VERSION, "This dialogue resource is older than the runtime expects.")
	
	# Temporarily add any extra game states that were passed in
	_extra_game_states = extra_game_states
	
	var resource_path = local_resource.resource_path
	if local_resource.lines.size() == 0:
		# We probably have pre-baking turned off so we need to compile on the fly
		local_resource = compile_resource(local_resource)
	
	if local_resource.errors.size() > 0:
		# Store in a local var for debugger convenience
		var errors = local_resource.errors
		printerr("There are %d error(s) in %s" % [errors.size(), resource_path])
		for error in errors:
			printerr("\tLine %s: %s" % [error.get("line"), error.get("message")])
		assert(false, "The provided DialogueResource contains errors. See Output for details.")
	
	self.is_dialogue_running = true
	
	var dialogue = get_line(key, local_resource)
	
	yield(get_tree(), "idle_frame")
	
	# If our dialogue is nothing then we hit the end
	if not is_valid(dialogue):
		self.is_dialogue_running = false
		return null
	
	# Run the mutation if it is one
	if dialogue.type == DialogueConstants.TYPE_MUTATION:
		yield(mutate(dialogue.mutation), "completed")
		if is_instance_valid(dialogue):
			dialogue.queue_free()
			var actual_next_id = Array(dialogue.next_id.split(",")).front()
			if actual_next_id in [DialogueConstants.ID_END_CONVERSATION, DialogueConstants.ID_NULL, null]:
				# End the conversation
				self.is_dialogue_running = false
				return null
			else:
				return get_next_dialogue_line(dialogue.next_id, local_resource, extra_game_states)
		else:
			# End the conversation
			self.is_dialogue_running = false
			return null
	else:
		return dialogue


func replace_values(line_or_response) -> String:
	if line_or_response is DialogueLine:
		var line: DialogueLine = line_or_response
		return get_with_replacements(line.dialogue, line.replacements)
	elif line_or_response is DialogueResponse:
		var response: DialogueResponse = line_or_response
		return get_with_replacements(response.prompt, response.replacements)
	else:
		return ""


func get_resource_from_text(text: String) -> DialogueResource:
	var parser = DialogueParser.new()
	var new_resource = DialogueResource.new()
	
	var results = parser.parse(text)
	parser.queue_free()
	
	new_resource.raw_text = text
	new_resource.syntax_version = DialogueConstants.SYNTAX_VERSION
	new_resource.titles = results.get("titles")
	new_resource.lines = results.get("lines")
	new_resource.errors = results.get("errors")
	
	return new_resource


func show_example_dialogue_balloon(title: String, local_resource: DialogueResource = null, extra_game_states: Array = []) -> void:
	var dialogue = yield(get_next_dialogue_line(title, local_resource, extra_game_states), "completed")
	if dialogue != null:
		var balloon = preload("res://addons/dialogue_manager/example_balloon/example_balloon.tscn").instance()
		balloon.dialogue = dialogue
		get_tree().current_scene.add_child(balloon)
		show_example_dialogue_balloon(yield(balloon, "actioned"), local_resource, extra_game_states)
	

### Helpers


func compile_resource(resource: DialogueResource) -> DialogueResource:
	# See if we have this cached, first
	for item in _resource_cache:
		if item[0] == resource.resource_path:
			return item[1]
	
	# Otherwise, compile it and then cache it
	var next_resource = get_resource_from_text(resource.raw_text)
	_resource_cache.insert(0, [resource.resource_path, next_resource])
	
	# Only keep recent stuff in the cache
	if _resource_cache.size() > 5:
		_resource_cache.remove(5)
	
	return next_resource


# Get a line by its ID
func get_line(key: String, local_resource: DialogueResource) -> DialogueLine:
	# See if we were given a stack instead of just the one key
	var stack: Array = key.split(",")
	key = stack.pop_front()
	var id_trail = "" if stack.size() == 0 else "," + PoolStringArray(stack).join(",")
	
	# See if we just ended the conversation
	if key in [DialogueConstants.ID_END, DialogueConstants.ID_NULL, null]:
		if stack.size() > 0:
			return get_line(PoolStringArray(stack).join(","), local_resource)
		else:
			return null
	elif key == DialogueConstants.ID_END_CONVERSATION:
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
	
	# Check for weighted random lines
	if data.has("siblings"):
		var total = 0
		for sibling in data.get("siblings"):
			total += sibling.get("weight")
		var result = randi() % total
		var cummulative_weight = 0
		for sibling in data.siblings:
			if result < cummulative_weight + sibling.weight:
				data = local_resource.lines.get(sibling.id)
				break
			else:
				cummulative_weight += sibling.weight
	
	# Check condtiions
	elif data.get("type") == DialogueConstants.TYPE_CONDITION:
		# "else" will have no actual condition
		if data.get("condition") == null or check(data.get("condition")):
			return get_line(data.get("next_id") + id_trail, local_resource)
		else:
			return get_line(data.get("next_conditional_id") + id_trail, local_resource)
	
	# Evaluate jumps
	elif data.get("type") == DialogueConstants.TYPE_GOTO:
		if data.get("is_snippet"):
			id_trail = "," + data.get("next_id_after") + id_trail
		return get_line(data.get("next_id") + id_trail, local_resource)
	
	# Set up a line object
	var line = DialogueLine.new(data, auto_translate, self)
	line.next_id += id_trail
	
	# Add as a child so that it gets cleaned up automatically
	if line.get("type") != DialogueConstants.TYPE_MUTATION:
		_trash.add_child(line)
	
	# If we are the first of a list of responses then get the other ones
	if data.get("type") == DialogueConstants.TYPE_RESPONSE:
		line.responses = get_responses(data.get("responses"), local_resource, id_trail, line)
		return line
	
	# Replace any variables in the dialogue text
	if data.get("type") == DialogueConstants.TYPE_DIALOGUE and data.has("replacements"):
		line.character = get_with_replacements(line.character, line.character_replacements)
		line.dialogue = get_with_replacements(line.dialogue, line.replacements)
	
	# Inject the next node's responses if they have any
	var next_line = local_resource.lines.get(line.next_id)
	if next_line != null and next_line.get("type") == DialogueConstants.TYPE_RESPONSE:
		line.responses = get_responses(next_line.get("responses"), local_resource, id_trail, line)
	
	return line


func set_is_dialogue_running(is_running: bool) -> void:
	if is_dialogue_running != is_running:
		if is_running:
			emit_signal("dialogue_started")
		else:
			emit_signal("dialogue_finished")
			
	is_dialogue_running = is_running


func get_game_states() -> Array:
	var current_scene = get_tree().current_scene
	var unique_states = []
	for state in _extra_game_states + [current_scene] + game_states:
		if not unique_states.has(state):
			unique_states.append(state)
	return unique_states


# Check if a condition is met
func check(condition: Dictionary) -> bool:
	if condition.size() == 0: return true
	
	return resolve(condition.get("expression").duplicate(true))


# Make a change to game state or run a method
func mutate(mutation: Dictionary) -> void:
	assert(mutation != null and mutation.has("expression"), "Mutation is not valid. You might need to re-open the source dialogue file.")
	
	var expression = mutation.get("expression")
	
	# Handle built in mutations
	if expression[0].get("type") == DialogueConstants.TOKEN_FUNCTION and expression[0].get("function") in ["wait", "emit", "debug"]:
		var args = resolve_each(expression[0].get("value"))
		match expression[0].get("function"):
			"wait":
				yield(get_tree().create_timer(float(args[0])), "timeout")
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
		var result = resolve(mutation.get("expression").duplicate(true))
		if result is GDScriptFunctionState and result.is_valid():
			yield(result, "completed")
			return
		
	# Wait one frame to give the dialogue handler a chance to yield
	yield(get_tree(), "idle_frame")


func resolve_each(array: Array) -> Array:
	var results = []
	for item in array:
		results.append(resolve(item.duplicate(true)))
	return results
	

# Replace any variables, etc in the dialogue with their state values
func get_with_replacements(text: String, replacements: Array) -> String:
	for replacement in replacements:
		var value = resolve(replacement.get("expression").duplicate(true))
		text = text.replace(replacement.get("value_in_text"), str(value))
	
	# Resolve random groups
	var random_regex: RegEx = RegEx.new()
	random_regex.compile("\\[\\[(?<options>.*?)\\]\\]")
	for found in random_regex.search_all(text):
		var options = found.get_string("options").split("|")
		text = text.replace("[[%s]]" % found.get_string("options"), options[rand_range(0, options.size())])
	
	return text


# Replace an array of line IDs with their response prompts
func get_responses(ids: Array, local_resource: DialogueResource, id_trail: String, line: Node) -> Array:
	var responses: Array = []
	for id in ids:
		var data = local_resource.lines.get(id)
		if settings.get_runtime_value("include_all_responses", false) or data.get("condition") == null or check(data.get("condition")):
			var response = DialogueResponse.new(data, auto_translate)
			response.next_id += id_trail
			response.character = get_with_replacements(response.character, response.character_replacements)
			response.prompt = get_with_replacements(response.prompt, response.replacements)
			response.is_allowed = data.get("condition") == null or check(data.get("condition"))
			# Add as a child so that it gets cleaned up automatically
			line.add_child(response)
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
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				state[property] = value
				return
		elif has_property(state, property):
			state.set(property, value)
			return
	
	printerr("'%s' is not a property on any game states (%s)." % [property, str(get_game_states())])
	assert(false, "Missing property on current scene or game state. See Output for details.")


# Collapse any expressions
func resolve(tokens: Array):
	# Handle groups first
	for token in tokens:
		if token.get("type") == DialogueConstants.TOKEN_GROUP:
			token["type"] = "value"
			token["value"] = resolve(token.get("value"))
	
	# Then variables/methods
	var i = 0
	var limit = 0
	while i < tokens.size() and limit < 1000:
		var token = tokens[i]
		
		if token.get("type") == DialogueConstants.TOKEN_FUNCTION:
			var function_name = token.get("function")
			var args = resolve_each(token.get("value"))
			if function_name == "str":
				token["type"] = "value"
				token["value"] = str(args[0])
			elif tokens[i - 1].get("type") == DialogueConstants.TOKEN_DOT:
				# If we are calling a deeper function then we need to collapse the
				# value into the thing we are calling the function on
				var caller = tokens[i - 2]
				if not caller.get("value").has_method(function_name):
					printerr("\"%s\" is not a callable method on \"%s\"" % [function_name, str(caller)])
					assert(false, "Missing callable method on calling object. See Output for details.")
				caller["type"] = "value"
				caller["value"] = caller.get("value").callv(function_name, args)
				tokens.remove(i)
				tokens.remove(i-1)
				i -= 2
			else:
				var found = false
				for state in get_game_states():
					if state.has_method(function_name):
						token["type"] = "value"
						token["value"] = state.callv(function_name, args)
						found = true
				
				if not found:
					printerr("\"%s\" is not a method on any game states (%s)" % [function_name, str(get_game_states())])
					assert(false, "Missing function on current scene or game state. See Output for details.")
		
		elif token.get("type") == DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
			var value = get_state_value(token.get("variable"))
			var index = resolve(token.get("value"))
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
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
						printerr("Key \"%s\" not found in dictionary \"%s\"" % [str(index), token.get("variable")])
						assert(false, "Key not found in dictionary. See Output for details.")
			elif typeof(value) == TYPE_ARRAY:
				if tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
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
						printerr("Index %d out of bounds of array \"%s\"" % [index, token.get("variable")])
						assert(false, "Index out of bounds of array. See Output for details.")
		
		elif token.get("type") == DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE:
			var dictionary = tokens[i - 1]
			var index = resolve(token.get("value"))
			var value = dictionary.get("value")
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary["type"] = "dictionary"
					dictionary["key"] = index
					dictionary["value"] = value
					tokens.remove(i)
					i -= 1
				else:
					if dictionary.get("value").has(index):
						dictionary["value"] = value.get(index)
						tokens.remove(i)
						i -= 1
					else:
						printerr("Key \"%s\" not found in dictionary \"%s\"" % [str(index), value])
						assert(false, "Key not found in dictionary. See Output for details.")
			elif typeof(value) == TYPE_ARRAY:
				if tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary["type"] = "array"
					dictionary["value"] = value
					dictionary["key"] = index
					tokens.remove(i)
					i -= 1
				else:
					if index >= 0 and index < value.size():
						dictionary["value"] = value[index]
						tokens.remove(i)
						i -= 1
					else:
						printerr("Index %d out of bounds of array \"%s\"" % [index, value])
						assert(false, "Index out of bounds of array. See Output for details.")
		
		elif token.get("type") == DialogueConstants.TOKEN_ARRAY:
			token["type"] = "value"
			token["value"] = resolve_each(token.get("value"))
			
		elif token.get("type") == DialogueConstants.TOKEN_DICTIONARY:
			token["type"] = "value"
			var dictionary = {}
			for key in token.get("value").keys():
				var resolved_key = resolve([key])
				var resolved_value = resolve([token.get("value").get(key)])
				dictionary[resolved_key] = resolved_value
			token["value"] = dictionary
			
		elif token.get("type") == DialogueConstants.TOKEN_VARIABLE:
			if token.get("value") == "null":
				token["type"] = "value"
				token["value"] = null
			elif tokens[i - 1].get("type") == DialogueConstants.TOKEN_DOT:
				var caller = tokens[i - 2]
				var property = token.get("value")
				if tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					caller["type"] = "property"
					caller["property"] = property
				else:
					# If we are requesting a deeper property then we need to collapse the
					# value into the thing we are referencing from
					caller["type"] = "value"
					caller["value"] = caller.get("value").get(property)
				tokens.remove(i)
				tokens.remove(i-1)
				i -= 2
			elif tokens.size() > i + 1 and tokens[i + 1].get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
				# It's a normal variable but we will be assigning to it so don't resolve
				# it until everything after it has been resolved
				token["type"] = "variable"
			else:
				token["type"] = "value"
				token["value"] = get_state_value(token.get("value"))
		
		i += 1
	
	# Then multiply and divide
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == DialogueConstants.TOKEN_OPERATOR and token.get("value") in ["*", "/", "%"]:
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
		if token.get("type") == DialogueConstants.TOKEN_OPERATOR and token.get("value") in ["+", "-"]:
			token["type"] = "value"
			token["value"] = apply_operation(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
		
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Then negations
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == DialogueConstants.TOKEN_NOT:
			token["type"] = "value"
			token["value"] = not tokens[i+1].get("value")
			tokens.remove(i+1)
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
		if token.get("type") == DialogueConstants.TOKEN_COMPARISON:
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
		if token.get("type") == DialogueConstants.TOKEN_AND_OR:
			token["type"] = "value"
			token["value"] = apply_operation(token.get("value"), tokens[i-1].get("value"), tokens[i+1].get("value"))
			tokens.remove(i+1)
			tokens.remove(i-1)
			i -= 1
		i += 1
				
	if limit >= 1000:
		assert(false, "Something went wrong")
	
	# Lastly, resolve any assignments
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token = tokens[i]
		if token.get("type") == DialogueConstants.TOKEN_ASSIGNMENT:
			var lhs = tokens[i - 1]
			var value
			
			match lhs.get("type"):
				"variable":
					value = apply_operation(token.get("value"), get_state_value(lhs.get("value")), tokens[i+1].get("value"))
					set_state_value(lhs.get("value"), value)
				"property":
					value = apply_operation(token.get("value"), lhs.get("value").get(lhs.get("property")), tokens[i+1].get("value"))
					if typeof(lhs.get("value")) == TYPE_DICTIONARY:
						lhs.get("value")[lhs.get("property")] = value
					else:
						lhs.get("value").set(lhs.get("property"), value)
				"dictionary", "array":
					value = apply_operation(token.get("value"), lhs.get("value")[lhs.get("key")], tokens[i+1].get("value"))
					lhs.get("value")[lhs.get("key")] = value
				_:
					assert(false, "Left hand side of expression cannot be assigned to.")
			
			token["type"] = "value"
			token["value"] = value
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
func is_valid(line: DialogueLine) -> bool:
	if not line: 
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


func cleanup() -> void:
	for line in _trash.get_children():
		line.queue_free()
