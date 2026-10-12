extends "res://backend/runner.gd"
func run() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/bmt_backend/lab_tracks.json"))
	var rows: Array = []
	for document: Dictionary in corpus.documents:
		var compiled: Dictionary = compile_track(document)
		if compiled.has("error"): continue
		var track: NativeTrack = compiled.track
		var config: HandlingConfig = VehicleCatalog.config("compact")
		var key: String = (track.content_hash+VehicleSimulation.PHYSICS_VERSION+JSON.stringify(config.snapshot(),"",true)+RaceRules.KEY).sha256_text()
		rows.append({"name":document.name,"key":key,"content_hash":track.content_hash})
	var file := FileAccess.open("res://../.tools/pace2-record-key-map.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows));file.close();print("Mapped %d track/handling record keys" % rows.size());quit(0)
