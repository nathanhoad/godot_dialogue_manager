extends Node

signal got_dialogue(line)
signal mutated(mutation)
signal dialogue_ended(resource)
signal bridge_get_next_dialogue_line_completed(line)


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")
const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")
const DialogueResponse = preload("res://addons/dialogue_manager/dialogue_response.gd")

const SUPPORTED_ARRAY_METHODS = [
	"assign",
	"append",
	"append_array",
	"back",
	"count",
	"clear",
	"erase",
	"has",
	"insert",
	"is_empty",
	"max",
	"min",
	"pick_random",
	"pop_at",
	"pop_back",
	"pop_front",
	"push_back",
	"push_front",
	"remove_at",
	"reverse",
	"shuffle",
	"size",
	"sort"
]
const SUPPORTED_DICTIONARY_METHODS = ["has", "has_all", "get", "keys", "values", "size"]


enum MutationBehaviour {
	Wait,
	DoNotWait,
	Skip
}

enum TranslationSource {
	None,
	Guess,
	CSV,
	PO
}


# The list of globals that dialogue can query
var game_states: Array = []

# Allow dialogue to call singletons
var include_singletons: bool = true

# Manage translation behaviour
var translation_source: TranslationSource = TranslationSource.Guess

var _node_properties: Array = []


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
		# Ignore the dialogue manager
		if child.name == StringName("DialogueManager"): continue
		# Ignore the current main scene
		if get_tree().current_scene and child.name == get_tree().current_scene.name: continue
		# Add the node to our known autoloads
		autoloads[child.name] = child
	game_states = [autoloads]

	# Add any other state shortcuts from settings
	for node_name in DialogueSettings.get_setting("states", []):
		var state: Node = get_node_or_null("/root/" + node_name)
		if state:
			game_states.append(state)

	# Make the dialogue manager available as a singleton
	Engine.register_singleton("DialogueManager", self)


## Step through lines and run any mutations until we either hit some dialogue or the end of the conversation
func get_next_dialogue_line(resource: DialogueResource, key: String = "0", extra_game_states: Array = [], mutation_behaviour: MutationBehaviour = MutationBehaviour.Wait) -> DialogueLine:
	# You have to provide a valid dialogue resource
	assert(resource != null, DialogueConstants.translate("runtime.no_resource"))
	assert(resource.lines.size() > 0, DialogueConstants.translate("runtime.no_content").format({ file_path = resource.resource_path }))

	var dialogue: DialogueLine = await get_line(resource, key, extra_game_states)

	# If our dialogue is nothing then we hit the end
	if not is_valid(dialogue):
		dialogue_ended.emit(resource)
		return null

	# Run the mutation if it is one
	if dialogue.type == DialogueConstants.TYPE_MUTATION:
		var actual_next_id: String = dialogue.next_id.split(",")[0]
		match mutation_behaviour:
			MutationBehaviour.Wait:
				await mutate(dialogue.mutation, extra_game_states)
			MutationBehaviour.DoNotWait:
				mutate(dialogue.mutation, extra_game_states)
			MutationBehaviour.Skip:
				pass
		if actual_next_id in [DialogueConstants.ID_END_CONVERSATION, DialogueConstants.ID_NULL, null]:
			# End the conversation
			dialogue_ended.emit(resource)
			return null
		else:
			return await get_next_dialogue_line(resource, dialogue.next_id, extra_game_states, mutation_behaviour)
	else:
		got_dialogue.emit(dialogue)
		return dialogue


## Replace any variables, etc in the dialogue with their state values
func get_resolved_text(text: String, replacements: Array, extra_game_states: Array = []) -> String:
	# Resolve variables
	for replacement in replacements:
		var value = await resolve(replacement.expression.duplicate(true), extra_game_states)
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
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	parser.parse(text, "")
	var results: DialogueManagerParseResult = parser.get_data()
	var errors: Array[Dictionary] = parser.get_errors()
	parser.free()

	if errors.size() > 0:
		printerr(DialogueConstants.translate("runtime.errors").format({ count = errors.size() }))
		for error in errors:
			printerr(DialogueConstants.translate("runtime.error_detail").format({
				line = error.line_number + 1,
				message = DialogueConstants.get_error_message(error.error)
			}))
		assert(false, DialogueConstants.translate("runtime.errors_see_details").format({ count = errors.size() }))

	var resource: DialogueResource = DialogueResource.new()
	resource.titles = results.titles
	resource.character_names = results.character_names
	resource.lines = results.lines

	return resource


