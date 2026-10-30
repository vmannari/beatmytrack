extends RefCounted
## Coalesced authoring analysis, followed by the existing ordered durable writer.
var pending: Array = []
var active: Dictionary = {}
var completed: Array = []
var thread: Thread

func enqueue(storage: TrackLibrary, document: Dictionary, workflow: String, revision: int = 0) -> void:
	var key: String = storage.directory+"/"+str(document.id)
	for index: int in range(pending.size()-1,-1,-1):
		if pending[index].key == key: pending.remove_at(index)
	pending.append({"key":key,"storage":storage,"source":document.duplicate(true),"workflow":workflow,"revision":revision})

static func prepare(entry: Dictionary) -> Dictionary:
	var document: Dictionary = entry.source
	if not document.pieces.is_empty():
		var route: Dictionary = RoadPieces.route_from_pieces(document)
		if route.ok: document = route.document
	return {"revision":entry.revision,"storage":entry.storage,"source":entry.source,"document":document,"errors":TrackDocument.validate(document),
		"workflow":TrackLifecycle.presentation_for_fingerprint(TrackLibrary.draft_fingerprint(document),entry.workflow) if not str(entry.workflow).is_empty() else {}}

func unsettled() -> bool:
	return thread != null or not pending.is_empty()

func poll() -> void:
	if thread != null and not thread.is_alive():
		completed.append(thread.wait_to_finish()); thread = null; active = {}
	if thread == null and not pending.is_empty():
		active = pending.pop_front(); thread = Thread.new()
		var error: Error = thread.start(prepare.bind(active),Thread.PRIORITY_LOW)
		if error != OK:
			thread = null
			# Explicit saves retain the synchronous recovery path; ordinary input
			# never silently runs expensive fallback work in the event handler.
			completed.append({"revision":active.revision,"storage":active.storage,"source":active.source,"error":error})
			active = {}

func flush() -> void:
	while unsettled():
		poll()
		if thread != null:
			completed.append(thread.wait_to_finish()); thread = null; active = {}
