extends Node

const DialogueResource = preload("./dialogue_resource.gd")
const DialogueLine = preload("./dialogue_line.gd")
const DialogueResponse = preload("./dialogue_response.gd")

const DMConstants = preload("./constants.gd")
const Builtins = preload("./utilities/builtins.gd")
const DMSettings = preload("./settings.gd")
const DMCompiler = preload("./compiler/compiler.gd")
const DMCompilerResult = preload("./compiler/compiler_result.gd")
const DMResolvedLineData = preload("./compiler/resolved_line_data.gd")


## Emitted when a dialogue balloon is created and dialogue starts
signal dialogue_started(resource: DialogueResource)

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

## Used internally.
signal bridge_get_line_completed(line: DialogueLine)

## Used internally
signal bridge_dialogue_started(resource: DialogueResource)

## Used internally
signal bridge_mutated()


## The list of globals that dialogue can query
var game_states: Array = []

## Allow dialogue to call singletons
var include_singletons: bool = true

## Allow dialogue to call static methods/properties on classes
var include_classes: bool = true

## Manage translation behaviour
var translation_source: DMConstants.TranslationSource = DMConstants.TranslationSource.Guess

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

var _dotnet_dialogue_manager: RefCounted

var _expression_parser: DMExpressionParser = DMExpressionParser.new()


func _ready() -> void:
	# Cache the known Node2D properties
	_node_properties = ["Script Variables"]
	var temp_node: Node2D = Node2D.new()
	for property in temp_node.get_property_list():
		_node_properties.append(property.name)
	temp_node.free()

	# Make the dialogue manager available as a singleton
	if not Engine.has_singleton("DialogueManager"):
		Engine.register_singleton("DialogueManager", self)


## Step through lines and run any mutations until we either hit some dialogue or the end of the conversation
func get_next_dialogue_line(resource: DialogueResource, key: String = "", extra_game_states: Array = [], mutation_behaviour: DMConstants.MutationBehaviour = DMConstants.MutationBehaviour.Wait) -> DialogueLine:
	var line = await _get_next_dialogue_line(resource, key, extra_game_states, mutation_behaviour)
	if line == null:
		# End the conversation
		dialogue_ended.emit(resource)
	return line


# Internal line getter.
func _get_next_dialogue_line(resource: DialogueResource, key: String = "", extra_game_states: Array = [], mutation_behaviour: DMConstants.MutationBehaviour = DMConstants.MutationBehaviour.Wait) -> DialogueLine:
	# You have to provide a valid dialogue resource
	if resource == null:
		assert(false, DMConstants.translate(&"runtime.no_resource"))
	if resource.lines.size() == 0:
		assert(false, DMConstants.translate(&"runtime.no_content").format({ file_path = resource.resource_path }))

	# Inject any "using" states into the game_states
	for state_name in resource.using_states:
		var autoload = Engine.get_main_loop().root.get_node_or_null(state_name)
		if autoload == null:
			printerr(DMConstants.translate(&"runtime.unknown_autoload").format({ autoload = state_name }))
		else:
			extra_game_states = [autoload] + extra_game_states

	# Inject "self" into the extra game states.
	extra_game_states = [{ "self": resource }] + extra_game_states

	# Get the line data
	var dialogue: DialogueLine = await get_line(resource, key, extra_game_states)

	# If our dialogue is nothing then we hit the end
	if not _is_valid(dialogue):
		return null

	# Run the mutation if it is one
	if dialogue.type == DMConstants.TYPE_MUTATION:
		var actual_next_id: String = dialogue.next_id.split("|")[0]
		match mutation_behaviour:
			DMConstants.MutationBehaviour.Wait:
				await _mutate(dialogue.mutation, extra_game_states)
			DMConstants.MutationBehaviour.DoNotWait:
				_mutate(dialogue.mutation, extra_game_states)
			DMConstants.MutationBehaviour.Skip:
				pass
		if actual_next_id in [DMConstants.ID_END_CONVERSATION, DMConstants.ID_NULL, null]:
			return null
		else:
			return await _get_next_dialogue_line(resource, dialogue.next_id, extra_game_states, mutation_behaviour)
	else:
		got_dialogue.emit(dialogue)
		return dialogue


