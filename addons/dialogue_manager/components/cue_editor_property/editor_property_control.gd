@tool

extends HBoxContainer


signal cue_changed(next_cue: String)


const CUE_ICON: Texture2D = preload("uid://d1aawtj2vsnxx")


var actionable: Node = null
var cue: String = "":
	set(value):
		cue = value
		if not is_node_ready():
			await ready
		_update()
	get:
		return cue

@onready var button: OptionButton = %Button
@onready var link_button: Button = %LinkButton


func _ready() -> void:
	_update()

	link_button.icon = get_theme_icon("ExternalLink", "EditorIcons")
	button.get_popup().index_pressed.connect(_on_index_pressed)

	button.get_popup().about_to_popup.connect(_on_menu_about_to_popup)


func _update() -> void:
	var has_valid_dialogue_resource: bool = is_instance_valid(actionable) and "dialogue_resource" in actionable and is_instance_valid(actionable.dialogue_resource)

	var cues: PackedStringArray = []
	if has_valid_dialogue_resource:
		cues = Array(actionable.dialogue_resource.get_cues()).filter(func(l: String) -> bool: return not l.contains("/"))

	var popup: PopupMenu = button.get_popup()
	popup.clear()

	var cue_icon: Texture2D = DMThemeValues.get_icon_with_color(CUE_ICON, DMThemeValues.get_values_from_editor().cues_color)

	if cues.is_empty() or not has_valid_dialogue_resource:
		popup.add_item(DMConstants.translate("<empty>"))
		popup.set_item_disabled(0, true)
		link_button.disabled = true
	else:
		for existing_cue: String in cues:
			popup.add_icon_item(cue_icon, existing_cue)
		if not cue.is_empty() and not cues.has(cue):
			popup.add_icon_item(CUE_ICON, cue)

	if cue.is_empty():
		button.text = DMConstants.translate("<empty>")
		button.icon = null
		link_button.disabled = true
	elif cues.has(cue):
		button.select(-1)
		button.select(cues.find(cue))
		link_button.disabled = false
	else:
		button.selected = cues.size()
		link_button.disabled = true


func show_cue_in_editor(next_cue: String) -> void:
	var resource: DialogueResource = actionable.dialogue_resource
	if is_instance_valid(resource):
		DMPlugin.open_file_at_cue(resource, next_cue, true)


#region Signals


func _on_menu_about_to_popup() -> void:
	_update()


func _on_index_pressed(index: int) -> void:
	cue = button.get_popup().get_item_text(index)
	cue_changed.emit(cue)
	_update()


func _on_link_button_pressed() -> void:
	if cue.is_empty():
		cue = actionable.name.to_snake_case()
		cue_changed.emit(cue)

	show_cue_in_editor.call_deferred(cue)
	_update.call_deferred()


#endregion
