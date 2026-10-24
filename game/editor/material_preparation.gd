extends RefCounted
## Real mesh/material combinations, with the receiving viewport's MSAA.
## Mobile sees mesh/surface pipelines; Compatibility actually draws them.

static func fixture(cancelled: Callable, theme: String) -> NativeTrack:
	if cancelled.call(): return null
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = theme
	var curve: Dictionary = RoadPieces.create("curve",Vector2(-12,0),0.0,8.0)
	curve.radius = 12.0
	doc.pieces = [curve,RoadPieces.create("straight",Vector2(-12,-16),0.0,8.0),RoadPieces.create("bridge",Vector2(-12,16),0.0,8.0)]
	return TrackCompiler.compile(doc)

static func warm(owner: Node, receiving: SubViewport, theme: String) -> int:
	if DisplayServer.get_name() == "headless": return 0
	var job = preload("res://editor/work_job.gd").start(fixture.bind(theme),owner.get_tree())
	while not job.done:
		await owner.get_tree().process_frame
		if not owner.is_inside_tree(): job.cancel(); return 0
	var track: NativeTrack = job.result
	if track == null: return 0
	var source := NativeTrackVisual.new()
	source.editor_preview = true; source.theme_id = theme; source.colors = TrackTheme.palette(theme)
	source.cache_road_meshes = false; source.persist_road_meshes = false
	source._menu_slices = true; source.visible = false
	owner.add_child(source)
	await source._build_terrain(track)
	if not owner.is_inside_tree(): return 0
	await source._build_creator_roads(track)
	if not owner.is_inside_tree(): return 0
	BridgePresentation.new(track).build(source)
	var count: int = await draw(owner,receiving,source)
	if is_instance_valid(source): source.free()
	return count

static func draw(owner: Node, receiving: SubViewport, source: Node) -> int:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.own_world_3d = true
	viewport.msaa_3d = receiving.msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	owner.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_energy = 0.5
	if owner is EditorWorld: ambient.environment = owner.environment.duplicate()
	stage.add_child(ambient)
	var sun: DirectionalLight3D = owner.sunlight.duplicate() if owner is EditorWorld else DirectionalLight3D.new()
	if not owner is EditorWorld: sun.rotation_degrees = Vector3(-58,-35,0); sun.shadow_enabled = true
	stage.add_child(sun)
	# Match the editor light rig. An unconditional omni previously compiled
	# unused point-light variants even in daylight biomes.
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0; camera.position = Vector3(0,32,0); camera.rotation.x = -PI/2.0
	stage.add_child(camera); camera.current = true
	var seen: Dictionary = {}
	var count: int = 0
	var submissions: Array[Node] = []
	var batch_times: Array[float] = []
	for node: Node in source.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
		if mesh == null: continue
		var material: Material = node.material_override
		if material == null: material = mesh.surface_get_material(0)
		var shader_identity: Variant = material.call("get_shader_rid") if material != null and material.has_method("get_shader_rid") else material
		var next_pass: Material = material.next_pass if material != null else null
		var pass_identity: Variant = next_pass.call("get_shader_rid") if next_pass != null and next_pass.has_method("get_shader_rid") else next_pass
		var signature: Array = [shader_identity,pass_identity,mesh.surface_get_format(0) if mesh is ArrayMesh else mesh.get_class(),node is MultiMeshInstance3D,node.cast_shadow]
		if seen.has(signature): continue
		seen[signature] = true
		var aabb: AABB = mesh.get_aabb()
		var scale: float = 2.5/maxf(0.01,maxf(aabb.size.x,maxf(aabb.size.y,aabb.size.z)))
		var item: GeometryInstance3D
		if node is MultiMeshInstance3D:
			var batch := MultiMeshInstance3D.new(); batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D; batch.multimesh.mesh = mesh
			batch.multimesh.instance_count = 1; batch.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
			item = batch
		else:
			var single := MeshInstance3D.new(); single.mesh = mesh; item = single
		item.material_override = material; item.cast_shadow = node.cast_shadow
		item.scale = Vector3.ONE*scale
		item.position = Vector3((count%8)*3.5-12.25,0,(count/8)*3.5-12.25)-aabb.get_center()*scale
		stage.add_child(item); submissions.append(item); count += 1
		if submissions.size() >= 4:
			var started: int = Time.get_ticks_usec()
			if not await _draw_batch(owner,viewport): return 0
			batch_times.append((Time.get_ticks_usec()-started)/1000.0)
			for submitted: Node in submissions: submitted.free()
			submissions.clear()
		if count >= 64: break
	if not submissions.is_empty():
		var started: int = Time.get_ticks_usec()
		if not await _draw_batch(owner,viewport): return 0
		batch_times.append((Time.get_ticks_usec()-started)/1000.0)
	if owner is EditorWorld:
		owner.preparation_metrics["pipeline_batches_ms"] = batch_times
		owner.preparation_metrics["pipeline_combinations"] = count
	viewport.free()
	return count

static func _draw_batch(owner: Node, viewport: SubViewport) -> bool:
	# Four combinations per submission instead of up to 64 cold pipelines at
	# once. Driver compilation of a single pipeline is separately measurable.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame: int in range(2):
		await RenderingServer.frame_post_draw
		if not owner.is_inside_tree(): return false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return true
