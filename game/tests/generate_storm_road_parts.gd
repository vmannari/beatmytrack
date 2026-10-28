extends SceneTree
## The actual editor generates the race route from standard connected pieces.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for id: String in IDS:
		var seed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/storm-driving-variety-2026-10-26/seeds/"+id+".json"))
		var issues: Array[Dictionary] = RoadPieces.joins(seed.pieces)
		if not issues.is_empty():
			push_error(id+" open or branched road joins: "+str(issues)); quit(1); return
		var route: Dictionary = RoadPieces.route_from_pieces(seed)
		if not route.ok:
			push_error(id+": "+str(route.errors)); quit(1); return
		var document: Dictionary = route.document
		var placed: Dictionary = CreatorStartLine.place(document,Vector2(document.start_line.position[0],document.start_line.position[1]),null)
		if placed.is_empty():
			push_error(id+": start line does not lie on a road part"); quit(1); return
		document.start_line = placed
		# Recompute from persisted part parameters using the editor's JSON boundary.
		document = JSON.parse_string(JSON.stringify(document,"\t"))
		var persisted_route: Dictionary = RoadPieces.route_from_pieces(document)
		if not persisted_route.ok:
			push_error(id+": persisted road parts failed generation"); quit(1); return
		document = persisted_route.document
		var errors: Array[String] = TrackDocument.validate(document)
		if not errors.is_empty():
			push_error(id+": "+str(errors)); quit(1); return
		var file := FileAccess.open("res://resources/storm_tracks/"+id+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(document,"\t")+"\n"); file.close()
		print("STORM_ROAD_PARTS_GENERATED ",id," pieces=",document.pieces.size()," start=",document.start_line," automatic_nodes=",document.points.size())
	quit()
