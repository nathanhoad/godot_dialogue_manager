extends Node


const DialogueConstants = preload("./constants.gd")
const Builtins = preload("./utilities/builtins.gd")
const DialogueSettings = preload("./settings.gd")
const DialogueResource = preload("./dialogue_resource.gd")
const DialogueLine = preload("./dialogue_line.gd")
const DialogueResponse = preload("./dialogue_response.gd")
const DialogueManagerParser = preload("./components/parser.gd")
const DialogueManagerParseResult = preload("./components/parse_result.gd")
const ResolvedLineData = preload("./components/resolved_line_data.gd")


## Emitted when a title is encountered while traversing dialogue, usually when jumping from a
## goto line
signal passed_title(title: String)

## Emitted when a line of dialogue is encountered.
signal got_dialogue(line: DialogueLine)

## Emitted when a mutation is encountered.
signal mutated(mutation: Dictionary)

## Emitted when some dialogue has reached the end.
signal dialogue_ended(resource: DialogueResource)

## Used internally.
signal bridge_get_next_dialogue_line_completed(line: DialogueLine)

## Used inernally
signal bridge_mutated()


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


## The list of globals that dialogue can query
var game_states: Array = []

## Allow dialogue to call singletons
var include_singletons: bool = true

## Allow dialogue to call static methods/properties on classes
var include_classes: bool = true

## Manage translation behaviour
var translation_source: TranslationSource = TranslationSource.Guess

## Used to resolve the current scene. Override if your game manages the current scene itself.
var get_current_scene: Callable = func():
	var current_scene: Node = Engine.get_main_loop().current_scene
	if current_scene == null:
		current_scene = Engine.get_main_loop().root.get_child(Engine.get_main_loop().root.get_child_count() - 1)
	return current_scene

var _has_loaded_autoloads: bool = false
var _autoloads: Dictionary = {}

var _node_properties: Array = []
var _method_info_cache: Dictionary = {}


func _ready() -> void:
	# Cache the known Node2D properties
	_node_properties = ["Script Variables"]
	var temp_node: Node2D = Node2D.new()
	for property in temp_node.get_property_list():
		_node_properties.append(property.name)
	temp_node.free()

	# Make the dialogue manager available as a singleton
	if Engine.has_singleton("DialogueManager"):
		Engine.unregister_singleton("DialogueManager")
	Engine.register_singleton("DialogueManager", self)

	# Connect up the C# signals if need be
	if DialogueSettings.check_for_dotnet_solution():
		_get_dotnet_dialogue_manager().Prepare()


## Step through lines and run any mutations until we either hit some dialogue or the end of the conversation
func get_next_dialogue_line(resource: DialogueResource, key: String = "", extra_game_states: Array = [], mutation_behaviour: MutationBehaviour = MutationBehaviour.Wait) -> DialogueLine:
	# You have to provide a valid dialogue resource
	if resource == null:
		assert(false, DialogueConstants.translate(&"runtime.no_resource"))
	if resource.lines.size() == 0:
		assert(false, DialogueConstants.translate(&"runtime.no_content").format({ file_path = resource.resource_path }))

	# Inject any "using" states into the game_states
	for state_name in resource.using_states:
		var autoload = Engine.get_main_loop().root.get_node_or_null(state_name)
		if autoload == null:
			printerr(DialogueConstants.translate(&"runtime.unknown_autoload").format({ autoload = state_name }))
		else:
			extra_game_states = [autoload] + extra_game_states

	# Get the line data
	var dialogue: DialogueLine = await get_line(resource, key, extra_game_states)

	# If our dialogue is nothing then we hit the end
	if not is_valid(dialogue):
		(func(): dialogue_ended.emit(resource)).call_deferred()
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
			(func(): dialogue_ended.emit(resource)).call_deferred()
			return null
		else:
			return await get_next_dialogue_line(resource, dialogue.next_id, extra_game_states, mutation_behaviour)
	else:
		got_dialogue.emit(dialogue)
		return dialogue


