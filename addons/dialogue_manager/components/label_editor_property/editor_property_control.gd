@tool

extends HBoxContainer


signal label_changed(next_label: String)


const LABEL_ICON: Texture2D = preload("uid://d1aawtj2vsnxx")


var actionable: Node = null
var label: String = "":
	set(value):
		label = value
		if not is_node_ready():
			await ready
		_update()
	get:
		return label

@onready var button: OptionButton = %Button
@onready var link_button: Button = %LinkButton


func _ready() -> void:
	_update()

	link_button.icon = get_theme_icon("ExternalLink", "EditorIcons")
	button.get_popup().index_pressed.connect(_on_index_pressed)

	button.get_popup().about_to_popup.connect(_on_menu_about_to_popup)


func _update() -> void:
	if not is_instance_valid(actionable): return

	var labels: PackedStringArray = Array(actionable.dialogue_resource.get_labels()).filter(func(l: String) -> bool: return not l.contains("/"))

	var popup: PopupMenu = button.get_popup()
	popup.clear()

	var label_icon: Texture2D = DMThemeValues.get_icon_with_color(LABEL_ICON, DMThemeValues.get_values_from_editor().labels_color)

	if actionable.dialogue_resource == null:
		popup.add_item(DMConstants.translate("<empty>"))
		popup.set_item_disabled(0, true)
	else:
		for existing_label: String in labels:
			popup.add_icon_item(label_icon, existing_label)
		if not label.is_empty() and not labels.has(label):
			popup.add_icon_item(LABEL_ICON, label)

	if label.is_empty():
		button.text = DMConstants.translate("<empty>")
		button.icon = null
	elif labels.has(label):
		button.select(-1)
		button.select(labels.find(label))
	else:
		button.selected = labels.size()


func show_label_in_editor(next_label: String) -> void:
	var resource: DialogueResource = actionable.dialogue_resource
	if is_instance_valid(resource):
		DMPlugin.open_file_at_label(resource, next_label, true)


#region Signals


func _on_menu_about_to_popup() -> void:
	_update()


func _on_index_pressed(index: int) -> void:
	label = button.get_popup().get_item_text(index)
	label_changed.emit(label)
	_update()


func _on_link_button_pressed() -> void:
	if label.is_empty():
		label = actionable.name.to_snake_case()
		label_changed.emit(label)

	show_label_in_editor.call_deferred(label)
	_update.call_deferred()


#endregion
