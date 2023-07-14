extends CanvasLayer


const COLORS = {
	"Nathan": "ff5741",
	"Coco": "f5cfa2"
}


@onready var audio_stream_player := $AudioStreamPlayer
@onready var dialogue_label := $DialogueLabel
@onready var responses_menu := $Background/Margin/Responses
@onready var response_template := $Background/Margin/ResponseTemplate


## The dialogue resource
var resource: DialogueResource

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

# Who is talking
var target: Node2D

## The current line
var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		if not next_dialogue_line:
			queue_free()
			return
		
		# Remove any previous responses
		for child in responses_menu.get_children():
			responses_menu.remove_child(child)
			child.queue_free()
		
		dialogue_line = next_dialogue_line
		
		# Center the dialogue
		dialogue_line.text = "[center]%s" % dialogue_line.text
		
		dialogue_label.hide()
		dialogue_label.dialogue_line = dialogue_line
		
		# Set the colour and attach the dialogue to the character
		dialogue_label.set("theme_override_colors/default_color", Color(COLORS[dialogue_line.character]))
		dialogue_label.set("theme_override_colors/font_outline_color", Color(COLORS[dialogue_line.character]).darkened(0.4))
		target = get_tree().current_scene.find_child(dialogue_line.character)
		dialogue_label.global_position = target.global_position - Vector2(dialogue_label.size.x * 0.5, dialogue_label.get_content_height())
		
		dialogue_label.show()
		dialogue_label.type_out()
		
		# Play sound and wait for sound to finish
		var stream = load("res://examples/point_n_click_balloon/voice/en/%s.ogg" % dialogue_line.translation_key)
		audio_stream_player.stream = stream
		audio_stream_player.play()
		
		Events.emit_signal("character_started_talking", dialogue_line.character)
		await audio_stream_player.finished
		Events.emit_signal("character_finished_talking", dialogue_line.character)
		dialogue_label.hide()
		
		if dialogue_line.responses.size() == 0:
			next(dialogue_line.next_id)
		else:
			for response in dialogue_line.responses:
				var item: RichTextLabel = response_template.duplicate(DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS)
				item.text = response.text
				item.show()
				responses_menu.add_child(item)
			configure_menu()
	get:
		return dialogue_line


func _ready() -> void:
	response_template.hide()
	dialogue_label.hide()
	
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)


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
	var items = get_responses()
	for i in items.size():
		var item: Control = items[i]
		
		item.focus_mode = Control.FOCUS_ALL
		
		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()
		
		if i == 0:
			item.focus_neighbor_top = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbor_top = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()
		
		if i == items.size() - 1:
			item.focus_neighbor_bottom = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbor_bottom = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()
		
		item.mouse_entered.connect(_on_response_mouse_entered.bind(item))
		item.focus_entered.connect(_on_response_focus_entered.bind(item))
		item.focus_exited.connect(_on_response_focus_exited.bind(item))
		item.gui_input.connect(_on_response_gui_input.bind(item))
	
	items[0].grab_focus()


# Get a list of enabled items
func get_responses() -> Array:
	var items: Array = []
	for child in responses_menu.get_children():
		if "Disallowed" in child.name: continue
		items.append(child)
		
	return items


### Signals


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false


func _on_response_mouse_entered(item: Control) -> void:
	if "Disallowed" in item.name: return
	
	item.grab_focus()


func _on_response_gui_input(event: InputEvent, item: Control) -> void:
	if "Disallowed" in item.name: return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.responses[item.get_index()].next_id)
	elif event.is_action_pressed("ui_accept") and item in get_responses():
		next(dialogue_line.responses[item.get_index()].next_id)


func _on_response_focus_entered(item):
	item.set("theme_override_colors/default_color", COLORS["Nathan"])


func _on_response_focus_exited(item):
	item.set("theme_override_colors/default_color", Color.WHITE)


func _on_dialogue_label_resized() -> void:
	if is_instance_valid(target):
		dialogue_label.global_position = target.global_position - Vector2(dialogue_label.size.x * 0.5, dialogue_label.get_content_height())
