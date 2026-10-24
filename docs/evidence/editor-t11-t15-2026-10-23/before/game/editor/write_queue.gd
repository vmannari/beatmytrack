extends RefCounted
## One ordered writer. Replace only queued revisions of the same local draft.
var pending: Array = []
var active: Dictionary = {}
var thread: Thread
var completed: Array = []

func unsettled(storage: TrackLibrary, id: String) -> bool:
	var key: String = storage.directory+"/"+id
	if not active.is_empty() and active.key == key: return true
	for entry: Dictionary in pending:
		if entry.key == key: return true
	return false

func enqueue(storage: TrackLibrary, document: Dictionary) -> Error:
	var key: String = storage.directory+"/"+str(document.id)
	for index: int in range(pending.size()-1,-1,-1):
		if pending[index].key == key: pending.remove_at(index)
	pending.append({"key":key,"storage":storage,"directory":storage.directory,"owner":storage.owner_name,"document":document.duplicate(true)})
	return OK

static func write(entry: Dictionary) -> Dictionary:
	var storage := TrackLibrary.new(entry.directory); storage.owner_name = entry.owner
	var error: Error = storage.save_wip(entry.document)
	return {"storage":entry.storage,"document":entry.document,"error":error,"message":storage.last_error,"digest":FileAccess.get_sha256(entry.directory.path_join("wip/"+str(entry.document.id)+".json")) if error == OK else ""}

func poll() -> void:
	if thread != null and not thread.is_alive():
		completed.append(thread.wait_to_finish()); thread = null; active = {}
	if thread == null and not pending.is_empty():
		active = pending.pop_front(); thread = Thread.new()
		var error: Error = thread.start(write.bind(active),Thread.PRIORITY_LOW)
		if error != OK:
			completed.append({"storage":active.storage,"document":active.document,"error":error,"message":"Could not start the draft writer.","digest":""}); active = {}; thread = null

func flush() -> void:
	while thread != null or not pending.is_empty():
		poll()
		if thread != null:
			completed.append(thread.wait_to_finish()); thread = null; active = {}
