extends Node
## Recoverable presentation snapshots: one ordered writer, latest value per path.
const IO = preload("res://backend/atomic_json.gd")
const MAX_PENDING_PATHS: int = 16
static var instance: Node
var pending: Dictionary = {}
var active: RefCounted
var active_value: Dictionary = {}
var completed_writes: int = 0

static func shared() -> Node:
	if not is_instance_valid(instance):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null: return null
		instance = load("res://backend/menu_snapshot_writer.gd").new()
		instance.name = "MenuSnapshotWriter"
		instance.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(instance)
	return instance

static func queue(destination: String, payload: Dictionary) -> void:
	var writer: Node = shared()
	if writer == null: return
	# RAM is main-thread owned until dispatch. Copy it once per batch, rather
	# than serializing/copying the entire cache after each arriving reply.
	writer.pending.erase(destination)
	writer.pending[destination] = payload
	while writer.pending.size() > MAX_PENDING_PATHS: writer.pending.erase(writer.pending.keys()[0])
	writer.set_process(true)

static func peek(destination: String, identity: String) -> Dictionary:
	if not is_instance_valid(instance): return {}
	var value: Dictionary = instance.pending.get(destination,{})
	if value.is_empty() and instance.active_value.get("path","") == destination: value = instance.active_value.payload
	return value.duplicate(true) if value.get("scope","") == identity else {}

static func idle() -> bool:
	return not is_instance_valid(instance) or (instance.active == null and instance.pending.is_empty())

func _process(_delta: float) -> void:
	if active != null:
		if not active.done: return
		if active.result == true: completed_writes += 1
		active = null
		active_value = {}
	if pending.is_empty():
		set_process(false)
		return
	var destination: String = pending.keys()[0]
	active_value = {"path":destination,"payload":(pending[destination] as Dictionary).duplicate(true)}
	pending.erase(destination)
	active = preload("res://editor/work_job.gd").start(_write.bind(active_value),get_tree())

static func _write(cancelled: Callable, value: Dictionary) -> bool:
	if cancelled.call(): return false
	return IO.write(value.path,value.payload,2097152)
