extends RefCounted
const PREPARATION = preload("res://editor/road_preparation.gd")
static var pending: Array = []
static var tree: SceneTree
var thread: Thread
var packet: Dictionary = {}
var done: bool = false

static func start(track: NativeTrack, owner_tree: SceneTree) -> RefCounted:
	var job = load("res://editor/road_preparation_job.gd").new()
	job.thread = Thread.new()
	if job.thread.start(PREPARATION.prepare.bind(track,true),Thread.PRIORITY_LOW) != OK: job.done = true; job.thread = null; return job
	pending.append(job)
	if tree == null:
		tree = owner_tree; tree.process_frame.connect(reap); tree.root.tree_exiting.connect(finish)
	return job

static func reap() -> void:
	for index: int in range(pending.size()-1,-1,-1):
		var job = pending[index]
		if job.thread.is_alive(): continue
		job.packet = job.thread.wait_to_finish(); job.thread = null; job.done = true
		pending.remove_at(index)

static func finish() -> void:
	for job in pending: job.thread.wait_to_finish(); job.thread = null; job.done = true
	pending.clear(); tree = null
