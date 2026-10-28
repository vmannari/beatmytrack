extends RefCounted
## Pure CPU ground sampling. Nodes, materials and uploads stay on the main thread.
static func run(cancelled: Callable, track: NativeTrack) -> Dictionary:
	if cancelled.call(): return {}
	# The preparation gate owns the track until this pure-CPU job completes.
	track._creator_query()
	if cancelled.call(): return {}
	var prepared := BridgePresentation.new(track)
	# Canonical gate construction is a pure layout bake and is cached on this
	# immutable track. Dense spline corridors can take seconds on a cold start;
	# build the exact existing layout here, before Game.restart reads that cache.
	if cancelled.call(): return {}
	var session := TrackSession.new()
	session._configure(track)
	if cancelled.call(): return {}
	var cover: Dictionary = {}
	if track.metadata.get("theme","pine") == "winter" and track.editor_winter_cover.is_empty(): cover = WinterScenery.cover_data(track,cancelled)
	return {} if cancelled.call() else {"bridge":prepared,"winter_cover":cover}
