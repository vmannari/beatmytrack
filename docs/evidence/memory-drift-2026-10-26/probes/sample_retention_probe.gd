extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../build/memory-drift-2026-10-26/original-sample.json").simplify_path()))
	var held: Array=[]
	var before: int=0
	for index: int in range(199):
		var row: Dictionary=source.duplicate(true); row.cycle=index
		held.append(row)
		if index==15: before=OS.get_static_memory_usage()
	print("RETAINED_SAMPLE_DELTA_15_198 ",OS.get_static_memory_usage()-before)
	held.clear()
	before=OS.get_static_memory_usage()
	for index: int in range(183):
		var row: Dictionary=source.duplicate(true); row.cycle=index
		var encoded: String=JSON.stringify(row)
	print("TRANSIENT_SAMPLE_DELTA ",OS.get_static_memory_usage()-before)
	quit()
