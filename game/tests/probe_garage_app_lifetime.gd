extends "res://tests/test_app.gd"
func _initialize() -> void:
	if "--no-staging" in OS.get_cmdline_user_args():
		var script: Script=load("res://ui/garage_opening_showroom.gd")
		var source: String=script.source_code
		var begin: int=source.find("\t# One MSAA level")
		var end: int=source.find("\nfunc _current_preparation()",begin)
		script.source_code=source.substr(0,begin)+"\tpreparing=false\n\tinteraction_ready=true\n\tset_process(true)\n\tstudio_prepared.emit()\n"+source.substr(end)
		assert(script.reload(true)==OK)
	if "--no-studio-resource-threads" in OS.get_cmdline_user_args():
		var script: Script=load("res://ui/garage_opening_showroom.gd")
		script.source_code=script.source_code.replace("[\"res://assets/garage/cars_v1/\"+vehicle_id+\".scn\",GarageEnvironment.PREPARED_ARCHITECTURE]", "[]")
		assert(script.reload(true)==OK)
	if "--no-picture-prefetch" in OS.get_cmdline_user_args():
		var script: Script=load("res://core/app.gd")
		script.source_code=script.source_code.replace("\tpreload(\"res://ui/garage_preview_cache.gd\").prefetch_catalogue(get_tree())\n", "")
		assert(script.reload(true)==OK)
	if "--legacy-entry" in OS.get_cmdline_user_args():
		var script: Script=load("res://core/app.gd")
		var source: String=script.source_code
		source=source.replace("\tpage.progressive_entry = true\n", "")
		source=source.replace("\tpreload(\"res://ui/garage_preview_cache.gd\").prefetch_catalogue(get_tree())\n", "")
		script.source_code=source
		assert(script.reload(true)==OK)
	super._initialize()
func _finish() -> void:
	for _frame: int in range(12): await process_frame
	print("GARAGE_LIFETIME_ORPHANS")
	Node.print_orphan_nodes()
	super._finish()
