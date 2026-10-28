extends "res://tests/test_weekly_rivalry.gd"
## Reproduce retained hub findings with task-start UI sources, only in memory.

func run() -> void:
	for path: String in ["res://core/app.gd","res://ui/weekly_rivalry_page.gd"]:
		var original: GDScript = load(path)
		original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-summary-popup-2026-10-26/before/"+path.get_file())
		check(original.reload() == OK,"task-start UI source reloads only in the isolated baseline process")
	await super.run()