func get_resolved_line_data(data: Dictionary, extra_game_states: Array = []) -> ResolvedLineData:
	var text: String = translate(data)

	# Resolve variables
	for replacement in data.text_replacements:
		var value = await resolve(replacement.expression.duplicate(true), extra_game_states)
		var index: int = text.find(replacement.value_in_text)
		if index > -1:
			text = text.substr(0, index) + str(value) + text.substr(index + replacement.value_in_text.length())

	var parser: DialogueManagerParser = DialogueManagerParser.new()

	# Resolve random groups
	for found in parser.INLINE_RANDOM_REGEX.search_all(text):
		var options = found.get_string(&"options").split(&"|")
		text = text.replace(&"[[%s]]" % found.get_string(&"options"), options[randi_range(0, options.size() - 1)])

	# Do a pass on the markers to find any conditionals
	var markers: ResolvedLineData = parser.extract_markers(text)

	# Resolve any conditionals and update marker positions as needed
	if data.type == DialogueConstants.TYPE_DIALOGUE:
		var resolved_text: String = markers.text
		var conditionals: Array[RegExMatch] = parser.INLINE_CONDITIONALS_REGEX.search_all(resolved_text)
		var replacements: Array = []
		for conditional in conditionals:
			var condition_raw: String = conditional.strings[conditional.names.condition]
			var body: String = conditional.strings[conditional.names.body]
			var body_else: String = ""
			if &"[else]" in body:
				var bits = body.split(&"[else]")
				body = bits[0]
				body_else = bits[1]
			var condition: Dictionary = parser.extract_condition("if " + condition_raw, false, 0)
			# If the condition fails then use the else of ""
			if not await check_condition({ condition = condition }, extra_game_states):
				body = body_else
			replacements.append({
				start = conditional.get_start(),
				end = conditional.get_end(),
				string = conditional.get_string(),
				body = body
			})

		for i in range(replacements.size() -1, -1, -1):
			var r: Dictionary = replacements[i]
			resolved_text = resolved_text.substr(0, r.start) + r.body + resolved_text.substr(r.end, 9999)
			# Move any other markers now that the text has changed
			var offset: int = r.end - r.start - r.body.length()
			for key in [&"pauses", &"speeds", &"time"]:
				if markers.get(key) == null: continue
				var marker = markers.get(key)
				var next_marker: Dictionary = {}
				for index in marker:
					if index < r.start:
						next_marker[index] = marker[index]
					elif index > r.start:
						next_marker[index - offset] = marker[index]
				markers.set(key, next_marker)
			var mutations: Array[Array] = markers.mutations
			var next_mutations: Array[Array] = []
			for mutation in mutations:
				var index = mutation[0]
				if index < r.start:
					next_mutations.append(mutation)
				elif index > r.start:
					next_mutations.append([index - offset, mutation[1]])
			markers.mutations = next_mutations

		markers.text = resolved_text

	parser.free()

	return markers


## Replace any variables, etc in the character name
func get_resolved_character(data: Dictionary, extra_game_states: Array = []) -> String:
	var character: String = data.get(&"character", "")

	# Resolve variables
	for replacement in data.get(&"character_replacements", []):
		var value = await resolve(replacement.expression.duplicate(true), extra_game_states)
		var index: int = character.find(replacement.value_in_text)
		if index > -1:
			character = character.substr(0, index) + str(value) + character.substr(index + replacement.value_in_text.length())

	# Resolve random groups
	var random_regex: RegEx = RegEx.new()
	random_regex.compile("\\[\\[(?<options>.*?)\\]\\]")
	for found in random_regex.search_all(character):
		var options = found.get_string(&"options").split("|")
		character = character.replace("[[%s]]" % found.get_string(&"options"), options[randi_range(0, options.size() - 1)])

	return character


## Generate a dialogue resource on the fly from some text
func create_resource_from_text(text: String) -> Resource:
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	parser.parse(text, "")
	var results: DialogueManagerParseResult = parser.get_data()
	var errors: Array[Dictionary] = parser.get_errors()
	parser.free()

	if errors.size() > 0:
		printerr(DialogueConstants.translate(&"runtime.errors").format({ count = errors.size() }))
		for error in errors:
			printerr(DialogueConstants.translate(&"runtime.error_detail").format({
				line = error.line_number + 1,
				message = DialogueConstants.get_error_message(error.error)
			}))
		assert(false, DialogueConstants.translate(&"runtime.errors_see_details").format({ count = errors.size() }))

	var resource: DialogueResource = DialogueResource.new()
	resource.using_states = results.using_states
	resource.titles = results.titles
	resource.first_title = results.first_title
	resource.character_names = results.character_names
	resource.lines = results.lines
	resource.raw_text = text

	return resource


