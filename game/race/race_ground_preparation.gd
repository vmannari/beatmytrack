extends RefCounted
## Pure CPU ground sampling. Nodes, materials and uploads stay on the main thread.
static func run(cancelled: Callable, track: NativeTrack) -> Dictionary:
	if cancelled.call(): return {}
	var costs: Dictionary = {}
	var mark: int = Time.get_ticks_usec()
	# The preparation gate owns the track until this pure-CPU job completes.
	track._creator_query()
	costs.queries_us = Time.get_ticks_usec()-mark
	mark = Time.get_ticks_usec()
	if cancelled.call(): return {}
	var prepared := BridgePresentation.new(track)
	costs.support_us = Time.get_ticks_usec()-mark
	mark = Time.get_ticks_usec()
	# Canonical gate construction is a pure layout bake and is cached on this
	# immutable track. Dense spline corridors can take seconds on a cold start;
	# build the exact existing layout here, before Game.restart reads that cache.
	if cancelled.call(): return {}
	var session := TrackSession.new()
	session.prepare_cached(track,cancelled)
	costs.checkpoints_us = Time.get_ticks_usec()-mark
	mark = Time.get_ticks_usec()
	if cancelled.call(): return {}
	var cover: Dictionary = {}
	if track.metadata.get("theme","pine") == "winter" and track.editor_winter_cover.is_empty(): cover = WinterScenery.cover_data(track,cancelled)
	costs.winter_us = Time.get_ticks_usec()-mark
	return {} if cancelled.call() else {"bridge":prepared,"winter_cover":cover,"costs":costs}
