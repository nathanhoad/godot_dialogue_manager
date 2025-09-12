@icon("./assets/responses_menu.svg")

## A [Container] for dialogue responses provided by [b]Dialogue Manager[/b].
class_name DialogueResponsesMenu extends Container


## Emitted when a response is focused.
signal response_focused(response: Control)

## Emitted when a response is selected.
signal response_selected(response: Control)


## Optionally specify a control to duplicate for each response
@export var response_template: Control

## The action for accepting a response (is possibly overridden by parent dialogue balloon).
@export var next_action: StringName = &""

## Automatically set up focus neighbours when the responses list changes.
@export var auto_configure_focus: bool = true

## Automatically focus the first item when showing.
@export var auto_focus_first_item: bool = true

## Hide any responses where [code]is_allowed[/code] is false
@export var hide_failed_responses: bool = false

## The list of dialogue responses.
var responses: Array = []:
	set(value):
		responses = value
		_apply_responses()
	get:
		return responses

# The previously focused item in this menu.
var _previously_focused_item: Control = null


func _ready() -> void:
	visibility_changed.connect(func():
		if auto_focus_first_item and visible and get_menu_items().size() > 0:
			var first_item: Control = get_menu_items()[0]
			if first_item.is_inside_tree():
				first_item.grab_focus()
	)

	if is_instance_valid(response_template):
		response_template.hide()

	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Get the selectable items in the menu.
func get_menu_items() -> Array:
	var items: Array = []
	for child in get_children():
		if not child.visible: continue
		if "Disallowed" in child.name: continue
		items.append(child)

	return items


## Prepare the menu for keyboard and mouse navigation.
func configure_focus() -> void:
	var items = get_menu_items()
	for i in items.size():
		var item: Control = items[i]

		item.focus_mode = Control.FOCUS_ALL

		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()

		if i == 0:
			item.focus_neighbor_top = item.get_path()
			item.focus_neighbor_left = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbor_top = items[i - 1].get_path()
			item.focus_neighbor_left = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()

		if i == items.size() - 1:
			item.focus_neighbor_bottom = item.get_path()
			item.focus_neighbor_right = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbor_bottom = items[i + 1].get_path()
			item.focus_neighbor_right = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()

		item.mouse_entered.connect(_on_response_mouse_entered.bind(item))
		item.gui_input.connect(_on_response_gui_input.bind(item, item.get_meta("response")))

	_previously_focused_item = items[0]

	if auto_focus_first_item:
		items[0].grab_focus()


#region Internal


# Set up the visual side of things.
func _apply_responses() -> void:
	# Remove any current items
	for item in get_children():
		if item == response_template: continue

		remove_child(item)
		item.queue_free()

	# Add new items
	if responses.size() > 0:
		for response in responses:
			if hide_failed_responses and not response.is_allowed: continue

			var item: Control
			if is_instance_valid(response_template):
				item = response_template.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS)
				item.show()
			else:
				item = Button.new()
			item.name = "Response%d" % get_child_count()
			if not response.is_allowed:
				item.name = item.name + &"Disallowed"
				item.disabled = true

			# If the item has a response property then use that
			if "response" in item:
				item.response = response
			# Otherwise assume we can just set the text
			else:
				item.text = response.text

			item.set_meta("response", response)

			add_child(item)

		if auto_configure_focus:
			configure_focus()


#endregion

#region Signals


func _on_focus_changed(control: Control) -> void:
	if "Disallowed" in control.name: return
	if not control in get_menu_items(): return

	if _previously_focused_item != control:
		_previously_focused_item = control
		response_focused.emit(control)


func _on_response_mouse_entered(item: Control) -> void:
	if "Disallowed" in item.name: return

	item.grab_focus()


func _on_response_gui_input(event: InputEvent, item: Control, response) -> void:
	if "Disallowed" in item.name: return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		response_selected.emit(response)
	elif event.is_action_pressed(&"ui_accept" if next_action.is_empty() else next_action) and item in get_menu_items():
		get_viewport().set_input_as_handled()
		response_selected.emit(response)


#endregion
