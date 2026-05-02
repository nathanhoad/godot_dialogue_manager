
@tool

class_name DMDebuggerView extends PanelContainer


const CONTEXT_ICON: Texture2D = preload("../nodes/context/dialogue_state_context.svg")


var session: EditorDebuggerSession

var contexts: Dictionary = {}:
	set(value):
		contexts = value
		_update_state_tree()
	get:
		return contexts

var autoloads: Dictionary = {}:
	set(value):
		autoloads = value
		_update_state_tree()
	get:
		return autoloads

@onready var runtime_warning: Label = %RuntimeWarning
@onready var content: HSplitContainer = %Content
@onready var state_tree: Tree = %StateTree
@onready var history_label: Label = %HistoryLabel
@onready var log_output: RichTextLabel = %LogOutput
@onready var clear_button: Button = %ClearButton


func _ready() -> void:
	content.hide()
	state_tree.clear()
	runtime_warning.text = DMConstants.translate("{game_name} isn't running.").format({ game_name = ProjectSettings.get_setting("application/config/name")})
	runtime_warning.add_theme_color_override("font_color", get_theme_color("warning_color", "Editor"))

	history_label.text = DMConstants.translate("History")

	clear_button.icon = get_theme_icon("Clear", "EditorIcons")
	clear_button.tooltip_text = DMConstants.translate("Clear")


func start() -> void:
	log_output.clear()
	runtime_warning.hide()
	content.show()


func stop() -> void:
	runtime_warning.show()
	content.hide()
	state_tree.clear()


func add_line(id: String) -> void:
	var resource_and_id: Dictionary = _get_resource_and_id(id)
	var line: Dictionary = resource_and_id.resource.lines.get(resource_and_id.id)

	var prefix: String = "[color={color}]{time} [url={url}]{file}[/url][/color] ".format({
		color = DMThemeValues.get_values_from_editor().comments_color.to_html(),
		time = Time.get_time_string_from_system(),
		url = id,
		file = resource_and_id.resource.resource_path.get_basename().get_file()
	})

	match line.type:
		DMConstants.TYPE_DIALOGUE:
			if line.has("character"):
				log_output.append_text("{prefix}[b]{character}:[/b] {text}\n".format({
					prefix = prefix,
					character = line.character,
					text = line.text
				}))
			else:
				log_output.append_text("{prefix}{text}".format({
					prefix = prefix,
					text = line.text
				}))

		DMConstants.TYPE_MUTATION:
			var dialogue: String = FileAccess.get_file_as_string(resource_and_id.resource.resource_path)
			log_output.append_text("{prefix}[color={color}]{mutation}[/color]\n".format({
				prefix = prefix,
				color = Color(DMThemeValues.get_values_from_editor().mutations_color, 0.5).to_html(),
				mutation = dialogue.split("\n")[line.id.to_int()]
			}))


func _update_state_tree() -> void:
	state_tree.clear()

	var root: TreeItem = state_tree.create_item()

	state_tree.columns = 2

	var item: TreeItem = state_tree.create_item(root)
	item.set_selectable(0, false)
	item.set_icon(0, CONTEXT_ICON)
	item.set_text(0, DMConstants.translate("Context Nodes"))
	create_state_items(item, contexts)

	item = state_tree.create_item(root)
	item.set_selectable(0, false)
	item.set_icon(0, get_theme_icon("Object", "EditorIcons"))
	item.set_text(0, DMConstants.translate("Globals"))
	create_state_items(item, autoloads)


func create_state_items(parent_item: TreeItem, state_data_list: Dictionary) -> void:
	if state_data_list.is_empty():
		var item: TreeItem = state_tree.create_item(parent_item)
		item.set_text(0, DMConstants.translate("None"))
		item.set_custom_color(0, Color(get_theme_color("font_color", "Editor"), 0.5))
	else:
		for data: Dictionary in state_data_list.values():
			var item: TreeItem = state_tree.create_item(parent_item)
			item.set_meta("state", data)
			if has_theme_icon(data.base_type, "EditorIcons"):
				item.set_icon(0, get_theme_icon(data.base_type, "EditorIcons"))
			item.set_text(0, data.alias)
			item.set_text(1, data.path)
			item.add_button(1, get_theme_icon("Script", "EditorIcons"), 0)


func _open_script(path: String) -> void:
	EditorInterface.edit_script(load(path))
	EditorInterface.set_main_screen_editor("Script")


func _get_resource_and_id(id: String) -> Dictionary:
	var uid_and_id: PackedStringArray = id.split("@")
	var resource: DialogueResource = load("uid://%s" % [uid_and_id[0]])
	return {
		resource = resource,
		id = uid_and_id[1]
	}


#region Signals


func _on_state_tree_item_selected() -> void:
	var selected_item: TreeItem = state_tree.get_selected()

	if not selected_item.has_meta("state"): return

	var context: Dictionary = selected_item.get_meta("state")
	session.send_message("dm:select_node", [context.instance_id])


func _on_state_tree_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT: return

	match id:
		0:
			_open_script(item.get_meta("state").script)


func _on_clear_button_pressed() -> void:
	log_output.clear()


func _on_log_meta_clicked(meta: Variant) -> void:
	var resource_and_id: Dictionary = _get_resource_and_id(meta)
	DMPlugin.open_file_at_line(resource_and_id.resource.resource_path, resource_and_id.id.to_int())
	EditorInterface.set_main_screen_editor("Dialogue")


#endregion