## Show the example balloon
func show_example_dialogue_balloon(resource: DialogueResource, title: String = "0", extra_game_states: Array = []) -> void:
	var ExampleBalloonScene = load("res://addons/dialogue_manager/example_balloon/example_balloon.tscn")
	var SmallExampleBalloonScene = load("res://addons/dialogue_manager/example_balloon/small_example_balloon.tscn")

	var is_small_window: bool = ProjectSettings.get_setting("display/window/size/viewport_width") < 400
	var balloon: Node = (SmallExampleBalloonScene if is_small_window else ExampleBalloonScene).instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(resource, title, extra_game_states)


### Dotnet bridge


func _bridge_get_next_dialogue_line(resource: DialogueResource, key: String, extra_game_states: Array = []) -> void:
	# dotnet needs at least one await tick of the signal gets called too quickly
	await get_tree().process_frame

	var line = await get_next_dialogue_line(resource, key, extra_game_states)
	bridge_get_next_dialogue_line_completed.emit(line)


### Helpers


# Get a line by its ID
func get_line(resource: DialogueResource, key: String, extra_game_states: Array) -> DialogueLine:
	key = key.strip_edges()

	# See if we were given a stack instead of just the one key
	var stack: Array = key.split("|")
	key = stack.pop_front()
	var id_trail: String = "" if stack.size() == 0 else "|" + "|".join(stack)

	# See if we just ended the conversation
	if key in [DialogueConstants.ID_END, DialogueConstants.ID_NULL, null]:
		if stack.size() > 0:
			return await get_line(resource, "|".join(stack), extra_game_states)
		else:
			return null
	elif key == DialogueConstants.ID_END_CONVERSATION:
		return null

	# See if it is a title
	if key.begins_with("~ "):
		key = key.substr(2)
	if resource.titles.has(key):
		key = resource.titles.get(key)

	# Key not found, just use the first title
	if not resource.lines.has(key):
		key = resource.first_title

	var data: Dictionary = resource.lines.get(key)

	# Check for weighted random lines
	if data.has("siblings"):
		var result = randi() % data.siblings.reduce(func(total, sibling): return total + sibling.weight, 0)
		var cummulative_weight = 0
		for sibling in data.siblings:
			if result < cummulative_weight + sibling.weight:
				data = resource.lines.get(sibling.id)
				break
			else:
				cummulative_weight += sibling.weight

	# Check condtiions
	elif data.type == DialogueConstants.TYPE_CONDITION:
		# "else" will have no actual condition
		if await check_condition(data, extra_game_states):
			return await get_line(resource, data.next_id + id_trail, extra_game_states)
		else:
			return await get_line(resource, data.next_conditional_id + id_trail, extra_game_states)

	# Evaluate jumps
	elif data.type == DialogueConstants.TYPE_GOTO:
		if data.is_snippet:
			id_trail = "|" + data.next_id_after + id_trail
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	# Set up a line object
	var line: DialogueLine = await create_dialogue_line(data, extra_game_states)

	# If we are the first of a list of responses then get the other ones
	if data.type == DialogueConstants.TYPE_RESPONSE:
		line.responses = await get_responses(data.responses, resource, id_trail, extra_game_states)
		return line

	# Inject the next node's responses if they have any
	if resource.lines.has(line.next_id):
		var next_line: Dictionary = resource.lines.get(line.next_id)
		if next_line != null and next_line.type == DialogueConstants.TYPE_RESPONSE:
			line.responses = await get_responses(next_line.responses, resource, id_trail, extra_game_states)

	line.next_id += id_trail
	return line


# Translate a string
func translate(data: Dictionary) -> String:
	if translation_source == TranslationSource.None:
		return data.text

	if data.translation_key == "" or data.translation_key == data.text:
		return tr(data.text)
	else:
		# Line IDs work slightly differently depending on whether the translation came from a
		# CSV or a PO file. CSVs use the line ID (or the line itself) as the translatable string
		# whereas POs use the ID as context and the line itself as the translatable string.
		match translation_source:
			TranslationSource.PO:
				return tr(data.text, StringName(data.translation_key))

			TranslationSource.CSV:
				return tr(data.translation_key)

			TranslationSource.Guess:
				var translation_files: Array = ProjectSettings.get_setting("internationalization/locale/translations")
				if translation_files.filter(func(f: String): return f.get_extension() == "po").size() > 0:
					# Assume PO
					return tr(data.text, StringName(data.translation_key))
				else:
					# Assume CSV
					return tr(data.translation_key)

	return tr(data.translation_key)


