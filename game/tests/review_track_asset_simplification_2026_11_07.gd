extends SceneTree
## TAS01-TAS03: investigation only; production builders and caches are unchanged.
const LODS = preload("res://tests/support/track_asset_lod_review.gd")
const OUTPUT: String = "res://../docs/evidence/track-asset-simplification-2026-11-07"
const CASES: Array = [["pine","tree"],["pine","tyre_wall"],["pine","container"],["pine","crate"],["pine","parked_car"],["pine","grandstand"],["winter","igloo"],["winter","snow_castle"],["winter","ice_compact"],["desert","egypt_pyramid"],["desert","egypt_column"],["night_city","abandoned_warehouse"]]
var checks: int = 0
var failures: int = 0
var rows: Array = []
var folder: String
var only: String = ""
var studio: bool = false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TRACK_ASSET_REVIEW_FAIL ",label)

func build(theme: String, kind: String) -> NativeTrackVisual:
	var track := NativeTrack.new()
	track.metadata = {"creator_document":{"objects":[{"kind":kind,"position":[0.0,0.0],"rotation":0.0}]},"scenery_objects":[]}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	var original: Dictionary = track.metadata.duplicate(true)
	var visual := NativeTrackVisual.new()
	visual.theme_id = theme
	visual.colors = TrackTheme.palette(theme)
	visual._suppress_night_fx = true
	await visual._build_placed_objects(track)
	check(track.metadata == original,theme+"/"+kind+" canonical metadata exact")
	return visual

func collect(node: Node, result: Array) -> void:
	if node is Node3D and not node.visible: return
	if node.is_in_group("contact_lighting"): return
	var mesh: Mesh
	var instances: int = 1
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
		instances = node.multimesh.instance_count
		if node.multimesh.visible_instance_count >= 0: instances = mini(instances,node.multimesh.visible_instance_count)
	if mesh != null and instances > 0:
		result.append({"node":node,"mesh":mesh,"instances":instances})
	for child: Node in node.get_children(): collect(child,result)

func prepare(parts: Array) -> Dictionary:
	var policy = LODS.new()
	var result: Dictionary = {"triangles":0,"first_lod_triangles":0,"smallest_lod_triangles":0,"vertices":0,"meshes":parts.size(),"meshes_with_lods":0,"lod_levels":0,"source_bytes":0,"lod_index_bytes":0,"levels":[]}
	for part: Dictionary in parts:
		var source: Mesh = part.mesh
		var candidate: Mesh = policy.prepare(source)
		part.candidate = candidate
		result.source_bytes += preload("res://editor/cache_bytes.gd").mesh(source)
		part.first = first_lod(candidate)
		var has_lods: bool = false
		var raw: Array = source.get("_surfaces") if source is ArrayMesh else []
		var prepared: Array = candidate.get("_surfaces") if candidate is ArrayMesh else []
		for surface: int in range(source.get_surface_count()):
			var arrays: Array = source.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			var smallest: int = count
			var first: int = count
			if not prepared.is_empty():
				var packet: Dictionary = prepared[surface].duplicate(true)
				var levels: Array = packet.get("lods",[])
				var stride: int = original_index_stride(raw[surface])
				var description: Array = []
				# The pinned ArrayMesh storage keeps alternating distance/index bytes.
				for index: int in range(0,levels.size(),2):
					var level_count: int = levels[index+1].size()/stride
					if index == 0: first = level_count
					smallest = mini(smallest,level_count)
					result.lod_index_bytes += levels[index+1].size()
					description.append({"metric":levels[index],"triangles":level_count/3,"index_storage":type_string(typeof(levels[index+1]))})
				result.levels.append(description)
				result.lod_levels += levels.size()/2
				has_lods = has_lods or not levels.is_empty()
				packet.erase("lods")
				var original: Dictionary = raw[surface].duplicate(true); original.erase("lods")
				check(packet == original,"original GPU surface storage exact")
			check(candidate.surface_get_arrays(surface) == arrays,"original decoded attributes and full indices exact")
			result.triangles += count/3*part.instances
			result.first_lod_triangles += first/3*part.instances
			result.smallest_lod_triangles += smallest/3*part.instances
			result.vertices += arrays[Mesh.ARRAY_VERTEX].size()*part.instances
		if has_lods: result.meshes_with_lods += 1
	result.changed_vertex_streams = policy.totals.changed_vertex_streams
	return result

func original_index_stride(packet: Dictionary) -> int:
	if int(packet.get("index_count",0)) > 0: return packet.index_data.size()/int(packet.index_count)
	return 2 if int(packet.vertex_count) <= 65536 else 4

func first_lod(source: Mesh) -> Mesh:
	if not source is ArrayMesh: return source
	var surfaces: Array = source.get("_surfaces").duplicate(true)
	for packet: Dictionary in surfaces:
		var levels: Array = packet.get("lods",[])
		if not levels.is_empty():
			var stride: int = original_index_stride(packet)
			packet.index_data = levels[1]
			packet.index_count = levels[1].size()/stride
		packet.erase("lods")
	var result := ArrayMesh.new(); result.set("_surfaces",surfaces)
	return result

func inventory() -> void:
	for theme: String in TrackTheme.IDS:
		for kind: String in CreatorObjects.KINDS:
			var visual: NativeTrackVisual = await build(theme,kind)
			var parts: Array = []; collect(visual,parts)
			var started: int = Time.get_ticks_usec()
			var row: Dictionary = prepare(parts)
			row.theme = theme; row.kind = kind; row.lod_preparation_us = Time.get_ticks_usec()-started
			rows.append(row)
			visual.free()
		print("TRACK_ASSET_INVENTORY ",theme," complete")
		await process_frame

