extends SceneTree
## WSB01: actual spline-bank geometry and rendered surface diagnostics.
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAILED ",label)

func capture(view: SubViewport, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(4): await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/winter-spline-banks-2026-10-18/"+RenderingServer.get_current_rendering_method())
	if "--before" in OS.get_cmdline_user_args(): output += "-before"
	DirAccess.make_dir_recursive_absolute(output)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	document.theme = "winter"
	check_ribbon_winding(document)
	var loop: Dictionary = RoadPieces.create("spline",Vector2(-20,-20),0.0,8.0)
	loop.spline_points = [[0.0,0.0],[30.0,0.0],[30.0,30.0],[0.0,30.0],[0.0,2.0]]
	check_ribbon_winding({"pieces":[loop]},true)
	for kind: String in ["straight","taper","curve","s_bend","hairpin","spline"]:
		for flipped: bool in [false,true]:
			var piece: Dictionary = RoadPieces.create(kind,Vector2.ZERO)
			piece.flip = flipped
			if kind == "spline": piece.point_widths = [6.0,10.0,8.0,10.0,6.0]
			check_ribbon_winding({"pieces":[piece]})
	await scene_case(document,"star")
	var loop_doc: Dictionary = TrackDocument.create_blank(); loop_doc.theme = "winter"; loop_doc.pieces = [loop]
	await scene_case(loop_doc,"island")
	var bridge_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	bridge_doc.theme = "winter"
	await scene_case(bridge_doc,"bridge")
	print("WINTER_SPLINE_BANKS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func scene_case(document: Dictionary, label: String) -> void:
	var track: NativeTrack = TrackCompiler.compile(document)
	var canonical: PackedByteArray = var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.snow_banks.triangles])
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 90
	view.add_child(camera)
	var target := Vector3(track.spawn.x,0,-track.spawn.y)
	camera.position = target+Vector3(18,66,55); camera.look_at(target); camera.current = true
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; view.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); view.add_child(environment)
	TrackTheme.apply_lighting("winter",environment.environment,light)
	var visual := NativeTrackVisual.new(); visual.cache_road_meshes = false; visual.persist_road_meshes = false
	visual.process_mode = Node.PROCESS_MODE_DISABLED; view.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	var banks: Array[MeshInstance3D] = []
	var materials: Array[Material] = []
	var up: int = 0; var down: int = 0; var invalid: int = 0; var total: int = 0
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		var mat: ShaderMaterial = node.material_override as ShaderMaterial
		if mat == null or not mat.shader.code.contains("smooth_road_bank"): continue
		banks.append(node); materials.append(mat)
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				if not n.is_finite() or absf(n.length()-1.0) > 0.02: invalid += 1
			for i: int in range(0,indices.size(),3):
				var normal: Vector3 = (vertices[indices[i+2]]-vertices[indices[i]]).cross(vertices[indices[i+1]]-vertices[indices[i]])
				if normal.y > 0.000001: up += 1
				elif normal.y < -0.000001: down += 1
			total += vertices.size()
	print("BANK_GEOMETRY ",JSON.stringify({"meshes":banks.size(),"vertices":total,"up":up,"down":down,"invalid_normals":invalid}))
	check(not banks.is_empty(),"Winter spline has banks")
	check(invalid == 0,"bank normals are finite and normalized")
	await capture(view,label)
	if "--diagnose" in OS.get_cmdline_user_args():
		light.shadow_enabled = false
		await capture(view,"star-no-shadows")
		var debug := ShaderMaterial.new(); debug.shader = Shader.new()
		debug.shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { ALBEDO = vec3(0.9); }"
		for bank: MeshInstance3D in banks: bank.material_override = debug
		await capture(view,"star-unlit-banks")
		for i: int in range(banks.size()): banks[i].material_override = materials[i]
	if label == "star":
		var topology: Dictionary = RoadPieces.prepare_endpoints(document.pieces)
		var contour: PackedVector2Array = RoadEdges.presentation_contours(document.pieces,0,-0.20,topology)[0]
		var anchor: Vector2 = contour[contour.size()/2]
		target = Vector3(anchor.x,0,-anchor.y)
		camera.size = 25; camera.position = target+Vector3(10,18,15); camera.look_at(target)
		await capture(view,"bank-detail")
	check(canonical == var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.snow_banks.triangles]),"visual build preserves canonical track and bank contacts")
	view.free()
	await process_frame

func check_ribbon_winding(document: Dictionary, expect_hole: bool = false) -> void:
	var pieces: Array = document.pieces
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var builder := NativeTrackVisual.new(); builder.theme_id = "winter"
	var failures_by_contour: Array = []
	var holes: int = 0
	for index: int in range(pieces.size()):
		# The unoffset swept boundary retains the enclosed island's role;
		# ordinary cases use the actual inset presentation boundary.
		var contours: Array[PackedVector2Array] = RoadEdges.presentation_contours(pieces,index,0.0 if expect_hole else -0.20,topology)
		var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index,topology)
		var points: PackedVector2Array = RoadPieces.samples(pieces[index])
		for polygon: PackedVector2Array in contours:
			var hole: bool = pieces[index].kind == "spline" and Geometry2D.is_polygon_clockwise(polygon)
			if hole: holes += 1
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var cache: Dictionary = {}
			for edge: int in range(polygon.size()):
				var a: Vector2 = polygon[edge]; var b: Vector2 = polygon[(edge+1)%polygon.size()]
				var na: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts,true)
				var nb: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts,true)
				if hole: na = -na; nb = -nb
				builder._winter_bank_section(tool,a,b,na,nb,points,cache)
			var arrays: Array = tool.commit_to_arrays()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var downward: int = 0
			for i: int in range(0,vertices.size(),3):
				if (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).y < -0.000001: downward += 1
			failures_by_contour.append({"piece":index,"hole":hole,"downward":downward})
			check(downward == 0,"bank ribbon faces upward on piece %d, hole=%s" % [index,hole])
	print("RIBBON_WINDING ",JSON.stringify(failures_by_contour))
	if expect_hole: check(holes > 0,"enclosed spline island exercises inner contour winding")
	builder.free()
