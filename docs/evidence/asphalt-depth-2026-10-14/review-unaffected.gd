extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func method(source: String, name: String) -> String:
	var first: int = source.find("func "+name+"(")
	var end: int = source.find("\nfunc ",first+1)
	return source.substr(first,end-first if end >= 0 else -1)+"\n"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder: String = "res://../docs/evidence/asphalt-depth-2026-10-14/"
	var source: String = FileAccess.get_file_as_string(folder+"before-source/game/track/native_track_visual.gd").replace("\r\n","\n")
	var old := GDScript.new()
	old.source_code = "extends NativeTrackVisual\n"+method(source,"_build_creator_roads")+method(source,"_asphalt_fringe_quad")+method(source,"_commit_creator_road")
	check(old.reload() == OK,"saved native geometry callbacks load against the unchanged supporting geometry")
	for theme: String in ["winter","desert","pine"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
		doc.theme = theme
		if theme == "pine": doc.surface = "dirt"
		var track: NativeTrack = TrackCompiler.compile(doc)
		var before: NativeTrackVisual = old.new()
		var after := NativeTrackVisual.new()
		for kit: NativeTrackVisual in [before,after]:
			kit.theme_id = theme; kit.colors = TrackTheme.palette(theme)
			kit.cache_road_meshes = false; kit.persist_road_meshes = false; kit.prepare_editor_roads = false
			kit._capture_road_arrays = true
			await kit._build_creator_roads(track)
		check(not after._prepared_road_parts.is_empty(),theme+" actual prepared geometry captured")
		check(var_to_bytes(before._prepared_road_parts) == var_to_bytes(after._prepared_road_parts),theme+" loose-surface geometry, normals, colours and UVs remain byte-exact")
		var bridge := BridgePresentation.new(track)
		check(bridge.road_surface.lift == 0.0,theme+" loose surface has no asphalt rise or depth-cue role")
		before.free(); after.free()
	print("ASPHALT_UNAFFECTED: ",checks," checks, ",failures," failures")
	var file := FileAccess.open(folder+"unaffected-geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t")); file.close()
	quit(1 if failures else 0)
