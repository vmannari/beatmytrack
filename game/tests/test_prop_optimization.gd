extends SceneTree
## Original builders are frozen in fixtures; compare actual production meshes.
const OUTPUT: String = "res://../docs/evidence/track-object-optimization-2026-10-16"
const REVIEW_KINDS: Array[String] = ["tree", "broadleaf", "bush", "grass_clump", "flowers", "pebbles", "rock", "boulder", "slate", "cliff", "log", "tyre_stack", "tyre_wall", "barrier", "guardrail", "fence", "wire_fence", "cone", "chevron", "braking_board", "banner", "flag", "light", "gantry", "jump", "speed_bump", "oil", "hay_bale", "crate", "barrel", "pallet", "parked_car", "van", "car_wreck", "container", "shed", "hut", "grandstand", "egypt_pyramid", "egypt_obelisk", "egypt_column", "egypt_column_broken", "egypt_wall", "puddle"]
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var views: Array[Dictionary] = []
var folder: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)

func track_for(kind: String) -> NativeTrack:
	var track := NativeTrack.new()
	track.cells = PackedInt32Array([0,1,2,3,4,5,6,7])
	track.metadata = {"creator_document":{"objects":[{"kind":kind,"position":[0,0],"rotation":0}]}}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	return track

func stats(node: Node) -> Dictionary:
	var result: Dictionary = {"triangles":0,"vertices":0,"bytes":0,"meshes":0}
	if node.is_in_group("contact_lighting"): return result
	var mesh: Mesh
	var instances: int = 1
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D: mesh = node.multimesh.mesh; instances = node.multimesh.instance_count
	if mesh != null and instances > 0:
		result.meshes += 1
		result.bytes += preload("res://editor/cache_bytes.gd").mesh(mesh)
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.vertices += arrays[Mesh.ARRAY_VERTEX].size()*instances
			result.triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3*instances
	for child: Node in node.get_children():
		var sub: Dictionary = stats(child)
		for key: String in result: result[key] += sub[key]
	return result

func primitive_checks() -> void:
	var tool: SurfaceTool = PropGeometry.model(0.00001)
	PropGeometry.box(tool,Vector3.ZERO,Vector3(2,2,2),Color.WHITE,0.1)
	PropGeometry.box(tool,Vector3.ZERO,Vector3(0.2,0.2,0.2),Color.RED,0.02)
	var mesh: ArrayMesh = bake(tool)
	check(elements(mesh) == 180,"enclosed small box is removed, outer bevel retained")
	tool = PropGeometry.model(0.00001)
	PropGeometry.box(tool,Vector3.ZERO,Vector3(2,2,2),Color.WHITE,0.1)
	PropGeometry.face(tool,[Vector3(-2,0,0),Vector3(2,0,0),Vector3(0,2,0)],Color.RED)
	mesh = bake(tool)
	check(elements(mesh) == 183,"crossing triangle is retained even with its centre inside a solid")
	tool = PropGeometry.model()
	PropGeometry.box(tool,Vector3.ZERO,Vector3(2,2,2),Color.WHITE,0.1)
	PropGeometry.face(tool,[Vector3(-0.2,0.97,-0.2),Vector3(0.2,0.97,-0.2),Vector3(0,0.97,0.2)],Color.RED)
	mesh = bake(tool)
	check(elements(mesh) == 183,"near-surface faces retain clearance for the 22 mm outline at half scale")
	tool = PropGeometry.model(0.00001)
	PropGeometry.face(tool,[Vector3.ZERO,Vector3.RIGHT,Vector3.UP],Color.WHITE)
	PropGeometry.face(tool,[Vector3.ZERO,Vector3.ZERO,Vector3.UP],Color.RED)
	mesh = bake(tool)
	check(elements(mesh) == 3,"collapsed triangle removed without removing a real face")
	tool = PropGeometry.model(0.00001)
	PropGeometry.face(tool,[Vector3.ZERO,Vector3.RIGHT*0.000001,Vector3.UP*0.000001],Color.WHITE)
	mesh = bake(tool)
	check(elements(mesh) == 3,"small real detail is retained")

func elements(mesh: ArrayMesh) -> int:
	return mesh.surface_get_array_index_len(0) if mesh.surface_get_array_index_len(0) else mesh.surface_get_array_len(0)

func bake(tool: SurfaceTool) -> ArrayMesh:
	var source: ArrayMesh = PropGeometry.finish(tool)
	tool.set_meta("prop_hidden_triangles",source.get_meta("prop_hidden_triangles"))
	return PropGeometry.commit(tool)