## Get a line by its ID
func get_line(resource: DialogueResource, key: String, extra_game_states: Array) -> DialogueLine:
	key = key.strip_edges()

	# See if we were given a stack instead of just the one key
	var stack: Array = key.split("|")
	key = stack.pop_front()
	var id_trail: String = "" if stack.size() == 0 else "|" + "|".join(stack)

	# Key is blank so just use the first title (or start of file)
	if key == null or key == "":
		if resource.first_title.is_empty():
			key = resource.lines.keys()[0]
		else:
			key = resource.first_title

	# See if we just ended the conversation
	if key in [DMConstants.ID_END, DMConstants.ID_NULL, null]:
		if stack.size() > 0:
			return await get_line(resource, "|".join(stack), extra_game_states)
		else:
			return null
	elif key == DMConstants.ID_END_CONVERSATION:
		return null

	# See if it is a title
	if key.begins_with("~ "):
		key = key.substr(2)
	if resource.titles.has(key):
		key = resource.titles.get(key)

	if key in resource.titles.values():
		passed_title.emit(resource.titles.find_key(key))

	if not resource.lines.has(key):
		assert(false, DMConstants.translate(&"errors.key_not_found").format({ key = key }))

	var data: Dictionary = resource.lines.get(key)

	# If next_id is an expression we need to resolve it.
	if data.has(&"next_id_expression"):
		data.next_id = await _resolve(data.next_id_expression, extra_game_states)

	# This title key points to another title key so we should jump there instead
	if data.type == DMConstants.TYPE_TITLE and data.next_id in resource.titles.values():
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	# Handle match statements
	if data.type == DMConstants.TYPE_MATCH:
		var value = await _resolve_condition_value(data, extra_game_states)
		var else_cases: Array[Dictionary] = data.cases.filter(func(s): return s.has("is_else"))
		var else_case: Dictionary = {} if else_cases.size() == 0 else else_cases.front()
		var next_id: String = ""
		for case in data.cases:
			if case == else_case:
				continue
			elif await _check_case_value(value, case, extra_game_states):
				next_id = case.next_id
				break
		# Nothing matched so check for else case
		if next_id == "":
			if not else_case.is_empty():
				next_id = else_case.next_id
			else:
				next_id = data.next_id_after
		return await get_line(resource, next_id + id_trail, extra_game_states)

	# Check for weighted random lines.
	if data.has(&"siblings"):
		# Only count siblings that pass their condition (if they have one).
		var successful_siblings: Array = data.siblings.filter(func(sibling): return not sibling.has("condition") or await _check_condition(sibling, extra_game_states))
		# If there are no siblings that pass their conditions then just skip over them all.
		if successful_siblings.size() == 0:
			return await get_line(resource, data.next_id + id_trail, extra_game_states)
		# Otherwise, pick a random one.
		var target_weight: float = randf_range(0, successful_siblings.reduce(func(total, sibling): return total + sibling.weight, 0))
		var cummulative_weight: float = 0
		for sibling in successful_siblings:
			if target_weight < cummulative_weight + sibling.weight:
				data = resource.lines.get(sibling.id)
				break
			else:
				cummulative_weight += sibling.weight

	# If this line is blank and it's the last line then check for returning snippets.
	if data.type in [DMConstants.TYPE_COMMENT, DMConstants.TYPE_UNKNOWN]:
		if data.next_id in [DMConstants.ID_END, DMConstants.ID_NULL, null]:
			if stack.size() > 0:
				return await get_line(resource, "|".join(stack), extra_game_states)
			else:
				return null
		else:
			return await get_line(resource, data.next_id + id_trail, extra_game_states)

	# If the line is a random block then go to the start of the block.
	elif data.type == DMConstants.TYPE_RANDOM:
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	# Check conditions.
	elif data.type in [DMConstants.TYPE_CONDITION, DMConstants.TYPE_WHILE]:
		# "else" will have no actual condition.
		if await _check_condition(data, extra_game_states):
			return await get_line(resource, data.next_id + id_trail, extra_game_states)
		elif data.has("next_sibling_id") and not data.next_sibling_id.is_empty():
			return await get_line(resource, data.next_sibling_id + id_trail, extra_game_states)
		else:
			return await get_line(resource, data.next_id_after + id_trail, extra_game_states)

	# Evaluate jumps.
	elif data.type == DMConstants.TYPE_GOTO:
		if data.is_snippet and not id_trail.begins_with("|" + data.next_id_after):
			id_trail = "|" + data.next_id_after + id_trail
		return await get_line(resource, data.next_id + id_trail, extra_game_states)

	elif data.type == DMConstants.TYPE_DIALOGUE:
		if not data.has(&"id"):
			data.id = key

	# Set up a line object.
	var line: DialogueLine = await create_dialogue_line(data, extra_game_states)

	# If the jump point somehow has no content then just end.
	if not line: return null

	# Find any simultaneously said lines.
	if data.has(&"concurrent_lines"):
		# If the list includes this line then it isn't the origin line so ignore it.
		if not data.concurrent_lines.has(data.id):
			# Resolve IDs to their actual lines.
			for line_id: String in data.concurrent_lines:
				line.concurrent_lines.append(await get_line(resource, line_id, extra_game_states))

	# If we are the first of a list of responses then get the other ones.
	if data.type == DMConstants.TYPE_RESPONSE:
		# Note: For some reason C# has occasional issues with using the responses property directly
		# so instead we use set and get here.
		line.set(&"responses", await _get_responses(data.get(&"responses", []), resource, id_trail, extra_game_states))
		return line

	# Inject the next node's responses if they have any.
	if resource.lines.has(line.next_id):
		var next_line: Dictionary = resource.lines.get(line.next_id)

		# If the response line is marked as a title then make sure to emit the passed_title signal.
		if line.next_id in resource.titles.values():
			passed_title.emit(resource.titles.find_key(line.next_id))

		# If the responses come from a snippet then we need to come back here afterwards.
		if next_line.type == DMConstants.TYPE_GOTO and next_line.is_snippet and not id_trail.begins_with("|" + next_line.next_id_after):
			id_trail = "|" + next_line.next_id_after + id_trail

		# If the next line is a title then check where it points to see if that is a set of responses.
		while [DMConstants.TYPE_TITLE, DMConstants.TYPE_GOTO].has(next_line.type) and resource.lines.has(next_line.next_id):
			next_line = resource.lines.get(next_line.next_id)

		if next_line != null and next_line.type == DMConstants.TYPE_RESPONSE:
			# Note: For some reason C# has occasional issues with using the responses property directly
			# so instead we use set and get here.
			line.set(&"responses", await _get_responses(next_line.get(&"responses", []), resource, id_trail, extra_game_states))

	line.next_id = "|".join(stack) if line.next_id == DMConstants.ID_NULL else line.next_id + id_trail
	return line

