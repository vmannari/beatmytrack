extends Node
## Profile-local cosmetics. One writer, immutable packets, bounded to five cars.
const MAX_BYTES: int = 131072
static var _stores: Dictionary = {}
var path: String
var current: Dictionary = {}
var committed: Dictionary = {}
var last_error: Error = OK
var revision: int = 0
var committed_revision: int = 0
var _thread: Thread
var _writing: Dictionary = {}
var _writing_revision: int = 0
var _retry_at: int = 0
var _owners: Array[WeakRef] = []
var _key: String

static func acquire(file_path: String, legacy: Dictionary, owner_ref: WeakRef) -> Node:
	var absolute: String = ProjectSettings.globalize_path(file_path).simplify_path()
	var key: String = absolute.to_lower() if OS.get_name() == "Windows" else absolute
	var existing: Node = _stores.get(key)
	if is_instance_valid(existing) and not existing.is_queued_for_deletion():
		existing.watch(owner_ref)
		return existing
	var store: Node = load("res://persistence/condition_store.gd").new(absolute,legacy,owner_ref)
	store._key = key
	_stores[key] = store
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(store)
	return store

func _init(file_path: String, legacy: Dictionary, owner_ref: WeakRef) -> void:
	path = file_path
	_owners.append(owner_ref)
	current = legacy.duplicate(true)
	for candidate: String in [path,path+".bak"]:
		var saved: Dictionary = _read(candidate)
		if saved.is_empty(): continue
		current = saved.conditions
		break
	committed = current.duplicate(true)

func _process(_delta: float) -> void:
	for index: int in range(_owners.size()-1,-1,-1):
		var owner_records: RefCounted = _owners[index].get_ref()
		if owner_records == null or owner_records._condition_store != self: _owners.remove_at(index)
	if _owners.is_empty(): close(); return
	poll()
	for owner_ref: WeakRef in _owners: owner_ref.get_ref()._sync_conditions()

func watch(owner_ref: WeakRef) -> void:
	for known: WeakRef in _owners:
		if known.get_ref() == owner_ref.get_ref(): return
	_owners.append(owner_ref)

func release(owner_records: RefCounted) -> void:
	for index: int in range(_owners.size()-1,-1,-1):
		if _owners[index].get_ref() == null or _owners[index].get_ref() == owner_records: _owners.remove_at(index)
	if _owners.is_empty(): close()

func close() -> void:
	flush()
	if _stores.get(_key) == self: _stores.erase(_key)
	queue_free()

func _exit_tree() -> void:
	flush()
	if _stores.get(_key) == self: _stores.erase(_key)

func stage(value: Dictionary) -> Error:
	if not VehicleCondition.valid_collection(value): return ERR_INVALID_DATA
	if current != value:
		current = value.duplicate(true)
		revision += 1
	poll()
	return OK

func poll() -> void:
	if _thread != null:
		if _thread.is_alive(): return
		_accept(_thread.wait_to_finish())
		_thread = null
	if revision == committed_revision or Time.get_ticks_msec() < _retry_at: return
	_writing = current.duplicate(true)
	_writing_revision = revision
	_thread = Thread.new()
	var error: Error = _thread.start(_write.bind(path,_writing),Thread.PRIORITY_LOW)
	if error != OK:
		_thread = null
		_accept(error)

func flush() -> Error:
	if _thread != null:
		_accept(_thread.wait_to_finish())
		_thread = null
	if revision == committed_revision: return OK
	_writing = current.duplicate(true)
	_writing_revision = revision
	_accept(_write(path,_writing))
	return last_error

func _accept(error: Error) -> void:
	if error != OK and last_error == OK: push_warning("Local car condition save failed: "+error_string(error))
	last_error = error
	if error == OK:
		committed = _writing
		committed_revision = _writing_revision
	_retry_at = Time.get_ticks_msec()+5000 if error != OK else 0
	_writing = {}

static func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null: return {}
	if file.get_length() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary or value.size() != 2 or value.get("schema") != 1 or not VehicleCondition.valid_collection(value.get("conditions")): return {}
	return value

static func _write(file_path: String, value: Dictionary) -> Error:
	if not VehicleCondition.valid_collection(value): return ERR_INVALID_DATA
	var content: String = JSON.stringify({"schema":1,"conditions":value},"",true)
	if content.to_utf8_buffer().size() > MAX_BYTES: return ERR_OUT_OF_MEMORY
	var temporary: String = file_path+".tmp"
	var backup: String = file_path+".bak"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or _read(temporary).is_empty(): return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(file_path):
		if not _read(file_path).is_empty():
			if FileAccess.file_exists(backup):
				error = DirAccess.remove_absolute(backup)
				if error != OK: return error
			error = DirAccess.rename_absolute(file_path,backup)
		else: error = DirAccess.remove_absolute(file_path)
		if error != OK: return error
	return DirAccess.rename_absolute(temporary,file_path)
