@tool
extends VBoxContainer

signal label_selected(label: String)


const REGION_ICON: Texture2D = preload("../assets/region.svg")
const LABEL_ICON: Texture2D = preload("../assets/label.svg")


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

@onready var filter_edit: LineEdit = %FilterEdit
@onready var menu_button: MenuButton = %MenuButton
@onready var list: ItemList = %List

var region_icon: Texture2D
var label_icon: Texture2D


func _ready() -> void:
	apply_theme()

	filter_edit.placeholder_text = DMConstants.translate(&"labels_list.filter")

	menu_button.get_popup().id_pressed.connect(_on_menu_button_id_pressed)


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
				if "regions" in DMSettings.get_user_value("label_list_view", "regions+labels"):
					list.add_item(label.strip_edges().substr(1), region_icon)
			elif "labels" in DMSettings.get_user_value("label_list_view", "regions+labels"):
				list.add_item(label.strip_edges(), label_icon)


func apply_theme() -> void:
	if is_instance_valid(filter_edit):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")
	if is_instance_valid(menu_button):
		menu_button.icon = get_theme_icon("GuiTabMenu", "EditorIcons")
	if is_instance_valid(list):
		list.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Panel"))

	var theme_values: DMThemeValues = DMThemeValues.get_values_from_editor()

	region_icon = DMThemeValues.get_icon_with_color(REGION_ICON, theme_values.comments_color)
	label_icon = DMThemeValues.get_icon_with_color(LABEL_ICON, theme_values.labels_color)


#region Signals


func _on_theme_changed() -> void:
	apply_theme()


func _on_filter_edit_text_changed(new_text: String) -> void:
	self.filter = new_text


func _on_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		var label: String = list.get_item_text(index)
		label_selected.emit(label)


func _on_menu_button_about_to_popup() -> void:
	var menu: PopupMenu = menu_button.get_popup()
	menu.clear()
	menu.add_radio_check_item(DMConstants.translate(&"Regions & Labels"), 0)
	menu.set_item_checked(0, DMSettings.get_user_value("label_list_view", "regions+labels") == "regions+labels")
	menu.add_radio_check_item(DMConstants.translate(&"Regions"), 1)
	menu.set_item_checked(1, DMSettings.get_user_value("label_list_view", "regions+labels") == "regions")
	menu.add_radio_check_item(DMConstants.translate(&"Labels"), 2)
	menu.set_item_checked(2, DMSettings.get_user_value("label_list_view", "regions+labels") == "labels")


func _on_menu_button_id_pressed(id: int) -> void:
	match id:
		0:
			DMSettings.set_user_value("label_list_view", "regions+labels")
		1:
			DMSettings.set_user_value("label_list_view", "regions")
		2:
			DMSettings.set_user_value("label_list_view", "labels")
	apply_filter()

#endregion