## Show the example balloon
func show_example_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> CanvasLayer:
	var balloon: Node = load(_get_example_balloon_path()).instantiate()
	get_current_scene.call().add_child(balloon)
	balloon.start(resource, title, extra_game_states)

	return balloon


## Show the configured dialogue balloon
func show_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> Node:
	var balloon_path: String = DialogueSettings.get_setting(&"balloon_path", _get_example_balloon_path())
	if not ResourceLoader.exists(balloon_path):
		balloon_path = _get_example_balloon_path()
	return show_dialogue_balloon_scene(balloon_path, resource, title, extra_game_states)


## Show a given balloon scene
func show_dialogue_balloon_scene(balloon_scene, resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> Node:
	if balloon_scene is String:
		balloon_scene = load(balloon_scene)
	if balloon_scene is PackedScene:
		balloon_scene = balloon_scene.instantiate()

	var balloon: Node = balloon_scene
	get_current_scene.call().add_child.call_deferred(balloon)
	if balloon.has_method(&"start"):
		balloon.start(resource, title, extra_game_states)
	elif balloon.has_method(&"Start"):
		balloon.Start(resource, title, extra_game_states)
	else:
		assert(false, DialogueConstants.translate(&"runtime.dialogue_balloon_missing_start_method"))
	return balloon


# Get the path to the example balloon
func _get_example_balloon_path() -> String:
	var is_small_window: bool = ProjectSettings.get_setting("display/window/size/viewport_width") < 400
	var balloon_path: String = "/example_balloon/small_example_balloon.tscn" if is_small_window else "/example_balloon/example_balloon.tscn"
	return get_script().resource_path.get_base_dir() + balloon_path


### Dotnet bridge


func _get_dotnet_dialogue_manager() -> Node:
	return load(get_script().resource_path.get_base_dir() + "/DialogueManager.cs").new()


func _bridge_get_new_instance() -> Node:
	return new()


func _bridge_get_next_dialogue_line(resource: DialogueResource, key: String, extra_game_states: Array = []) -> void:
	# dotnet needs at least one await tick of the signal gets called too quickly
	await Engine.get_main_loop().process_frame

	var line = await get_next_dialogue_line(resource, key, extra_game_states)
	bridge_get_next_dialogue_line_completed.emit(line)


func _bridge_mutate(mutation: Dictionary, extra_game_states: Array, is_inline_mutation: bool = false) -> void:
	await mutate(mutation, extra_game_states, is_inline_mutation)
	bridge_mutated.emit()


### Helpers


# Get a line by its ID
func get_line(resource: DialogueResource, key: String, extra_game_states: Array) -> DialogueLine:
	key = key.strip_edges()

	# See if we were given a stack instead of just the one key
	var stack: Array = key.split("|")
	key = stack.pop_front()
	var id_trail: String = "" if stack.size() == 0 else "|" + "|".join(stack)

	# Key is blank so just use the first title
	if key == null or key == "":
		key = resource.first_title

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

	if key in resource.titles.values():
		passed_title.emit(resource.titles.find_key(key))

	if not resource.lines.has(key):
		assert(false, DialogueConstants.translate(&"errors.key_not_found").format({ key = key }))

	var data: Dictionary = resource.lines.get(key)

	# This title key points to another title key so we should jump there instead
	if data.type == DialogueConstants.TYPE_TITLE and data.next_id in resource.titles.values():
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	# Check for weighted random lines
	if data.has(&"siblings"):
		# Only count siblings that pass their condition (if they have one)
		var successful_siblings: Array = data.siblings.filter(func(sibling): return not sibling.has("condition") or await check_condition(sibling, extra_game_states))
		var target_weight: float = randf_range(0, successful_siblings.reduce(func(total, sibling): return total + sibling.weight, 0))
		var cummulative_weight: float = 0
		for sibling in successful_siblings:
			if target_weight < cummulative_weight + sibling.weight:
				data = resource.lines.get(sibling.id)
				break
			else:
				cummulative_weight += sibling.weight

	# Check condtiions
	if data.type == DialogueConstants.TYPE_CONDITION:
		# "else" will have no actual condition
		if await check_condition(data, extra_game_states):
			return await get_line(resource, data.next_id + id_trail, extra_game_states)
		else:
			return await get_line(resource, data.next_conditional_id + id_trail, extra_game_states)

	# Evaluate jumps
	elif data.type == DialogueConstants.TYPE_GOTO:
		if data.is_snippet and not id_trail.begins_with("|" + data.next_id_after):
			id_trail = "|" + data.next_id_after + id_trail
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	elif data.type == DialogueConstants.TYPE_DIALOGUE:
		if not data.has(&"id"):
			data.id = key

	# Set up a line object
	var line: DialogueLine = await create_dialogue_line(data, extra_game_states)

	# If the jump point somehow has no content then just end
	if not line: return null

	# If we are the first of a list of responses then get the other ones
	if data.type == DialogueConstants.TYPE_RESPONSE:
		# Note: For some reason C# has occasional issues with using the responses property directly
		# so instead we use set and get here.
		line.set(&"responses", await get_responses(data.get(&"responses", []), resource, id_trail, extra_game_states))
		return line

	# Inject the next node's responses if they have any
	if resource.lines.has(line.next_id):
		var next_line: Dictionary = resource.lines.get(line.next_id)

		# If the response line is marked as a title then make sure to emit the passed_title signal.
		if line.next_id in resource.titles.values():
			passed_title.emit(resource.titles.find_key(line.next_id))

		# If the responses come from a snippet then we need to come back here afterwards
		if next_line.type == DialogueConstants.TYPE_GOTO and next_line.is_snippet and not id_trail.begins_with("|" + next_line.next_id_after):
			id_trail = "|" + next_line.next_id_after + id_trail

		# If the next line is a title then check where it points to see if that is a set of responses.
		while [DialogueConstants.TYPE_TITLE, DialogueConstants.TYPE_GOTO].has(next_line.type) and resource.lines.has(next_line.next_id):
			next_line = resource.lines.get(next_line.next_id)

		if next_line != null and next_line.type == DialogueConstants.TYPE_RESPONSE:
			# Note: For some reason C# has occasional issues with using the responses property directly
			# so instead we use set and get here.
			line.set(&"responses", await get_responses(next_line.get(&"responses", []), resource, id_trail, extra_game_states))

	line.next_id = "|".join(stack) if line.next_id == DialogueConstants.ID_NULL else line.next_id + id_trail
	return line


# Show a message or crash with error
func show_error_for_missing_state_value(message: String, will_show: bool = true) -> void:
	if not will_show: return

	if DialogueSettings.get_setting(&"ignore_missing_state_values", false):
		push_error(message)
	elif will_show:
		# If you're here then you're missing a method or property in your game state. The error
		# message down in the debugger will give you some more information.
		assert(false, message)


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
				var translation_files: Array = ProjectSettings.get_setting(&"internationalization/locale/translations")
				if translation_files.filter(func(f: String): return f.get_extension() in [&"po", &"mo"]).size() > 0:
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
			var resolved_data: ResolvedLineData = await get_resolved_line_data(data, extra_game_states)
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DialogueConstants.TYPE_DIALOGUE,
				next_id = data.next_id,
				character = await get_resolved_character(data, extra_game_states),
				character_replacements = data.character_replacements,
				text = resolved_data.text,
				text_replacements = data.text_replacements,
				translation_key = data.translation_key,
				pauses = resolved_data.pauses,
				speeds = resolved_data.speeds,
				inline_mutations = resolved_data.mutations,
				time = resolved_data.time,
				tags = data.get(&"tags", []),
				extra_game_states = extra_game_states
			})

		DialogueConstants.TYPE_RESPONSE:
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DialogueConstants.TYPE_RESPONSE,
				next_id = data.next_id,
				tags = data.get(&"tags", []),
				extra_game_states = extra_game_states
			})

		DialogueConstants.TYPE_MUTATION:
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DialogueConstants.TYPE_MUTATION,
				next_id = data.next_id,
				mutation = data.mutation,
				extra_game_states = extra_game_states
			})

	return null


