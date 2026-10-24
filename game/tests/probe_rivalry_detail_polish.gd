extends "res://tests/test_rivalry_track_detail.gd"
## Diagnostic: task-start sources reload only in this isolated process's memory.
func _initialize() -> void:
	if "--baseline" in OS.get_cmdline_user_args():
		for filename: String in ["menu_style.gd","race_mode_rail.gd","weekly_rivalry_page.gd"]:
			var original: String = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-view-polish-2026-10-24/before/"+filename)
			var script: GDScript = load("res://ui/"+filename)
			script.source_code = original
			if script.reload() != OK:
				print("BASELINE_RELOAD_FAILED: ",filename)
				quit(2)
				return
		print("TASK_START_UI_RELOADED_IN_MEMORY")
	super._initialize()

func check(value: bool, description: String) -> void:
	if description == "fourteen entrants expose the remaining six":
		var list: VBoxContainer = table()
		print("DETAIL_LAYOUT_PROBE: ",root.size," text=",list.more.text," viewport=",list.scroll.get_global_rect()," first=",list.rows.get_child(0).get_global_rect()," eighth=",list.rows.get_child(7).get_global_rect()," ninth=",list.rows.get_child(8).get_global_rect())
	super.check(value,description)
