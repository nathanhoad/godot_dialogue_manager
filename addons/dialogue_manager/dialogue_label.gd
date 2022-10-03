extends RichTextLabel


signal spoke(letter, speed)
signal paused(duration)
signal finished()


const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")

export var skip_action: String = "ui_cancel"
export var seconds_per_step: float = 0.02


var dialogue: DialogueLine

var index: int = 0
var percent_per_index: float = 0
var last_wait_index: int = -1
var last_mutation_index: int = -1
var waiting_seconds: float = 0
var is_typing: bool = false
var has_finished: bool = false


func _ready() -> void:
	bbcode_text = ""


func _process(delta: float) -> void:
	if is_typing:
		# Type out text
		if percent_visible < 1:
			# If cancel is pressed then skip typing it out
			if Input.is_action_just_pressed(skip_action):
				percent_visible = 1
				# Run any inline mutations that haven't been run yet
				for i in range(index, get_total_character_count()):
					dialogue.mutate_inline_mutations(i)
				has_finished = true
				emit_signal("finished")
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
				emit_signal("finished")


func reset_height() -> void:
	# If there is no dialogue then this label should have no height
	if dialogue.dialogue == "":
		fit_content_height = false
		rect_min_size = Vector2(rect_size.x, 0)
		rect_size = Vector2.ZERO
		yield(get_tree(), "idle_frame")
		return
	
	fit_content_height = true
	
	# For some reason, RichTextLabels within containers don't resize properly when their content 
	# changes so we make a clone that isn't bound by a VBox
	var size_check_label = duplicate(0)
	size_check_label.modulate.a = 0
	get_tree().current_scene.add_child(size_check_label)
	size_check_label.rect_size.x = rect_size.x
	size_check_label.bbcode_text = dialogue.dialogue
	
	# Give the size check a chance to resize
	yield(get_tree(), "idle_frame")
	
	# Resize our dialogue label with the new size hint
	rect_min_size = Vector2(rect_size.x, size_check_label.get_content_height())
	rect_size = Vector2.ZERO
	
	# Destroy our clone
	size_check_label.queue_free()
	


func type_next(delta: float, seconds_needed: float) -> void:
	if last_mutation_index != index:
		last_mutation_index = index
		dialogue.mutate_inline_mutations(index)
	
	if last_wait_index != index and dialogue.get_pause(index) > 0:
		last_wait_index = index
		waiting_seconds += dialogue.get_pause(index)
		emit_signal("paused", dialogue.get_pause(index))
	else:
		percent_visible += percent_per_index
		index += 1
		seconds_needed += seconds_per_step * (1.0 / dialogue.get_speed(index))
		if seconds_needed > delta:
			waiting_seconds += seconds_needed
			if index < text.length():
				emit_signal("spoke", text[index - 1], dialogue.get_speed(index))
		else:
			type_next(delta, seconds_needed)


func type_out() -> void:
	bbcode_text = dialogue.dialogue
	percent_visible = 0
	index = 0
	has_finished = false
	waiting_seconds = 0
	
	# Text isn't calculated until the next frame
	yield(get_tree(), "idle_frame")
	if not get_total_character_count():
		emit_signal("finished")
		queue_free()
		return
	
	if seconds_per_step == 0:
		is_typing = false
		percent_visible = 1
		# Run any inline mutations
		for i in range(index, get_total_character_count()):
			dialogue.mutate_inline_mutations(i)
	else:
		percent_per_index = 100.0 / float(get_total_character_count()) / 100.0
		is_typing = true
