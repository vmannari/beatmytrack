extends SceneTree
## Export the existing original starter for canonical backend registration.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/tracks/starter_circuit.json"))
	var document: Dictionary = source.creator_document.duplicate(true)
	for key: String in document.keys():
		if key not in TrackDocument.KEYS: document.erase(key)
	document.id = "starter_circuit"
	document.creator = "Beat my track"
	# The bundled starter predates connected-piece authoring. Represent its
	# original polygon with the current road pieces before backend validation.
	if document.pieces.is_empty():
		for index: int in range(document.points.size()):
			var a := Vector2(document.points[index][0],document.points[index][1])
			var b := Vector2(document.points[(index+1)%document.points.size()][0],document.points[(index+1)%document.points.size()][1])
			var segments: int = ceili(a.distance_to(b)/70.0)
			for segment: int in range(segments):
				var piece: Dictionary = RoadPieces.create("straight",a.lerp(b,float(segment)/segments),rad_to_deg((b-a).angle()))
				piece.length = a.distance_to(b)/segments
				piece.width = document.width
				document.pieces.append(piece)
		document.layout = {}
	var track: NativeTrack = TrackCompiler.compile(document.duplicate(true))
	document["start_line"] = CreatorStartLine.place(document,Vector2(document.points[0][0],document.points[0][1]),track)
	var routed: Dictionary = RoadPieces.route_from_pieces(document)
	# Equivalent cyclic piece orders provide a sampling origin away from joins.
	for attempt: int in range(document.pieces.size()):
		if routed.ok: break
		document.pieces.append(document.pieces.pop_front())
		routed = RoadPieces.route_from_pieces(document)
	if not routed.ok:
		print("STARTER_ROUTE_REJECTED: ",routed.get("message",routed.get("errors",routed)))
		quit(1)
		return
	document = routed.document
	assert(TrackDocument.validate(document).is_empty())
	var output := FileAccess.open("res://../build/backend-starter.json",FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(document))
	output.close()
	print("BACKEND_STARTER_EXPORTED")
	quit()
