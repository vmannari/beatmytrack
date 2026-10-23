extends RefCounted
## Optional local CPU implementation. Never called by the simulation step.
static var enabled: bool = true
static var roads_enabled: bool = true
static var winter_enabled: bool = true
static var raster_enabled: bool = true

static func winter() -> RefCounted:
	return _feature("winter_algorithm_version") if winter_enabled else null

static func raster() -> RefCounted:
	return _feature("raster_algorithm_version") if raster_enabled else null

static func _feature(method: String) -> RefCounted:
	if not available(): return null
	var native: RefCounted = ClassDB.instantiate("BmtTrackGeometry")
	return native if native != null and native.has_method(method) and native.call(method) == 1 else null

static func roads() -> RefCounted:
	if not roads_enabled or not available(): return null
	var native: RefCounted = ClassDB.instantiate("BmtTrackGeometry")
	return native if native != null and native.has_method("road_algorithm_version") and native.call("road_algorithm_version") == 1 else null

static func blend_data(sampler: RefCounted) -> Dictionary:
	if sampler == null: return {}
	return {"points":sampler.piece_points,"outlines":sampler.piece_outlines,"bounds":sampler.piece_bounds,"candidates":sampler.candidates,"settings":sampler.settings}

static func available() -> bool:
	return enabled and ClassDB.class_exists("BmtTrackGeometry")

static func relief(streams: Array, data: RefCounted, transform: Transform3D, refine: bool, cancelled: Callable) -> Array:
	if not available(): return []
	var native: RefCounted = ClassDB.instantiate("BmtTrackGeometry")
	if native == null or native.call("algorithm_version") != 1: return []
	var track: NativeTrack = data.track
	var terrain: Dictionary = {"field":data.field,"width":track.grid_width,"rows":track.grid_height,"cell_size":track.cell_size,"half_extent":track.half_extent,"bounds":data.bounds}
	return native.call("relief",streams,terrain,transform,refine,cancelled)
