extends RefCounted

static func run(cancelled: Callable, source: Dictionary, terrain: NativeTrack, population: ObjectPopulation, seed_value: int, density: float, reach: float) -> Dictionary:
	var prepared: ObjectPopulation = population
	if prepared == null:
		prepared = ObjectPopulation.new(); prepared.cancelled = cancelled; prepared.prepare(source,terrain)
	prepared.cancelled = cancelled
	if cancelled.call(): prepared.cancelled = Callable(); return {}
	var objects: Array = prepared.generate(seed_value,density,reach)
	if cancelled.call(): prepared.cancelled = Callable(); return {}
	var candidate: Dictionary = source.duplicate(true); candidate.objects.append_array(objects); candidate["automatic_scenery"] = false
	if not TrackDocument.validate(candidate).is_empty() and TrackDocument.validate(candidate,false).is_empty():
		var fallback: Dictionary = TrackDocument.create_default()
		for key: String in ["points","widths","corners"]: candidate[key] = fallback[key]
		candidate.route_override = true
	var track: NativeTrack = TrackCompiler.compile(candidate,{},cancelled) if prepared.error.is_empty() else null
	prepared.cancelled = Callable()
	if cancelled.call(): return {}
	return {"population":prepared,"objects":objects,"track":track,"error":prepared.error}