## Replace any variables, etc in the text.
func get_resolved_line_data(data: Dictionary, extra_game_states: Array = []) -> DMResolvedLineData:
	var text: String = translate(data)

	# Resolve variables
	var text_replacements: Array[Dictionary] = data.get(&"text_replacements", [] as Array[Dictionary])
	if text_replacements.size() == 0 and "{{" in text:
		# This line is translated but has expressions that didn't exist in the base text.
		text_replacements = _expression_parser.extract_replacements(text, 0)

	for replacement in text_replacements:
		if replacement.has("error"):
			assert(false, "%s \"%s\"" % [DMConstants.get_error_message(replacement.get("error")), text])

		var value = await _resolve(replacement.expression.duplicate(true), extra_game_states)
		var index: int = text.find(replacement.value_in_text)
		if index == -1:
			# The replacement wasn't found but maybe the regular quotes have been replaced
			# by special quotes while translating.
			index = text.replace("“", "\"").replace("”", "\"").find(replacement.value_in_text)
		if index > -1:
			text = text.substr(0, index) + str(value) + text.substr(index + replacement.value_in_text.length())

	var compilation: DMCompilation = DMCompilation.new()

	# Resolve random groups
	for found in compilation.regex.INLINE_RANDOM_REGEX.search_all(text):
		var options = found.get_string(&"options").split(&"|")
		text = text.replace(&"[[%s]]" % found.get_string(&"options"), options[randi_range(0, options.size() - 1)])

	# Do a pass on the markers to find any conditionals
	var markers: DMResolvedLineData = DMResolvedLineData.new(text)

	# Resolve any conditionals and update marker positions as needed
	if data.type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE]:
		var resolved_text: String = markers.text
		var conditionals: Array[RegExMatch] = compilation.regex.INLINE_CONDITIONALS_REGEX.search_all(resolved_text)
		var replacements: Array = []
		for conditional in conditionals:
			var condition_raw: String = conditional.strings[conditional.names.condition]
			var body: String = conditional.strings[conditional.names.body]
			var body_else: String = ""
			if &"[else]" in body:
				var bits = body.split(&"[else]")
				body = bits[0]
				body_else = bits[1]
			var condition: Dictionary = compilation.extract_condition("if " + condition_raw, false, 0)
			# If the condition fails then use the else of ""
			if not await _check_condition({ condition = condition }, extra_game_states):
				body = body_else
			replacements.append({
				start = conditional.get_start(),
				end = conditional.get_end(),
				string = conditional.get_string(),
				body = body
			})

		for i in range(replacements.size() - 1, -1, -1):
			var r: Dictionary = replacements[i]
			resolved_text = resolved_text.substr(0, r.start) + r.body + resolved_text.substr(r.end, 9999)
			# Move any other markers now that the text has changed
			var offset: int = r.end - r.start - r.body.length()
			for key in [&"speeds", &"time"]:
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

	return markers


## Replace any variables, etc in the character name
func get_resolved_character(data: Dictionary, extra_game_states: Array = []) -> String:
	var character: String = data.get(&"character", "")

	# Resolve variables
	for replacement in data.get(&"character_replacements", []):
		var value = await _resolve(replacement.expression.duplicate(true), extra_game_states)
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
	var result: DMCompilerResult = DMCompiler.compile_string(text, "")

	if result.errors.size() > 0:
		printerr(DMConstants.translate(&"runtime.errors").format({ count = result.errors.size() }))
		for error in result.errors:
			printerr(DMConstants.translate(&"runtime.error_detail").format({
				line = error.line_number + 1,
				message = DMConstants.get_error_message(error.error)
			}))
		assert(false, DMConstants.translate(&"runtime.errors_see_details").format({ count = result.errors.size() }))

	var resource: DialogueResource = DialogueResource.new()
	resource.using_states = result.using_states
	resource.titles = result.titles
	resource.first_title = result.first_title
	resource.character_names = result.character_names
	resource.lines = result.lines
	resource.raw_text = text

	return resource


#region Balloon helpers


## Show the example balloon
func show_example_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> CanvasLayer:
	var balloon: Node = load(_get_example_balloon_path()).instantiate()
	_start_balloon.call_deferred(balloon, resource, title, extra_game_states)
	return balloon


## Show the configured dialogue balloon
func show_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> Node:
	var balloon_path: String = DMSettings.get_setting(DMSettings.BALLOON_PATH, _get_example_balloon_path())
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
	_start_balloon.call_deferred(balloon, resource, title, extra_game_states)
	return balloon


## Resolve a static line ID to an actual line ID
func static_id_to_line_id(resource: DialogueResource, static_id: String) -> String:
	var ids = static_id_to_line_ids(resource, static_id)
	if ids.size() == 0: return ""
	return ids[0]


## Resolve a static line ID to any actual line IDs that match
func static_id_to_line_ids(resource: DialogueResource, static_id: String) -> PackedStringArray:
	return resource.lines.values().filter(func(l): return l.get(&"translation_key", "") == static_id).map(func(l): return l.id)


# Call "start" on the given balloon.
func _start_balloon(balloon: Node, resource: DialogueResource, title: String, extra_game_states: Array) -> void:
	get_current_scene.call().add_child(balloon)

	if balloon.has_method(&"start"):
		balloon.start(resource, title, extra_game_states)
	elif balloon.has_method(&"Start"):
		balloon.Start(resource, title, extra_game_states)
	else:
		assert(false, DMConstants.translate(&"runtime.dialogue_balloon_missing_start_method"))

	dialogue_started.emit(resource)
	bridge_dialogue_started.emit(resource)


# Get the path to the example balloon
func _get_example_balloon_path() -> String:
	var is_small_window: bool = ProjectSettings.get_setting("display/window/size/viewport_width") < 400
	var balloon_path: String = "/example_balloon/small_example_balloon.tscn" if is_small_window else "/example_balloon/example_balloon.tscn"
	return get_script().resource_path.get_base_dir() + balloon_path


#endregion

#region dotnet bridge


func _get_dotnet_dialogue_manager() -> RefCounted:
	if not is_instance_valid(_dotnet_dialogue_manager):
		_dotnet_dialogue_manager = load(get_script().resource_path.get_base_dir() + "/DialogueManager.cs").new()
	return _dotnet_dialogue_manager


func _bridge_get_new_instance() -> Node:
	# For some reason duplicating the node with its signals doesn't work so we have to copy them over manually
	var instance = new()
	for s: Dictionary in dialogue_started.get_connections():
		instance.dialogue_started.connect(s.callable)
	for s: Dictionary in passed_title.get_connections():
		instance.passed_title.connect(s.callable)
	for s: Dictionary in got_dialogue.get_connections():
		instance.got_dialogue.connect(s.callable)
	for s: Dictionary in mutated.get_connections():
		instance.mutated.connect(s.callable)
	for s: Dictionary in dialogue_ended.get_connections():
		instance.dialogue_ended.connect(s.callable)
	instance.get_current_scene = get_current_scene
	return instance


