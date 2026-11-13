extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var panel: Control = load("res://ui/licences_panel.gd").new()
	root.add_child(panel); await process_frame
	var entries: Array = panel.get("entries")
	var found: bool = false
	for i: int in range(entries.size()):
		if entries[i].id == "challenger_hellcat":
			panel.call("_select",i); found = true
	assert(found)
	await process_frame
	var expected: String = FileAccess.get_file_as_string("res://legal/challenger_hellcat_notices.txt")
	assert((panel.get("document") as RichTextLabel).get_parsed_text() == expected)
	assert(expected.contains("Richerworld") and expected.contains("Surface refinement") and expected.contains("https://creativecommons.org/licenses/by/4.0/"))
	panel.free(); print("CHALLENGER_CREDIT: updated artist, licence and modifications render verbatim"); quit()
