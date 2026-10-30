extends "res://tests/test_weekly_rivalry.gd"
## Diagnostic replay of the unchanged task-start page in this process only.
func run() -> void:
	var page: GDScript = load("res://ui/weekly_rivalry_page.gd")
	page.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-track-profiles-2026-10-25/before/weekly_rivalry_page.gd")
	check(page.reload(true) == OK,"task-start page reloads for baseline comparison")
	await super.run()
