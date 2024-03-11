@icon("./assets/icon.svg")

@tool

## A RichTextLabel specifically for use with [b]Dialogue Manager[/b] dialogue.
class_name DialogueLabel extends RichTextLabel


## Emitted for each letter typed out.
signal spoke(letter: String, letter_index: int, speed: float)

## Emitted when typing paused for a `[wait]`
signal paused_typing(duration: float)

## Emitted when the player skips the typing of dialogue.
signal skipped_typing()

## Emitted when typing finishes.
signal finished_typing()


# The action to press to skip typing.
@export var skip_action: StringName = &"ui_cancel"

## The speed with which the text types out.
@export var seconds_per_step: float = 0.02

## Automatically have a brief pause when these characters are encountered.
@export var pause_at_characters: String = ".?!"

## Don't auto pause if the charcter after the pause is one of these.
@export var skip_pause_at_character_if_followed_by: String = ")\""

## Don't auto pause after these abbreviations (only if "." is in `pause_at_characters`).[br]
## Abbreviations are limitted to 5 characters in length [br]
## Does not support multi-period abbreviations (ex. "p.m.")
@export var skip_pause_at_abbreviations: PackedStringArray = ["Mr", "Mrs", "Ms", "Dr", "etc", "eg", "ex"]

## The amount of time to pause when exposing a character present in pause_at_characters.
@export var seconds_per_pause_step: float = 0.3


## The current line of dialogue.
var dialogue_line:
	set(next_dialogue_line):
		dialogue_line = next_dialogue_line
		custom_minimum_size = Vector2.ZERO
		text = dialogue_line.text
	get:
		return dialogue_line

## Whether the label is currently typing itself out.
var is_typing: bool = false:
	set(value):
		var is_finished: bool = is_typing != value and value == false
		is_typing = value
		if is_finished:
			finished_typing.emit()
	get:
		return is_typing

var _last_wait_index: int = -1
var _last_mutation_index: int = -1
var _waiting_seconds: float = 0
var _is_awaiting_mutation: bool = false


func _process(delta: float) -> void:
	if self.is_typing:
		# Type out text
		if visible_ratio < 1:
			# See if we are waiting
			if _waiting_seconds > 0:
				_waiting_seconds = _waiting_seconds - delta
			# If we are no longer waiting then keep typing
			if _waiting_seconds <= 0:
				_type_next(delta, _waiting_seconds)
		else:
			# Make sure any mutations at the end of the line get run
			_mutate_inline_mutations(get_total_character_count())
			self.is_typing = false


func _unhandled_input(event: InputEvent) -> void:
	# Note: this will no longer be reached if using Dialogue Manager > 2.32.2. To make skip handling
	# simpler (so all of mouse/keyboard/joypad are together) it is now the responsibility of the
	# dialogue balloon.
	if self.is_typing and visible_ratio < 1 and InputMap.has_action(skip_action) and event.is_action_pressed(skip_action):
		get_viewport().set_input_as_handled()
		skip_typing()


## Start typing out the text
func type_out() -> void:
	text = dialogue_line.text
	visible_characters = 0
	visible_ratio = 0
	_waiting_seconds = 0
	_last_wait_index = -1
	_last_mutation_index = -1

	self.is_typing = true

	# Allow typing listeners a chance to connect
	await get_tree().process_frame

	if get_total_character_count() == 0:
		self.is_typing = false
	elif seconds_per_step == 0:
		_mutate_remaining_mutations()
		visible_characters = get_total_character_count()
		self.is_typing = false


## Stop typing out the text and jump right to the end
func skip_typing() -> void:
	_mutate_remaining_mutations()
	visible_characters = get_total_character_count()
	self.is_typing = false
	skipped_typing.emit()


# Type out the next character(s)
func _type_next(delta: float, seconds_needed: float) -> void:
	if _is_awaiting_mutation: return

	if visible_characters == get_total_character_count():
		return

	if _last_mutation_index != visible_characters:
		_last_mutation_index = visible_characters
		_mutate_inline_mutations(visible_characters)
		if _is_awaiting_mutation: return

	var additional_waiting_seconds: float = _get_pause(visible_characters)

	# Pause on characters like "."
	if _should_auto_pause():
		additional_waiting_seconds += seconds_per_pause_step

	# Pause at literal [wait] directives
	if _last_wait_index != visible_characters and additional_waiting_seconds > 0:
		_last_wait_index = visible_characters
		_waiting_seconds += additional_waiting_seconds
		paused_typing.emit(_get_pause(visible_characters))
	else:
		visible_characters += 1
		if visible_characters <= get_total_character_count():
			spoke.emit(get_parsed_text()[visible_characters - 1], visible_characters - 1, _get_speed(visible_characters))
		# See if there's time to type out some more in this frame
		seconds_needed += seconds_per_step * (1.0 / _get_speed(visible_characters))
		if seconds_needed > delta:
			_waiting_seconds += seconds_needed
		else:
			_type_next(delta, seconds_needed)


# Get the pause for the current typing position if there is one
func _get_pause(at_index: int) -> float:
	return dialogue_line.pauses.get(at_index, 0)


# Get the speed for the current typing position
func _get_speed(at_index: int) -> float:
	var speed: float = 1
	for index in dialogue_line.speeds:
		if index > at_index:
			return speed
		speed = dialogue_line.speeds[index]
	return speed


# Run any inline mutations that haven't been run yet
func _mutate_remaining_mutations() -> void:
	for i in range(visible_characters, get_total_character_count() + 1):
		_mutate_inline_mutations(i)


# Run any mutations at the current typing position
func _mutate_inline_mutations(index: int) -> void:
	for inline_mutation in dialogue_line.inline_mutations:
		# inline mutations are an array of arrays in the form of [character index, resolvable function]
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index:
			_is_awaiting_mutation = true
			# The DialogueManager can't be referenced directly here so we need to get it by its path
			await Engine.get_singleton("DialogueManager").mutate(inline_mutation[1], dialogue_line.extra_game_states, true)
			_is_awaiting_mutation = false


# Determine if the current autopause character at the cursor should qualify to pause typing.
func _should_auto_pause() -> bool:
	if visible_characters == 0: return false

	var parsed_text: String = get_parsed_text()

	# Ignore pause characters if they are next to a non-pause character
	if parsed_text[visible_characters] in skip_pause_at_character_if_followed_by.split():
		return false

	# Ignore "." if it's between two numbers
	if visible_characters > 3 and parsed_text[visible_characters - 1] == ".":
		var possible_number: String = parsed_text.substr(visible_characters - 2, 3)
		if str(float(possible_number)) == possible_number:
			return false

	# Ignore "." if it's used in an abbreviation
	# Note: does NOT support multi-period abbreviations (ex. p.m.)
	if "." in pause_at_characters and parsed_text[visible_characters - 1] == ".":
		for abbreviation in skip_pause_at_abbreviations:
			if visible_characters >= abbreviation.length():
				var previous_characters: String = parsed_text.substr(visible_characters - abbreviation.length() - 1, abbreviation.length())
				if previous_characters == abbreviation:
					return false

	# Ignore two non-"." characters next to each other
	var other_pause_characters: PackedStringArray = pause_at_characters.replace(".", "").split()
	if visible_characters > 1 and parsed_text[visible_characters - 1] in other_pause_characters and parsed_text[visible_characters] in other_pause_characters:
		return false

	return parsed_text[visible_characters - 1] in pause_at_characters.split()
