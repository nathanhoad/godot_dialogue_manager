tool
extends VBoxContainer


signal title_clicked(title)
signal title_dbl_clicked(title)


onready var filter_input: LineEdit = $Filter
onready var list: ItemList = $List


export var include_end_conversation: bool = false


var titles: Array setget set_titles
var filter: String = "" setget set_filter


func _ready() -> void:
	filter_input.right_icon = get_icon("Search", "EditorIcons")


func focus_filter() -> void:
	filter_input.grab_focus()


func get_selected_index() -> int:
	if list.is_anything_selected():
		return list.get_selected_items()[0]
	else:
		return -1


func get_item_text(index: int) -> String:
	return list.get_item_text(index)


func set_titles(next_titles: Array) -> void:
	titles = next_titles
	
	list.clear()
	if include_end_conversation:
		list.add_item("END CONVERSATION")
		
	for title in titles:
		if filter == "" or filter.to_lower() in title.to_lower():
			list.add_item(title.strip_edges())


func select_title(title: String) -> void:
	for i in range(0, list.get_item_count()):
		if list.get_item_text(i) == title.strip_edges():
			list.select(i)


func set_filter(next_filter: String) -> void:
	filter = next_filter
	self.titles = titles


### Signals


func _on_Filter_text_changed(new_text):
	self.filter = new_text


func _on_List_item_selected(index):
	var title = list.get_item_text(index)
	if title == "END CONVERSATION":
		title = "END"
	emit_signal("title_clicked", title)


func _on_List_item_activated(index):
	var title = list.get_item_text(index)
	if title == "END CONVERSATION":
		title = "END"
	emit_signal("title_dbl_clicked", title)
