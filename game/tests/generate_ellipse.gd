extends SceneTree
## Prepare the existing official Ellipse for immediate offline tutorial loading.
const SOURCE: String = "res://resources/cloud_tracks/893027446fb96e8a38a64b3143b033c04c15587b0364f6700fbda7985973defc.json"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var errors: Array[String] = TrackDocument.validate(document)
	if not errors.is_empty():
		print("ELLIPSE_INVALID: ",errors)
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null:
		quit(1)
		return
	var data: Dictionary = track.metadata.duplicate(true)
	data.identity = "ellipse"
	data.creator = document.creator
	data.provenance = {"source":"bundled official Ellipse", "source_sha256":FileAccess.get_sha256(SOURCE), "use":"offline tutorial and local fallback"}
	var file := FileAccess.open("res://resources/tracks/ellipse.json",FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	print("ELLIPSE_GENERATED: ",document.id)
	quit()
