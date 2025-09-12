@tool
extends Control

signal result_selected(path: String, cursor: Vector2, length: int)


const DialogueConstants = preload("../constants.gd")


var main_view: Control

@onready var input: LineEdit = %Input
@onready var search_button: Button = %SearchButton
@onready var match_case_button: CheckBox = %MatchCaseButton
@onready var replace_toggle: CheckButton = %ReplaceToggle
@onready var replace_container: VBoxContainer = %ReplaceContainer
@onready var replace_input: LineEdit = %ReplaceInput
@onready var replace_selected_button: Button = %ReplaceSelectedButton
@onready var replace_all_button: Button = %ReplaceAllButton
@onready var results_container: VBoxContainer = %ResultsContainer
@onready var result_template: HBoxContainer = %ResultTemplate

var current_results: Dictionary = {}:
	set(value):
		current_results = value
		update_results_view()
		if current_results.size() == 0:
			replace_selected_button.disabled = true
			replace_all_button.disabled = true
		else:
			replace_selected_button.disabled = false
			replace_all_button.disabled = false
	get:
		return current_results

var selections: PackedStringArray = []


func _ready() -> void:
	remove_child(result_template)


func _exit_tree() -> void:
	result_template.queue_free()


func prepare() -> void:
	if not is_node_ready():
		await ready

	input.grab_focus()

	var template_label = result_template.get_node("Label")
	template_label.get_theme_stylebox(&"focus").bg_color = main_view.code_edit.theme_overrides.current_line_color
	template_label.add_theme_font_override(&"normal_font", main_view.code_edit.get_theme_font(&"font"))

	replace_toggle.set_pressed_no_signal(false)
	replace_container.hide()

	$VBoxContainer/HBoxContainer/FindContainer/Label.text = DialogueConstants.translate(&"search.find")
	input.placeholder_text = DialogueConstants.translate(&"search.placeholder")
	input.text = ""
	search_button.text = DialogueConstants.translate(&"search.find_all")
	match_case_button.text = DialogueConstants.translate(&"search.match_case")
	replace_toggle.text = DialogueConstants.translate(&"search.toggle_replace")
	$VBoxContainer/HBoxContainer/ReplaceContainer/ReplaceLabel.text = DialogueConstants.translate(&"search.replace_with")
	replace_input.placeholder_text = DialogueConstants.translate(&"search.replace_placeholder")
	replace_input.text = ""
	replace_all_button.text = DialogueConstants.translate(&"search.replace_all")
	replace_selected_button.text = DialogueConstants.translate(&"search.replace_selected")

	selections.clear()
	current_results = {}


#region helpers


func update_results_view() -> void:
	for child in results_container.get_children():
		child.queue_free()

	for path in current_results.keys():
		var path_label: Label = Label.new()
		path_label.text = path
		# Show open files
		if main_view.open_buffers.has(path):
			path_label.text += "(*)"
		results_container.add_child(path_label)
		for path_result in current_results.get(path):
			var result_item: HBoxContainer = result_template.duplicate()

			var checkbox: CheckBox = result_item.get_node("CheckBox") as CheckBox
			var key: String = get_selection_key(path, path_result)
			checkbox.toggled.connect(func(is_pressed):
				if is_pressed:
					if not selections.has(key):
						selections.append(key)
				else:
					if selections.has(key):
						selections.remove_at(selections.find(key))
			)
			checkbox.set_pressed_no_signal(selections.has(key))
			checkbox.visible = replace_toggle.button_pressed

			var result_label: RichTextLabel = result_item.get_node("Label") as RichTextLabel
			var colors: Dictionary = main_view.code_edit.theme_overrides
			var highlight: String = ""
			if replace_toggle.button_pressed:
				var matched_word: String = "[bgcolor=" + colors.critical_color.to_html() + "][color=" + colors.text_color.to_html() + "]" + path_result.matched_text + "[/color][/bgcolor]"
				highlight = "[s]" + matched_word + "[/s][bgcolor=" + colors.notice_color.to_html() + "][color=" + colors.text_color.to_html() + "]" + replace_input.text + "[/color][/bgcolor]"
			else:
				highlight = "[bgcolor=" + colors.notice_color.to_html() + "][color=" + colors.text_color.to_html() + "]" + path_result.matched_text + "[/color][/bgcolor]"
			var text: String = path_result.text.substr(0, path_result.index) + highlight + path_result.text.substr(path_result.index + path_result.query.length())
			result_label.text = "%s: %s" % [str(path_result.line + 1).lpad(4), text]
			result_label.gui_input.connect(func(event):
				if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).double_click:
					result_selected.emit(path, Vector2(path_result.index, path_result.line), path_result.query.length())
			)

			results_container.add_child(result_item)


