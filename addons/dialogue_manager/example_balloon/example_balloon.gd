extends CanvasLayer


signal actioned(next_id)


const DialogueLine = preload("res://addons/dialogue_manager/dialogue_line.gd")
const ExampleMenuItem = preload("res://addons/dialogue_manager/example_balloon/menu_item.tscn")


onready var balloon := $Balloon
onready var margin := $Balloon/Margin
onready var character_label := $Balloon/Margin/VBox/Character
onready var dialogue_label := $Balloon/Margin/VBox/Dialogue
onready var responses_menu := $Balloon/Margin/VBox/Responses/Menu


var dialogue: DialogueLine


func _ready() -> void:
	balloon.visible = false
	responses_menu.is_active = false
	
	if not dialogue:
		queue_free()
		return
	
	if dialogue.character != "":
		character_label.visible = true
		character_label.bbcode_text = dialogue.character
	else:
		character_label.visible = false
	dialogue_label.dialogue = dialogue

	yield(dialogue_label.reset_height(), "completed")
	
	# Show any responses we have
	for item in responses_menu.get_children():
		item.queue_free()
	
	if dialogue.responses.size() > 0:
		for response in dialogue.responses:
			var item = ExampleMenuItem.instance()
			item.bbcode_text = response.prompt
			item.is_allowed = response.is_allowed
			responses_menu.add_child(item)
	
	# Make sure our responses get included in the height reset
	responses_menu.visible = true
	margin.rect_size = Vector2(0, 0)
	
	yield(get_tree(), "idle_frame")
	
	balloon.rect_min_size = margin.rect_size
	balloon.rect_size = Vector2(0, 0)
	balloon.rect_global_position.y = balloon.get_viewport_rect().size.y - balloon.rect_size.y - 20
	
	# Ok, we can hide it now. It will come back later if we have any responses
	responses_menu.visible = false
	
	# Show our box
	balloon.visible = true
	
	dialogue_label.type_out()
	yield(dialogue_label, "finished")
	
	# Wait for input
	var next_id: String = ""
	if dialogue.responses.size() > 0:
		responses_menu.is_active = true
		responses_menu.visible = true
		responses_menu.index = 0
		var response = yield(responses_menu, "actioned")
		next_id = dialogue.responses[response[0]].next_id
	elif dialogue.time != null:
		var time = dialogue.dialogue.length() * 0.02 if dialogue.time == "auto" else dialogue.time.to_float()
		yield(get_tree().create_timer(time), "timeout")
		next_id = dialogue.next_id
	else:
		while true:
			if Input.is_action_just_pressed("ui_accept"):
				next_id = dialogue.next_id
				break
			yield(get_tree(), "idle_frame")
	
	# Send back input
	emit_signal("actioned", next_id)
	queue_free()
