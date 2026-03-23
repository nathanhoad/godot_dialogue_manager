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

var link_action: String = "show"

@onready var button: OptionButton = %Button
@onready var link_button: Button = %LinkButton
@onready var confirm_cue_name_dialog: ConfirmationDialog = %ConfirmCueNameDialog
@onready var cue_name_label: Label = %CueNameLabel
@onready var cue_name_edit: LineEdit = %CueNameEdit


func _ready() -> void:
	confirm_cue_name_dialog.register_text_enter(cue_name_edit)

	_update()

	button.get_popup().index_pressed.connect(_on_index_pressed)
	button.get_popup().about_to_popup.connect(_on_menu_about_to_popup)

	DMPlugin.instance.import_plugin.compiled_resource.connect(_on_dialogue_compiled)


func _update() -> void:
	var has_valid_dialogue_resource: bool = is_instance_valid(actionable) and "dialogue_resource" in actionable and is_instance_valid(actionable.dialogue_resource)

	var cues: PackedStringArray = []
	if has_valid_dialogue_resource:
		var resource: DialogueResource = ResourceLoader.load(actionable.dialogue_resource.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		cues = Array(resource.get_cues()).filter(func(l: String) -> bool: return not l.contains("/"))

	link_button.disabled = not has_valid_dialogue_resource

	var popup: PopupMenu = button.get_popup()
	popup.clear()

	var cue_icon: Texture2D = DMThemeValues.get_icon_with_color(CUE_ICON, DMThemeValues.get_values_from_editor().cues_color)

	if cues.is_empty() or not has_valid_dialogue_resource:
		popup.add_item(DMConstants.translate("<empty>"))
		popup.set_item_disabled(0, true)
	else:
		for existing_cue: String in cues:
			popup.add_icon_item(cue_icon, existing_cue)
		if not cue.is_empty() and not cues.has(cue):
			popup.add_icon_item(CUE_ICON, cue)

	if cue.is_empty():
		button.text = DMConstants.translate("<empty>")
		button.icon = null
		link_button.icon = get_theme_icon("New", "EditorIcons")
		link_action = "create"
	elif cues.has(cue):
		button.select(-1)
		button.select(cues.find(cue))
		link_button.icon = get_theme_icon("ExternalLink", "EditorIcons")
		link_action = "show"
	else:
		button.select(cues.size())
		link_button.icon = get_theme_icon("New", "EditorIcons")
		link_action = "create"


func show_cue_in_editor(next_cue: String) -> void:
	var resource: DialogueResource = actionable.dialogue_resource
	if is_instance_valid(resource):
		DMPlugin.open_file_at_cue(resource, next_cue, true)


#region Signals


func _on_dialogue_compiled(_resource: DialogueResource) -> void:
	_update.call_deferred()


func _on_menu_about_to_popup() -> void:
	_update()


func _on_index_pressed(index: int) -> void:
	cue = button.get_popup().get_item_text(index)
	cue_changed.emit(cue)
	_update()


func _on_link_button_pressed() -> void:
	match link_action:
		"create":
			if cue.is_empty():
				cue_name_edit.text = actionable.name.to_snake_case()
			else:
				cue_name_edit.text = cue
			cue_name_label.text = DMConstants.translate("Cue:")
			confirm_cue_name_dialog.popup_centered()
			cue_name_edit.grab_focus.call_deferred()
			cue_name_edit.select_all.call_deferred()

		"show":
			show_cue_in_editor.call_deferred(cue)
			_update.call_deferred()


func _on_confirm_cue_name_dialog_confirmed() -> void:
	cue = cue_name_edit.text.to_snake_case()
	cue_changed.emit(cue)
	show_cue_in_editor.call_deferred(cue)
	_update.call_deferred()


#endregion
