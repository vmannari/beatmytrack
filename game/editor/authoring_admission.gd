extends RefCounted
## Aggregate limits for already domain-validated UI edits. Imports retain the
## complete TrackDocument validator; unfinished racing routes remain legal.
static func error(document: Dictionary, field: String = "") -> String:
	if document.get("hidden_scenery",[]).size() > 256: return "Too many removed scenery trees."
	if field.is_empty() or field == "pieces":
		if document.pieces.size() > RoadPieces.MAX_PIECES: return "Use up to 96 road sections."
		var length: float = 0.0
		for piece: Dictionary in document.pieces:
			var points: PackedVector2Array = RoadPieces.samples(piece)
			for index: int in range(1,points.size()): length += points[index-1].distance_to(points[index])
		if length > 4000.0: return "Use up to 4000 metres of road sections."
	if field.is_empty() or field == "paint":
		if document.paint.size() > 256: return "Use up to 256 paint strokes; undo a stroke or start a new map."
		var points: int = 0
		for stroke: Dictionary in document.paint: points += stroke.points.size()
		if points > 16384: return "The map has too many paint points."
	if field.is_empty() or field == "objects":
		var capacity: String = preload("res://editor/creator_limits.gd").error(document.objects,str(document.theme))
		if not capacity.is_empty(): return capacity
	var encoded_bytes: int = JSON.stringify(document,"",true).to_utf8_buffer().size()
	if encoded_bytes > TrackDocument.MAX_BYTES:
		return "This creator track exceeds %d KB." % (TrackDocument.MAX_BYTES/1024)
	# The writer derives up to 96 route points from connected sections. Only
	# documents near the byte ceiling need that expensive exact second check.
	if not document.pieces.is_empty() and encoded_bytes > TrackDocument.MAX_BYTES-16384:
		var route: Dictionary = RoadPieces.route_from_pieces(document)
		if route.ok and JSON.stringify(route.document,"",true).to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
			return "This creator track exceeds %d KB." % (TrackDocument.MAX_BYTES/1024)
	return ""

static func replacement(document: Dictionary, field: String, value: Variant) -> String:
	var proposed: Dictionary = document.duplicate()
	proposed[field] = value
	return error(proposed,field)
