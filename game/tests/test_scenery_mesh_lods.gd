extends "res://tests/review_track_asset_simplification_2026_11_07.gd"
## TSO01-TSO04: production batches, exact masters, cache fences and native views.
const POLICY = preload("res://track/scenery_mesh_lods.gd")
const WORLDS = preload("res://track/prepared_world_cache.gd")
const BYTES = preload("res://editor/cache_bytes.gd")

func make(theme: String, objects: Array, reduced: bool, editor: bool = false) -> NativeTrackVisual:
	var visual := NativeTrackVisual.new(); visual.theme_id = theme; visual.colors = TrackTheme.palette(theme)
	visual.scenery_lods = reduced; visual.editor_preview = editor; visual._suppress_night_fx = true
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects.duplicate(true)},"scenery_objects":[],"theme":theme}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	var original: Dictionary = track.metadata.duplicate(true)
	await visual._build_placed_objects(track)
	check(track.metadata == original,"canonical placements, dimensions and cosmetic data remain exact")
	return visual

func objects(kind: String, scale: float = 1.0, count: int = 1) -> Array:
	var result: Array = []
	for index: int in range(count):
		var object: Dictionary = {"kind":kind,"position":[(index%3-1)*80.0 if count>1 else 0.0,(index/3)*80.0 if count>1 else 0.0],"rotation":37.0 if scale != 1.0 else 0.0,"scale":scale}
		if kind == "container" and scale != 1.0: object.color = "c54a38"
		result.append(object)
	return result

func meshes(visual: Node) -> Array:
	var parts: Array = []; collect(visual,parts); return parts

func triangles(mesh: Mesh, reduced: bool = false) -> int:
	var model: Mesh = first_lod(mesh) if reduced else mesh
	var arrays: Array = model.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3

func triangle_set(parts: Array, reduced: bool) -> Array[String]:
	var result: Array[String] = []
	for part: Dictionary in parts:
		var mesh: Mesh = first_lod(part.mesh) if reduced else part.mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for start: int in range(0,indices.size(),3):
			var values: Array = []
			for corner: int in range(3):
				var index: int = indices[start+corner]
				for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]: values.append(arrays[attribute][index])
			result.append(var_to_bytes(values).hex_encode())
	result.sort(); return result

