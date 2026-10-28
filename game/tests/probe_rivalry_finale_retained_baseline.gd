extends "res://tests/test_ranking_newspaper.gd"
## Reload task-start UI only in this disposable process; never change runtime files.
func run() -> void:
	for filename: String in ["world_ranking_week_summary.gd","rivalry_victory_car.gd","weekly_rivalry_finale.gd","weekly_rivalry_page.gd"]:
		var script: GDScript = load("res://ui/"+filename)
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-finale-layout-2026-10-26/before/"+filename)
		check(script.reload() == OK,"isolated task-start reload: "+filename)
	await super.run()