# Create a response
func create_response(data: Dictionary, extra_game_states: Array) -> DialogueResponse:
	var resolved_data: ResolvedLineData = await get_resolved_line_data(data, extra_game_states)
	return DialogueResponse.new({
		id = data.get(&"id", ""),
		type = DialogueConstants.TYPE_RESPONSE,
		next_id = data.next_id,
		is_allowed = data.is_allowed,
		character = await get_resolved_character(data, extra_game_states),
		character_replacements = data.get(&"character_replacements", [] as Array[Dictionary]),
		text = resolved_data.text,
		text_replacements = data.text_replacements,
		tags = data.get(&"tags", []),
		translation_key = data.translation_key
	})


# Get the current game states
func get_game_states(extra_game_states: Array) -> Array:
	if not _has_loaded_autoloads:
		_has_loaded_autoloads = true
		# Add any autoloads to a generic state so we can refer to them by name
		for child in Engine.get_main_loop().root.get_children():
			# Ignore the dialogue manager
			if child.name == &"DialogueManager": continue
			# Ignore the current main scene
			if Engine.get_main_loop().current_scene and child.name == Engine.get_main_loop().current_scene.name: continue
			# Add the node to our known autoloads
			_autoloads[child.name] = child
		game_states = [_autoloads]
		# Add any other state shortcuts from settings
		for node_name in DialogueSettings.get_setting(&"states", []):
			var state: Node = Engine.get_main_loop().root.get_node_or_null(node_name)
			if state:
				game_states.append(state)

	var current_scene: Node = get_current_scene.call()
	var unique_states: Array = []
	for state in extra_game_states + [current_scene] + game_states:
		if state != null and not unique_states.has(state):
			unique_states.append(state)
	return unique_states