func _bridge_get_next_dialogue_line(resource: DialogueResource, key: String, extra_game_states: Array = [], mutation_behaviour: int = DMConstants.MutationBehaviour.Wait) -> void:
	# dotnet needs at least one await tick of the signal gets called too quickly
	await Engine.get_main_loop().process_frame
	var line = await _get_next_dialogue_line(resource, key, extra_game_states, mutation_behaviour)
	bridge_get_next_dialogue_line_completed.emit(line)
	if line == null:
		# End the conversation
		dialogue_ended.emit(resource)


func _bridge_get_line(resource: DialogueResource, key: String, extra_game_states: Array = []) -> void:
	# dotnet needs at least one await tick of the signal gets called too quickly
	await Engine.get_main_loop().process_frame
	var line = await get_line(resource, key, extra_game_states)
	bridge_get_line_completed.emit(line)


func _bridge_mutate(mutation: Dictionary, extra_game_states: Array, is_inline_mutation: bool = false) -> void:
	await _mutate(mutation, extra_game_states, is_inline_mutation)
	bridge_mutated.emit()


func _bridge_get_error_message(error: int) -> String:
	return DMConstants.get_error_message(error)


#endregion

#region Internal helpers


# Show a message or crash with error
func show_error_for_missing_state_value(message: String, will_show: bool = true) -> void:
	if not will_show: return

	if DMSettings.get_setting(DMSettings.IGNORE_MISSING_STATE_VALUES, false):
		push_error(message)
	elif will_show:
		# If you're here then you're missing a method or property in your game state. The error
		# message down in the debugger will give you some more information.
		assert(false, message)


# Translate a string
func translate(data: Dictionary) -> String:
	if TranslationServer.get_loaded_locales().size() == 0 or translation_source == DMConstants.TranslationSource.None:
		return data.text

	var translation_key: String = data.get(&"translation_key", data.text)

	if translation_key == "" or translation_key == data.text:
		return tr(data.text)
	else:
		# Line IDs work slightly differently depending on whether the translation came from a
		# CSV or a PO file. CSVs use the line ID (or the line itself) as the translatable string
		# whereas POs use the ID as context and the line itself as the translatable string.
		match translation_source:
			DMConstants.TranslationSource.PO:
				return tr(data.text, StringName(translation_key))

			DMConstants.TranslationSource.CSV:
				return tr(translation_key)

			DMConstants.TranslationSource.Guess:
				var translation_files: Array = ProjectSettings.get_setting(&"internationalization/locale/translations")
				if translation_files.filter(func(f: String): return f.get_extension() in [&"po", &"mo"]).size() > 0:
					# Assume PO
					return tr(data.text, StringName(translation_key))
				else:
					# Assume CSV
					return tr(translation_key)

	return tr(translation_key)


# Create a line of dialogue
func create_dialogue_line(data: Dictionary, extra_game_states: Array) -> DialogueLine:
	match data.type:
		DMConstants.TYPE_DIALOGUE:
			var resolved_data: DMResolvedLineData = await get_resolved_line_data(data, extra_game_states)
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DMConstants.TYPE_DIALOGUE,
				next_id = data.next_id,
				character = await get_resolved_character(data, extra_game_states),
				character_replacements = data.get(&"character_replacements", [] as Array[Dictionary]),
				text = resolved_data.text,
				text_replacements = data.get(&"text_replacements", [] as Array[Dictionary]),
				translation_key = data.get(&"translation_key", data.text),
				speeds = resolved_data.speeds,
				inline_mutations = resolved_data.mutations,
				time = resolved_data.time,
				tags = data.get(&"tags", []),
				extra_game_states = extra_game_states
			})

		DMConstants.TYPE_RESPONSE:
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DMConstants.TYPE_RESPONSE,
				next_id = data.next_id,
				tags = data.get(&"tags", []),
				extra_game_states = extra_game_states
			})

		DMConstants.TYPE_MUTATION:
			return DialogueLine.new({
				id = data.get(&"id", ""),
				type = DMConstants.TYPE_MUTATION,
				next_id = data.next_id,
				mutation = data.mutation,
				extra_game_states = extra_game_states
			})

	return null


# Create a response
func create_response(data: Dictionary, extra_game_states: Array) -> DialogueResponse:
	var resolved_data: DMResolvedLineData = await get_resolved_line_data(data, extra_game_states)
	return DialogueResponse.new({
		id = data.get(&"id", ""),
		type = DMConstants.TYPE_RESPONSE,
		next_id = data.next_id,
		is_allowed = data.is_allowed,
		condition_as_text = data.get(&"condition_as_text", ""),
		character = await get_resolved_character(data, extra_game_states),
		character_replacements = data.get(&"character_replacements", [] as Array[Dictionary]),
		text = resolved_data.text,
		text_replacements = data.get(&"text_replacements", [] as Array[Dictionary]),
		tags = data.get(&"tags", []),
		translation_key = data.get(&"translation_key", data.text),
	})


# Get the current game states
func _get_game_states(extra_game_states: Array) -> Array:
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
		for node_name in DMSettings.get_setting(DMSettings.STATE_AUTOLOAD_SHORTCUTS, ""):
			var state: Node = Engine.get_main_loop().root.get_node_or_null(NodePath(node_name))
			if state:
				game_states.append(state)

	var current_scene: Node = get_current_scene.call()
	var unique_states: Array = []
	for state in extra_game_states + [current_scene] + game_states:
		if state != null and not unique_states.has(state):
			unique_states.append(state)
	return unique_states


# Check if a condition is met
func _check_condition(data: Dictionary, extra_game_states: Array) -> bool:
	return bool(await _resolve_condition_value(data, extra_game_states))