func run() -> void:
	folder = ProjectSettings.globalize_path(OUTPUT+"/"+("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(folder)
	primitive_checks()
	# Freeze the comparison catalog; later assets have no original builder in
	# this task's before fixtures and are reviewed by their own authoring pass.
	var kinds: Array[String] = REVIEW_KINDS.duplicate()
	for biome: String in TrackTheme.IDS:
		for kind: String in kinds:
			var track: NativeTrack = track_for(kind)
			var original: Dictionary = track.metadata.duplicate(true)
			var cells: PackedInt32Array = track.cells.duplicate()
			var old := BeforePropTrackVisual.new(); old.theme_id = biome
			var now := NativeTrackVisual.new(); now.theme_id = biome
			var started: int = Time.get_ticks_usec()
			old._build_placed_objects(track)
			var old_us: int = Time.get_ticks_usec()-started
			started = Time.get_ticks_usec()
			now._build_placed_objects(track)
			var new_us: int = Time.get_ticks_usec()-started
			var a: Dictionary = stats(old); var b: Dictionary = stats(now)
			check(b.triangles > 0 and b.triangles <= a.triangles,biome+"/"+kind+" has no additional triangles")
			check(b.meshes == a.meshes,biome+"/"+kind+" retains original draw grouping")
			check(track.metadata == original and track.cells == cells,biome+"/"+kind+" leaves canonical data exact")
			rows.append({"biome":biome,"kind":kind,"before":a,"after":b,"before_build_us":old_us,"after_build_us":new_us})
			old.free(); now.free()
	if DisplayServer.get_name() != "headless": await captures(kinds)
	var report: Dictionary = {"checks":checks,"failures":failures,"models":rows,"views":views,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PROP_OPTIMIZATION: %d checks, %d failures; %d model/biome combinations" % [checks,failures,rows.size()])
	quit(1 if failures else 0)

func frames() -> void:
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw

func captures(kinds: Array[String]) -> void:
	root.size = Vector2i(1920,1152); root.content_scale_size = root.size
	var stages: Array[Dictionary] = []
	for i: int in range(kinds.size()):
		var viewport := SubViewport.new(); viewport.size = Vector2i(240,192)
		viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_4X
		root.add_child(viewport)
		var image := TextureRect.new(); image.texture = viewport.get_texture()
		image.position = Vector2((i%8)*240,(i/8)*192); image.size = Vector2(240,192); root.add_child(image)
		var label := Label.new(); label.text = CreatorCatalog.label(kinds[i]); image.add_child(label)
		var track: NativeTrack = track_for(kinds[i])
		var old := BeforePropTrackVisual.new(); viewport.add_child(old); old._build_placed_objects(track)
		var now := NativeTrackVisual.new(); viewport.add_child(now); now._build_placed_objects(track); now.visible = false
		var bounds: AABB = ObjectThumbnail._mesh_bounds(old)
		var center: Vector3 = bounds.get_center()
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-38,0); light.shadow_enabled = true; viewport.add_child(light)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("34424a")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("b6c5d0"); environment.environment.ambient_light_energy = 0.55; viewport.add_child(environment)
		var camera := Camera3D.new(); viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.length()*1.12,0.5)
		camera.current = true
		stages.append({"viewport":viewport,"before":old,"after":now,"camera":camera,"center":center,"distance":maxf(8,bounds.size.length()*2),"kind":kinds[i]})
	# Warm both instances, then observe the original again. Mobile can finish
	# its first material/shadow preparation after the initial submitted draw.
	for stage: Dictionary in stages:
		stage.camera.look_at_from_position(stage.center+Vector3(1,0.8,0)*stage.distance,stage.center)
	await frames()
	var cold_originals: Array[PackedByteArray] = []
	for stage: Dictionary in stages: cold_originals.append(stage.viewport.get_texture().get_image().get_data())
	root.get_texture().get_image().save_png(folder.path_join("warmup-original-first.png"))
	for stage: Dictionary in stages: stage.before.visible = false; stage.after.visible = true
	await frames()
	for stage: Dictionary in stages: stage.before.visible = true; stage.after.visible = false
	await frames()
	root.get_texture().get_image().save_png(folder.path_join("warmup-original-return.png"))
	for i: int in range(stages.size()):
		views.append({"kind":stages[i].kind,"original_warmup_changed":cold_originals[i] != stages[i].viewport.get_texture().get_image().get_data()})
	for angle: int in range(10):
		var yaw: float = angle*PI*0.5
		var elevation: float = 0.8 if angle < 4 else 0.16 if angle < 6 else -0.65
		if angle == 8: elevation = 5.0; yaw = 0.37
		if angle == 9: elevation = 0.7; yaw = 0.71
		for stage: Dictionary in stages:
			stage.camera.look_at_from_position(stage.center+Vector3(cos(yaw),elevation,sin(yaw))*stage.distance,stage.center)
			stage.before.visible = true; stage.after.visible = false
		await frames()
		var originals: Array[PackedByteArray] = []
		for stage: Dictionary in stages: originals.append(stage.viewport.get_texture().get_image().get_data())
		root.get_texture().get_image().save_png(folder.path_join("before-%d.png"%angle))
		for stage: Dictionary in stages: stage.before.visible = false; stage.after.visible = true
		await frames()
		root.get_texture().get_image().save_png(folder.path_join("after-%d.png"%angle))
		for i: int in range(stages.size()):
			var pixels: Image = stages[i].viewport.get_texture().get_image()
			var exact: bool = originals[i] == pixels.get_data()
			views.append({"kind":stages[i].kind,"angle":angle,"exact":exact})
			check(exact,"native pixels retained: %s angle %d"%[stages[i].kind,angle])
			if not exact:
				var before_image := Image.create_from_data(240,192,false,pixels.get_format(),originals[i])
				before_image.save_png(folder.path_join("difference-%s-%d-before.png"%[stages[i].kind,angle]))
				pixels.save_png(folder.path_join("difference-%s-%d-after.png"%[stages[i].kind,angle]))
	for stage: Dictionary in stages: stage.viewport.queue_free()
	await frames()
