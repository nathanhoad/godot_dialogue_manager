@tool
extends VBoxContainer

signal cue_selected(cue: String)


const REGION_ICON: Texture2D = preload("../assets/region.svg")
const CUE_ICON: Texture2D = preload("../assets/cue.svg")

const VIEW_REGIONS_CUES: String = "regions+cues"
const VIEW_REGIONS: String = "regions"
const VIEW_CUES: String = "cues"
const VIEW_AUTO: String = "auto"


var cues: PackedStringArray:
	set(value):
		cues = value
		apply_filter()
	get:
		return cues

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
var cue_icon: Texture2D


func _ready() -> void:
	apply_theme()

	filter_edit.placeholder_text = DMConstants.translate(&"cues_list.filter")

	menu_button.get_popup().id_pressed.connect(_on_menu_button_id_pressed)


func select_cue(cue: String) -> void:
	list.deselect_all()
	for i: int in range(0, list.get_item_count()):
		if list.get_item_text(i) == cue.strip_edges():
			list.select(i)


func apply_filter() -> void:
	list.clear()

	var view_setting: String = DMSettings.get_user_value("cue_list_view", "regions+cues")
	# If auto then see if there are regions in the list to then default to regions but if there
	# are none default to cues instead
	if view_setting == VIEW_AUTO:
		view_setting = VIEW_CUES
		for cue: String in cues:
			if cue.begins_with("#"):
				view_setting = VIEW_REGIONS
				break

	for cue: String in cues:
		if filter == "" or filter.to_lower() in cue.to_lower():
			if cue.begins_with("#"):
				if VIEW_REGIONS in view_setting:
					list.add_item(cue.strip_edges().substr(1), region_icon)
			elif VIEW_CUES in view_setting:
				list.add_item(cue.strip_edges(), cue_icon)


func apply_theme() -> void:
	if is_instance_valid(filter_edit):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")
	if is_instance_valid(menu_button):
		menu_button.icon = get_theme_icon("GuiTabMenu", "EditorIcons")
	if is_instance_valid(list):
		list.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Panel"))

	var theme_values: DMThemeValues = DMThemeValues.get_values_from_editor()

	region_icon = DMThemeValues.get_icon_with_color(REGION_ICON, theme_values.comments_color)
	cue_icon = DMThemeValues.get_icon_with_color(CUE_ICON, theme_values.cues_color)


#region Signals


func _on_theme_changed() -> void:
	apply_theme()


func _on_filter_edit_text_changed(new_text: String) -> void:
	self.filter = new_text


func _on_list_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		var cue: String = list.get_item_text(index)
		cue_selected.emit(cue)


func _on_menu_button_about_to_popup() -> void:
	var menu: PopupMenu = menu_button.get_popup()
	menu.clear()
	menu.add_radio_check_item(DMConstants.translate(&"Regions & Cues"), 0)
	menu.set_item_checked(0, DMSettings.get_user_value("cue_list_view", VIEW_REGIONS_CUES) == VIEW_REGIONS_CUES)
	menu.add_radio_check_item(DMConstants.translate(&"Regions"), 1)
	menu.set_item_checked(1, DMSettings.get_user_value("cue_list_view", VIEW_REGIONS_CUES) == VIEW_REGIONS)
	menu.add_radio_check_item(DMConstants.translate(&"Cues"), 2)
	menu.set_item_checked(2, DMSettings.get_user_value("cue_list_view", VIEW_REGIONS_CUES) == VIEW_CUES)
	menu.add_radio_check_item(DMConstants.translate(&"Auto"), 3)
	menu.set_item_checked(3, DMSettings.get_user_value("cue_list_view", VIEW_REGIONS_CUES) == VIEW_AUTO)


func _on_menu_button_id_pressed(id: int) -> void:
	match id:
		0:
			DMSettings.set_user_value("cue_list_view", VIEW_REGIONS_CUES)
		1:
			DMSettings.set_user_value("cue_list_view", VIEW_REGIONS)
		2:
			DMSettings.set_user_value("cue_list_view", VIEW_CUES)
		3:
			DMSettings.set_user_value("cue_list_view", VIEW_AUTO)
	apply_filter()

#endregion
