tool

extends VBoxContainer


signal open_requested()
signal close_requested()


export var _text_edit := NodePath()

onready var text_edit: TextEdit = get_node(_text_edit)

onready var input: LineEdit = $Search/Input
onready var result_label: Label = $Search/ResultLabel
onready var previous_button: ToolButton = $Search/PreviousButton
onready var next_button: ToolButton = $Search/NextButton
onready var replace_panel: HBoxContainer = $Replace
onready var replace_input: LineEdit = $Replace/Input
onready var replace_button: ToolButton = $Replace/ReplaceButton
onready var replace_all_button: ToolButton = $Replace/ReplaceAllButton

var results: Array = []
var result_index: int = -1 setget set_result_index


func _ready():
	previous_button.icon = get_icon("ArrowLeft", "EditorIcons")
	next_button.icon = get_icon("ArrowRight", "EditorIcons")
	self.result_index = -1
	
	text_edit.connect("gui_input", self, "_on_text_edit_gui_input")
	text_edit.connect("text_changed", self, "_on_text_edit_text_changed")
	
	replace_panel.visible = false
	replace_button.disabled = true
	replace_all_button.disabled = true
	

func search(text: String = "", default_result_index: int = 0) -> void:
	results.clear()
	
	if text == "":
		text = input.text
	
	var lines = text_edit.text.split("\n")
	for line_number in range(0, lines.size()):
		var line = lines[line_number]
		
		var column = line.findn(text, 0)
		while column > -1:
			results.append([line_number, column, text.length()])
			column = line.findn(text, column + 1)
	
	if results.size() > 0:
		replace_button.disabled = false
		replace_all_button.disabled = false
	else:
		replace_button.disabled = true
		replace_all_button.disabled = true
	
	self.result_index = clamp(default_result_index, 0, results.size() - 1)


### Set/get


func set_result_index(value: int) -> void:
	result_index = value
	
	if results.size() > 0:
		var r = results[result_index]
		text_edit.cursor_set_line(r[0])
		text_edit.select(r[0], r[1], r[0], r[1] + r[2])
	else:
		result_index = -1
		text_edit.deselect()
	
	result_label.text = "%d of %d" % [result_index + 1, results.size()]


### Signals


func _on_text_edit_gui_input(event):
	if event is InputEventKey and event.is_pressed() and event.as_text() == "Control+F":
		emit_signal("open_requested")


func _on_text_edit_text_changed():
	results.clear()


func _on_Input_text_changed(new_text):
	search(new_text)


func _on_PreviousButton_pressed():
	self.result_index = wrapi(result_index - 1, 0, results.size())


func _on_NextButton_pressed():
	self.result_index = wrapi(result_index + 1, 0, results.size())


func _on_SearchAndReplace_visibility_changed():
	if visible:
		if is_instance_valid(input):
			input.grab_focus()
			var selection = text_edit.get_selection_text()
			if input.text == "" and selection != "":
				input.text = selection
				search(selection)
			else:
				search()
	else:
		input.text = ""


func _on_Input_gui_input(event):
	if event is InputEventKey and event.is_pressed():
		match event.as_text():
			"Enter":
				search(input.text)
			"Escape":
				emit_signal("close_requested")


func _on_ReplaceButton_pressed():
	if result_index == -1: return
	
	# Replace the selection at result index
	var r = results[result_index]
	var lines = text_edit.text.split("\n")
	var line = lines[r[0]]
	line = line.substr(0, r[1]) + replace_input.text + line.substr(r[1] + r[2])
	lines[r[0]] = line
	text_edit.text = lines.join("\n")
	search(input.text, self.result_index)


func _on_ReplaceAllButton_pressed():
	text_edit.text = text_edit.text.replace(input.text, replace_input.text)
	search()


func _on_ReplaceCheckbox_toggled(button_pressed):
	replace_panel.visible = button_pressed
	if button_pressed:
		replace_input.grab_focus()


func _on_Input_focus_entered():
	if results.size() == 0:
		search()
	else:
		self.result_index = result_index
