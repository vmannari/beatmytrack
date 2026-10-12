extends SceneTree
## Reject painted/apron end caps across joined spline driving lanes.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func pieces(angle: float = 340.0, width_a: float = 14.0, width_b: float = 14.0) -> Array:
	var first: Dictionary = RoadPieces.create("spline",Vector2(-18,32),270.0,width_a)
	first.spline_points = [[0.0,0.0],[10.0,0.0],[20.0,1.0],[30.0,2.0],[40.0,2.0]]
	var second: Dictionary = RoadPieces.create("spline",RoadPieces.end_pose(first).position,angle,width_b)
	second.spline_points = [[0.0,0.0],[12.0,0.0],[24.0,-2.0],[38.0,-3.0],[52.0,1.0]]
	return [first,second]

func reversed_piece(piece: Dictionary) -> Dictionary:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	nodes.reverse()
	var result: Dictionary = piece.duplicate(true)
	result.heading = 0.0; result.flip = false; result.position = [nodes[0].x,nodes[0].y]
	for i: int in range(nodes.size()):
		var local: Vector2 = nodes[i]-nodes[0]
		result.spline_points[i] = [local.x,local.y]
	result.point_widths.reverse()
	return result

func document(roads: Array) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "spline_join"; doc.name = "Open spline joins"; doc.pieces = roads
	return doc

