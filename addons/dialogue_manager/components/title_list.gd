@tool
extends VBoxContainer

signal title_selected(title: String)


@onready var filter_edit: LineEdit = $FilterEdit
@onready var list: ItemList = $List

var titles: PackedStringArray:
	set(next_titles):
		titles = next_titles
		apply_filter()
	get:
		return titles

var filter: String:
	set(next_filter):
		filter = next_filter
		apply_filter()
	get:
		return filter


func _ready() -> void:
	apply_theme()


func select_title(title: String) -> void:
	list.deselect_all()
	for i in range(0, list.get_item_count()):
		if list.get_item_text(i) == title.strip_edges():
			list.select(i)


func apply_filter() -> void:
	list.clear()
	for title in titles:
		if filter == "" or filter.to_lower() in title.to_lower():
			list.add_item(title.strip_edges())


func apply_theme() -> void:
	if is_instance_valid(filter_edit):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")


### Signals


func _on_theme_changed() -> void:
	apply_theme()


func _on_filter_edit_text_changed(new_text: String) -> void:
	self.filter = new_text


func _on_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var title = list.get_item_text(index)
	emit_signal("title_selected", title)
