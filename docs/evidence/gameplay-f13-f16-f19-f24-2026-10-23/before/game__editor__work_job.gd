extends RefCounted
## CPU job lifetime belongs to the tree, independently of a closing editor panel.
static var pending: Array = []
static var tree: SceneTree
var thread: Thread
var result: Variant
var done: bool = false
var aborted: bool = false
var _guard := Mutex.new()
var _work: Callable

static func start(work: Callable, owner_tree: SceneTree) -> RefCounted:
	var job = load("res://editor/work_job.gd").new()
	job._work = work; job.thread = Thread.new()
	if job.thread.start(job.run,Thread.PRIORITY_LOW) != OK: job.thread = null; job.done = true; return job
	pending.append(job)
	if tree == null:
		tree = owner_tree; tree.process_frame.connect(reap); tree.root.tree_exiting.connect(finish)
	return job

func run() -> Variant: return _work.call(cancelled)
func cancel() -> void:
	_guard.lock(); aborted = true; _guard.unlock()
func cancelled() -> bool:
	_guard.lock(); var value: bool = aborted; _guard.unlock(); return value

static func reap() -> void:
	for index: int in range(pending.size()-1,-1,-1):
		var job = pending[index]
		if job.thread.is_alive(): continue
		job.result = job.thread.wait_to_finish(); job.thread = null; job._work = Callable(); job.done = true
		pending.remove_at(index)

static func finish() -> void:
	for job in pending: job.cancel()
	for job in pending: job.thread.wait_to_finish(); job.thread = null; job._work = Callable(); job.done = true
	pending.clear(); tree = null
