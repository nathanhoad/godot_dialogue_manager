extends CanvasLayer


@onready var balloon: ColorRect = $Balloon
@onready var margin: MarginContainer = $Balloon/Margin
@onready var character_label: RichTextLabel = $Balloon/Margin/VBox/CharacterLabel
@onready var dialogue_label := $Balloon/Margin/VBox/DialogueLabel
@onready var responses_menu: VBoxContainer = $Balloon/Margin/VBox/Responses
@onready var response_template: RichTextLabel = %ResponseTemplate

## The dialogue resource
var resource: DialogueResource

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## The current line
var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		is_waiting_for_input = false
		
		if not next_dialogue_line:
			queue_free()
			return
		
		dialogue_line = next_dialogue_line
		
		# Remove any previous responses
		remove_previous_responses()
		
		# Show any responses we have
		display_responses()
		
		# Show our balloon
		balloon.show()
		will_hide_balloon = false
		
		dialogue_label.modulate.a = 1
		if not dialogue_line.text.is_empty():
			dialogue_label.type_out()
			await dialogue_label.finished_typing
		
		# Wait for input
		wait_for_input()
	get:
		return dialogue_line

func remove_previous_responses() -> void:
	for child in responses_menu.get_children():
		child.free()
		
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = dialogue_line.character
	
	dialogue_label.modulate.a = 0
	dialogue_label.dialogue_line = dialogue_line
	
func display_responses() -> void:
	responses_menu.modulate.a = 0
	if dialogue_line.responses.size() > 0:
		for response in dialogue_line.responses:
			# Duplicate the template so we can grab the fonts, sizing, etc
			var item: RichTextLabel = response_template.duplicate(0)
			item.name = "Response%d" % responses_menu.get_child_count()
			if not response.is_allowed:
				item.name = String(item.name) + "Disallowed"
				item.modulate.a = 0.4
			item.text = response.text
			item.show()
			responses_menu.add_child(item)
			
func wait_for_input() -> void:
	if dialogue_line.responses.size() > 0:
		response_template.hide()
		responses_menu.modulate.a = 1
		configure_menu()
	elif dialogue_line.time != null:
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

func _ready() -> void:
	response_template.hide()
	balloon.hide()
	balloon.custom_minimum_size.x = balloon.get_viewport_rect().size.x
	
	Engine.get_singleton("DialogueManager").mutation.connect(_on_mutation)


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	get_viewport().set_input_as_handled()


## Start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	temporary_game_states = extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


## Go to the next line
func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


### Helpers


# Set up keyboard movement and signals for the response menu
func configure_menu() -> void:
	balloon.focus_mode = Control.FOCUS_NONE
	
	var items = get_responses()
	var path_next
	var path_previous
	for i in items.size():
		#Setup response parameters
		items[i].focus_mode = Control.FOCUS_ALL
		items[i].focus_neighbor_left = items[i].get_path()
		items[i].focus_neighbor_right = items[i].get_path()
		items[i].mouse_entered.connect(_on_response_mouse_entered.bind(items[i]))
		items[i].gui_input.connect(_on_response_gui_input.bind(items[i]))
		
		# link above (previous) response, if it exists
		path_previous = items[max(0,i-1)].get_path()
		items[i].focus_neighbor_top = path_previous
		items[i].focus_previous = path_previous
		
		# link below (next) response, if it exists
		path_next = items[min(i+1, items.size()-1)].get_path()
		items[i].focus_neighbor_bottom = path_next
		items[i].focus_next = path_next
	
	items[0].grab_focus()


# Get a list of enabled items
func get_responses() -> Array:
	var items: Array = []
	for child in responses_menu.get_children():
		if "Disallowed" in child.name: continue
		items.append(child)
		
	return items


func handle_resize() -> void:
	if not is_instance_valid(margin):
		call_deferred("handle_resize")
		return
		
	balloon.custom_minimum_size.y = margin.size.y
	# Force a resize on only the height
	balloon.size.y = 0
	var viewport_size = balloon.get_viewport_rect().size
	balloon.global_position = Vector2((viewport_size.x - balloon.size.x) * 0.5, viewport_size.y - balloon.size.y)


### Signals


func _on_mutation() -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	get_tree().create_timer(0.1).timeout.connect(func():
		if will_hide_balloon:
			will_hide_balloon = false
			balloon.hide()
	)


func _on_response_mouse_entered(item: Control) -> void:
	if "Disallowed" in item.name: return
	
	item.grab_focus()


func _on_response_gui_input(event: InputEvent, item: Control) -> void:
	if "Disallowed" in item.name: return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.responses[item.get_index()].next_id)
	elif event.is_action_pressed("ui_accept") and item in get_responses():
		next(dialogue_line.responses[item.get_index()].next_id)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing	
	get_viewport().set_input_as_handled()
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.next_id)
	elif event.is_action_pressed("ui_accept") and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_margin_resized() -> void:
	handle_resize()