# Check if a condition is met
func check_condition(data: Dictionary, extra_game_states: Array) -> bool:
	if data.get(&"condition", null) == null: return true
	if data.condition.is_empty(): return true

	return await resolve(data.condition.expression.duplicate(true), extra_game_states)


# Make a change to game state or run a method
func mutate(mutation: Dictionary, extra_game_states: Array, is_inline_mutation: bool = false) -> void:
	var expression: Array[Dictionary] = mutation.expression

	# Handle built in mutations
	if expression[0].type == DialogueConstants.TOKEN_FUNCTION and expression[0].function in [&"wait", &"debug"]:
		var args: Array = await resolve_each(expression[0].value, extra_game_states)
		match expression[0].function:
			&"wait":
				mutated.emit(mutation)
				await Engine.get_main_loop().create_timer(float(args[0])).timeout
				return

			&"debug":
				prints("Debug:", args)
				await Engine.get_main_loop().process_frame

	# Or pass through to the resolver
	else:
		if not mutation_contains_assignment(mutation.expression) and not is_inline_mutation:
			mutated.emit(mutation)

		if mutation.get("is_blocking", true):
			await resolve(mutation.expression.duplicate(true), extra_game_states)
			return
		else:
			resolve(mutation.expression.duplicate(true), extra_game_states)

	# Wait one frame to give the dialogue handler a chance to yield
	await Engine.get_main_loop().process_frame


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
		var data: Dictionary = resource.lines.get(id).duplicate(true)
		data.is_allowed = await check_condition(data, extra_game_states)
		if DialogueSettings.get_setting(&"include_all_responses", false) or data.is_allowed:
			var response: DialogueResponse = await create_response(data, extra_game_states)
			response.next_id += id_trail
			responses.append(response)

	return responses


