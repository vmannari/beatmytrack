extends SceneTree
## Device-only CPU accelerator against the frozen original visual algorithm.
const ORIGINAL = preload("res://tests/fixtures/desert_relief_before_editor_latency.gd")
var checks: int = 0
var failures: int = 0
var timings: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func compare(expected: Array, actual: Array, label: String) -> void:
	check(expected == actual,label+" exact final mesh arrays")
	if expected == actual: return
	for channel: int in range(Mesh.ARRAY_MAX):
		if expected[channel] == actual[channel]: continue
		print("GEOMETRY_DIFFERENCE ",label," channel=",channel," expected=",typeof(expected[channel])," actual=",typeof(actual[channel]))
		if expected[channel] == null or actual[channel] == null: continue
		print(" counts=",expected[channel].size(),"/",actual[channel].size())
		var shown: int = 0
		for i: int in range(mini(expected[channel].size(),actual[channel].size())):
			if expected[channel][i] != actual[channel][i]:
				print(" index=",i," expected=",expected[channel][i]," actual=",actual[channel][i])
				shown += 1
				if shown == 3: break

func run() -> void:
	check(ClassDB.class_exists("BmtTrackGeometry"),"native geometry extension is loaded")
	if not ClassDB.class_exists("BmtTrackGeometry"): quit(1); return
	var native: RefCounted = ClassDB.instantiate("BmtTrackGeometry")
	check(native.call("algorithm_version") == 1,"native algorithm is the expected version")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	doc.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(doc)
	var original: RefCounted = ORIGINAL.new(track)
	var terrain: Dictionary = {"field":original.field,"width":track.grid_width,"rows":track.grid_height,"cell_size":track.cell_size,"half_extent":track.half_extent,"bounds":original.bounds}
	var plane := PlaneMesh.new(); plane.size = Vector2(55,55)
	var large := PlaneMesh.new(); large.size = Vector2(160,160)
	var cube := BoxMesh.new(); cube.size = Vector3(8,2,5)
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(6):
		tool.set_normal(Vector3(0.13,1.0,0.27).normalized())
		tool.set_uv(Vector2(i*0.13,i*0.31)); tool.set_uv2(Vector2(i*0.19,-i*0.05))
		tool.set_color(Color(i*0.12,0.34,0.57,0.81))
		tool.add_vertex(Vector3([-12.0,15.0,-8.0,15.0,-12.0,11.0][i],i*0.2,[-12.0,-10.0,13.0,-10.0,-12.0,17.0][i]))
	var colored: ArrayMesh = tool.commit()
	var sources: Array[Mesh] = [plane,cube,colored,large]
	var poses: Array[Transform3D] = [Transform3D.IDENTITY,Transform3D(Basis(Vector3.UP,0.23),Vector3(3,0,8)),Transform3D(Basis.from_euler(Vector3(0.07,0.31,-0.03)).scaled(Vector3(1.2,0.8,0.7)),Vector3(-7,0.4,-9))]
	for source: Mesh in sources:
		for pose: Transform3D in poses:
			var refine: bool = source != cube
			var began: int = Time.get_ticks_usec()
			var expected: Mesh = original.deform(source,pose,refine)
			var original_ms: float = (Time.get_ticks_usec()-began)/1000.0
			var streams: Array = [source.surface_get_arrays(0)]
			began = Time.get_ticks_usec()
			var result: Array = native.call("relief",streams,terrain,pose,refine,Callable())
			var native_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(result.size() == 1,"native returns one prepared surface")
			if result.size() != 1: continue
			var actual := ArrayMesh.new(); actual.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result[0])
			compare(expected.surface_get_arrays(0),actual.surface_get_arrays(0),str(source.get_class())+" "+str(pose))
			timings.append({"source":source.get_class(),"original_ms":original_ms,"native_ms":native_ms,"vertices":actual.surface_get_array_len(0)})
	check(native.call("relief",[large.surface_get_arrays(0)],terrain,Transform3D.IDENTITY,true,func() -> bool: return true).is_empty(),"native honours cancellation before geometry work")
	var cancel_state: Dictionary = {"calls":0}
	var cancelled_later: Array = native.call("relief",[large.surface_get_arrays(0)],terrain,Transform3D.IDENTITY,true,func() -> bool:
		cancel_state.calls += 1
		return cancel_state.calls >= 4)
	check(cancelled_later.is_empty() and cancel_state.calls >= 4,"native discards partial output on cancellation during subdivision")
	preload("res://track/geometry_acceleration.gd").enabled = false
	var fallback = preload("res://track/desert_road_relief.gd").new(track)
	var fallback_mesh: Mesh = fallback.deform(colored,poses[1],true)
	check(fallback_mesh.surface_get_arrays(0) == original.deform(colored,poses[1],true).surface_get_arrays(0),"unsupported/disabled native path preserves the original geometry")
	preload("res://track/geometry_acceleration.gd").enabled = true
	var invalid: Dictionary = terrain.duplicate(); invalid.width += 1
	check(native.call("relief",[plane.surface_get_arrays(0)],invalid,Transform3D.IDENTITY,true,Callable()).is_empty(),"inconsistent field dimensions are rejected")
	var folder: String = ProjectSettings.globalize_path("res://../build/device-track-loading")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("native-geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings},"\t")); file.close()
	print("DEVICE_TRACK_GEOMETRY: ",checks," checks, ",failures," failures ",JSON.stringify(timings))
	quit(1 if failures else 0)
