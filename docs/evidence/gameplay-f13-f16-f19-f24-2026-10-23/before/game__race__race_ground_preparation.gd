extends RefCounted
## Pure CPU ground sampling. Nodes, materials and uploads stay on the main thread.
static func run(cancelled: Callable, track: NativeTrack) -> Dictionary:
	if cancelled.call(): return {}
	var prepared := BridgePresentation.new(track)
	var cover: Dictionary = {}
	if track.metadata.get("theme","pine") == "winter" and track.editor_winter_cover.is_empty(): cover = WinterScenery.cover_data(track,cancelled)
	return {} if cancelled.call() else {"bridge":prepared,"winter_cover":cover}