func seam_triangles(visual: Node, cut: Dictionary, parameter: String) -> int:
	var count: int = 0
	for child: Node in visual.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		var material: ShaderMaterial = child.material_override
		if material.shader.resource_path != "res://track/creator_road.gdshader" or not material.get_shader_parameter(parameter): continue
		var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(0,vertices.size(),3):
			var center: Vector3 = (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
			var delta: Vector2 = Vector2(center.x,-center.z)-Vector2(cut.point)
			if absf(delta.dot(cut.normal)) < 0.5 and absf(delta.dot(Vector2(cut.normal).orthogonal())) < float(cut.lane_width)*0.30:
				count += 1
	return count

func geometry_checks() -> void:
	var contacts_script := GDScript.new()
	contacts_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/spline-joins-2026-10-06/before/game/track/road_kerbs.gd").replace("\r\n","\n").replace("class_name RoadKerbs\n","")
	check(contacts_script.reload() == OK,"task-start physical contact builder compiles")
	var renderer_script := GDScript.new()
	renderer_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/spline-joins-2026-10-06/before/game/track/native_track_visual.gd").replace("\r\n","\n").replace("class_name NativeTrackVisual\n","")
	check(renderer_script.reload() == OK,"task-start renderer compiles for seam reproduction")
	var sample_roads: Array = pieces()
	var sample_native: NativeTrack = TrackCompiler.compile(document(sample_roads))
	var sample_cut: Dictionary = RoadEdges._join_cuts(sample_roads,0)[0]; sample_cut["lane_width"] = 14.0
	var old_visual: Node3D = renderer_script.new()
	old_visual.set("cache_road_meshes",false); old_visual.set("theme_id","pine"); old_visual.set("colors",TrackTheme.palette("pine"))
	root.add_child(old_visual); await old_visual.call("_build_creator_roads",sample_native)
	check(seam_triangles(old_visual,sample_cut,"road_marking") > 0 and seam_triangles(old_visual,sample_cut,"gravel") > 0,"same centre-lane probe reproduces both old cap stripes and apron")
	old_visual.free(); await process_frame
	var cases: Array[Dictionary] = []
	for angle: float in [270.0,300.0,340.0,25.0]:
		for widths: Vector2 in [Vector2(14,14),Vector2(8,18)]: cases.append({"roads":pieces(angle,widths.x,widths.y),"label":"angle %.0f / widths %s" % [angle,widths]})
	var pair: Array = pieces(340,8,18)
	cases.append({"roads":[reversed_piece(pair[0]),pair[1]],"label":"start to start"})
	cases.append({"roads":[pair[0],reversed_piece(pair[1])],"label":"end to end"})
	cases.append({"roads":[reversed_piece(pair[0]),reversed_piece(pair[1])],"label":"both reversed"})
	cases.append({"roads":[pair[1],pair[0]],"label":"piece order reversed"})
	var total_markings: int = 0
	var total_aprons: int = 0
	for case: Dictionary in cases:
		var roads: Array = case.roads
		var topology: Dictionary = RoadPieces.prepare_endpoints(roads)
		var cuts: Array[Dictionary] = RoadEdges._join_cuts(roads,0,topology)
		check(cuts.size() == 1,"fixture has an actual shared endpoint")
		var partner: Array = RoadPieces._matches(topology,0,int(cuts[0].endpoint))[0]
		cuts[0]["lane_width"] = (RoadPieces.endpoint_width(roads[0],int(cuts[0].endpoint))+RoadPieces.endpoint_width(roads[int(partner[0])],int(partner[1])))*0.5
		for index: int in range(2):
			var own_cuts: Array[Dictionary] = RoadEdges._join_cuts(roads,index,topology)
			var cap_count: int = 0
			var stale_count: int = 0
			for polygon: PackedVector2Array in RoadEdges.presentation_contours(roads,index,-0.2,topology):
				for edge: int in range(polygon.size()):
					var a: Vector2 = polygon[edge]; var b: Vector2 = polygon[(edge+1)%polygon.size()]
					if RoadEdges._on_join_cap(a,b,own_cuts): cap_count += 1
					var normal: Vector2 = own_cuts[0].normal
					var da: float = (a-Vector2(own_cuts[0].point)).dot(normal)
					var db: float = (b-Vector2(own_cuts[0].point)).dot(normal)
					if absf(da-0.2)<0.002 and absf(db-0.2)<0.002 and a.distance_to(b)>1.0: stale_count += 1
			check(cap_count > 0,"inset retains its mouth on the actual shared plane")
			check(stale_count == 0,"whole asymmetric cap is extended back rather than left inside the road")
		var native: NativeTrack = TrackCompiler.compile(document(roads))
		check(native != null,"connected spline fixture compiles: "+str(case.label))
		if native == null: continue
		var old_contacts: RefCounted = contacts_script.new()
		old_contacts.call("build",native)
		check(old_contacts.get("triangles") == native.kerbs.triangles and old_contacts.get("blocked") == native.kerbs.blocked,"presentation fix preserves exact original physical kerbs and masks")
		var original: Array = roads.duplicate(true)
		var visual := NativeTrackVisual.new(); visual.cache_road_meshes = false
		visual.theme_id = "pine"; visual.colors = TrackTheme.palette("pine")
		root.add_child(visual); await visual._build_creator_roads(native)
		var markings: int = seam_triangles(visual,cuts[0],"road_marking")
		var aprons: int = seam_triangles(visual,cuts[0],"gravel")
		print("SPLINE_JOIN_CASE ",case.label," marking=",markings," apron=",aprons)
		total_markings += markings; total_aprons += aprons
		check(markings == 0,"no white end-cap stripe across joined spline lane")
		check(aprons == 0,"no sandy apron across joined spline lane")
		check(roads == original,"join presentation preserves authored points and widths")
		visual.free(); await process_frame
	print("SPLINE_JOIN_INTERIOR_TRIANGLES marking=",total_markings," apron=",total_aprons)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"real joined-spline scene finishes preparation")
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"save "+name)

func run() -> void:
	await geometry_checks()
	root.size = Vector2i(1280,720)
	folder = "user://spline_join_test_"+TrackLibrary.unique_id()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/spline-joins-2026-10-06").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = document(pieces()); app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	app.canvas.fit(); await shot("joined-1280x720")
	app.canvas.zoom_by(2.0,app.canvas.to_screen(Vector2(-16,-8))); await shot("join-closeup")
	root.size = Vector2i(960,540); await process_frame; app.canvas.fit(); await shot("joined-960x540")
	app.queue_free(); await process_frame
	cleanup(folder)
	print("SPLINE_JOIN_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
