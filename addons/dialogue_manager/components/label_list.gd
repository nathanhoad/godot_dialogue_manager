@tool
extends VBoxContainer

signal label_selected(label: String)


const DialogueConstants = preload("../constants.gd")


@onready var filter_edit: LineEdit = $FilterEdit
@onready var list: ItemList = $List

var labels: PackedStringArray:
	set(next_labels):
		labels = next_labels
		apply_filter()
	get:
		return labels

var filter: String:
	set(next_filter):
		filter = next_filter
		apply_filter()
	get:
		return filter


func _ready() -> void:
	apply_theme()

	filter_edit.placeholder_text = DialogueConstants.translate(&"labels_list.filter")


func select_label(label: String) -> void:
	list.deselect_all()
	for i in range(0, list.get_item_count()):
		if list.get_item_text(i) == label.strip_edges():
			list.select(i)


func apply_filter() -> void:
	list.clear()
	for label in labels:
		if filter == "" or filter.to_lower() in label.to_lower():
			if label.begins_with("#"):
				list.add_item(label.strip_edges().substr(1), get_theme_icon("VisualShaderNodeComment", "EditorIcons"))
			else:
				list.add_item(label.strip_edges(), get_theme_icon("ArrowRight", "EditorIcons"))


func apply_theme() -> void:
	if is_instance_valid(filter_edit):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")
	if is_instance_valid(list):
		list.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Panel"))


### Signals


func _on_theme_changed() -> void:
	apply_theme()


func _on_filter_edit_text_changed(new_text: String) -> void:
	self.filter = new_text


func _on_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		var label: String = list.get_item_text(index)
		label_selected.emit(label)
