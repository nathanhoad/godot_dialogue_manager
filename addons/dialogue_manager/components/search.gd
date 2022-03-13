tool

extends HBoxContainer


signal open_requested()
signal close_requested()


export var _text_edit := NodePath()

onready var text_edit: TextEdit = get_node(_text_edit)

onready var input: LineEdit = $Input
onready var result_label: Label = $ResultLabel
onready var previous_button: ToolButton = $PreviousButton
onready var next_button: ToolButton = $NextButton


var results: Array = []
var result_index: int = -1 setget set_result_index


func _ready():
	previous_button.icon = get_icon("ArrowLeft", "EditorIcons")
	next_button.icon = get_icon("ArrowRight", "EditorIcons")
	self.result_index = -1
	
	text_edit.connect("gui_input", self, "_on_text_edit_gui_input")
	

func search(text: String) -> void:
	results.clear()
	
	var lines = text_edit.text.split("\n")
	for i in range(0, lines.size()):
		var line = lines[i]
		
		var column = line.findn(text, 0)
		while column > -1:
			results.append([i, column, text.length()])
			column = line.findn(text, column + 1)
	
	self.result_index = 0


### Set/get


func set_result_index(value: int) -> void:
	result_index = value
	
	if results.size() > 0:
		var r = results[result_index]
		text_edit.cursor_set_line(r[0])
		text_edit.select(r[0], r[1], r[0], r[1] + r[2])
	else:
		result_index = -1
	
	result_label.text = "%d of %d" % [result_index + 1, results.size()]


### Signals


func _on_text_edit_gui_input(event):
	if event is InputEventKey and event.is_pressed() and event.as_text() == "Control+F":
		emit_signal("open_requested")


func _on_Input_text_changed(new_text):
	search(new_text)


func _on_PreviousButton_pressed():
	self.result_index = wrapi(result_index - 1, 0, results.size())


func _on_NextButton_pressed():
	self.result_index = wrapi(result_index + 1, 0, results.size())


func _on_Search_visibility_changed():
	if visible:
		if is_instance_valid(input):
			input.grab_focus()
			var selection = text_edit.get_selection_text()
			if selection != "":
				input.text = selection
				search(selection)
	else:
		input.text = ""


func _on_Input_gui_input(event):
	if event is InputEventKey and event.is_pressed() and event.as_text() == "Escape":
		emit_signal("close_requested")
