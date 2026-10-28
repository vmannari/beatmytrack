extends SceneTree
## Run unchanged economy assertions with only the task-start purchase builder restored in memory.
func _initialize() -> void:
	var source: String = FileAccess.get_file_as_string("res://tests/test_earned_coins.gd")
	var original: String = FileAccess.get_file_as_string("res://../docs/evidence/customisation-purchase-reference-2026-10-26/before/garage_page.gd")
	var start: int = original.find("func _require_owned(")
	var end: int = original.find("\nfunc ",start+1)
	if start<0 or end<0:
		push_error("Missing task-start purchase builder")
		quit(1)
		return
	var method: String = original.substr(start,end-start)
	source = source.replace("GaragePage.new()","TaskStartGarage.new()")
	source += "\nclass TaskStartGarage extends GaragePage:\n"
	for line: String in method.split("\n"): source += "\t"+line+"\n"
	var fixture := GDScript.new()
	fixture.source_code = source
	if fixture.reload() != OK:
		quit(1)
		return
	set_script(fixture)
	call_deferred("_run")
