extends RefCounted
static func start(track: NativeTrack, owner_tree: SceneTree) -> RefCounted:
	return preload("res://editor/work_job.gd").start(preload("res://editor/road_preparation.gd").run.bind(track),owner_tree)
