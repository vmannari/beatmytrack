class_name RaceRecommendations
extends RefCounted
## Replaceable local provider. Remote categories are identifiers, not fake feeds.
const CATEGORIES: Array[String] = ["similar", "friend_challenge", "trending", "unplayed", "different_biome", "recently_popular", "beaten_time"]

static func suggest(catalog: TrackCatalog, current: NativeTrack) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in catalog.entries:
		if entry.id == current.identity: continue
		var points := PackedVector2Array()
		for p: Array in entry.points: points.append(Vector2(float(p[0]),float(p[1])))
		if points.size() < 3: continue
		var length: float = 0.0
		for i: int in range(points.size()): length += points[i].distance_to(points[(i+1)%points.size()])
		candidates.append({"entry":entry,"name":entry.name,"laps":RaceRules.LAPS,"estimated_seconds":length/22.0*RaceRules.LAPS,"route":points,"category":"similar","reason":"Similar length · New challenge","score":absf(length-current.route_length)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score < b.score if a.score != b.score else str(a.entry.id) < str(b.entry.id))
	var result: Array[Dictionary] = []
	for item: Dictionary in candidates:
		if result.size() == 3: break
		if item.entry.source == "saved":
			var document: Dictionary = catalog.library.load_document(item.entry.local_id)
			if document.is_empty() or not TrackDocument.validate(document).is_empty(): continue
			item.route = TrackDocument.smooth_points(document)
			item.estimated_seconds = TrackDocument.route_length(item.route)/22.0*RaceRules.LAPS
		if item.score > current.route_length*0.25: item.reason = "Local circuit \u00b7 New challenge"
		if item.entry.theme != current.metadata.get("theme","pine"):
			item.category = "different_biome"
			item.reason = str(item.entry.theme).capitalize()+" · Different scenery"
		result.append(item)
	return result