func structural() -> void:
	for theme: String in TrackTheme.IDS:
		for kind: String in POLICY.KINDS:
			for scale: float in [0.5,1.0,2.0]:
				var before: NativeTrackVisual = await make(theme,objects(kind,scale),false)
				var after: NativeTrackVisual = await make(theme,objects(kind,scale),true)
				var a: Array = meshes(before); var b: Array = meshes(after)
				check(a.size()==b.size(),"original draw grouping retained")
				for index: int in range(a.size()):
					var old: Dictionary = a[index].mesh.get("_surfaces")[0].duplicate(true)
					var now: Dictionary = b[index].mesh.get("_surfaces")[0].duplicate(true)
					now.erase("lods")
					check(old==now,"full-detail GPU positions/normals/colours/indices remain byte-exact")
					check(b[index].mesh.has_meta("scenery_lod_bytes"),theme+"/"+kind+" source signature accepts saved paint and scale")
					check(triangles(b[index].mesh,true)<triangles(a[index].mesh)*0.52,"approved lower level survives joined assembly")
					check(BYTES.mesh(b[index].mesh)>BYTES.mesh(a[index].mesh),"additional LOD memory is accounted within existing budgets")
				before.free(); after.free()
	for kind: String in ["igloo","egypt_pyramid","grandstand","abandoned_warehouse","crate"]:
		var visual: NativeTrackVisual = await make("pine",objects(kind),true)
		for part: Dictionary in meshes(visual): check(not part.mesh.has_meta("scenery_lod_bytes"),"unapproved "+kind+" retains its original geometry")
		visual.free()
	for kind: String in POLICY.KINDS:
		var visual: NativeTrackVisual = await make("pine",objects(kind),true,true)
		for part: Dictionary in meshes(visual): check(not part.mesh.has_meta("scenery_lod_bytes"),"editor retains full detail")
		visual.free()
		CreatorPropVisual.trim_cache()
		check(CreatorPropVisual.publish_warm(CreatorPropVisual.warm(Callable(),kind,"pine")),"worker-prepared source publishes")
		visual = await make("pine",objects(kind),true)
		check(meshes(visual)[0].mesh.has_meta("scenery_lod_bytes"),"warm source retains approved reduction")
		visual.free()
	var wrong := ArrayMesh.new(); var sphere := SphereMesh.new(); wrong.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sphere.surface_get_arrays(0))
	POLICY.prepare_source(wrong,"container")
	check(not wrong.has_meta("scenery_lod_plan"),"changed/mismatched geometry fails closed to full detail")
	for kind: String in POLICY.KINDS:
		var visual: NativeTrackVisual = await make("winter" if kind != "container" else "pine",objects(kind,1.0,6),true)
		var original: Array = meshes(visual)
		var full: Array[String] = triangle_set(original,false)
		var low: Array[String] = triangle_set(original,true)
		await visual._partition_bank_meshes()
		var parts: Array = []
		for node: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			if node.has_meta("spatial_mesh_tile"): parts.append({"node":node,"mesh":node.mesh,"instances":1})
		check(parts.size()>original.size(),kind+" spatial batching remains active, including adaptive hidden draw views")
		check(triangle_set(parts,false)==full,"spatial worker preserves every master triangle and attribute")
		check(triangle_set(parts,true)==low,"spatial worker preserves every reduced triangle exactly once")
		WORLDS.trim_cache()
		var track := NativeTrack.new(); track.metadata = {"theme":visual.theme_id}
		WORLDS.remember([kind,"lod-test"],visual,track)
		var restored := NativeTrackVisual.new()
		check(WORLDS.restore([kind,"lod-test"],restored),"prepared world remains inside its unchanged byte budget")
		check(triangle_set(meshes(restored),true)==low,"prepared world restoration retains reduced index buffers")
		restored.free(); visual.free(); WORLDS.trim_cache()
	var mixed: Array = objects("container",0.5,3)+objects("snow_castle",1.0,3)+objects("ice_compact",2.0,3)+objects("igloo",1.0,3)
	for index: int in range(mixed.size()): mixed[index].position = [float((index%4)*40-60),float((index/4)*40-40)]
	var mixed_visual: NativeTrackVisual = await make("winter",mixed,true)
	var mixed_full: Array[String] = triangle_set(meshes(mixed_visual),false)
	var mixed_low: Array[String] = triangle_set(meshes(mixed_visual),true)
	await mixed_visual._partition_bank_meshes()
	var mixed_parts: Array = []
	for node: MeshInstance3D in mixed_visual.find_children("*","MeshInstance3D",true,false):
		if node.has_meta("spatial_mesh_tile"): mixed_parts.append({"node":node,"mesh":node.mesh,"instances":1})
	check(triangle_set(mixed_parts,false)==mixed_full,"mixed-scale and protected props retain every master triangle through splitting")
	check(triangle_set(mixed_parts,true)==mixed_low,"mixed families retain protected full geometry and all approved reduced triangles")
	mixed_visual.free()
	for theme: String in ["pine","winter","night_city"]:
		var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
		track.metadata.theme = theme
		track.metadata.scenery_objects = []
		for index: int in range(POLICY.KINDS.size()): track.metadata.scenery_objects.append({"kind":POLICY.KINDS[index],"position":[float(index*20-20),-55.0],"rotation":0.0})
		var game: Node = load("res://core/game.tscn").instantiate()
		game.vehicle_id = "compact"; game.initial_track = track; game.production_mode = true; game.attempt_practice = true; game.hitch_diagnostics_enabled = false
		root.add_child(game); game.paused = true; game.set_physics_process(false)
		while game.car == null or not game.car.model_ready: await process_frame
		var count: int = 0
		for part: Dictionary in meshes(game.track_ground):
			if part.mesh.has_meta("scenery_lod_bytes"): count += 1
		check(count>=2,"actual Game "+theme+" installs both optimized material families")
		var state: Array = game.sim.state.snapshot(); game.call("_process",0.0)
		check(game.sim.state.snapshot()==state and game.track_session.target_laps==RaceRules.LAPS,"actual Game retains canonical state and lap contract")
		game.free(); await process_frame

