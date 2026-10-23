extends SceneTree
## Shared shipping architecture, real openings and native views.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/winter-architecture-2026-10-18/after"
var metrics: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func model(kind: String) -> ArrayMesh:
	var kit := NativeTrackVisual.new(); kit.theme_id = "winter"
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1.0,0.0)
	kit.free()
	return tool.commit()

func blocked(mesh: ArrayMesh, origin: Vector3, direction: Vector3) -> bool:
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i: int in range(0,v.size(),3):
		if Geometry3D.segment_intersects_triangle(origin,origin+direction,v[i],v[i+1],v[i+2]) != null: return true
	return false

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-to="): output = arg.trim_prefix("--capture-to=")
	for kind: String in ["igloo","snow_castle"]:
		var mesh: ArrayMesh = model(kind)
		var data: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var valid: bool = normals.size() == vertices.size()
		var collapsed: int = 0
		var reversed_faces: int = 0
		for i: int in range(vertices.size()): valid = valid and vertices[i].is_finite() and normals[i].is_finite() and normals[i].length() > 0.9
		for i: int in range(0,vertices.size(),3):
			if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared() < 1e-16: collapsed += 1
			if -(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).dot(normals[i]+normals[i+1]+normals[i+2]) < -0.000001:
				reversed_faces += 1
				if reversed_faces <= 4: print("REVERSED: ",kind," ",(vertices[i]+vertices[i+1]+vertices[i+2])/3.0," ",normals[i]," ",normals[i+1]," ",normals[i+2])
		check(valid and collapsed == 0,kind+" finite unit normals and no collapsed faces")
		check(reversed_faces == 0,kind+" every rendered triangle agrees with its outward shading normal")
		check(vertices.size()/3 < 10000,kind+" retains the existing ten-thousand triangle ceiling")
		var bounds: AABB = mesh.get_aabb(); var footprint: Vector2 = CreatorObjects.dimensions(kind)
		check(bounds.position.x >= -footprint.x*0.5 and bounds.end.x <= footprint.x*0.5 and bounds.position.z >= -footprint.y*0.5 and bounds.end.z <= footprint.y*0.5,kind+" fits the existing selection footprint")
		check(model(kind).surface_get_arrays(0) == data,kind+" repeated cached construction is exact")
		if kind == "snow_castle":
			check(not blocked(mesh,Vector3(0,0.8,-4),Vector3(0,0,4)),"castle gate opens into the actual court")
			check(blocked(mesh,Vector3(1.6,0.8,-4),Vector3(0,0,4)),"castle wall remains solid beside its gate")
			check(blocked(mesh,Vector3(0,3,-4),Vector3(0,0,4)),"castle gate has a solid sculpted arch crown")
		else:
			check(not blocked(mesh,Vector3(0,0.6,-4.3),Vector3(0,0,4.3)),"igloo entrance leads into the real dome interior")
			check(blocked(mesh,Vector3(0.97,0.6,-4.3),Vector3(0,0,2)),"igloo tunnel has real thick sidewalls")
			check(blocked(mesh,Vector3(0,2,-4.3),Vector3(0,0,4.3)),"igloo retains a continuous roof above the opening")
			for x: float in [-2.5,-1.5,-0.5,0.5,1.5,2.5]:
				for z: float in [-1.5,-0.5,0.5,1.5]:
					check(blocked(mesh,Vector3(x,5,z),Vector3(0,-5,0)),"igloo shell has no daylight hole at "+str(Vector2(x,z)))
		metrics.append({"kind":kind,"triangles":vertices.size()/3,"bounds":str(bounds)})
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/winter-architecture-2026-10-18/before/prop_winter_craft.gd.txt").replace("\r\n","\n").replace("class_name PropWinterCraft\n","")
	check(old.reload() == OK,"saved original Winter builder loads")
	for kind: String in ["snowman","snow_lantern","ice_lantern"]:
		var a := SurfaceTool.new(); a.begin(Mesh.PRIMITIVE_TRIANGLES)
		var b := SurfaceTool.new(); b.begin(Mesh.PRIMITIVE_TRIANGLES)
		old.append(a,kind,Vector3.ZERO,1.0,0.0); PropWinterCraft.append(b,kind,Vector3.ZERO,1.0,0.0)
		check(a.commit_to_arrays() == b.commit_to_arrays(),kind+" preserves every original mesh channel")
	check(CreatorPropVisual.cache_bytes <= CreatorPropVisual.CACHE_BUDGET,"shared prop cache retains its existing budget")
	check(CreatorPropVisual.VERSION != "authored-props-12-biome-winter","finished-world and thumbnail caches fence the revised models")
	if DisplayServer.get_name() != "headless": await captures()
	print("WINTER_ARCHITECTURE_METRICS: ",JSON.stringify(metrics))
	print("WINTER_ARCHITECTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func frames() -> void:
	for i: int in range(5): await process_frame
	await RenderingServer.frame_post_draw

func captures() -> void:
	var folder: String = ProjectSettings.globalize_path(output+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	for kind: String in ["igloo","snow_castle"]:
		var host := Button.new(); root.add_child(host)
		var view: SubViewport = ObjectThumbnail._render_preview(host,kind,"winter")
		view.size = Vector2i(1400,1000); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var camera: Camera3D = view.get_camera_3d()
		camera.size = 8.4 if kind == "snow_castle" else 8.0
		await frames()
		check(view.get_texture().get_image().save_png(folder+"/"+kind+"-studio.png") == OK,kind+" native studio capture")
		camera.look_at_from_position(Vector3(0,3.4,-13),Vector3(0,1.25,0))
		await frames()
		check(view.get_texture().get_image().save_png(folder+"/"+kind+"-front.png") == OK,kind+" native entrance capture")
		camera.look_at_from_position(Vector3(-8,9,10),Vector3(0,1.25,0))
		await frames()
		check(view.get_texture().get_image().save_png(folder+"/"+kind+"-rear.png") == OK,kind+" native rear and court capture")
		host.queue_free(); await process_frame
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "winter"; doc.automatic_scenery = false
	doc.objects = [{"kind":"igloo","position":[-5,0],"rotation":0},{"kind":"snow_castle","position":[5,0],"rotation":0}]
	var track := NativeTrack.new(); track.metadata = {"creator_document":doc}
	var scene := Node3D.new(); root.add_child(scene)
	var visual := NativeTrackVisual.new(); scene.add_child(visual); visual.theme_id = "winter"; visual._build_placed_objects(track)
	VisualGeometry.box(scene,Vector3(40,0.1,30),Vector3(0,-0.08,0),VisualGeometry.material(Color("c0cdd3")))
	var env := WorldEnvironment.new(); env.environment = Environment.new(); scene.add_child(env)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var sun := DirectionalLight3D.new(); scene.add_child(sun); TrackTheme.apply_lighting("winter",env.environment,sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 18; scene.add_child(camera)
	camera.look_at_from_position(Vector3(8,16,-19),Vector3(0,0.5,0)); camera.current = true
	root.size = Vector2i(1600,1000); root.content_scale_size = root.size
	await frames()
	check(root.get_texture().get_image().save_png(folder+"/placed-overhead.png") == OK,"actual shipping placed-model overhead capture")
	scene.queue_free(); await process_frame
	await editor_capture(folder)

func editor_capture(folder: String) -> void:
	var app: Node = load("res://core/app.gd").new()
	var directory: String = "user://winter_architecture_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json")); root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+30000
	while not app.get("startup_complete") and Time.get_ticks_msec() < deadline: await process_frame
	check(app.get("startup_complete"),"real editor completes covered startup")
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "winter"
	doc.objects = [{"kind":"igloo","position":[-9,0],"rotation":0},{"kind":"snow_castle","position":[3,0],"rotation":0}]
	app.set("document",doc); app.call("_show_screen","create")
	deadline = Time.get_ticks_msec()+40000
	while Time.get_ticks_msec() < deadline:
		var canvas: EditorCanvas = app.get("canvas")
		if canvas != null and canvas.native_preview != null and not app.get("editor_world")._building and app.get("editor_preview_thread") == null: break
		await process_frame
	check(app.get("canvas") != null and app.get("canvas").native_preview != null,"real Winter editor prepares the refined saved models")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser = app.get("object_browser"); browser.category = "Buildings"; browser.page = 0; browser.refresh()
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	for tick: int in range(35): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/editor-buildings.png") == OK,"real Winter editor and original building thumbnails captured")
	var canvas: EditorCanvas = app.get("canvas")
	check(canvas.document.objects == doc.objects,"opening the revised presentation preserves saved placements")
	app.queue_free()
	for tick: int in range(5): await process_frame
