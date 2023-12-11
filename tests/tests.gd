extends Control

@onready var tests_count_label: Label = $TestsCount
@onready var assertions_count_label: Label = $AssertionsCount
@onready var seconds_count_label: Label = $SecondsCount

var started_at: float = 0
var tests_count: int = 0
var assertions_count: int = 0


func _ready() -> void:
	tests_count = 0
	started_at = Time.get_ticks_msec()

	var tests: PackedStringArray = Array(DirAccess.get_files_at("res://tests")) \
		.filter(func(path): return path.begins_with("test_"))
	for test in tests:
		await _run_tests(test)

	var duration: float = (Time.get_ticks_msec() - started_at) / 1000
	print_rich("[color=#555]_______________________[/color]\n\n[b]%d tests[/b] with %d assertions in [color=yellow]%.2fs[/color]" % [tests_count, assertions_count, duration])

	tests_count_label.text = str(tests_count)
	assertions_count_label.text = str(assertions_count)
	seconds_count_label.text = "%.2f" % duration


# Run all the test methods on a node
func _run_tests(path: String) -> void:
	print_rich("[b]%s[/b]" % path.get_basename().replace("test_", "").replace("_", " ").to_upper())
	var node: Node = load(get_script().resource_path.get_base_dir() + "/" + path).new()

	node.before_all()

	for method in node.get_method_list():
		if method.name.begins_with("test_"):
			node.before_each()
			await node.call(method.name)
			print_rich("\t[color=lime]o[/color] " + method.name.replace("test_", "").replace("_", " "))
			tests_count += 1
			node.after_each()

	node.after_all()

	assertions_count += node.get_script().source_code.count("assert(")

	print_rich("\n")
