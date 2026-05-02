@tool

class_name DMDebuggerPlugin extends EditorDebuggerPlugin


const DebuggerView: PackedScene = preload("./views/debugger_view.tscn")


var debugger_view: DMDebuggerView
var debug_info: Dictionary = {}


func _setup_session(session_id: int) -> void:
	var session: EditorDebuggerSession = get_session(session_id)
	session.started.connect(_on_started)
	session.breaked.connect(_on_breaked)
	session.continued.connect(_on_continued)
	session.stopped.connect(_on_stopped)

	debugger_view = DebuggerView.instantiate()
	debugger_view.name = DMConstants.translate("Dialogue")
	debugger_view.session = session
	session.add_session_tab(debugger_view)


func _has_capture(capture: String) -> bool:
	return capture == "dm"


func _capture(message: String, data: Array, _session_id: int) -> bool:
	match message:
		"dm:debug":
			debug_info = data[0]
			return true

		"dm:state":
			debugger_view.contexts = data[0]
			debugger_view.autoloads = data[1]
			return true

		"dm:get_line":
			debugger_view.add_line(data[0])
			return true

	return false


#region Signals


func _on_started() -> void:
	debugger_view.start()
	debug_info = {}


func _on_breaked(_can_debug: bool) -> void:
	if debug_info.is_empty(): return

	DMPlugin.open_file_at_line(debug_info.resource_path, debug_info.line_number)

	await (Engine.get_main_loop() as SceneTree).create_timer(1).timeout

	EditorInterface.set_main_screen_editor("Dialogue")
	DMPlugin.instance.main_view.code_edit.runtime_error = DMError.new({
		line_number = debug_info.line_number + 1
	})

	debug_info = {}


func _on_continued() -> void:
	DMPlugin.instance.main_view.code_edit.runtime_error = null
	debug_info = {}


func _on_stopped() -> void:
	debugger_view.stop()
	DMPlugin.instance.main_view.code_edit.runtime_error = null
	debug_info = {}