# Resolve a condition's expression value
func _resolve_condition_value(data: Dictionary, extra_game_states: Array) -> Variant:
	if data.get(&"condition", null) == null: return true
	if data.condition.is_empty(): return true

	return await _resolve(data.condition.expression.duplicate(true), extra_game_states)


# Check if a match value matches a case value
func _check_case_value(match_value: Variant, data: Dictionary, extra_game_states: Array) -> bool:
	if data.get(&"condition", null) == null: return true
	if data.condition.is_empty(): return true

	var expression: Array[Dictionary] = data.condition.expression.duplicate(true)

	# Check for multiple values
	var expressions_to_check: Array = []
	var previous_comma_index: int = 0
	for i in range(0, expression.size()):
		if expression[i].type == DMConstants.TOKEN_COMMA:
			expressions_to_check.append(expression.slice(previous_comma_index, i))
			previous_comma_index = i + 1
		elif i == expression.size() - 1:
			expressions_to_check.append(expression.slice(previous_comma_index))

	for expression_to_check in expressions_to_check:
		# If the when is a comparison when insert the match value as the first value to compare to
		var already_compared: bool = false
		if expression_to_check[0].type == DMConstants.TOKEN_COMPARISON:
			expression_to_check.insert(0, {
				type = DMConstants.TOKEN_VALUE,
				value = match_value
			})
			already_compared = true

		var resolved_value = await _resolve(expression_to_check, extra_game_states)
		if already_compared:
			if resolved_value:
				return true
		else:
			if match_value == resolved_value:
				return true

	return false



# Make a change to game state or run a method
func _mutate(mutation: Dictionary, extra_game_states: Array, is_inline_mutation: bool = false) -> void:
	var expression: Array[Dictionary] = mutation.expression

	# Handle built in mutations
	if expression[0].type == DMConstants.TOKEN_FUNCTION and expression[0].function in [&"wait", &"Wait", &"debug", &"Debug"]:
		var args: Array = await _resolve_each(expression[0].value, extra_game_states)
		match expression[0].function:
			&"wait", &"Wait":
				mutated.emit(mutation.merged({ is_inline = is_inline_mutation }))
				if [TYPE_FLOAT, TYPE_INT].has(typeof(args[0])):
					await Engine.get_main_loop().create_timer(float(args[0])).timeout
				else:
					var actions: PackedStringArray = PackedStringArray(args[0] if typeof(args[0]) == TYPE_ARRAY else [args[0]])
					await _wait_for(actions)
				return

			&"debug", &"Debug":
				prints("Debug:", args)
				await Engine.get_main_loop().process_frame

	# Or pass through to the resolver
	else:
		if not _mutation_contains_assignment(mutation.expression) and not is_inline_mutation:
			mutated.emit(mutation.merged({ is_inline = is_inline_mutation }))

		if mutation.get("is_blocking", true):
			await _resolve(mutation.expression.duplicate(true), extra_game_states)
			return
		else:
			_resolve(mutation.expression.duplicate(true), extra_game_states)

	# Wait one frame to give the dialogue handler a chance to yield
	await Engine.get_main_loop().process_frame


# Wait for a given action
func _wait_for(actions: PackedStringArray) -> void:
	var waiter = DMWaiter.new(actions)
	add_child(waiter)
	await waiter.waited
	waiter.queue_free()


# Check if a mutation contains an assignment token.
func _mutation_contains_assignment(mutation: Array) -> bool:
	for token in mutation:
		if token.type == DMConstants.TOKEN_ASSIGNMENT:
			return true
	return false


# Replace an array of line IDs with their response prompts
func _get_responses(ids: Array, resource: DialogueResource, id_trail: String, extra_game_states: Array) -> Array[DialogueResponse]:
	var responses: Array[DialogueResponse] = []
	for id in ids:
		var data: Dictionary = resource.lines.get(id).duplicate(true)
		data.is_allowed = await _check_condition(data, extra_game_states)
		var response: DialogueResponse = await create_response(data, extra_game_states)
		response.next_id += id_trail
		responses.append(response)

	return responses


# Get a value on the current scene or game state
func _get_state_value(property: String, extra_game_states: Array):
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
		assert(false, DMConstants.translate(&"runtime.invalid_expression").format({ expression = property, error = expression.get_error_text() }))

	# Warn about possible name collisions
	_warn_about_state_name_collisions(property, extra_game_states)

	for state in _get_game_states(extra_game_states):
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				return state.get(property)
		else:
			# Try for a C# constant first
			if state.get_script() \
			and state.get_script().resource_path.ends_with(".cs") \
			and _get_dotnet_dialogue_manager().ThingHasConstant(state, property):
				return _get_dotnet_dialogue_manager().ResolveThingConstant(state, property)

			# Otherwise just let Godot try and resolve it.
			var result = expression.execute([], state, false)
			if not expression.has_execute_failed():
				return result

	if include_singletons and Engine.has_singleton(property):
		return Engine.get_singleton(property)

	if include_classes:
		for class_data in ProjectSettings.get_global_class_list():
			if class_data.get(&"class") == property:
				return load(class_data.path)

	show_error_for_missing_state_value(DMConstants.translate(&"runtime.property_not_found").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))


