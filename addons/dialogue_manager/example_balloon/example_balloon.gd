extends CanvasLayer


signal actioned(next_id)


const Line = preload("res://addons/dialogue_manager/dialogue_line.gd")
const MenuItem = preload("res://addons/dialogue_manager/example_balloon/menu_item.tscn")


onready var balloon := $Balloon
onready var margin := $Balloon/Margin
onready var character_label := $Balloon/Margin/VBox/Character
onready var size_check_label := $SizeCheck
onready var dialogue_label := $Balloon/Margin/VBox/Dialogue
onready var responses_menu := $Balloon/Margin/VBox/Responses/Menu


var dialogue: Line


func _ready() -> void:
	balloon.visible = false
	size_check_label.modulate.a = 0
	
	if not dialogue:
		queue_free()
		return
	
	if dialogue.character != "":
		character_label.visible = true
		character_label.bbcode_text = dialogue.character
	else:
		character_label.visible = false
	dialogue_label.dialogue = dialogue
	
	# For some reason, RichTextLabels within containers
	# don't resize properly when their content changes
	size_check_label.rect_size.x = dialogue_label.rect_size.x
	size_check_label.bbcode_text = dialogue.dialogue
	# Give the size check a chance to resize
	yield(get_tree(), "idle_frame")
	
	# Resize our dialogue label with the new size hint
	dialogue_label.rect_min_size = Vector2(dialogue_label.rect_size.x, size_check_label.get_content_height())
	dialogue_label.rect_size = Vector2(0, 0)
	
	# Show any responses we have
	responses_menu.is_active = false
	for item in responses_menu.get_children():
		item.queue_free()
	
	if dialogue.responses.size() > 1:
		for response in dialogue.responses:
			var item = MenuItem.instance()
			item.bbcode_text = response.prompt
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
	if dialogue.responses.size() > 1:
		responses_menu.is_active = true
		responses_menu.visible = true
		responses_menu.index = 0
		var response = yield(responses_menu, "actioned")
		next_id = dialogue.responses[response[0]].next_id
	else:
		while true:
			if Input.is_action_just_pressed("ui_accept"):
				next_id = dialogue.next_id
				break
			yield(get_tree(), "idle_frame")
	
	# Send back input
	emit_signal("actioned", next_id)
	queue_free()