# Create a line of dialogue
func create_dialogue_line(data: Dictionary, extra_game_states: Array) -> DialogueLine:
	match data.type:
		DialogueConstants.TYPE_DIALOGUE:
			# Our bbcodes need to be process after text has been resolved so that the markers are at the correct index
			var text: String = await get_resolved_text(translate(data), data.text_replacements, extra_game_states)
			var markers: Dictionary = DialogueManagerParser.extract_markers_from_string(text)

			return DialogueLine.new({
				type = DialogueConstants.TYPE_DIALOGUE,
				next_id = data.next_id,
				character = await get_resolved_text(data.character, data.character_replacements, extra_game_states),
				character_replacements = data.character_replacements,
				text = markers.text,
				text_replacements = data.text_replacements,
				translation_key = data.translation_key,
				pauses = markers.pauses,
				speeds = markers.speeds,
				inline_mutations = markers.mutations,
				time = markers.time,
				extra_game_states = extra_game_states
			})

		DialogueConstants.TYPE_RESPONSE:
			return DialogueLine.new({
				type = DialogueConstants.TYPE_RESPONSE,
				next_id = data.next_id,
				extra_game_states = extra_game_states
			})

		DialogueConstants.TYPE_MUTATION:
			return DialogueLine.new({
				type = DialogueConstants.TYPE_MUTATION,
				next_id = data.next_id,
				mutation = data.mutation,
				extra_game_states = extra_game_states
			})

	return null


# Create a response
func create_response(data: Dictionary, extra_game_states: Array) -> DialogueResponse:
	return DialogueResponse.new({
		type = DialogueConstants.TYPE_RESPONSE,
		next_id = data.next_id,
		is_allowed = await check_condition(data, extra_game_states),
		text = await get_resolved_text(translate(data), data.text_replacements, extra_game_states),
		text_replacements = data.text_replacements,
		translation_key = data.translation_key
	})


# Get the current game states
func get_game_states(extra_game_states: Array) -> Array:
	var current_scene: Node = get_tree().current_scene
	var unique_states: Array = []
	for state in extra_game_states + [current_scene] + game_states:
		if state != null and not unique_states.has(state):
			unique_states.append(state)
	return unique_states


# Check if a condition is met
func check_condition(data: Dictionary, extra_game_states: Array) -> bool:
	if data.get("condition", null) == null: return true
	if data.condition.size() == 0: return true

	return await resolve(data.condition.expression.duplicate(true), extra_game_states)


# Make a change to game state or run a method
func mutate(mutation: Dictionary, extra_game_states: Array, is_inline_mutation: bool = false) -> void:
	var expression: Array[Dictionary] = mutation.expression

	# Handle built in mutations
	if expression[0].type == DialogueConstants.TOKEN_FUNCTION and expression[0].function in ["wait", "emit", "debug"]:
		var args: Array = await resolve_each(expression[0].value, extra_game_states)
		match expression[0].function:
			"wait":
				mutated.emit(mutation)
				await get_tree().create_timer(float(args[0])).timeout
				return

			"emit":
				for state in get_game_states(extra_game_states):
					if typeof(state) == TYPE_DICTIONARY:
						continue
					elif state.has_signal(args[0]):
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
						return

				# The signal hasn't been found anywhere
				assert(false, DialogueConstants.translate("runtime.signal_not_found").format({ signal_name = args[0], states = str(get_game_states(extra_game_states)) }))

			"debug":
				prints("Debug:", args)

	# Or pass through to the resolver
	else:
		if not mutation_contains_assignment(mutation.expression) and not is_inline_mutation:
			mutated.emit(mutation)

		await resolve(mutation.expression.duplicate(true), extra_game_states)
		return

	# Wait one frame to give the dialogue handler a chance to yield
	await get_tree().process_frame


func mutation_contains_assignment(mutation: Array) -> bool:
	for token in mutation:
		if token.type == DialogueConstants.TOKEN_ASSIGNMENT:
			return true
	return false


func resolve_each(array: Array, extra_game_states: Array) -> Array:
	var results: Array = []
	for item in array:
		results.append(await resolve(item.duplicate(true), extra_game_states))
	return results


# Replace an array of line IDs with their response prompts
func get_responses(ids: Array, resource: DialogueResource, id_trail: String, extra_game_states: Array) -> Array[DialogueResponse]:
	var responses: Array[DialogueResponse] = []
	for id in ids:
		var data: Dictionary = resource.lines.get(id)
		if DialogueSettings.get_setting("include_all_responses", false) or await check_condition(data, extra_game_states):
			var response: DialogueResponse = await create_response(data, extra_game_states)
			response.next_id += id_trail
			responses.append(response)

	return responses