# Print warnings for top-level state name collisions.
func _warn_about_state_name_collisions(target_key: String, extra_game_states: Array) -> void:
	# Don't run the check if this is a release build
	if not OS.is_debug_build(): return
	# Also don't run if the setting is off
	if not DMSettings.get_setting(DMSettings.WARN_ABOUT_METHOD_PROPERTY_OR_SIGNAL_NAME_CONFLICTS, false): return

	# Get the list of state shortcuts.
	var state_shortcuts: Array = []
	for node_name in DMSettings.get_setting(DMSettings.STATE_AUTOLOAD_SHORTCUTS, ""):
		var state: Node = Engine.get_main_loop().root.get_node_or_null(NodePath(node_name))
		if state:
			state_shortcuts.append(state)

	# Check any top level names for a collision
	var states_with_key: Array = []
	for state in extra_game_states + [get_current_scene.call()] + state_shortcuts:
		if state is Dictionary:
			if state.keys().has(target_key):
				states_with_key.append("Dictionary")
		else:
			var script: Script = (state as Object).get_script()
			if script == null:
				continue

			for method in script.get_script_method_list():
				if method.name == target_key and not states_with_key.has(state.name):
					states_with_key.append(state.name)
					break

			for property in script.get_script_property_list():
				if property.name == target_key and not states_with_key.has(state.name):
					states_with_key.append(state.name)
					break

			for signal_info in script.get_script_signal_list():
				if signal_info.name == target_key and not states_with_key.has(state.name):
					states_with_key.append(state.name)
					break

	if states_with_key.size() > 1:
		push_warning(DMConstants.translate(&"runtime.top_level_states_share_name").format({ states = ", ".join(states_with_key), key = target_key }))


# Set a value on the current scene or game state
func _set_state_value(property: String, value, extra_game_states: Array) -> void:
	for state in _get_game_states(extra_game_states):
		if typeof(state) == TYPE_DICTIONARY:
			if state.has(property):
				state[property] = value
				return
		elif _thing_has_property(state, property):
			state.set(property, value)
			return

	if property.to_snake_case() != property:
		show_error_for_missing_state_value(DMConstants.translate(&"runtime.property_not_found_missing_export").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))
	else:
		show_error_for_missing_state_value(DMConstants.translate(&"runtime.property_not_found").format({ property = property, states = _get_state_shortcut_names(extra_game_states) }))


# Get the list of state shortcut names
func _get_state_shortcut_names(extra_game_states: Array) -> String:
	var states = _get_game_states(extra_game_states)
	states.erase(_autoloads)
	return ", ".join(states.map(func(s): return "\"%s\"" % (s.name if "name" in s else s)))


# Resolve an array of expressions.
func _resolve_each(array: Array, extra_game_states: Array) -> Array:
	var results: Array = []
	for item in array:
		if not item[0].type in [DMConstants.TOKEN_BRACE_CLOSE, DMConstants.TOKEN_BRACKET_CLOSE, DMConstants.TOKEN_PARENS_CLOSE]:
			results.append(await _resolve(item.duplicate(true), extra_game_states))
	return results


