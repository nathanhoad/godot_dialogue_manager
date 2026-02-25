@tool
extends VBoxContainer

signal label_selected(label: String)


const REGION_ICON: Texture2D = preload("../assets/region.svg")
const LABEL_ICON: Texture2D = preload("../assets/label.svg")

const VIEW_REGIONS_LABELS: String = "regions+labels"
const VIEW_REGIONS: String = "regions"
const VIEW_LABELS: String = "labels"
const VIEW_AUTO: String = "auto"


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
	for i: int in range(0, list.get_item_count()):
		if list.get_item_text(i) == label.strip_edges():
			list.select(i)


func apply_filter() -> void:
	list.clear()

	var view_setting: String = DMSettings.get_user_value("label_list_view", "regions+labels")
	# If auto then see if there are regions in the list to then default to regions but if there
	# are none default to labels instead
	if view_setting == VIEW_AUTO:
		view_setting = VIEW_LABELS
		for label: String in labels:
			if label.begins_with("#"):
				view_setting = VIEW_REGIONS
				break

	for label: String in labels:
		if filter == "" or filter.to_lower() in label.to_lower():
			if label.begins_with("#"):
				if VIEW_REGIONS in view_setting:
					list.add_item(label.strip_edges().substr(1), region_icon)
			elif VIEW_LABELS in view_setting:
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
	menu.set_item_checked(0, DMSettings.get_user_value("label_list_view", VIEW_REGIONS_LABELS) == VIEW_REGIONS_LABELS)
	menu.add_radio_check_item(DMConstants.translate(&"Regions"), 1)
	menu.set_item_checked(1, DMSettings.get_user_value("label_list_view", VIEW_REGIONS_LABELS) == VIEW_REGIONS)
	menu.add_radio_check_item(DMConstants.translate(&"Labels"), 2)
	menu.set_item_checked(2, DMSettings.get_user_value("label_list_view", VIEW_REGIONS_LABELS) == VIEW_LABELS)
	menu.add_radio_check_item(DMConstants.translate(&"Auto"), 3)
	menu.set_item_checked(3, DMSettings.get_user_value("label_list_view", VIEW_REGIONS_LABELS) == VIEW_AUTO)


func _on_menu_button_id_pressed(id: int) -> void:
	match id:
		0:
			DMSettings.set_user_value("label_list_view", VIEW_REGIONS_LABELS)
		1:
			DMSettings.set_user_value("label_list_view", VIEW_REGIONS)
		2:
			DMSettings.set_user_value("label_list_view", VIEW_LABELS)
		3:
			DMSettings.set_user_value("label_list_view", VIEW_AUTO)
	apply_filter()

#endregion