# Get a value on the current scene or game state
func get_state_value(property: String, extra_game_states: Array):
	# Special case for static primitive calls
	if property == "Color":
		return Color()
	elif property == "Vector2":
		return Vector2.ZERO
	elif property == "Vector3":
		return Vector3.ZERO
	elif property == "Vector4":
		return Vector4.ZERO
	elif property == "Quaternion":
		return Quaternion()

	var expression = Expression.new()
	if expression.parse(property) != OK:
		assert(false, DialogueConstants.translate(&"runtime.invalid_expression").format({ expression = property, error = expression.get_error_text() }))

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

	if include_classes:
		for class_data in ProjectSettings.get_global_class_list():
			if class_data.get(&"class") == property:
				return load(class_data.path).new()

	show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.property_not_found").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))


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

	if property.to_snake_case() != property:
		show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.property_not_found_missing_export").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))
	else:
		show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.property_not_found").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))


# Get the list of state shortcut names
func _get_state_shortcut_names(extra_game_states: Array) -> String:
	var states = get_game_states(extra_game_states)
	states.erase(_autoloads)
	return ", ".join(states.map(func(s): return "\"%s\"" % (s.name if "name" in s else s)))


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
		limit += 1
		var token: Dictionary = tokens[i]

		if token.type == DialogueConstants.TOKEN_FUNCTION:
			var function_name: String = token.function
			var args = await resolve_each(token.value, extra_game_states)
			if tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				# If we are calling a deeper function then we need to collapse the
				# value into the thing we are calling the function on
				var caller: Dictionary = tokens[i - 2]
				if Builtins.is_supported(caller.value):
					caller["type"] = "value"
					caller["value"] = Builtins.resolve_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				elif thing_has_method(caller.value, function_name, args):
					caller["type"] = "value"
					caller["value"] = await resolve_thing_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i-1)
					i -= 2
				else:
					show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.method_not_callable").format({ method = function_name, object = str(caller.value) }))
			else:
				var found: bool = false
				match function_name:
					&"str":
						token["type"] = "value"
						token["value"] = str(args[0])
						found = true
					&"Vector2":
						token["type"] = "value"
						token["value"] = Vector2(args[0], args[1])
						found = true
					&"Vector2i":
						token["type"] = "value"
						token["value"] = Vector2i(args[0], args[1])
						found = true
					&"Vector3":
						token["type"] = "value"
						token["value"] = Vector3(args[0], args[1], args[2])
						found = true
					&"Vector3i":
						token["type"] = "value"
						token["value"] = Vector3i(args[0], args[1], args[2])
						found = true
					&"Vector4":
						token["type"] = "value"
						token["value"] = Vector4(args[0], args[1], args[2], args[3])
						found = true
					&"Vector4i":
						token["type"] = "value"
						token["value"] = Vector4i(args[0], args[1], args[2], args[3])
						found = true
					&"Quaternion":
						token["type"] = "value"
						token["value"] = Quaternion(args[0], args[1], args[2], args[3])
						found = true
					&"Callable":
						token["type"] = "value"
						match args.size():
							0:
								token["value"] = Callable()
							1:
								token["value"] = Callable(args[0])
							2:
								token["value"] = Callable(args[0], args[1])
						found = true
					&"Color":
						token["type"] = "value"
						match args.size():
							0:
								token["value"] = Color()
							1:
								token["value"] = Color(args[0])
							2:
								token["value"] = Color(args[0], args[1])
							3:
								token["value"] = Color(args[0], args[1], args[2])
							4:
								token["value"] = Color(args[0], args[1], args[2], args[3])
						found = true
					&"load":
						token["type"] = "value"
						token["value"] = load(args[0])
						found = true
					&"emit":
						token["type"] = "value"
						token["value"] = resolve_signal(args, extra_game_states)
						found = true
					_:
						for state in get_game_states(extra_game_states):
							if thing_has_method(state, function_name, args):
								token["type"] = "value"
								token["value"] = await resolve_thing_method(state, function_name, args)
								found = true
								break

				show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.method_not_found").format({
					method = args[0] if function_name in ["call", "call_deferred"] else function_name,
					states = _get_state_shortcut_names(extra_game_states)
				}), not found)

		elif token.type == DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
			var value
			if i > 0 and tokens[i - 1].type == DialogueConstants.TOKEN_DOT:
				# If we are deep referencing then we need to get the parent object.
				# `parent.value` is the actual object and `token.variable` is the name of
				# the property within it.
				value = tokens[i - 2].value[token.variable]
				# Clean up the previous tokens
				token.erase("variable")
				tokens.remove_at(i - 1)
				tokens.remove_at(i - 2)
				i -= 2
			else:
				# Otherwise we can just get this variable as a normal state reference
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
						show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.key_not_found").format({ key = str(index), dictionary = token.variable }))
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
						show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = index, array = token.variable }))

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
						show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.key_not_found").format({ key = str(index), dictionary = value }))
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
						show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = index, array = value }))

		elif token.type == DialogueConstants.TOKEN_ARRAY:
			token["type"] = "value"
			token["value"] = await resolve_each(token.value, extra_game_states)

		elif token.type == DialogueConstants.TOKEN_DICTIONARY:
			token["type"] = "value"
			var dictionary = {}
			for key in token.value.keys():
				var resolved_key = await resolve([key], extra_game_states)
				var preresolved_value = token.value.get(key)
				if typeof(preresolved_value) != TYPE_ARRAY:
					preresolved_value = [preresolved_value]
				var resolved_value = await resolve(preresolved_value, extra_game_states)
				dictionary[resolved_key] = resolved_value
			token["value"] = dictionary

		elif token.type == DialogueConstants.TOKEN_VARIABLE or token.type == DialogueConstants.TOKEN_NUMBER:
			if str(token.value) == "null":
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
					if Builtins.is_supported(caller.value):
						caller["value"] = Builtins.resolve_property(caller.value, property)
					else:
						caller["value"] = caller.value.get(property)
				tokens.remove_at(i)
				tokens.remove_at(i-1)
				i -= 2
			elif tokens.size() > i + 1 and tokens[i + 1].type == DialogueConstants.TOKEN_ASSIGNMENT:
				# It's a normal variable but we will be assigning to it so don't resolve
				# it until everything after it has been resolved
				token["type"] = "variable"
			else:
				if token.type == DialogueConstants.TOKEN_NUMBER:
					token["type"] = "value"
					token["value"] = token.value
				else:
					token["type"] = "value"
					token["value"] = get_state_value(str(token.value), extra_game_states)

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
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

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
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

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
				&"variable":
					value = apply_operation(token.value, get_state_value(lhs.value, extra_game_states), tokens[i+1].value)
					set_state_value(lhs.value, value, extra_game_states)
				&"property":
					value = apply_operation(token.value, lhs.value.get(lhs.property), tokens[i+1].value)
					if typeof(lhs.value) == TYPE_DICTIONARY:
						lhs.value[lhs.property] = value
					else:
						lhs.value.set(lhs.property, value)
				&"dictionary":
					value = apply_operation(token.value, lhs.value.get(lhs.key, null), tokens[i+1].value)
					lhs.value[lhs.key] = value
				&"array":
					show_error_for_missing_state_value(
						DialogueConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = lhs.key, array = lhs.value }),
						lhs.key >= lhs.value.size()
					)
					value = apply_operation(token.value, lhs.value[lhs.key], tokens[i+1].value)
					lhs.value[lhs.key] = value
				_:
					show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.left_hand_size_cannot_be_assigned_to"))

			token["type"] = "value"
			token["value"] = value
			tokens.remove_at(i+1)
			tokens.remove_at(i-1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DialogueConstants.translate(&"runtime.something_went_wrong"))

	return tokens[0].value


