extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "res://../docs/evidence/desert-correction-2026-10-12/crossing/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	doc.objects = []
	doc["automatic_scenery"] = false
	doc.pieces = []
	for entry: Array in [[Vector2(-22,0),0.0],[Vector2(0,-22),90.0]]:
		var piece: Dictionary = RoadPieces.create("straight",entry[0],entry[1],10.0)
		piece.length = 44.0
		doc.pieces.append(piece)
	print("CROSSING_DOCUMENT_ISSUES: ",TrackDocument.validate(doc))
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"crossing fixture compiles")
	if track == null: quit(1); return
	var cells: PackedInt32Array = track.cells.duplicate()
	var content: String = track.content_hash
	var visual := NativeTrackVisual.new()
	visual.cache_road_meshes = false
	root.add_child(visual)
	var bridge := BridgePresentation.new(track)
	await visual.build(track,bridge)
	var triangles: Array[PackedVector2Array] = []
	for mesh: Node in visual.get_children():
		if not mesh is MeshInstance3D or not mesh.material_override is ShaderMaterial: continue
		var material: ShaderMaterial = mesh.material_override
		if material.get_shader_parameter("desert_dunes") == true:
			check(material.shader.code.contains("diffuse_burley") and not material.shader.code.contains("diffuse_toon"),"terrain, skirt and deposits share continuous desert lighting")
		if material.get_shader_parameter("asphalt_surface") != true or material.get_shader_parameter("edge_fringe") == true: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i: int in range(0,vertices.size(),3):
				triangles.append(PackedVector2Array([Vector2(vertices[i].x,-vertices[i].z),Vector2(vertices[i+1].x,-vertices[i+1].z),Vector2(vertices[i+2].x,-vertices[i+2].z)]))
	var area: float = 0.0
	for triangle: PackedVector2Array in triangles: area += absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))*0.5
	# Independent polygon-union oracle includes the authored end-cap shapes.
	var topology: Dictionary = RoadPieces.prepare_endpoints(doc.pieces)
	var polygons: Array[PackedVector2Array] = []
	for i: int in range(2):
		var join: Dictionary = VisualRoadJoin.build(doc.pieces,i,0.0,topology)
		polygons.append(Geometry2D.offset_polygon(join.contours[0],0.16,Geometry2D.JOIN_ROUND)[0])
	var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(polygons[0],polygons[1])
	var expected_area: float = 0.0
	for polygon: PackedVector2Array in merged:
		for i: int in range(polygon.size()): expected_area += polygon[i].cross(polygon[(i+1)%polygon.size()])*0.5
	expected_area = absf(expected_area)
	print("CROSSING_AREA: ",area," triangles=",triangles.size())
	check(absf(area-expected_area) < 0.05,"crossing renders the union area without duplicate coplanar road")
	for y: float in [-3.731,-1.129,0.327,2.613,4.117]:
		for x: float in [-4.019,-2.341,0.713,2.137,3.821]:
			var covered: int = 0
			for triangle: PackedVector2Array in triangles:
				if Geometry2D.point_is_inside_triangle(Vector2(x,y),triangle[0],triangle[1],triangle[2]): covered += 1
			check(covered == 1,"each crossing sample has exactly one visible road face")
	check(cells == track.cells and content == track.content_hash,"union leaves canonical surfaces and hash unchanged")
	if DisplayServer.get_name() != "headless":
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		TrackTheme.apply_lighting("desert",environment.environment,light)
		root.add_child(environment); root.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 38.0
		root.add_child(camera)
		camera.current = true
		camera.position = Vector3(0,36,24)
		camera.look_at(Vector3.ZERO)
		# Warm renderer pipelines/shadows before measuring motion stability.
		for frame: int in range(12): await RenderingServer.frame_post_draw
		var samples: Array[Color] = []
		for frame: int in range(48):
			camera.position = Vector3(sin(frame*0.21)*0.5,36,24+cos(frame*0.17)*0.5)
			camera.look_at(Vector3.ZERO)
			await RenderingServer.frame_post_draw
			var shot: Image = root.get_texture().get_image()
			var p: Vector2 = camera.unproject_position(Vector3(0.713,0.012,-0.327))
			samples.append(shot.get_pixel(roundi(p.x),roundi(p.y)))
			if frame%2 == 0: check(shot.save_png(folder+"frame-%02d.png"%frame) == OK,"crossing motion frame saved")
		var maximum_delta: float = 0.0
		for color: Color in samples: maximum_delta = maxf(maximum_delta,Vector3(color.r-samples[0].r,color.g-samples[0].g,color.b-samples[0].b).length())
		print("DESERT_CROSSING_PIGMENT_DELTA: ",maximum_delta)
		check(maximum_delta < 0.025,"fixed crossing point retains pigment during camera motion")
	visual.queue_free()
	await process_frame
	print("DESERT_CROSSINGS: ",checks," checks; ",failures," failures; union area=",area," triangles=",triangles.size())
	quit(1 if failures else 0)
