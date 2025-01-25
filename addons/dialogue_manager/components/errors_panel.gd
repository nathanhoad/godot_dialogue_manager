@tool
extends HBoxContainer


signal error_pressed(line_number)


const DialogueConstants = preload("../constants.gd")


@onready var error_button: Button = $ErrorButton
@onready var next_button: Button = $NextButton
@onready var count_label: Label = $CountLabel
@onready var previous_button: Button = $PreviousButton

## The index of the current error being shown
var error_index: int = 0:
	set(next_error_index):
		error_index = wrap(next_error_index, 0, errors.size())
		show_error()
	get:
		return error_index

## The list of all errors
var errors: Array = []:
	set(next_errors):
		errors = next_errors
		self.error_index = 0
	get:
		return errors


func _ready() -> void:
	apply_theme()
	hide()


## Set up colors and icons
func apply_theme() -> void:
	error_button.add_theme_color_override("font_color", get_theme_color("error_color", "Editor"))
	error_button.add_theme_color_override("font_hover_color", get_theme_color("error_color", "Editor"))
	error_button.icon = get_theme_icon("StatusError", "EditorIcons")
	previous_button.icon = get_theme_icon("ArrowLeft", "EditorIcons")
	next_button.icon = get_theme_icon("ArrowRight", "EditorIcons")


## Move the error index to match a given line
func show_error_for_line_number(line_number: int) -> void:
	for i in range(0, errors.size()):
		if errors[i].line_number == line_number:
			self.error_index = i


## Show the current error
func show_error() -> void:
	if errors.size() == 0:
		hide()
	else:
		show()
		count_label.text = DialogueConstants.translate(&"n_of_n").format({ index = error_index + 1, total = errors.size() })
		var error = errors[error_index]
		error_button.text = DialogueConstants.translate(&"errors.line_and_message").format({ line = error.line_number, column = error.column_number, message = DialogueConstants.get_error_message(error.error) })
		if error.has("external_error"):
			error_button.text += " " + DialogueConstants.get_error_message(error.external_error)


### Signals


func _on_errors_panel_theme_changed() -> void:
	apply_theme()


func _on_error_button_pressed() -> void:
	error_pressed.emit(errors[error_index].line_number, errors[error_index].column_number)


func _on_previous_button_pressed() -> void:
	self.error_index -= 1
	_on_error_button_pressed()


func _on_next_button_pressed() -> void:
	self.error_index += 1
	_on_error_button_pressed()
