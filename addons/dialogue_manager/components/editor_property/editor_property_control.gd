@tool

extends HBoxContainer


signal pressed()
signal resource_changed(next_resource: DialogueResource)


const ITEM_NEW: int = 100
const ITEM_QUICK_LOAD: int = 200
const ITEM_LOAD: int = 201
const ITEM_EDIT: int = 300
const ITEM_CLEAR: int = 301
const ITEM_FILESYSTEM: int = 400


@onready var button: Button = $ResourceButton
@onready var menu_button: Button = $MenuButton
@onready var menu: PopupMenu = $Menu
@onready var quick_open_dialog: ConfirmationDialog = $QuickOpenDialog
@onready var files_list = $QuickOpenDialog/FilesList
@onready var new_dialog: FileDialog = $NewDialog
@onready var open_dialog: FileDialog = $OpenDialog

var editor_plugin: EditorPlugin

var resource: Resource:
	set(next_resource):
		resource = next_resource
		if button:
			button.resource = resource
	get:
		return resource

var is_waiting_for_file: bool = false
var quick_selected_file: String = ""


func _ready() -> void:
	menu_button.icon = get_theme_icon("GuiDropdown", "EditorIcons")
	editor_plugin = Engine.get_meta("DialogueManagerPlugin")


func build_menu() -> void:
	menu.clear()

	menu.add_icon_item(editor_plugin._get_plugin_icon(), "New Dialogue", ITEM_NEW)
	menu.add_separator()
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), "Quick Load", ITEM_QUICK_LOAD)
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), "Load", ITEM_LOAD)
	if resource:
		menu.add_icon_item(get_theme_icon("Edit", "EditorIcons"), "Edit", ITEM_EDIT)
		menu.add_icon_item(get_theme_icon("Clear", "EditorIcons"), "Clear", ITEM_CLEAR)
		menu.add_separator()
		menu.add_item("Show in FileSystem", ITEM_FILESYSTEM)

	menu.size = Vector2.ZERO


#region Signals


func _on_new_dialog_file_selected(path: String) -> void:
	editor_plugin.main_view.new_file(path)
	is_waiting_for_file = false
	if Engine.get_meta("DMCache").has_file(path):
		resource_changed.emit(load(path))
	else:
		var next_resource: DialogueResource = await editor_plugin.import_plugin.compiled_resource
		next_resource.resource_path = path
		resource_changed.emit(next_resource)


func _on_open_dialog_file_selected(file: String) -> void:
	resource_changed.emit(load(file))


func _on_file_dialog_canceled() -> void:
	is_waiting_for_file = false


func _on_resource_button_pressed() -> void:
	if is_instance_valid(resource):
		EditorInterface.call_deferred("edit_resource", resource)

	elif menu.visible:
		menu.hide()
	else:
		build_menu()
		menu.position = get_viewport().position + Vector2i(
			button.global_position.x + button.size.x - menu.size.x,
			2 + menu_button.global_position.y + button.size.y
		)
		menu.popup()


func _on_resource_button_resource_dropped(next_resource: Resource) -> void:
	resource_changed.emit(next_resource)


func _on_menu_button_pressed() -> void:
	if menu.visible:
		menu.hide()
	else:
		build_menu()
		menu.position = get_viewport().position + Vector2i(
			menu_button.global_position.x + menu_button.size.x - menu.size.x,
			2 + menu_button.global_position.y + menu_button.size.y
		)
		menu.popup()


func _on_menu_id_pressed(id: int) -> void:
	match id:
		ITEM_NEW:
			is_waiting_for_file = true
			new_dialog.popup_centered()

		ITEM_QUICK_LOAD:
			quick_selected_file = ""
			files_list.files = Engine.get_meta("DMCache").get_files()
			if resource:
				files_list.select_file(resource.resource_path)
			quick_open_dialog.popup_centered()
			files_list.focus_filter()

		ITEM_LOAD:
			is_waiting_for_file = true
			open_dialog.popup_centered()

		ITEM_EDIT:
			EditorInterface.call_deferred("edit_resource", resource)

		ITEM_CLEAR:
			resource_changed.emit(null)

		ITEM_FILESYSTEM:
			EditorInterface.get_file_system_dock().navigate_to_path(resource.resource_path)


func _on_files_list_file_double_clicked(file_path: String) -> void:
	resource_changed.emit(load(file_path))
	quick_open_dialog.hide()


func _on_files_list_file_selected(file_path: String) -> void:
	quick_selected_file = file_path


func _on_quick_open_dialog_confirmed() -> void:
	if quick_selected_file != "":
		resource_changed.emit(load(quick_selected_file))


#endregion