func native() -> void:
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewport := SubViewport.new(); viewport.size = root.size; viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.mesh_lod_threshold = 1.0; viewport.msaa_3d = Viewport.MSAA_4X; root.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect = Camera3D.KEEP_HEIGHT; camera.current = true; stage.add_child(camera)
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; stage.add_child(light)
	var world := WorldEnvironment.new(); world.environment = Environment.new(); world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; stage.add_child(world)
	var plane := PlaneMesh.new(); plane.size = Vector2(200,200)
	var floor := MeshInstance3D.new(); floor.mesh = plane; floor.position.y = -0.035; stage.add_child(floor)
	for kind: String in POLICY.KINDS:
		for theme: String in ["pine","winter","night_city"]:
			TrackTheme.apply_lighting(theme,world.environment,light)
			if theme == "night_city": world.environment.ambient_light_energy = 0.5; light.light_energy = 0.7
			floor.material_override = VisualGeometry.material(TrackTheme.palette(theme)[1])
			var before: NativeTrackVisual = await make(theme,objects(kind),false); stage.add_child(before)
			var after: NativeTrackVisual = await make(theme,objects(kind),true); stage.add_child(after); after.hide()
			var bounds: AABB = ObjectThumbnail._mesh_bounds(before)
			for view: String in ["overhead","follow","speed_zoom","close"]:
				camera.size = maxf(bounds.size.length()*1.2,2.0) if view == "close" else 35.0/1.15*(1.3 if view == "speed_zoom" else 1.0)
				var pitch: float = deg_to_rad(48.0 if view == "follow" else 56.0)
				var center: Vector3 = bounds.get_center() if view == "close" else Vector3.ZERO
				camera.look_at_from_position(center+Vector3(sin(0.314)*cos(pitch),sin(pitch),cos(0.314)*cos(pitch))*65.0,center)
				before.hide(); after.show(); await frames()
				after.hide(); before.show(); var a: Dictionary = await observe(viewport)
				before.hide(); after.show(); var b: Dictionary = await observe(viewport)
				after.hide(); before.show(); var restored: Dictionary = await observe(viewport)
				check(a.image.get_data()==restored.image.get_data(),"original native restoration remains exact")
				check(a.primitives>1000 and a.draws>0,"native comparison contains the actual visible prop")
				check(a.draws==b.draws,"no per-object render passes added")
				if view == "close": check(a.primitives==b.primitives,"full visible near-detail geometry retained")
				else: check(b.primitives < a.primitives*0.53,"approved reduction selected at normal racing cameras")
				var name: String = theme+"-"+kind+"-"+view
				a.image.save_png(folder.path_join(name+"-before.png")); b.image.save_png(folder.path_join(name+"-after.png"))
				var row: Dictionary = {"theme":theme,"kind":kind,"view":view,"before_primitives":a.primitives,"after_primitives":b.primitives,"before_draws":a.draws,"after_draws":b.draws,"image_metrics":a.image.compute_image_metrics(b.image,false)}
				rows.append(row); print("SCENERY_LOD_NATIVE ",JSON.stringify(row))
			if theme == "winter":
				before.hide(); after.show()
				var seen: Dictionary = {}
				var expected: Array[int] = []
				for row: Dictionary in rows:
					if row.kind == kind and row.theme == theme and row.view in ["overhead","close"]: expected.append(int(row.after_primitives))
				for index: int in range(32):
					var amount: float = float(index)/15.0 if index < 16 else float(31-index)/15.0
					camera.size = lerpf(35.0/1.15,maxf(bounds.size.length()*1.2,2.0),amount)
					await RenderingServer.frame_post_draw
					var count: int = RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
					check(count in expected,"camera motion uses only intact full/reduced geometry")
					seen[count] = true
				check(seen.size()==2,"camera zoom selects both detail levels and returns")
			before.free(); after.free()
	viewport.free()

func run() -> void:
	var mode: String = "headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method()
	folder = ProjectSettings.globalize_path("res://../docs/evidence/track-asset-optimization-2026-11-07/"+mode); DirAccess.make_dir_recursive_absolute(folder)
	if mode == "headless": await structural()
	else: await native()
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t",true)+"\n")
	print("SCENERY_MESH_LODS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
