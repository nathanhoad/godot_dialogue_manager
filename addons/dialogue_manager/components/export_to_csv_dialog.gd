@tool

extends ConfirmationDialog


var delimiter: String = ","

@onready var file_dialog: FileDialog = %FileDialog
@onready var path_edit: LineEdit = %PathEdit
@onready var path_button: Button = %PathButton
@onready var locale_edit: LineEdit = %LocaleEdit
@onready var delimiter_menu: OptionButton = %DelimiterMenu
@onready var include_character_names_button: CheckBox = %IncludeCharacterNamesButton
@onready var include_notes_button: CheckBox = %IncludeNotesButton
@onready var path_label: Label = %PathLabel
@onready var locale_label: Label = %LocaleLabel
@onready var delimiter_label: Label = %DelimiterLabel


func _ready() -> void:
	path_button.icon = get_theme_icon("Folder", "EditorIcons")
	path_button.text = ""

	delimiter_menu.get_popup().about_to_popup.connect(_on_delimiter_menu_about_to_popup)
	delimiter_menu.get_popup().index_pressed.connect(_on_delimiter_menu_index_pressed)
	delimiter_menu.text = DMConstants.translate("Comma")

	locale_edit.text = TranslationServer.get_tool_locale()

	title = DMConstants.translate("Simple CSV export...")
	get_ok_button().text = DMConstants.translate("Export simple CSV")
	get_ok_button().disabled = true

	path_label.text = DMConstants.translate("CSV path")
	locale_label.text = DMConstants.translate("Default locale")
	delimiter_label.text = DMConstants.translate("Default delimiter")
	include_character_names_button.text = DMConstants.translate("Include character name column")
	include_notes_button.text = DMConstants.translate("Include notes column")

	path_edit.grab_focus()


#region Signals


func _on_path_button_pressed() -> void:
	file_dialog.popup_centered()


func _on_file_dialog_file_selected(path: String) -> void:
	path_edit.text = path


func _on_file_dialog_confirmed() -> void:
	path_edit.text = file_dialog.current_path


func _on_confirmed() -> void:
	DMTranslationUtilities.export_all_translations_to_csv(
		path_edit.text,
		locale_edit.text,
		delimiter,
		include_character_names_button.button_pressed,
		include_notes_button.button_pressed
	)
	hide()


func _on_delimiter_menu_about_to_popup() -> void:
	var menu: PopupMenu = delimiter_menu.get_popup()
	menu.clear()

	menu.add_item(DMConstants.translate("Comma"))
	menu.add_item(DMConstants.translate("Tab"))
	menu.add_item(DMConstants.translate("Semicolon"))


func _on_delimiter_menu_index_pressed(index: int) -> void:
	var menu: PopupMenu = delimiter_menu.get_popup()
	delimiter_menu.text = menu.get_item_text(index)

	match index:
		0: # comma
			delimiter = ","
		1: # tab
			delimiter = "\t"
		2: # semicolon
			delimiter = ";"


func _on_locale_edit_focus_exited() -> void:
	if locale_edit.text.is_empty():
		locale_edit.text = TranslationServer.get_tool_locale()


func _on_path_edit_text_changed(new_text: String) -> void:
	get_ok_button().disabled = new_text.is_empty()


#endregion