func compare(operator: String, first_value, second_value) -> bool:
	match operator:
		&"in":
			if first_value == null or second_value == null:
				return false
			else:
				return first_value in second_value
		&"<":
			if first_value == null:
				return true
			elif second_value == null:
				return false
			else:
				return first_value < second_value
		&">":
			if first_value == null:
				return false
			elif second_value == null:
				return true
			else:
				return first_value > second_value
		&"<=":
			if first_value == null:
				return true
			elif second_value == null:
				return false
			else:
				return first_value <= second_value
		&">=":
			if first_value == null:
				return false
			elif second_value == null:
				return true
			else:
				return first_value >= second_value
		&"==":
			if first_value == null:
				if typeof(second_value) == TYPE_BOOL:
					return second_value == false
				else:
					return second_value == null
			else:
				return first_value == second_value
		&"!=":
			if first_value == null:
				if typeof(second_value) == TYPE_BOOL:
					return second_value == true
				else:
					return second_value != null
			else:
				return first_value != second_value

	return false


func apply_operation(operator: String, first_value, second_value):
	match operator:
		&"=":
			return second_value
		&"+", &"+=":
			return first_value + second_value
		&"-", &"-=":
			return first_value - second_value
		&"/", &"/=":
			return first_value / second_value
		&"*", &"*=":
			return first_value * second_value
		&"%":
			return first_value % second_value
		&"and":
			return first_value and second_value
		&"or":
			return first_value or second_value

	assert(false, DialogueConstants.translate(&"runtime.unknown_operator"))


