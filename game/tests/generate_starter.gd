extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = "starter_circuit"
	doc.name = "Starter Circuit"
	doc["creator"] = "Beat my track"
	var errors: Array[String] = TrackDocument.validate(doc)
	if not errors.is_empty():
		print("STARTER_INVALID: ",errors)
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(doc)
	assert(track != null)
	var data: Dictionary = track.metadata.duplicate(true)
	data.identity = "starter_circuit"
	data.creator = doc.creator
	data.provenance = {"source":"original creator layout","use":"bundled starter circuit"}
	var file := FileAccess.open("res://resources/tracks/starter_circuit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	print("STARTER_GENERATED")
	quit()
