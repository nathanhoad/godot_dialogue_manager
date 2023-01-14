extends RichTextLabel


signal spoke(letter: String, letter_index: int, speed: float)
signal paused_typing(duration: float)
signal finished_typing()


const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")


## The action to press to skip typing
@export var skip_action: String = "ui_cancel"

## The speed with which the text types out
@export var seconds_per_step: float = 0.02

## When off, the label will grow in height as the text types out
@export var start_with_full_height: bool = true


var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		dialogue_line = next_dialogue_line
		custom_minimum_size = Vector2.ZERO
		text = dialogue_line.text
	get:
		return dialogue_line

var last_wait_index: int = -1
var last_mutation_index: int = -1
var waiting_seconds: float = 0
var is_typing: bool = false
var has_finished: bool = false


func _process(delta: float) -> void:
	if is_typing:
		# Type out text
		if visible_ratio < 1:
			# If cancel is pressed then skip typing it out
			if Input.is_action_just_pressed(skip_action):
				# Run any inline mutations that haven't been run yet
				for i in range(visible_characters, get_total_character_count()):
					mutate_inline_mutations(i)
				visible_characters = get_total_character_count()
				has_finished = true
				emit_signal("finished_typing")
				return
			
			# Otherwise, see if we are waiting
			if waiting_seconds > 0:
				waiting_seconds = waiting_seconds - delta
			# If we are no longer waiting then keep typing
			if waiting_seconds <= 0:
				type_next(delta, waiting_seconds)
		else:
			is_typing = false
			if has_finished == false:
				has_finished = true
				emit_signal("finished_typing")


func reset_height() -> void:
	# For some reason, RichTextLabels within containers don't resize properly when their content 
	# changes so we make a clone that isn't bound by a VBox
	var size_check_label: RichTextLabel = duplicate(DUPLICATE_USE_INSTANTIATION)
	size_check_label.modulate.a = 0
	size_check_label.anchor_left = 1
	get_tree().current_scene.add_child(size_check_label)
	size_check_label.size = Vector2(size.x, 0)
	
	if start_with_full_height:
		# Give the size check a chance to resize
		await get_tree().process_frame
	
	# Resize our dialogue label with the new size hint
	custom_minimum_size = size_check_label.size
	size = Vector2.ZERO
	
	# Destroy our clone
	size_check_label.free()


# Start typing out the text
func type_out() -> void:
	text = dialogue_line.text
	visible_characters = 0
	has_finished = false
	waiting_seconds = 0
	
	# Text isn't calculated until the next frame
	await get_tree().process_frame
	
	if get_total_character_count() == 0:
		emit_signal("finished_typing")
	elif seconds_per_step == 0:
		is_typing = false
		# Run any inline mutations
		for i in range(0, get_total_character_count()):
			mutate_inline_mutations(i)
		visible_characters = get_total_character_count()
		emit_signal("finished_typing")
	else:
#		percent_per_index = 100.0 / float(get_total_character_count()) / 100.0
		is_typing = true


# Type out the next character(s)
func type_next(delta: float, seconds_needed: float) -> void:
	if visible_characters == get_total_character_count():
		return
	
	if last_mutation_index != visible_characters:
		last_mutation_index = visible_characters
		mutate_inline_mutations(visible_characters)
	
	if last_wait_index != visible_characters and get_pause(visible_characters) > 0:
		last_wait_index = visible_characters
		waiting_seconds += get_pause(visible_characters)
		emit_signal("paused_typing", get_pause(visible_characters))
	else:
#		visible_ratio += percent_per_index
		visible_characters += 1
		seconds_needed += seconds_per_step * (1.0 / get_speed(visible_characters))
		if seconds_needed > delta:
			waiting_seconds += seconds_needed
			if visible_characters < get_total_character_count():
				emit_signal("spoke", text[visible_characters - 1], visible_characters - 1, get_speed(visible_characters))
		else:
			type_next(delta, seconds_needed)


# Get the pause for the current typing position if there is one
func get_pause(at_index: int) -> float:
	return dialogue_line.pauses.get(at_index, 0)


# Get the speed for the current typing position
func get_speed(at_index: int) -> float:
	var speed: float = 1
	for index in dialogue_line.speeds:
		if index > at_index:
			return speed
		speed = dialogue_line.speeds[index]
	return speed


# Run any mutations at the current typing position
func mutate_inline_mutations(index: int) -> void:
	for inline_mutation in dialogue_line.inline_mutations:
		# inline mutations are an array of arrays in the form of [character index, resolvable function]
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index:
			# The DialogueManager can't be referenced directly here so we need to get it by its path
			get_node("/root/DialogueManager").mutate(inline_mutation[1], dialogue_line.extra_game_states)