func find_in_files() -> Dictionary:
	var results: Dictionary = {}

	var q: String = input.text
	var cache = Engine.get_meta("DMCache")
	var file: FileAccess
	for path in cache.get_files():
		var path_results: Array = []
		var lines: PackedStringArray = []

		if main_view.open_buffers.has(path):
			lines = main_view.open_buffers.get(path).text.split("\n")
		else:
			file = FileAccess.open(path, FileAccess.READ)
			lines = file.get_as_text().split("\n")

		for i in range(0, lines.size()):
			var index: int = find_in_line(lines[i], q)
			while index > -1:
				path_results.append({
					line = i,
					index = index,
					text = lines[i],
					matched_text = lines[i].substr(index, q.length()),
					query = q
				})
				index = find_in_line(lines[i], q, index + q.length())

		if file != null and file.is_open():
			file.close()

		if path_results.size() > 0:
			results[path] = path_results

	return results


func get_selection_key(path: String, path_result: Dictionary) -> String:
	return "%s-%d-%d" % [path, path_result.line, path_result.index]


func find_in_line(line: String, query: String, from_index: int = 0) -> int:
	if match_case_button.button_pressed:
		return line.find(query, from_index)
	else:
		return line.findn(query, from_index)


func replace_results(only_selected: bool) -> void:
	var file: FileAccess
	var lines: PackedStringArray = []
	for path in current_results:
		if main_view.open_buffers.has(path):
			lines = main_view.open_buffers.get(path).text.split("\n")
		else:
			file = FileAccess.open(path, FileAccess.READ)
			lines = file.get_as_text().split("\n")

		# Read the results in reverse because we're going to be modifying them as we go
		var path_results: Array = current_results.get(path).duplicate()
		path_results.reverse()
		for path_result in path_results:
			var key: String = get_selection_key(path, path_result)
			if not only_selected or (only_selected and selections.has(key)):
				lines[path_result.line] = lines[path_result.line].substr(0, path_result.index) + replace_input.text + lines[path_result.line].substr(path_result.index + path_result.matched_text.length())

		var replaced_text: String = "\n".join(lines)
		if file != null and file.is_open():
			file.close()
			file = FileAccess.open(path, FileAccess.WRITE)
			file.store_string(replaced_text)
			file.close()
		else:
			main_view.open_buffers.get(path).text = replaced_text
			if main_view.current_file_path == path:
				main_view.code_edit.text = replaced_text

	current_results = find_in_files()


#endregion

#region signals


func _on_search_button_pressed() -> void:
	selections.clear()
	self.current_results = find_in_files()


func _on_input_text_submitted(new_text: String) -> void:
	_on_search_button_pressed()


func _on_replace_toggle_toggled(toggled_on: bool) -> void:
	replace_container.visible = toggled_on
	if toggled_on:
		replace_input.grab_focus()
	update_results_view()


func _on_replace_input_text_changed(new_text: String) -> void:
	update_results_view()


func _on_replace_selected_button_pressed() -> void:
	replace_results(true)


func _on_replace_all_button_pressed() -> void:
	replace_results(false)


func _on_match_case_button_toggled(toggled_on: bool) -> void:
	_on_search_button_pressed()


#endregion
