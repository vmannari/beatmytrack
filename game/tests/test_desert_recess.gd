extends SceneTree
const OUT: String = "res://../docs/evidence/desert-recess-2026-10-16/"
var checks: int = 0
var failures: int = 0
var before: bool = false
var report: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func circuit(theme: String) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = theme
	var point := Vector2(-32,-16); var heading: float = 0.0
	for kind: String in ["straight","bridge","straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,point,heading,10)
		piece.length = 32.0 if kind == "bridge" else 64.0 if doc.pieces.size() == 4 else 16.0 if kind == "straight" else 0.0
		piece.radius = 16.0; doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); point = pose.position; heading = pose.heading
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	check(result.ok,theme+" circuit routes")
	return TrackCompiler.compile(result.document)

func hash_value(value: Variant) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(value)); return hash.finish().hex_encode()

func inspect(node: Node, meshes: Array, materials: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var arrays: Array = []
		for i: int in range(node.mesh.get_surface_count()): arrays.append(node.mesh.surface_get_arrays(i))
		meshes.append(hash_value([node.transform,arrays]))
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material != null: materials.append(material.shader.code.sha256_text())
	for child: Node in node.get_children(): inspect(child,meshes,materials)

func run() -> void:
	before = "--before" in OS.get_cmdline_user_args(); root.size = Vector2i(1440,810)
	var original: Dictionary = {} if before else JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-headless.json"))
	for theme: String in ["desert","pine","storm","winter","night_city"]:
		var track: NativeTrack = circuit(theme)
		var canonical: String = hash_value([track.cells,track.deck_cells,track.route,track.metadata])
		var heights := BridgePresentation.new(track)
		var world := NativeTrackVisual.new(); world.cache_road_meshes = false; world.persist_road_meshes = false; world.cache_race_world = false; world.partition_static_meshes = false
		root.add_child(world); await world.build(track,heights)
		var meshes: Array = []; var materials: Array = []; inspect(world,meshes,materials)
		report[theme] = {"canonical":canonical,"meshes":meshes,"materials":materials}
		check(canonical == hash_value([track.cells,track.deck_cells,track.route,track.metadata]),theme+" scenery leaves canonical data intact")
		if not before:
			check(canonical == original[theme].canonical,theme+" original track data remains exact")
			check(materials == original[theme].materials,theme+" actual material/shader roles remain exact")
			if theme != "desert": check(meshes == original[theme].meshes,theme+" every mesh stays byte exact")
			else: await desert_checks(world,track,heights)
		if theme == "desert" and DisplayServer.get_name() != "headless": await capture(world,track,heights)
		world.queue_free(); await process_frame
	var renderer: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(OUT+("before-" if before else "final-")+renderer+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report if before else {"checks":checks,"failures":failures,"themes":report},"\t"))
	print("DESERT_RECESS: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)

func desert_checks(world: NativeTrackVisual, track: NativeTrack, bridge: BridgePresentation) -> void:
	check(bridge.has_method("visual_height_at"),"cosmetic elevation is separate from canonical elevation")
	if not bridge.has_method("visual_height_at"): return
	var road := Vector2(27,-16); var outside := Vector2(27,-27)
	check(absf(bridge.visual_height_at(road,0,0)+0.18) < 0.0001,"road presentation is lowered by eighteen centimetres")
	check(bridge.height_at(road,0,0) == 0.0,"canonical road support remains unchanged")
	check(absf(bridge.visual_height_at(outside,0,0)) < 0.0001,"distant terrain keeps its original level")
	var pure := BridgeElevation.new(track)
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var ordinary := VehicleSimulation.new(config); var presented := VehicleSimulation.new(config)
		ordinary.reset(road,PI*0.5); presented.reset(road,PI*0.5)
		ordinary.prepare_ground(track,pure); presented.prepare_ground(track,bridge)
		for tick: int in range(240):
			var frame: DriveFrame = DriveFrame.sample(sin(tick*0.023)*0.2,0.6,0)
			ordinary.step(frame,track); presented.step(frame,track)
		check(ordinary.state.snapshot() == presented.state.snapshot(),id+" full canonical trace remains exact with visual relief attached")
	var top: float = -INF
	for child: Node in world.get_children():
		if not child is MeshInstance3D or child.mesh == null or not child.material_override is ShaderMaterial: continue
		var material: ShaderMaterial = child.material_override
		if material.get_shader_parameter("asphalt_surface") != true or material.get_shader_parameter("edge_fringe") == true: continue
		var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p: Vector3 in vertices:
			if absf(p.x-27) < 8 and absf(p.z-16) < 4: top = maxf(top,p.y)
	check(absf(top+0.168) < 0.0001,"actual road mesh sits about eleven centimetres below surrounding terrain")
	var plane := PlaneMesh.new(); plane.size = Vector2(20,20)
	var original: Array = plane.surface_get_arrays(0)
	var original_points: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var original_uv: PackedVector2Array = original[Mesh.ARRAY_TEX_UV]
	var origin: Vector3 = original_points[0]
	var first: int = 1; var second: int = 2
	var u := Vector2(original_points[first].x-origin.x,original_points[first].z-origin.z)
	var v := Vector2(original_points[second].x-origin.x,original_points[second].z-origin.z)
	var determinant: float = u.cross(v)
	check(absf(determinant) > 0.1,"native terrain fixture has a valid material projection")
	var warped: ArrayMesh = bridge.visual_relief.deform(plane,Transform3D(Basis.IDENTITY,Vector3(road.x,-0.06,-road.y)),true)
	var arrays: Array = warped.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var coverage_exact: bool = true; var floor_found: bool = false
	for i: int in range(points.size()):
		var relative := Vector2(points[i].x-origin.x,points[i].z-origin.z)
		var a: float = relative.cross(v)/determinant; var b: float = u.cross(relative)/determinant
		var expected: Vector2 = original_uv[0]+(original_uv[first]-original_uv[0])*a+(original_uv[second]-original_uv[0])*b
		coverage_exact = coverage_exact and uv[i].distance_to(expected) < 0.000001
		if Vector2(points[i].x,points[i].z).length() < 0.001: floor_found = absf(points[i].y+0.18) < 0.0001
	check(coverage_exact,"refined terrain keeps the original world-space material UV projection")
	check(floor_found,"large terrain triangles are depressed through their interior without a flat lid")
	check(bridge.visual_relief.field.size()*4 <= 8*1024*1024,"cosmetic field stays inside its explicit memory bound")
	var instances := MultiMeshInstance3D.new(); instances.multimesh = MultiMesh.new(); instances.visible = false
	var source_batch: MultiMesh = instances.multimesh
	source_batch.transform_format = MultiMesh.TRANSFORM_3D; source_batch.use_colors = true; source_batch.use_custom_data = true
	source_batch.mesh = BoxMesh.new(); source_batch.instance_count = 2
	source_batch.set_instance_transform(0,Transform3D(Basis.IDENTITY,VisualGeometry.world(road)))
	source_batch.set_instance_transform(1,Transform3D(Basis.IDENTITY,VisualGeometry.world(outside)))
	source_batch.set_instance_color(0,Color(0.25,0.5,0.75,1)); source_batch.set_instance_custom_data(0,Color(0.1,0.2,0.3,0.4))
	world.add_child(instances); await bridge.visual_relief.apply(instances)
	check(instances.multimesh != source_batch and instances.multimesh.instance_count == 2,"scenery owns an independent correctly sized instance buffer")
	check(instances.multimesh.custom_aabb == AABB(),"moving instances retain automatic culling bounds")
	if DisplayServer.get_name() != "headless":
		check(instances.multimesh.get_instance_color(0).is_equal_approx(source_batch.get_instance_color(0)) and instances.multimesh.get_instance_custom_data(0).is_equal_approx(source_batch.get_instance_custom_data(0)),"native instance colours and custom payloads remain exact")
		check(absf(instances.multimesh.get_instance_transform(0).origin.y+0.18) < 0.0001 and instances.multimesh.get_instance_transform(1).origin.y == 0.0,"native scenery seats on recessed and unchanged ground")
	var first_mesh: MultiMesh = instances.multimesh; await bridge.visual_relief.apply(instances)
	check(instances.multimesh == first_mesh,"reapplying relief cannot lower scenery twice")
	var tyre_owner := NativeTrackVisual.new(); tyre_owner.desert_relief = bridge.visual_relief; tyre_owner.ground_support = bridge.road_surface
	tyre_owner.tyre_instances = instances
	var tyre_state := VehicleState.new(); tyre_state.loose_tyres = [[road.x,road.y,0.0,0.0,0.4],[outside.x,outside.y,0.0,0.0,0.0]]
	tyre_owner.update_tyres(tyre_state,PackedVector2Array([road,outside]))
	if DisplayServer.get_name() != "headless": check(absf(instances.multimesh.get_instance_transform(0).origin.y+0.166) < 0.0001 and absf(instances.multimesh.get_instance_transform(1).origin.y-0.014) < 0.0001,"moving tyre presenter retains exact visual ground support")
	tyre_owner.free()
	instances.queue_free()
	var editor := NativeTrackVisual.new(); editor.editor_preview = true; editor.world_built = true; editor.theme_id = "desert"; editor.colors = TrackTheme.palette("desert")
	editor.ground_support = bridge.road_surface; editor.desert_relief = bridge.visual_relief; editor.hide(); root.add_child(editor)
	var doc: Dictionary = track.metadata.creator_document.duplicate(true)
	doc.objects = [{"kind":"tyre_stack","position":[road.x,road.y],"rotation":0.0},{"kind":"tyre_stack","position":[outside.x,outside.y],"rotation":0.0}]
	var edited: NativeTrack = TrackCompiler.compile(doc); await editor.refresh_editor_objects(edited,false)
	var retained: Array = []
	for group: Dictionary in editor.editor_objects._editor_authored_batches.groups.values():
		for node: Node3D in group.nodes:
			if node is MultiMeshInstance3D: retained.append(node.get_instance_id())
	doc.objects[0].position[0] += 0.5; edited = TrackCompiler.compile(doc); await editor.refresh_editor_objects(edited,false)
	var current_nodes: Array = []; var seated: bool = true
	for group: Dictionary in editor.editor_objects._editor_authored_batches.groups.values():
		for node: Node3D in group.nodes:
			if not node is MultiMeshInstance3D: continue
			current_nodes.append(node.get_instance_id())
			if DisplayServer.get_name() == "headless": continue
			for i: int in range(group.poses.size()):
				var pose: Transform3D = group.poses[i]; pose.origin.y += bridge.visual_offset(Vector2(pose.origin.x,-pose.origin.z))
				seated = seated and node.multimesh.get_instance_transform(i).is_equal_approx(pose)
	check(current_nodes == retained,"editor movement retains its existing native instance groups")
	check(seated,"changed and unchanged editor instances remain seated without accumulating relief")
	editor.queue_free()
	for span: Dictionary in track.creator_bridges:
		for along: float in [0.0,1.0,float(span.length)*0.5,float(span.length)-1.0,float(span.length)]:
			var p: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(along,0).rotated(deg_to_rad(span.heading))
			check(absf(bridge.visual_height_at(p,0,1)-pure.height_at(p,0,1)-bridge.visual_offset(p)) < 0.000001,"bridge visual support matches its recessed mesh while canonical flight stays original")

func capture(world: Node3D, track: NativeTrack, bridge: BridgePresentation) -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = TrackTheme.DESERT_SUN_ROTATION; sun.shadow_enabled = true; world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("aab8b8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("d9e4eb"); env.environment.ambient_light_energy = 0.7; world.add_child(env)
	var car := CarVisual.new(); world.add_child(car); var state := VehicleState.new(); state.position = Vector2(27,-16); state.heading = PI*0.5
	car.present(state.position,state.heading,state,DriveFrame.new())
	car.position.y = bridge.visual_height_at(state.position,0,0) if bridge.has_method("visual_height_at") else bridge.height_at(state.position,0,0)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.current = true; world.add_child(camera)
	var folder: String = OUT+("before/" if before else "final/")+RenderingServer.get_current_rendering_method()+"/"; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for view: String in ["corner","edge","bridge"]:
		var target := Vector3(33,0,10) if view == "corner" else Vector3(27,0,22) if view == "edge" else Vector3(-16,0,16)
		camera.size = 30.0 if view == "corner" else 6.0 if view == "edge" else 18.0
		camera.position = target+Vector3(-3,25,21) if view != "edge" else target+Vector3(-1,1.7,3); camera.look_at(target)
		for frame: int in range(24): await process_frame
		await RenderingServer.frame_post_draw; check(root.get_texture().get_image().save_png(folder+view+".png") == OK,"actual "+view+" capture saved")