# Collapse any expressions
func _resolve(tokens: Array, extra_game_states: Array):
	var i: int = 0
	var limit: int = 0

	# Handle groups first
	for token in tokens:
		if token.type == DMConstants.TOKEN_GROUP:
			token.type = DMConstants.TOKEN_VALUE
			token.value = await _resolve(token.value, extra_game_states)

	# Then variables/methods
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]

		if token.type == DMConstants.TOKEN_NULL_COALESCE:
			var caller: Dictionary = tokens[i - 1]
			if caller.value == null:
				# If the caller is null then the method/property is also null
				caller.type = DMConstants.TOKEN_VALUE
				caller.value = null
				tokens.remove_at(i + 1)
				tokens.remove_at(i)
			else:
				token.type = DMConstants.TOKEN_DOT

		elif token.type == DMConstants.TOKEN_FUNCTION:
			var function_name: String = token.function
			var args = await _resolve_each(token.value, extra_game_states)
			if tokens[i - 1].type == DMConstants.TOKEN_DOT:
				# If we are calling a deeper function then we need to collapse the
				# value into the thing we are calling the function on
				var caller: Dictionary = tokens[i - 2]
				if Builtins.is_supported(caller.value):
					caller.type = DMConstants.TOKEN_VALUE
					caller.value = Builtins.resolve_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i - 1)
					i -= 2
				elif _thing_has_method(caller.value, function_name, args):
					caller.type = DMConstants.TOKEN_VALUE
					caller.value = await _resolve_thing_method(caller.value, function_name, args)
					tokens.remove_at(i)
					tokens.remove_at(i - 1)
					i -= 2
				else:
					show_error_for_missing_state_value(DMConstants.translate(&"runtime.method_not_callable").format({ method = function_name, object = str(caller.value) }))
			else:
				var found: bool = false
				match function_name:
					&"str":
						token.type = DMConstants.TOKEN_VALUE
						token.value = str(args[0])
						found = true
					&"Vector2":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector2(args[0], args[1])
						found = true
					&"Vector2i":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector2i(args[0], args[1])
						found = true
					&"Vector3":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector3(args[0], args[1], args[2])
						found = true
					&"Vector3i":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector3i(args[0], args[1], args[2])
						found = true
					&"Vector4":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector4(args[0], args[1], args[2], args[3])
						found = true
					&"Vector4i":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Vector4i(args[0], args[1], args[2], args[3])
						found = true
					&"Quaternion":
						token.type = DMConstants.TOKEN_VALUE
						token.value = Quaternion(args[0], args[1], args[2], args[3])
						found = true
					&"Callable":
						token.type = DMConstants.TOKEN_VALUE
						match args.size():
							0:
								token.value = Callable()
							1:
								token.value = Callable(args[0])
							2:
								token.value = Callable(args[0], args[1])
						found = true
					&"Color":
						token.type = DMConstants.TOKEN_VALUE
						match args.size():
							0:
								token.value = Color()
							1:
								token.value = Color(args[0])
							2:
								token.value = Color(args[0], args[1])
							3:
								token.value = Color(args[0], args[1], args[2])
							4:
								token.value = Color(args[0], args[1], args[2], args[3])
						found = true
					&"load", &"Load":
						token.type = DMConstants.TOKEN_VALUE
						token.value = load(args[0])
						found = true
					&"roll_dice", &"RollDice":
						token.type = DMConstants.TOKEN_VALUE
						token.value = randi_range(1, args[0])
						found = true
					_:
						# Check for top level name conflicts
						_warn_about_state_name_collisions(function_name, extra_game_states)

						for state in _get_game_states(extra_game_states):
							if _thing_has_method(state, function_name, args):
								token.type = DMConstants.TOKEN_VALUE
								token.value = await _resolve_thing_method(state, function_name, args)
								found = true
								break

				show_error_for_missing_state_value(DMConstants.translate(&"runtime.method_not_found").format({
					method = args[0] if function_name in ["call", "call_deferred"] else function_name,
					states = _get_state_shortcut_names(extra_game_states)
				}), not found)

		elif token.type == DMConstants.TOKEN_DICTIONARY_REFERENCE:
			var value
			if i > 0 and tokens[i - 1].type == DMConstants.TOKEN_DOT:
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
				value = _get_state_value(token.variable, extra_game_states)

			var index = await _resolve(token.value, extra_game_states)
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					token.type = "dictionary"
					token.value = value
					token.key = index
				else:
					if value.has(index):
						token.type = DMConstants.TOKEN_VALUE
						token.value = value[index]
					else:
						show_error_for_missing_state_value(DMConstants.translate(&"runtime.key_not_found").format({ key = str(index), dictionary = token.variable }))
			elif typeof(value) in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY]:
				if tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					token.type = "array"
					token.value = value
					token.key = index
				else:
					if index >= 0 and index < value.size():
						token.type = DMConstants.TOKEN_VALUE
						token.value = value[index]
					else:
						show_error_for_missing_state_value(DMConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = index, array = token.variable }))

		elif token.type == DMConstants.TOKEN_DICTIONARY_NESTED_REFERENCE:
			var dictionary: Dictionary = tokens[i - 1]
			var index = await _resolve(token.value, extra_game_states)
			var value = dictionary.value
			if typeof(value) == TYPE_DICTIONARY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary.type = "dictionary"
					dictionary.key = index
					dictionary.value = value
					tokens.remove_at(i)
					i -= 1
				else:
					if dictionary.value.has(index):
						dictionary.value = value.get(index)
						tokens.remove_at(i)
						i -= 1
					else:
						show_error_for_missing_state_value(DMConstants.translate(&"runtime.key_not_found").format({ key = str(index), dictionary = value }))
			elif typeof(value) == TYPE_ARRAY:
				if tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					dictionary.type = "array"
					dictionary.value = value
					dictionary.key = index
					tokens.remove_at(i)
					i -= 1
				else:
					if index >= 0 and index < value.size():
						dictionary.value = value[index]
						tokens.remove_at(i)
						i -= 1
					else:
						show_error_for_missing_state_value(DMConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = index, array = value }))

		elif token.type == DMConstants.TOKEN_ARRAY:
			token.type = DMConstants.TOKEN_VALUE
			token.value = await _resolve_each(token.value, extra_game_states)

		elif token.type == DMConstants.TOKEN_DICTIONARY:
			token.type = DMConstants.TOKEN_VALUE
			var dictionary = {}
			for key in token.value.keys():
				var resolved_key = await _resolve([key], extra_game_states)
				var preresolved_value = token.value.get(key)
				if typeof(preresolved_value) != TYPE_ARRAY:
					preresolved_value = [preresolved_value]
				var resolved_value = await _resolve(preresolved_value, extra_game_states)
				dictionary[resolved_key] = resolved_value
			token.value = dictionary

		elif token.type == DMConstants.TOKEN_VARIABLE or token.type == DMConstants.TOKEN_NUMBER:
			if str(token.value) == "null":
				token.type = DMConstants.TOKEN_VALUE
				token.value = null
			elif str(token.value) == "self":
				token.type = DMConstants.TOKEN_VALUE
				token.value = extra_game_states[0].self
			elif tokens[i - 1].type == DMConstants.TOKEN_DOT:
				var caller: Dictionary = tokens[i - 2]
				var property = token.value
				if tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
					# If the next token is an assignment then we need to leave this as a reference
					# so that it can be resolved once everything ahead of it has been resolved
					caller.type = "property"
					caller.property = property
				else:
					# If we are requesting a deeper property then we need to collapse the
					# value into the thing we are referencing from
					caller.type = DMConstants.TOKEN_VALUE
					if Builtins.is_supported(caller.value):
						caller.value = Builtins.resolve_property(caller.value, property)
					else:
						caller.value = caller.value.get(property)
				tokens.remove_at(i)
				tokens.remove_at(i - 1)
				i -= 2
			elif tokens.size() > i + 1 and tokens[i + 1].type == DMConstants.TOKEN_ASSIGNMENT:
				# It's a normal variable but we will be assigning to it so don't resolve
				# it until everything after it has been resolved
				token.type = "variable"
			else:
				if token.type == DMConstants.TOKEN_NUMBER:
					token.type = DMConstants.TOKEN_VALUE
					token.value = token.value
				else:
					token.type = DMConstants.TOKEN_VALUE
					token.value = _get_state_value(str(token.value), extra_game_states)

		i += 1

	# Then multiply and divide
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_OPERATOR and token.value in ["*", "/", "%"]:
			token.type = DMConstants.TOKEN_VALUE
			token.value = _apply_operation(token.value, tokens[i - 1].value, tokens[i + 1].value)
			tokens.remove_at(i + 1)
			tokens.remove_at(i - 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	# Then addition and subtraction
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_OPERATOR and token.value in ["+", "-"]:
			token.type = DMConstants.TOKEN_VALUE
			token.value = _apply_operation(token.value, tokens[i - 1].value, tokens[i + 1].value)
			tokens.remove_at(i + 1)
			tokens.remove_at(i - 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	# Then negations
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_NOT:
			token.type = DMConstants.TOKEN_VALUE
			token.value = not tokens[i + 1].value
			tokens.remove_at(i + 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	# Then comparisons
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_COMPARISON:
			token.type = DMConstants.TOKEN_VALUE
			token.value = _compare(token.value, tokens[i - 1].value, tokens[i + 1].value)
			tokens.remove_at(i + 1)
			tokens.remove_at(i - 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	# Then and/or
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_AND_OR:
			token.type = DMConstants.TOKEN_VALUE
			token.value = _apply_operation(token.value, tokens[i - 1].value, tokens[i + 1].value)
			tokens.remove_at(i + 1)
			tokens.remove_at(i - 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	# Lastly, resolve any assignments
	i = 0
	limit = 0
	while i < tokens.size() and limit < 1000:
		limit += 1
		var token: Dictionary = tokens[i]
		if token.type == DMConstants.TOKEN_ASSIGNMENT:
			var lhs: Dictionary = tokens[i - 1]
			var value

			match lhs.type:
				&"variable":
					value = _apply_operation(token.value, _get_state_value(lhs.value, extra_game_states), tokens[i + 1].value)
					_set_state_value(lhs.value, value, extra_game_states)
				&"property":
					value = _apply_operation(token.value, lhs.value.get(lhs.property), tokens[i + 1].value)
					if typeof(lhs.value) == TYPE_DICTIONARY:
						lhs.value[lhs.property] = value
					else:
						lhs.value.set(lhs.property, value)
				&"dictionary":
					value = _apply_operation(token.value, lhs.value.get(lhs.key, null), tokens[i + 1].value)
					lhs.value[lhs.key] = value
				&"array":
					show_error_for_missing_state_value(
						DMConstants.translate(&"runtime.array_index_out_of_bounds").format({ index = lhs.key, array = lhs.value }),
						lhs.key >= lhs.value.size()
					)
					value = _apply_operation(token.value, lhs.value[lhs.key], tokens[i + 1].value)
					lhs.value[lhs.key] = value
				_:
					show_error_for_missing_state_value(DMConstants.translate(&"runtime.left_hand_size_cannot_be_assigned_to"))

			token.type = DMConstants.TOKEN_VALUE
			token.value = value
			tokens.remove_at(i + 1)
			tokens.remove_at(i - 1)
			i -= 1
		i += 1

	if limit >= 1000:
		assert(false, DMConstants.translate(&"runtime.something_went_wrong"))

	return tokens[0].value


# Compare two values.
func _compare(operator: String, first_value, second_value) -> bool:
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


# Apply an operation from one value to another.
func _apply_operation(operator: String, first_value, second_value):
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

	assert(false, DMConstants.translate(&"runtime.unknown_operator"))


# Check if a dialogue line contains meaningful information.
func _is_valid(line: DialogueLine) -> bool:
	if line == null:
		return false
	if line.type == DMConstants.TYPE_MUTATION and line.mutation == null:
		return false
	if line.type == DMConstants.TYPE_RESPONSE and line.get(&"responses").size() == 0:
		return false
	return true


# Check that a thing has a given method.
func _thing_has_method(thing, method: String, args: Array) -> bool:
	if not is_instance_valid(thing):
		return false

	if Builtins.is_supported(thing, method):
		return thing != _autoloads
	elif thing is Dictionary:
		return false

	if method in [&"call", &"call_deferred"]:
		return thing.has_method(args[0])

	if method == &"emit_signal":
		return thing.has_signal(args[0])

	if thing.has_method(method):
		return true

	if thing.get_script() and thing.get_script().resource_path.ends_with(".cs"):
		# If we get this far then the method might be a C# method with a Task return type
		return _get_dotnet_dialogue_manager().ThingHasMethod(thing, method, args)

	return false


# Check if a given property exists
func _thing_has_property(thing: Object, property: String) -> bool:
	if thing == null:
		return false

	for p in thing.get_property_list():
		if _node_properties.has(p.name):
			# Ignore any properties on the base Node
			continue
		if p.name == property:
			return true

	if thing.get_script() and thing.get_script().resource_path.ends_with(".cs"):
		# If we get this far then the property might be a C# constant.
		return _get_dotnet_dialogue_manager().ThingHasConstant(thing, property)

	return false


func _get_method_info_for(thing: Variant, method: String, args: Array) -> Dictionary:
	# Use the thing instance id as a key for the caching dictionary.
	var thing_instance_id: int = thing.get_instance_id()
	if not _method_info_cache.has(thing_instance_id):
		var methods: Dictionary = {}
		for m in thing.get_method_list():
			methods["%s:%d" % [m.name, m.args.size()]] = m
			if not methods.has(m.name):
				methods[m.name] = m
		_method_info_cache[thing_instance_id] = methods

	var methods: Dictionary = _method_info_cache.get(thing_instance_id, {})
	var method_key: String = "%s:%d" % [method, args.size()]
	if methods.has(method_key):
		return methods.get(method_key)
	elif methods.has(method):
		return methods.get(method)
	else:
		return _get_method_info_for(thing.new(), method, args)


func _resolve_thing_method(thing, method: String, args: Array):
	if Builtins.is_supported(thing):
		var result = Builtins.resolve_method(thing, method, args)
		if not Builtins.has_resolve_method_failed():
			return result

	if thing.has_method(method):
		# Try to convert any literals to the right type
		var method_info: Dictionary = _get_method_info_for(thing, method, args)
		var method_args: Array = method_info.args
		if method_info.flags & METHOD_FLAG_VARARG == 0 and method_args.size() < args.size():
			assert(false, DMConstants.translate(&"runtime.expected_n_got_n_args").format({ expected = method_args.size(), method = method, received = args.size()}))
		for i in range(0, min(method_args.size(), args.size())):
			var m: Dictionary = method_args[i]
			var to_type: int = typeof(args[i])
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
							assert(false, DMConstants.translate(&"runtime.unsupported_array_type").format({ type = m.hint_string}))
			if typeof(args[i]) != to_type:
				args[i] = convert(args[i], to_type)

		return await thing.callv(method, args)

	# If we get here then it's probably a C# method with a Task return type
	var dotnet_dialogue_manager = _get_dotnet_dialogue_manager()
	dotnet_dialogue_manager.ResolveThingMethod(thing, method, args)
	return await dotnet_dialogue_manager.Resolved
