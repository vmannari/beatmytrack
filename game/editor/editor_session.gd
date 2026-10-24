extends RefCounted
## Authoring transaction state, independent of controls, scenes and race data.
const HISTORY = preload("res://editor/editor_history.gd")
var undo: Array[Dictionary] = []
var redo: Array[Dictionary] = []
var gesture_undo: Array[Dictionary] = []
var gesture_redo: Array[Dictionary] = []
var commits = preload("res://editor/commit_queue.gd").new()
var revision: int = 0
var derived_revision: int = -1
var validated: Dictionary = {}
var errors: Array[String] = []
var workflow: Dictionary = {}

func remember(document: Dictionary) -> void:
	undo.append(HISTORY.capture(document,undo.back() if not undo.is_empty() else {}))
	redo.clear()
	HISTORY.trim(undo,redo)

func begin_gesture(document: Dictionary) -> void:
	gesture_undo = undo.duplicate(); gesture_redo = redo.duplicate()
	remember(document)

func finish_gesture() -> void:
	gesture_undo.clear(); gesture_redo.clear()

func cancel_gesture() -> void:
	undo = gesture_undo.duplicate(); redo = gesture_redo.duplicate()
	finish_gesture()

func restore(document: Dictionary, backwards: bool) -> Dictionary:
	var source: Array[Dictionary] = undo if backwards else redo
	var destination: Array[Dictionary] = redo if backwards else undo
	if source.is_empty(): return document
	destination.append(HISTORY.capture(document,source.back()))
	var result: Dictionary = HISTORY.restore(source.pop_back())
	HISTORY.trim(undo,redo)
	return result

func enqueue(storage: TrackLibrary, document: Dictionary, workflow_root: String) -> void:
	revision += 1
	commits.enqueue(storage,document,workflow_root,revision)

func accept(receipt: Dictionary, storage: TrackLibrary, document: Dictionary) -> bool:
	# A receipt may still be saved for recovery, but never owns newer live data.
	if receipt.storage != storage or receipt.get("revision",-1) != revision or receipt.source != document: return false
	if receipt.has("error"): return true
	derived_revision = revision
	validated = receipt.document.duplicate(true)
	errors.assign(receipt.errors)
	workflow = receipt.workflow
	return true
