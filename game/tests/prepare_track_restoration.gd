extends SceneTree
## Operations helper: prepare retained saved circuits without changing road geometry.
const INPUT: String = "res://../build/backend-restoration-candidates.json"
const OUTPUT: String = "res://../build/backend-restoration-prepared.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var prepared: Array[Dictionary] = []
	var failures: int = 0
	for candidate: Dictionary in candidates:
		var document: Dictionary = candidate.document.duplicate(true)
		document["creator"] = "Beat my track"
		var added_start: bool = not document.has("start_line")
		var start_adjustment: float = 0.0
		if added_start:
			var start := Vector2(document.points[0][0],document.points[0][1])
			if document.has("practice_start"):
				start = Vector2(document.practice_start.position[0],document.practice_start.position[1])
			document["start_line"] = CreatorStartLine.place(document,start,null)
			if document.start_line.is_empty():
				print("RESTORATION_REJECTED: ",document.name," start is off the road")
				failures += 1
				continue
		else:
			var old_position := Vector2(document.start_line.position[0],document.start_line.position[1])
			var placed: Dictionary = CreatorStartLine.place(document,old_position,null)
			if placed.is_empty():
				print("RESTORATION_REJECTED: ",document.name," saved start is off the road")
				failures += 1
				continue
			var new_position := Vector2(placed.position[0],placed.position[1])
			if old_position.distance_to(new_position) > 0.05:
				start_adjustment = old_position.distance_to(new_position)
				document.start_line.position = placed.position
		var routed: Dictionary = RoadPieces.route_from_pieces(document)
		var rotations: int = 0
		# Cyclic order changes sampling origin only; every road piece is retained.
		while not routed.ok and rotations < document.pieces.size()-1:
			document.pieces.append(document.pieces.pop_front())
			rotations += 1
			routed = RoadPieces.route_from_pieces(document)
		if not routed.ok:
			print("RESTORATION_REJECTED: ",document.name," ",routed.errors)
			failures += 1
			continue
		document = routed.document
		prepared.append({"source_path":candidate.source_path,"original":candidate.document,
			"document":document,"added_start_line":added_start,"start_adjustment_metres":start_adjustment,
			"cyclic_piece_rotations":rotations})
		print("RESTORATION_PREPARED: ",document.name," start migrated=",added_start," start snapped=",start_adjustment,"m cyclic order=",rotations)
	var output := FileAccess.open(OUTPUT,FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(prepared,"\t"))
	output.close()
	print("TRACK_RESTORATION_PREPARATION: ",prepared.size()," ready, ",failures," rejected")
	quit(1 if failures else 0)