# Get a value on the current scene or game state
func get_state_value(property: String, extra_game_states: Array):
	var expression = Expression.new()
	if expression.parse(property) != OK:
		assert(false, DialogueConstants.translate("runtime.invalid_expression").format({ expression = property, error = expression.get_error_text() }))

	for state in get_game_states(extra_game_states):
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				return state.get(property)
		else:
			var result = expression.execute([], state, false)
			if not expression.has_execute_failed():
				return result

	if include_singletons and Engine.has_singleton(property):
		return Engine.get_singleton(property)

	assert(false, DialogueConstants.translate("runtime.property_not_found").format({ property = property, states = str(get_game_states(extra_game_states)) }))


# Set a value on the current scene or game state
func set_state_value(property: String, value, extra_game_states: Array) -> void:
	for state in get_game_states(extra_game_states):
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				state[property] = value
				return
		elif thing_has_property(state, property):
			state.set(property, value)
			return

	assert(false, DialogueConstants.translate("runtime.property_not_found").format({ property = property, states = str(get_game_states(extra_game_states)) }))


# Collapse any expressions
func resolve(tokens: Array, extra_game_states: Array):
	# Handle groups first
	for token in tokens:
		if token.type == DialogueConstants.TOKEN_GROUP:
			token["type"] = "value"
			token["value"] = await resolve(token.value, extra_game_states)

	# Then variables/methods
	var i: int = 0
	var limit: int = 0
	while i < tokens.size() and limit < 1000:
		var token: Dictionary = tokens[i]

		if token.type == DialogueConstants.TOKEN_FUNCTION:
			var function_name: String = token.function
			var args = await resolve_each(token.value, extra_game_states)
			if function_name == "str":
				token["type"] = "value"
				token["value"] = str(args[0])
			elif tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				# If we are calling a deeper function then we need to collapse the
				# value into the thing we are calling the function on
				var caller: Dictionary = tokens[i - 2]
				if typeof(caller.value) == TYPE_DICTIONARY:
					caller["type"] = "value"
					caller["value"] = resolve_dictionary_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				elif typeof(caller.value) == TYPE_ARRAY:
					caller["type"] = "value"
					caller["value"] = resolve_array_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				elif thing_has_method(caller.value, function_name, args):
					caller["type"] = "value"
					caller["value"] = await caller.value.callv(function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				else:
					assert(false, DialogueConstants.translate("runtime.method_not_callable").format({ method = function_name, object = str(caller) }))
			else:
				var found: bool = false
				for state in get_game_states(extra_game_states):
					if typeof(state) == TYPE_DICTIONARY and function_name in SUPPORTED_DICTIONARY_METHODS:
						token["type"] = "value"
						token["value"] = resolve_dictionary_method(state, function_name, args)
						found = true
					elif typeof(state) == TYPE_ARRAY and function_name in SUPPORTED_ARRAY_METHODS:
						token["type"] = "value"
						token["value"] = resolve_array_method(state, function_name, args)
						found = true
					elif thing_has_method(state, function_name, args):
						token["type"] = "value"
						token["value"] = await state.callv(function_name, args)
						found = true

					if found:
						break

				if not found:
					assert(false, DialogueConstants.translate("runtime.method_not_found").format({
						method = args[0] if function_name in ["call", "call_deferred"] else function_name,
						states = str(get_game_states(extra_game_states))
					}))

		elif token.type == DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
			var value
			if i > 0 and tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				value = tokens[i - 2].value[token.variable]
			else:
				value = get_state_value(token.variable, extra_game_states)
			var index = await resolve(token.value, extra_game_states)
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
						assert(false, DialogueConstants.translate("runtime.key_not_found").format({ key = str(index), dictionary = token.variable }))
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
						assert(false, DialogueConstants.translate("runtime.array_index_out_of_bounds").format({ index = index, array = token.variable }))

		elif token.type == DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE:
			var dictionary: Dictionary = tokens[i - 1]
			var index = await resolve(token.value, extra_game_states)
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
						assert(false, DialogueConstants.translate("runtime.key_not_found").format({ key = str(index), dictionary = value }))
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
						assert(false, DialogueConstants.translate("runtime.array_index_out_of_bounds").format({ index = index, array = value }))

		elif token.type == DialogueConstants.TOKEN_ARRAY:
			token["type"] = "value"
			token["value"] = await resolve_each(token.value, extra_game_states)

		elif token.type == DialogueConstants.TOKEN_DICTIONARY:
			token["type"] = "value"
			var dictionary = {}
			for key in token.value.keys():
				var resolved_key = await resolve([key], extra_game_states)
				var resolved_value = await resolve([token.value.get(key)], extra_game_states)
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
				token["value"] = get_state_value(token.value, extra_game_states)

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
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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
					value = apply_operation(token.value, get_state_value(lhs.value, extra_game_states), tokens[i+1].value)
					set_state_value(lhs.value, value, extra_game_states)
				"property":
					value = apply_operation(token.value, lhs.value.get(lhs.property), tokens[i+1].value)
					if typeof(lhs.value) == TYPE_DICTIONARY:
						lhs.value[lhs.property] = value
					else:
						lhs.value.set(lhs.property, value)
				"dictionary":
					value = apply_operation(token.value, lhs.value.get(lhs.key, null), tokens[i+1].value)
					lhs.value[lhs.key] = value
				"array":
					assert(lhs.key < lhs.value.size(), DialogueConstants.translate("runtime.array_index_out_of_bounds").format({ index = lhs.key, array = lhs.value }))
					value = apply_operation(token.value, lhs.value[lhs.key], tokens[i+1].value)
					lhs.value[lhs.key] = value
				_:
					assert(false, DialogueConstants.translate("runtime.left_hand_size_cannot_be_assigned_to"))

			token["type"] = "value"
			token["value"] = value
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DialogueConstants.translate("runtime.something_went_wrong"))

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

	assert(false, DialogueConstants.translate("runtime.unknown_operator"))


