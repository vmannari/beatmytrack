extends RefCounted
static func start(track: NativeTrack, owner_tree: SceneTree, planning: bool = false, previous: NativeTrack = null) -> RefCounted:
	var prepared: Dictionary = preload("res://editor/road_preparation.gd").prepare_worker(track,planning)
	if planning: return preload("res://editor/work_job.gd").start(preload("res://editor/road_preparation.gd").run_editor.bind(track,previous),owner_tree)
	return preload("res://editor/work_job.gd").start(preload("res://editor/road_preparation.gd").run.bind(track,prepared),owner_tree)
