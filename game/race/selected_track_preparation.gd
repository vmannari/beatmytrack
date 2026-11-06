extends RefCounted
## One selected-track CPU job. Scope validation and publication stay on main.
const ROADS = preload("res://editor/road_preparation.gd")
const DISK = preload("res://track/road_mesh_disk_cache.gd")
static var discarded: Array = []
static var cleanup_tree: SceneTree

static func start(track: NativeTrack, entry: Dictionary, document: Dictionary, owner_tree: SceneTree) -> RefCounted:
	var job = preload("res://editor/work_job.gd").start(run.bind(track,entry,document),owner_tree)
	ensure_cleanup(owner_tree)
	return job

static func ensure_cleanup(owner_tree: SceneTree) -> void:
	if cleanup_tree == null:
		cleanup_tree = owner_tree
		owner_tree.process_frame.connect(reap_discarded)
		owner_tree.root.tree_exiting.connect(finish)

static func run(cancelled: Callable, selected: NativeTrack, entry: Dictionary, document: Dictionary) -> Dictionary:
	var track: NativeTrack = selected
	if track.metadata.get("metadata_only",false):
		track = preload("res://backend/cloud_tracks.gd").compile_document(entry,document,cancelled)
	if track == null or cancelled.call(): return {}
	var receipt: Dictionary = {}
	var disk_key: Array = ROADS.disk_key_for(track)
	var packet: Dictionary = ROADS.prepare(track,false,false,cancelled)
	packet = ROADS.with_winter_cover(packet,track,cancelled)
	if cancelled.call(): return {}
	# Prime existing query/gate data and the bounded numeric support cache in
	# this same worker. Do not construct another bridge/Desert field or repeat
	# the Winter cover bake, and retain no extra presenter/track owner.
	track._creator_query()
	if cancelled.call(): return {}
	preload("res://track/road_surface_height.gd").new(track)
	if cancelled.call(): return {}
	var session := TrackSession.new()
	session.prepare_cached(track,cancelled)
	if cancelled.call(): return {}
	receipt = DISK.stage_arrays(disk_key,packet,cancelled)
	if cancelled.call(): DISK.discard_arrays(receipt); return {}
	# Oversized packets are released here; only the existing road LRU can keep
	# CPU arrays. The bounded disk artifact supplies a later active race.
	return {"track":track,"receipt":receipt,"winter_cover":packet.get("winter_cover",{})}

static func request_cancelled(owner: WeakRef, generation: int) -> bool:
	var app: Node = owner.get_ref()
	return not is_instance_valid(app) or app.call("_selected_preparation_obsolete",generation)

static func download(owner: WeakRef, generation: int, cloud: Node, entry: Dictionary) -> void:
	var document: Dictionary = await cloud.download_document(entry,request_cancelled.bind(owner,generation))
	if request_cancelled(owner,generation): return
	var app: Node = owner.get_ref()
	app.call("_begin_selected_geometry",generation,entry,document)

static func cancel(job: RefCounted, owner_tree: SceneTree = null) -> void:
	if owner_tree != null: ensure_cleanup(owner_tree)
	if job == null: return
	job.cancel()
	if job.done:
		_discard(job)
	else:
		discarded.append(job)

static func _discard(job: RefCounted) -> void:
	if job.result is Dictionary: DISK.discard_arrays(job.result.get("receipt",{}))
	job.result = null

static func reap_discarded() -> void:
	for i: int in range(discarded.size()-1,-1,-1):
		if not discarded[i].done: continue
		_discard(discarded[i]); discarded.remove_at(i)

static func ready_for_job() -> bool:
	reap_discarded()
	return discarded.is_empty()

static func finish() -> void:
	# WorkJob's earlier tree-exit handler joins workers before this callback.
	reap_discarded()
	discarded.clear()
	cleanup_tree = null