# Check if a dialogue line contains meaningful information
func is_valid(line: DialogueLine) -> bool:
	if line == null:
		return false
	if line.type == DialogueConstants.TYPE_MUTATION and line.mutation == null:
		return false
	if line.type == DialogueConstants.TYPE_RESPONSE and line.responses.size() == 0:
		return false
	return true


func thing_has_method(thing, method: String, args: Array) -> bool:
	match typeof(thing):
		TYPE_DICTIONARY:
			return method in SUPPORTED_DICTIONARY_METHODS
		TYPE_ARRAY:
			return method in SUPPORTED_ARRAY_METHODS

	if method in ["call", "call_deferred"]:
		return thing.has_method(args[0])
	else:
		return thing.has_method(method)


# Check if a given property exists
func thing_has_property(thing: Object, property: String) -> bool:
	if thing == null:
		return false

	for p in thing.get_property_list():
		if _node_properties.has(p.name):
			# Ignore any properties on the base Node
			continue
		if p.name == property:
			return true

	return false


func resolve_array_method(array: Array, method_name: String, args: Array):
	match method_name:
		"assign":
			array.assign(args[0])
			return null
		"append":
			array.append(args[0])
			return null
		"append_array":
			array.append_array(args[0])
			return null
		"back":
			return array.back()
		"count":
			return array.count(args[0])
		"clear":
			array.clear()
			return null
		"erase":
			array.erase(args[0])
		"has":
			return array.has(args[0])
		"insert":
			return array.insert(args[0], args[1])
		"is_empty":
			return array.is_empty()
		"max":
			return array.max()
		"min":
			return array.min()
		"pick_random":
			return array.pick_random()
		"pop_at":
			return array.pop_at(args[0])
		"pop_back":
			return array.pop_back()
		"pop_front":
			return array.pop_front()
		"push_back":
			array.push_back(args[0])
			return null
		"push_front":
			array.push_front(args[0])
			return null
		"remove_at":
			array.remove_at(args[0])
			return null
		"reverse":
			array.reverse()
			return null
		"shuffle":
			array.shuffle()
			return null
		"size":
			return array.size()
		"sort":
			array.sort()
			return null

	assert(false, DialogueConstants.translate("runtime.unsupported_array_method").format({ method_name = method_name }))


func resolve_dictionary_method(dictionary: Dictionary, method_name: String, args: Array):
	match method_name:
		"has":
			return dictionary.has(args[0])
		"has_all":
			return dictionary.has_all(args[0])
		"get":
			return dictionary.get(args[0])
		"keys":
			return dictionary.keys()
		"values":
			return dictionary.values()
		"size":
			return dictionary.size()

	assert(false, DialogueConstants.translate("runtime.unsupported_dictionary_method").format({ method_name = method_name }))
