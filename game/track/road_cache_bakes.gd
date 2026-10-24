extends RefCounted
## One owned CPU cache writer and one coalesced pending save. Never reads a GPU mesh.
const ROADS = preload("res://editor/road_preparation.gd")
const DISK = preload("res://track/road_mesh_disk_cache.gd")
static var job: RefCounted
static var pending_track: NativeTrack
static var tree: SceneTree

static func start(track: NativeTrack, owner_tree: SceneTree) -> void:
	if track == null or DISK.directory.is_empty(): return
	if tree == null:
		# Register WorkJob's join before our final receipt cleanup.
		job = preload("res://editor/work_job.gd").start(run.bind(track),owner_tree)
		tree = owner_tree
		tree.process_frame.connect(poll)
		tree.root.tree_exiting.connect(finish)
	elif job == null:
		job = preload("res://editor/work_job.gd").start(run.bind(track),owner_tree)
	else: pending_track = track

static func run(cancelled: Callable, track: NativeTrack) -> Dictionary:
	var packet: Dictionary = ROADS.prepare(track,true,false,cancelled)
	var receipt: Dictionary = DISK.stage_arrays(ROADS.disk_key_for(track),packet,cancelled)
	if cancelled.call(): DISK.discard_arrays(receipt); return {}
	return receipt

static func poll() -> void:
	if job == null or not job.done: return
	if job.aborted: DISK.discard_arrays(job.result if job.result is Dictionary else {})
	else: DISK.publish_arrays(job.result if job.result is Dictionary else {})
	job.result = null; job = null
	if pending_track != null:
		var track: NativeTrack = pending_track
		pending_track = null
		start(track,tree)

static func finish() -> void:
	# WorkJob has joined all threads. Cache writes are optional at shutdown.
	if job != null and job.result is Dictionary: DISK.discard_arrays(job.result)
	job = null; pending_track = null; tree = null
