extends RefCounted
## Retire cancelled scans between files; page close never joins a live worker.
static var pending: Array = []
static var tree: SceneTree
var thread: Thread
var entries: Array[Dictionary] = []
var done: bool = false
var aborted: bool = false
var guard := Mutex.new()

static func start(directory: String, owner_tree: SceneTree, workflow_directory: String = "") -> RefCounted:
	var job = load("res://persistence/draft_scan.gd").new()
	job.thread = Thread.new()
	if job.thread.start(job.run.bind(directory,workflow_directory),Thread.PRIORITY_LOW) != OK: job.done = true; job.thread = null; return job
	pending.append(job)
	if tree == null:
		tree = owner_tree
		tree.process_frame.connect(reap)
		tree.root.tree_exiting.connect(finish)
	return job

func cancel() -> void:
	guard.lock(); aborted = true; guard.unlock()

func cancelled() -> bool:
	guard.lock(); var value: bool = aborted; guard.unlock()
	return value

func run(directory: String, workflow_directory: String) -> Array[Dictionary]:
	var storage := TrackLibrary.new(directory)
	var result: Array[Dictionary] = storage.editable_entries(true,cancelled)
	for item: Dictionary in result:
		if cancelled(): return []
		if not workflow_directory.is_empty():
			item["lifecycle"] = TrackLifecycle.presentation_for_fingerprint(item.document.fingerprint,workflow_directory)
			item.tested = item.lifecycle.ready
		else: item.tested = storage.is_tested_fingerprint(str(item.id),item.document.fingerprint)
	return result

static func reap() -> void:
	for index: int in range(pending.size()-1,-1,-1):
		var job = pending[index]
		if job.thread.is_alive(): continue
		job.entries = job.thread.wait_to_finish()
		job.thread = null; job.done = true
		pending.remove_at(index)

static func finish() -> void:
	for job in pending: job.cancel()
	for job in pending:
		job.thread.wait_to_finish(); job.thread = null; job.done = true
	pending.clear(); tree = null
