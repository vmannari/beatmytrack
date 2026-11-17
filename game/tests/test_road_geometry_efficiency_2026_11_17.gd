extends SceneTree
## RCE01: complete source arrays against the independently retained builder.
const ROADS = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var original: Script
var original_edges: Script
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("ROAD_EFFICIENCY_FAIL ",label)
func clear_cache() -> void:
	ROADS.trim_retained()
	NativeTrackVisual._road_mesh_cache.clear()
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	load("res://track/road_support_cache.gd").trim()
func packet(track: NativeTrack, before: bool) -> Dictionary:
	var visual: Node3D = original.new() if before else NativeTrackVisual.new()
	visual.theme_id = track.metadata.theme; visual.colors = TrackTheme.palette(visual.theme_id)
	visual.cache_road_meshes = false; visual.persist_road_meshes = false
	visual._capture_road_arrays = true
	await visual._build_creator_roads(track)
	if before and preload("res://track/road_surface_height.gd").is_asphalt(track):
		check(visual.get_meta("rce_original_edges",false),"reference actually executed the original asphalt builder")
	var result: Dictionary = {"parts":visual._prepared_road_parts,"metadata":{}}
	for key: String in ["winter_smooth_sections","winter_deposits","desert_clod_count","desert_bank_sections"]:
		if visual.has_meta(key): result.metadata[key] = visual.get_meta(key)
	visual.free()
	return result
func run() -> void:
	var folder: String = OS.get_environment("BMT_ROAD_REFERENCE")
	if folder.is_empty(): folder = "res://../docs/evidence/road-checkpoint-efficiency-2026-11-17/before/game/track"
	original = GDScript.new()
	# A subclass retains all unchanged typed collaborators and overrides the
	# one changed method with its exact task-start body.
	var source: String = FileAccess.get_file_as_string(folder+"/native_track_visual.gd").replace("\r\n","\n")
	var start: int = source.find("func _asphalt_edge_faces(")
	var end: int = source.find("\n\nfunc _inner_bend_distance",start)
	check(start >= 0 and end > start,"original edge builder is present")
	original.source_code = 'extends "res://track/native_track_visual.gd"\n'+source.substr(start,end-start)
	original.source_code = original.source_code.replace("\n\t# Close the raised asphalt","\n\tset_meta(\"rce_original_edges\",true)\n\t# Close the raised asphalt")
	check(original.reload() == OK,"independent original visual compiles")
	original_edges = GDScript.new()
	original_edges.source_code = FileAccess.get_file_as_string(folder+"/road_edges.gd").replace("class_name RoadEdges","")
	check(original_edges.reload() == OK,"independent original edges compile")
	profile_cases()
	var themes: PackedStringArray = ["pine","desert","winter","storm","night_city"]
	if "--pine-only" in OS.get_cmdline_user_args(): themes = ["pine"]
	for theme: String in themes:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
		doc.theme = theme
		await compare_case(doc,theme+" Star")
	if not "--pine-only" in OS.get_cmdline_user_args():
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
		doc.theme = "desert"
		await compare_case(doc,"desert overlapping bridges")
	clear_cache()
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("ROAD_ALGORITHM_EQUIVALENCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func profile_cases() -> void:
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").roads()
	check(native != null and native.has_method("road_asphalt_sides"),"native asphalt profile is loaded")
	if native == null or not native.has_method("road_asphalt_sides"): return
	var ends := PackedVector3Array()
	var outwards := PackedVector3Array()
	for i: int in range(31):
		var a := Vector3(i*0.2,0.062,sin(i*0.3))
		ends.append(a); ends.append(a+Vector3(0.17,0.0,0.06))
		outwards.append(Vector3(cos(i*0.3),0.0,sin(i*0.3))*(1.0+i%4*0.2))
		outwards.append(Vector3(cos(i*0.3+0.2),0.0,sin(i*0.3+0.2))*(1.0+i%3*0.2))
	var expected := SurfaceTool.new(); expected.begin(Mesh.PRIMITIVE_TRIANGLES)
	var actual := SurfaceTool.new(); actual.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0,ends.size(),2):
		preload("res://track/asphalt_edge_profile.gd").append(expected,ends[i],ends[i+1],outwards[i],outwards[i+1],0.013,0.013)
	check(native.road_asphalt_sides(actual,ends,outwards,0.013),"complete native side batch emits")
	check(var_to_bytes(expected.commit_to_arrays()) == var_to_bytes(actual.commit_to_arrays()),"rounded lip profile preserves every vertex, normal, colour and UV bit")
	var invalid := SurfaceTool.new(); invalid.begin(Mesh.PRIMITIVE_TRIANGLES)
	check(not native.road_asphalt_sides(invalid,ends,outwards.slice(1),0.013),"mismatched batch rejected before emission")
	check(not native.road_asphalt_sides(invalid,PackedVector3Array([Vector3.ZERO,Vector3(INF,0,0)]),outwards.slice(0,2),0.013),"nonfinite batch rejected before emission")
	# A valid batch can still use this untouched tool after both rejections.
	check(native.road_asphalt_sides(invalid,ends,outwards,0.013),"rejected batches permit complete fallback/retry")
	var expected_again := SurfaceTool.new(); expected_again.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0,ends.size(),2):
		preload("res://track/asphalt_edge_profile.gd").append(expected_again,ends[i],ends[i+1],outwards[i],outwards[i+1],0.013,0.013)
	check(var_to_bytes(expected_again.commit_to_arrays()) == var_to_bytes(invalid.commit_to_arrays()),"rejected batches leave no partial vertices")
func compare_case(doc: Dictionary, label: String) -> void:
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,label+" compiles")
	if track == null: return
	var canonical: PackedByteArray = var_to_bytes([track.content_hash,track.cells,track.deck_cells,track.route,track.route_widths,track.kerbs.triangles])
	var support: RefCounted = preload("res://track/road_surface_height.gd").new(track)
	for polygon: PackedVector2Array in support.floors:
		for reverse: bool in [false,true]:
			var shape: PackedVector2Array = polygon.duplicate()
			if reverse: shape.reverse()
			var actual: PackedVector2Array = RoadEdges.edge_miters(shape)
			for index: int in range(shape.size()):
				check(actual[index] == original_edges._edge_miter(shape,index),label+" winding and corner offset exact")
	clear_cache()
	var began: int = Time.get_ticks_usec(); var expected: Dictionary = await packet(track,true)
	var before_us: int = Time.get_ticks_usec()-began
	clear_cache()
	began = Time.get_ticks_usec(); var actual: Dictionary = await packet(track,false)
	var after_us: int = Time.get_ticks_usec()-began
	check(not expected.parts.is_empty(),label+" reference contains geometry")
	check(expected.parts.size() == actual.parts.size(),label+" same part count")
	for index: int in range(mini(expected.parts.size(),actual.parts.size())):
		check(expected.parts[index].role == actual.parts[index].role,label+" same role "+str(index))
		check(var_to_bytes(expected.parts[index].arrays) == var_to_bytes(actual.parts[index].arrays),label+" exact positions, normals, colours, UVs and indices "+str(index))
	check(expected.metadata == actual.metadata,label+" diagnostic geometry counts exact")
	check(canonical == var_to_bytes([track.content_hash,track.cells,track.deck_cells,track.route,track.route_widths,track.kerbs.triangles]),label+" canonical contact and route data exact")
	rows.append({"fixture":label,"before_us":before_us,"after_us":after_us,"parts":actual.parts.size()})
	print("ROAD_EFFICIENCY_ROW ",JSON.stringify(rows[-1]))