# Check if a dialogue line contains meaningful information
func is_valid(line: DialogueLine) -> bool:
	if line == null:
		return false
	if line.type == DialogueConstants.TYPE_MUTATION and line.mutation == null:
		return false
	if line.type == DialogueConstants.TYPE_RESPONSE and line.get(&"responses").size() == 0:
		return false
	return true


func thing_has_method(thing, method: String, args: Array) -> bool:
	if Builtins.is_supported(thing):
		return thing != _autoloads

	if method in [&"call", &"call_deferred"]:
		return thing.has_method(args[0])

	if method == &"emit_signal":
		return thing.has_signal(args[0])

	if thing.has_method(method):
		return true

	if method.to_snake_case() != method and DialogueSettings.check_for_dotnet_solution():
		# If we get this far then the method might be a C# method with a Task return type
		return _get_dotnet_dialogue_manager().ThingHasMethod(thing, method)

	return false


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


func resolve_signal(args: Array, extra_game_states: Array):
	if args[0] is Signal:
		args[0] = args[0].get_name()

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
	show_error_for_missing_state_value(DialogueConstants.translate(&"runtime.signal_not_found").format({ signal_name = args[0], states = _get_state_shortcut_names(extra_game_states) }))


func get_method_info_for(thing, method: String) -> Dictionary:
	# Use the thing instance id as a key for the caching dictionary.
	var thing_instance_id: int = thing.get_instance_id()
	if not _method_info_cache.has(thing_instance_id):
		var methods: Dictionary = {}
		for m in thing.get_method_list():
			methods[m.name] = m
		_method_info_cache[thing_instance_id] = methods

	return _method_info_cache.get(thing_instance_id, {}).get(method)


func resolve_thing_method(thing, method: String, args: Array):
	if Builtins.is_supported(thing):
		var result = Builtins.resolve_method(thing, method, args)
		if not Builtins.has_resolve_method_failed():
			return result

	if thing.has_method(method):
		# Try to convert any literals to the right type
		var method_info: Dictionary = get_method_info_for(thing, method)
		var method_args: Array = method_info.args
		if method_info.flags & METHOD_FLAG_VARARG == 0 and method_args.size() < args.size():
			assert(false, DialogueConstants.translate(&"runtime.expected_n_got_n_args").format({ expected = method_args.size(), method = method, received = args.size()}))
		for i in range(0, min(method_args.size(), args.size())):
			var m: Dictionary = method_args[i]
			var to_type:int = typeof(args[i])
			if m.type == TYPE_ARRAY:
				match m.hint_string:
					&"String":
						to_type = TYPE_PACKED_STRING_ARRAY
					&"int":
						to_type = TYPE_PACKED_INT64_ARRAY
					&"float":
						to_type = TYPE_PACKED_FLOAT64_ARRAY
					&"Vector2":
						to_type = TYPE_PACKED_VECTOR2_ARRAY
					&"Vector3":
						to_type = TYPE_PACKED_VECTOR3_ARRAY
					_:
						if m.hint_string != "":
							assert(false, DialogueConstants.translate(&"runtime.unsupported_array_type").format({ type = m.hint_string}))
			if typeof(args[i]) != to_type:
				args[i] = convert(args[i], to_type)

		return await thing.callv(method, args)

	# If we get here then it's probably a C# method with a Task return type
	var dotnet_dialogue_manager = _get_dotnet_dialogue_manager()
	dotnet_dialogue_manager.ResolveThingMethod(thing, method, args)
	return await dotnet_dialogue_manager.Resolved
