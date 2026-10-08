extends AbstractTest


func test_can_generate_static_ids() -> void:
	var text: String = ""

	for line: String in [
		"Dialogue without character.",
		"Nathan: Dialogue with a character.",
		"- [if condition/][#tag] First Response",
		"- [#tag] Second Response",
		"- Third Response [#tag]",
		"- Fourth Response [#tag] [if condition/]",
		"- Fifth Response [if condition/][#tag]"
	]:
		text = DMTranslationUtilities.generate_static_line_ids_for_text(line, ".")
		assert(text.contains("[ID:"), "Should include a static ID.")

	for ignored_line: String in [
		"~ cue",
		"$> mutation()"
	]:
		text = DMTranslationUtilities.generate_static_line_ids_for_text(ignored_line, ".")
		assert(not text.contains("[ID:"), "Should not include a static ID.")
