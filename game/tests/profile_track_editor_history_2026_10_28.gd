extends SceneTree
const SESSION = preload("res://editor/editor_session.gd")
const HISTORY = preload("res://editor/editor_history.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	for count: int in [32,512,4096]:
		var session = SESSION.new(); var doc: Dictionary = TrackDocument.create_blank()
		for index: int in range(count): doc.objects.append({"kind":"grass_clump","position":[float(index%64)-32,float(index/64)-32],"rotation":0.0})
		var samples: Array[float] = []
		for revision: int in range(40):
			doc.objects[10].rotation = float(revision)
			var began: int = Time.get_ticks_usec(); session.remember(doc)
			samples.append((Time.get_ticks_usec()-began)/1000.0)
		var sorted: Array[float] = samples.duplicate(); sorted.sort()
		var row: Dictionary = {"objects":count,"history_size":session.undo.size(),"history_bytes":HISTORY.bytes_used([session.undo,session.redo]),
			"samples_ms":samples,"median_ms":sorted[20],"p95_ms":sorted[38],"max_ms":sorted[-1]}
		rows.append(row); print("TRACK_EDITOR_HISTORY ",JSON.stringify(row))
	var file := FileAccess.open("res://../docs/evidence/track-editor-review-2026-10-28/history-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close(); quit()