func frames() -> void:
	for index: int in range(8): await RenderingServer.frame_post_draw

func observe(viewport: SubViewport) -> Dictionary:
	await frames()
	return {"image":viewport.get_texture().get_image(),"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func set_meshes(parts: Array, version: String) -> void:
	for part: Dictionary in parts:
		if part.node is MeshInstance3D: part.node.mesh = part[version]
		else: part.node.multimesh.mesh = part[version]

func native_review() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.time_scale = 0.0
	var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true
	viewport.mesh_lod_threshold = 1.0; viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	var camera := Camera3D.new(); stage.add_child(camera); camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; stage.add_child(light)
	var world := WorldEnvironment.new(); world.environment = Environment.new(); stage.add_child(world)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var plane := PlaneMesh.new(); plane.size = Vector2(100,100)
	var floor := MeshInstance3D.new(); floor.mesh = plane; floor.position.y = -0.035; stage.add_child(floor)
	for specification: Array in CASES:
		var theme: String = specification[0]; var kind: String = specification[1]
		if not only.is_empty() and kind != only: continue
		var visual: NativeTrackVisual = await build(theme,kind); stage.add_child(visual)
		var parts: Array = []; collect(visual,parts)
		var geometry: Dictionary = prepare(parts)
		TrackTheme.apply_lighting(theme,world.environment,light)
		var inspection_lighting: bool = studio or kind == "abandoned_warehouse"
		if inspection_lighting:
			light.light_energy = 1.0; light.light_color = Color.WHITE; light.rotation_degrees = Vector3(-58,-35,0)
			world.environment.ambient_light_energy = 0.5; world.environment.ambient_light_color = Color("bac8ce")
		world.environment.background_color = Color("34424a")
		floor.material_override = VisualGeometry.material(TrackTheme.palette(theme)[1])
		var bounds: AABB = ObjectThumbnail._mesh_bounds(visual)
		for view: String in ["race_front","race_back","close_front","close_back"]:
			var close: bool = view.begins_with("close")
			var back: bool = view.ends_with("back")
			camera.size = maxf(bounds.size.length()*1.2,2.0) if close else 35.0/1.15
			var pitch: float = deg_to_rad(56.0)
			var yaw: float = deg_to_rad(18.0)+(PI if back else 0.0)
			var center: Vector3 = bounds.get_center() if close else Vector3.ZERO
			camera.look_at_from_position(center+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*65.0,center)
			set_meshes(parts,"candidate"); await frames() # Warm all paths before comparison.
			set_meshes(parts,"first"); await frames()
			set_meshes(parts,"mesh"); var before: Dictionary = await observe(viewport)
			set_meshes(parts,"candidate"); var after: Dictionary = await observe(viewport)
			set_meshes(parts,"first"); var first: Dictionary = await observe(viewport)
			set_meshes(parts,"mesh"); var restored: Dictionary = await observe(viewport)
			var control: Dictionary = before.image.compute_image_metrics(restored.image,false)
			check(control.max == 0.0,theme+"/"+kind+"/"+view+" unchanged original control")
			var name: String = theme+"-"+kind+"-"+view
			before.image.save_png(folder.path_join(name+"-original.png"))
			after.image.save_png(folder.path_join(name+"-lod.png"))
			first.image.save_png(folder.path_join(name+"-firstlod.png"))
			if control.max != 0.0: restored.image.save_png(folder.path_join(name+"-restored.png"))
			var metrics: Dictionary = before.image.compute_image_metrics(after.image,false)
			var row: Dictionary = {"theme":theme,"kind":kind,"view":view,"inspection_lighting":inspection_lighting,"geometry":geometry,"original_primitives":before.primitives,"lod_primitives":after.primitives,"first_lod_primitives":first.primitives,"original_draws":before.draws,"lod_draws":after.draws,"first_lod_draws":first.draws,"image_metrics":metrics,"first_lod_image_metrics":before.image.compute_image_metrics(first.image,false),"original_control_metrics":control,"camera_extent":camera.size,"lod_threshold":viewport.mesh_lod_threshold}
			rows.append(row)
			print("TRACK_ASSET_NATIVE ",theme,"/",kind,"/",view," primitives ",before.primitives," -> ",after.primitives," mean ",metrics.mean)
		visual.free(); await process_frame
	viewport.free(); await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		if argument == "--studio": studio = true
	var mode: String = "inventory" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	if studio: mode += "-studio"
	folder = ProjectSettings.globalize_path(OUTPUT.path_join(mode)); DirAccess.make_dir_recursive_absolute(folder)
	if DisplayServer.get_name() == "headless": await inventory()
	else: await native_review()
	check(not rows.is_empty(),"review contains actual cases")
	var report: Dictionary = {"requirements":["TAS01-current-catalogue","TAS02-index-lod-prototype","TAS03-native-visual-review"],"engine":Engine.get_version_info().string,"mode":mode,"checks":checks,"failures":failures,"rows":rows,"scope":"Investigation only. Individual production prop builders; default scale and span, visible parts excluding contact-lighting overlays. LOD generation occurs only in this offline review. Native views isolate model work, use race pitch/extent plus enlarged detail views, and compare restored-original controls. No full race, FPS, loading or device improvement claim."}
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t",true)+"\n")
	print("TRACK_ASSET_REVIEW ",checks," checks, ",failures," failures, ",rows.size()," cases")
	quit(1 if failures else 0)
