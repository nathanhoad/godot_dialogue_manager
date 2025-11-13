extends Control

@onready var tests_count_label: Label = $TestsCount
@onready var assertions_count_label: Label = $AssertionsCount
@onready var seconds_count_label: Label = $SecondsCount

var started_at: float = 0
var tests_count: int = 0
var assertions_count: int = 0


func _ready() -> void:
	TranslationServer.set_locale("en")

	visible = false

	tests_count = 0
	started_at = Time.get_ticks_msec()

	var test_files: PackedStringArray = Array(DirAccess.get_files_at("res://tests")) \
		.filter(func(path: String) -> bool: return path.begins_with("test_") and path.ends_with(".gd"))

	await _run_tests(test_files)

	var duration: float = (Time.get_ticks_msec() - started_at) / 1000
	print_rich("[color=#555]_______________________[/color]\n\n[b]%d tests[/b] with %d assertions in [color=yellow]%.2fs[/color]" % [tests_count, assertions_count, duration])

	tests_count_label.text = str(tests_count)
	assertions_count_label.text = str(assertions_count)
	seconds_count_label.text = "%.2f" % duration

	visible = true


# Run all the test methods on a node
func _run_tests(test_files: PackedStringArray) -> void:
	var is_limited_run: bool = false

	for path: String in test_files:
		var node: Node = load(get_script().resource_path.get_base_dir() + "/" + path).new()
		for method in node.get_method_list():
			if method.name.begins_with("only_"):
				is_limited_run = true

	for path: String in test_files:
		var did_run_a_test: bool = false
		var node: Node = load(get_script().resource_path.get_base_dir() + "/" + path).new()

		if (is_limited_run and "func only_" in node.get_script().source_code) or not is_limited_run:
			print_rich("[b]%s[/b]" % path.get_basename().replace("test_", "").replace("_", " ").to_upper())

		await node._before_all()

		for method in node.get_method_list():
			if (is_limited_run and method.name.begins_with("only_")) or (not is_limited_run and method.name.begins_with("test_")):
				await node._before_each()
				await node.call(method.name)
				print_rich("\t[color=lime]o[/color] " + method.name.replace("only_", "").replace("test_", "").replace("_", " "))
				tests_count += 1
				await node._after_each()
				did_run_a_test = true

		await node._after_all()

		if not is_limited_run:
			assertions_count += node.get_script().source_code.count("assert(")

		if did_run_a_test:
			print_rich("\n")
