extends RefCounted
const VERSION: String = "track-kit-220-finite-join-caps"
const PREPARED_WORLDS = preload("res://track/prepared_world_cache.gd")
static func race_roads_need_preparation(track: NativeTrack) -> bool:
	if track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): return false
	var theme: String = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	var key: Array = [track.content_hash,VERSION,theme,TrackTheme.palette(theme),true]
	var builder: Script = ResourceLoader.get_cached_ref("res://track/native_track_visual.gd") if ResourceLoader.has_cached("res://track/native_track_visual.gd") else null
	var roads: Array = builder.get("_road_mesh_cache") if builder != null else []
	for entry: Dictionary in roads:
		if entry.key == key: return false
	var world_key: Array = [track.content_hash,VERSION,ContactShading.VERSION,CreatorPropVisual.VERSION,theme,TrackTheme.palette(theme),true]
	world_key.append([true,false,true,false,VisualGeometry.optimize_model_geometry])
	for entry: Dictionary in PREPARED_WORLDS.entries:
		if entry.key == world_key: return false
	# Production disk hits use verified numeric arrays on the CPU worker.
	# Legacy resource artifacts are disposable and rebuild once.
	return true
