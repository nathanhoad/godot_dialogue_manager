extends CanvasLayer


signal actioned(next_id)


onready var balloon := $Balloon
onready var margin := $Balloon/Margin
onready var character_label := $Balloon/Margin/VBox/Character
onready var dialogue_label := $Balloon/Margin/VBox/Dialogue
onready var responses_menu := $Balloon/Margin/VBox/Responses
onready var response_template := $ResponseTemplate


var dialogue_line: Dictionary
var is_waiting_for_input: bool = false


func _ready() -> void:
	if dialogue_line.size() == 0:
		queue_free()
		return
	
	response_template.hide()
	balloon.modulate.a = 0
	
	var viewport_size = balloon.get_viewport_rect().size
	balloon.anchor_right = 1
	balloon.rect_min_size = Vector2(viewport_size.x * 0.9, 0)
	balloon.rect_size = Vector2.ZERO
	
	character_label.visible = dialogue_line.character != ""
	character_label.bbcode_text = dialogue_line.character
	
	dialogue_label.rect_size.x = balloon.rect_size.x - margin.get("custom_constants/margin_left") - margin.get("custom_constants/margin_right")
	dialogue_label.dialogue_line = dialogue_line
	yield(dialogue_label.reset_height(), "completed")
	
	# Show any responses we have
	if dialogue_line.responses.size() > 0:
		for response in dialogue_line.responses:
			# Duplicate the template so we can grab the fonts, sizing, etc
			var item: RichTextLabel = response_template.duplicate(0)
			item.name = "Response" + str(responses_menu.get_child_count())
			if not response.is_allowed:
				item.name += "Disallowed"
			item.bbcode_text = response.text
			item.connect("mouse_entered", self, "_on_response_mouse_entered", [item])
			item.connect("gui_input", self, "_on_response_gui_input", [item])
			item.show()
			responses_menu.add_child(item)
	
	# Make sure our responses get included in the height reset
	responses_menu.visible = true
	margin.rect_size = Vector2(0, 0)
	
	yield(get_tree(), "idle_frame")
	
	balloon.rect_min_size = margin.rect_size
	balloon.rect_size = Vector2(0, 0)
	balloon.rect_global_position = Vector2((viewport_size.x - balloon.rect_size.x) * 0.5, viewport_size.y - balloon.rect_size.y - viewport_size.y * 0.02)
	
	# Ok, we can hide it now. It will come back later if we have any responses
	responses_menu.visible = false
	
	# Show our box
	balloon.modulate.a = 1
	
	if dialogue_line.text != "":
		dialogue_label.type_out()
		yield(dialogue_label, "finished")
	
	# Wait for input
	if dialogue_line.responses.size() > 0:
		responses_menu.visible = true
		configure_focus()
	elif dialogue_line.time != null:
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		yield(get_tree().create_timer(time), "timeout")
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	get_tree().set_input_as_handled()


func next(next_id: String) -> void:
	emit_signal("actioned", next_id)
	queue_free()


### Helpers


func configure_focus() -> void:
	responses_menu.show()
	
	var items = get_responses()
	for i in items.size():
		var item: Control = items[i]
		
		item.focus_mode = Control.FOCUS_ALL
		
		item.focus_neighbour_left = item.get_path()
		item.focus_neighbour_right = item.get_path()
		
		if i == 0:
			item.focus_neighbour_top = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbour_top = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()
		
		if i == items.size() - 1:
			item.focus_neighbour_bottom = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbour_bottom = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()
	
	items[0].grab_focus()


func get_responses() -> Array:
	var items: Array = []
	for child in responses_menu.get_children():
		if "disallowed" in child.name.to_lower(): continue
		items.append(child)
		
	return items


### Signals


func _on_response_mouse_entered(item):
	if not "disallowed" in item.name.to_lower():
		item.grab_focus()


func _on_response_gui_input(event, item):
	if "disallowed" in item.name.to_lower(): return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.responses[item.get_index()].next_id)
	elif event.is_action_pressed("ui_accept") and item in get_responses():
		next(dialogue_line.responses[item.get_index()].next_id)


# When there are no response options the balloon itself is the clickable thing
func _on_Balloon_gui_input(event):
	if not is_waiting_for_input: return
	
	get_tree().set_input_as_handled()
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.next_id)
	elif event.is_action_pressed("ui_accept") and balloon.get_focus_owner() == balloon:
		next(dialogue_line.next_id)
