@tool
extends VBoxContainer


signal open_requested()
signal close_requested()


const DialogueConstants = preload("../constants.gd")


@onready var input: LineEdit = $Search/Input
@onready var result_label: Label = $Search/ResultLabel
@onready var previous_button: Button = $Search/PreviousButton
@onready var next_button: Button = $Search/NextButton
@onready var match_case_button: CheckBox = $Search/MatchCaseCheckBox
@onready var replace_check_button: CheckButton = $Search/ReplaceCheckButton
@onready var replace_panel: HBoxContainer = $Replace
@onready var replace_input: LineEdit = $Replace/Input
@onready var replace_button: Button = $Replace/ReplaceButton
@onready var replace_all_button: Button = $Replace/ReplaceAllButton

# The code edit we will be affecting (for some reason exporting this didn't work)
var code_edit: CodeEdit:
	set(next_code_edit):
		code_edit = next_code_edit
		code_edit.gui_input.connect(_on_text_edit_gui_input)
		code_edit.text_changed.connect(_on_text_edit_text_changed)
	get:
		return code_edit

var results: Array = []
var result_index: int = -1:
	set(next_result_index):
		result_index = next_result_index
		if results.size() > 0:
			var r = results[result_index]
			code_edit.set_caret_line(r[0])
			code_edit.select(r[0], r[1], r[0], r[1] + r[2])
		else:
			result_index = -1
			if is_instance_valid(code_edit):
				code_edit.deselect()

		result_label.text = DialogueConstants.translate(&"n_of_n").format({ index = result_index + 1, total = results.size() })
	get:
		return result_index


func _ready() -> void:
	apply_theme()

	input.placeholder_text = DialogueConstants.translate(&"search.placeholder")
	previous_button.tooltip_text = DialogueConstants.translate(&"search.previous")
	next_button.tooltip_text = DialogueConstants.translate(&"search.next")
	match_case_button.text = DialogueConstants.translate(&"search.match_case")
	$Search/ReplaceCheckButton.text = DialogueConstants.translate(&"search.toggle_replace")
	replace_button.text = DialogueConstants.translate(&"search.replace")
	replace_all_button.text = DialogueConstants.translate(&"search.replace_all")
	$Replace/ReplaceLabel.text = DialogueConstants.translate(&"search.replace_with")

	self.result_index = -1

	replace_panel.hide()
	replace_button.disabled = true
	replace_all_button.disabled = true

	hide()


func focus_line_edit() -> void:
	input.grab_focus()
	input.select_all()


func apply_theme() -> void:
	if is_instance_valid(previous_button):
		previous_button.icon = get_theme_icon("ArrowLeft", "EditorIcons")
	if is_instance_valid(next_button):
		next_button.icon = get_theme_icon("ArrowRight", "EditorIcons")


# Find text in the code
func search(text: String = "", default_result_index: int = 0) -> void:
	results.clear()

	if text == "":
		text = input.text

	var lines = code_edit.text.split("\n")
	for line_number in range(0, lines.size()):
		var line = lines[line_number]

		var column = find_in_line(line, text, 0)
		while column > -1:
			results.append([line_number, column, text.length()])
			column = find_in_line(line, text, column + 1)

	if results.size() > 0:
		replace_button.disabled = false
		replace_all_button.disabled = false
	else:
		replace_button.disabled = true
		replace_all_button.disabled = true

	self.result_index = clamp(default_result_index, 0, results.size() - 1)


# Find text in a string and match case if requested
func find_in_line(line: String, text: String, from_index: int = 0) -> int:
	if match_case_button.button_pressed:
		return line.find(text, from_index)
	else:
		return line.findn(text, from_index)


### Signals


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		match event.as_text():
			"Ctrl+F", "Command+F":
				open_requested.emit()
			"Ctrl+Shift+R", "Command+Shift+R":
				replace_check_button.set_pressed(true)
				open_requested.emit()


func _on_text_edit_text_changed() -> void:
	results.clear()


func _on_search_and_replace_theme_changed() -> void:
	apply_theme()


func _on_input_text_changed(new_text: String) -> void:
	search(new_text)


func _on_previous_button_pressed() -> void:
	self.result_index = wrapi(result_index - 1, 0, results.size())


func _on_next_button_pressed() -> void:
	self.result_index = wrapi(result_index + 1, 0, results.size())


func _on_search_and_replace_visibility_changed() -> void:
	if is_instance_valid(input):
		if visible:
			input.grab_focus()
			var selection = code_edit.get_selected_text()
			if input.text == "" and selection != "":
				input.text = selection
				search(selection)
			else:
				search()
		else:
			input.text = ""


func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		match event.as_text():
			"Enter":
				search(input.text)
			"Escape":
				emit_signal("close_requested")


func _on_replace_button_pressed() -> void:
	if result_index == -1: return

	# Replace the selection at result index
	var r: Array = results[result_index]
	var lines: PackedStringArray = code_edit.text.split("\n")
	var line: String = lines[r[0]]
	line = line.substr(0, r[1]) + replace_input.text + line.substr(r[1] + r[2])
	lines[r[0]] = line
	code_edit.text = "\n".join(lines)
	search(input.text, result_index)
	code_edit.text_changed.emit()


func _on_replace_all_button_pressed() -> void:
	if match_case_button.button_pressed:
		code_edit.text = code_edit.text.replace(input.text, replace_input.text)
	else:
		code_edit.text = code_edit.text.replacen(input.text, replace_input.text)
	search()
	code_edit.text_changed.emit()


func _on_replace_check_button_toggled(button_pressed: bool) -> void:
	replace_panel.visible = button_pressed
	if button_pressed:
		replace_input.grab_focus()


func _on_input_focus_entered() -> void:
	if results.size() == 0:
		search()
	else:
		self.result_index = result_index


func _on_match_case_check_box_toggled(button_pressed: bool) -> void:
	search()
