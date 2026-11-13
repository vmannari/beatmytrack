extends "res://../docs/evidence/rivalry-summary-clarity-2026-11-09/before/test_rivalry_summary_popup.gd"
## Execute the untouched original suite against task-start UI in process memory.
func run() -> void:
	for source: String in ["rivalry_summary_banner.gd","rivalry_summary_dialog.gd"]:
		var original: GDScript = load("res://ui/"+source)
		original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-summary-clarity-2026-11-09/before/"+source)
		check(original.reload() == OK,"task-start UI loads only in this control process")
	await super.run()
