class_name DMThemeValues extends RefCounted


var scale: float = 1
var background_color: Color = Color.WHITE
var current_line_color: Color = Color.WHITE
var error_line_color: Color = Color.WHITE

var critical_color: Color = Color.WHITE
var notice_color: Color = Color.WHITE

var labels_color: Color = Color.WHITE
var text_color: Color = Color.WHITE
var tags_color: Color = Color.WHITE
var conditions_color: Color = Color.WHITE
var mutations_color: Color = Color.WHITE
var mutations_line_color: Color = Color.WHITE
var members_color: Color = Color.WHITE
var strings_color: Color = Color.WHITE
var numbers_color: Color = Color.WHITE
var symbols_color: Color = Color.WHITE
var comments_color: Color = Color.WHITE
var jumps_color: Color = Color.WHITE

var font_size: float = 16


func _init(values: Dictionary) -> void:
	scale = values.scale

	background_color = values.background_color
	current_line_color = values.current_line_color
	error_line_color = values.error_line_color

	critical_color = values.critical_color
	notice_color = values.notice_color

	labels_color = values.labels_color
	text_color = values.text_color
	tags_color = values.tags_color
	conditions_color = values.conditions_color
	mutations_color = values.mutations_color
	mutations_line_color = values.mutations_line_color
	members_color = values.members_color
	strings_color = values.strings_color
	numbers_color = values.numbers_color
	symbols_color = values.symbols_color
	comments_color = values.comments_color
	jumps_color = values.jumps_color

	font_size = values.font_size


## Get size and colour values used for setting themes.
static func get_values_from_editor() -> DMThemeValues:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	return DMThemeValues.new({
		scale = EditorInterface.get_editor_scale(),

		background_color = Color(editor_settings.get_setting("interface/theme/base_color").blend(editor_settings.get_setting("text_editor/theme/highlighting/background_color")), 1),
		current_line_color = editor_settings.get_setting("text_editor/theme/highlighting/current_line_color"),
		error_line_color = editor_settings.get_setting("text_editor/theme/highlighting/mark_color"),

		critical_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/critical_color"),
		notice_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/notice_color"),

		labels_color = editor_settings.get_setting("text_editor/theme/highlighting/gdscript/node_reference_color"),
		text_color = editor_settings.get_setting("text_editor/theme/highlighting/text_color"),
		tags_color = editor_settings.get_setting("text_editor/theme/highlighting/string_placeholder_color"),
		conditions_color = editor_settings.get_setting("text_editor/theme/highlighting/keyword_color"),
		mutations_color = editor_settings.get_setting("text_editor/theme/highlighting/function_color"),
		mutations_line_color = Color(editor_settings.get_setting("text_editor/theme/highlighting/function_color"), 0.6),
		members_color = editor_settings.get_setting("text_editor/theme/highlighting/member_variable_color"),
		strings_color = editor_settings.get_setting("text_editor/theme/highlighting/string_color"),
		numbers_color = editor_settings.get_setting("text_editor/theme/highlighting/number_color"),
		symbols_color = editor_settings.get_setting("text_editor/theme/highlighting/symbol_color"),
		comments_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_color"),
		jumps_color = Color(editor_settings.get_setting("text_editor/theme/highlighting/gdscript/node_reference_color"), 0.6),

		font_size = editor_settings.get_setting("interface/editor/code_font_size")
	})


## Return a copy of a texture with a tint applied.
static func get_icon_with_color(icon: Texture2D, color: Color) -> ImageTexture:
	var image: Image = icon.get_image().duplicate()
	for x: int in image.get_width():
		for y: int in image.get_height():
			var pixel: Color = image.get_pixel(x, y)
			pixel *= color
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
