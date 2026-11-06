extends Node
## Main-thread delivery of requested resources. Never get an unfinished load.
var requests: Dictionary = {}
var _tree_ref: WeakRef

func _ready() -> void:
	_tree_ref = weakref(get_tree())
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func request(path: String) -> Dictionary:
	if requests.has(path) and not requests[path].get("failed",false): return requests[path]
	var entry: Dictionary = {"done":false,"failed":false,"resource":null,"began":Time.get_ticks_usec()}
	requests[path] = entry
	var error: Error = ResourceLoader.load_threaded_request(path)
	if error != OK:
		entry.done = true
		entry.failed = true
	else: set_process(true)
	return entry

func _process(_delta: float) -> void:
	var pending: bool = false
	for path: String in requests:
		var entry: Dictionary = requests[path]
		if entry.done: continue
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pending = true
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			entry.resource = ResourceLoader.load_threaded_get(path)
		entry.failed = entry.resource == null
		entry.done = true
		entry.elapsed_ms = (Time.get_ticks_usec()-int(entry.began))/1000.0
	set_process(pending)

func _exit_tree() -> void:
	var pending: Array[String] = []
	for path: String in requests:
		if not requests[path].done: pending.append(path)
	requests.clear()
	_retire(pending,_tree_ref)

static func _retire(paths: Array[String],tree_ref: WeakRef) -> void:
	var pending: Array[String] = []
	for path: String in paths:
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: pending.append(path)
		elif status == ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(path)
	var tree: Object = tree_ref.get_ref() if tree_ref != null else null
	if not pending.is_empty() and is_instance_valid(tree):
		tree.process_frame.connect(_retire.bind(pending,tree_ref),CONNECT_ONE_SHOT)
