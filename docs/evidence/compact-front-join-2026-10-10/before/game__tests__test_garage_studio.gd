extends SceneTree
## Native studio/model inspection. Isolated records; no account, backend or race writes.
var failures: int = 0
var checks: int = 0
var output: String = "res://../docs/evidence/garage-studio-2026-10-10"

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func capture(label: String) -> void:
	for frame: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func inspect(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		result.meshes += 1
		for index: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			result.uv_vertices += uv.size()
			result.vertices += vertices.size()
			result.triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else vertices.size())/3
			for point: Vector3 in vertices:
				if not is_finite(point.x) or not is_finite(point.y) or not is_finite(point.z): result.finite=false
	for child: Node in node.get_children(): inspect(child,result)

func _run() -> void:
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var records := LocalRecords.new("user://studio_test_"+TrackLibrary.unique_id()+".json")
	var holder := MarginContainer.new()
	holder.theme = MenuStyle.theme()
	MenuStyle.fill(holder)
	for side: String in ["left","right","top","bottom"]: holder.add_theme_constant_override("margin_"+side,20)
	root.add_child(holder)
	var page := GaragePage.new()
	page.records = records
	page.circuit_title = "STARTER CIRCUIT"
	var build_began: int = Time.get_ticks_usec()
	holder.add_child(page)
	print("STUDIO_BUILD_MS ",(Time.get_ticks_usec()-build_began)/1000.0)
	await capture("compact-default-1280")
	var view: CarShowroom = page.showroom
	check(view.car.vehicle_id == "compact","actual shared Compact model")
	check(view.camera.projection == Camera3D.PROJECTION_PERSPECTIVE,"perspective preserved")
	check(view.showroom_viewport.own_world_3d,"studio world isolated")
	check(view.showroom_viewport.msaa_3d == Viewport.MSAA_4X,"menu antialiasing")
	check(view.showroom_viewport.find_child("SeamlessStudioCove",true,false) != null,"continuous cove replaces platform")
	var env: WorldEnvironment = view.showroom_viewport.find_child("StudioEnvironment",true,false)
	check(env.environment.sky == ShowroomStudio.cached_sky,"cached studio radiance")
	check(view.showroom_viewport.find_child("PreparedStudioShadow",true,false)!=null,"mesh-derived soft ground shadow")
	var body: StandardMaterial3D = view.car.paint_materials.body
	check(body.roughness < 0.5 and body.specular_mode != BaseMaterial3D.SPECULAR_DISABLED,"satin automotive finish")
	var before: Dictionary = {"meshes":0,"triangles":0,"uv_vertices":0,"vertices":0,"finite":true}
	inspect(view.car,before)
	check(before.finite and before.uv_vertices > 4000,"finite authored UV surfaces")
	var unbatched := CarVisual.new()
	unbatched.batch_parts = false
	root.add_child(unbatched)
	var source: Dictionary = {"meshes":0,"triangles":0,"uv_vertices":0,"vertices":0,"finite":true}
	inspect(unbatched,source)
	check(before.triangles == source.triangles,"batching retains all new geometry")
	check(before.meshes < source.meshes*0.6,"batching remains effective")
	var baked: Dictionary = CompactCoachwork.meshes.duplicate()
	check(baked.size()==48,"forty-eight revised baked authored surfaces")
	var glazing=preload("res://vehicle/compact_glazing.gd")
	var baked_glass: Dictionary=glazing.sheets.duplicate()
	check(baked_glass.size()==4,"four baked glazing surfaces")
	CompactCoachwork.use_baked=false
	CompactCoachwork.meshes.clear()
	glazing.use_baked=false
	glazing.sheets.clear()
	var regenerated := CarVisual.new()
	regenerated.batch_parts=false
	root.add_child(regenerated)
	for key: String in baked:
		check(var_to_bytes((baked[key] as ArrayMesh).surface_get_arrays(0)) == var_to_bytes((CompactCoachwork.meshes[key] as ArrayMesh).surface_get_arrays(0)),"baked/source geometry exact "+key)
	for key: String in baked_glass:
		check(var_to_bytes((baked_glass[key] as ArrayMesh).surface_get_arrays(0)) == var_to_bytes((glazing.sheets[key] as ArrayMesh).surface_get_arrays(0)),"baked/source glazing exact "+key)
	CompactCoachwork.meshes=baked
	CompactCoachwork.use_baked=true
	glazing.sheets=baked_glass
	glazing.use_baked=true
	regenerated.queue_free()
	check(view.car.rolling_wheels.size()==4 and view.car.front_wheels.size()==2,"wheel transforms preserved")
	var livery: Dictionary = VehicleLivery.defaults("compact")
	livery.colors.body = "804439"
	livery.colors.accent = "b7af9c"
	view.apply_livery(livery)
	check(view.car.paint_materials.body.albedo_color.to_html(false)=="804439","body recolors all shared paint")
	for variant: Dictionary in view.car.paint_variants:
		check((variant.material as StandardMaterial3D).albedo_color==Color(livery.colors[variant.slot]).darkened(float(variant.get("darken",0.0))),"detail follows livery")
	await capture("compact-copper-1280")
	view.yaw = -0.72
	view.elevation = 0.15
	view.set_zoom(0.88)
	await capture("compact-front-close-1280")
	view.yaw = 2.45
	view.elevation = 0.30
	view.set_zoom(1.0)
	await capture("compact-rear-1280")
	view.yaw = 1.55
	view.elevation = 0.62
	view.set_zoom(0.85)
	await capture("compact-side-high-1280")
	root.size = Vector2i(960,540)
	view.reset_view()
	view.apply_livery(VehicleLivery.defaults("compact"))
	await capture("compact-default-960")
	check(page.get_global_rect().encloses(page.pickers.body.get_global_rect()),"paint control stays within layout")
	# A fresh driving asset never inherits the showroom-only glass override.
	var shader: ShaderMaterial = preload("res://vehicle/compact_glazing.gd").shared_glass
	check(not bool(shader.get_shader_parameter("studio_mode")),"shared driving glass remains independent")
	print("STUDIO_MODEL ",JSON.stringify(before))
	var viewport: RID = view.showroom_viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	for frame: int in range(120):
		view.yaw += 0.012
		view._orbit()
		await process_frame
		if frame>29:
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	cpu.sort()
	gpu.sort()
	print("STUDIO_RENDER_MS ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu_median":cpu[cpu.size()/2],"gpu_median":gpu[gpu.size()/2],"cpu_p95":cpu[int(cpu.size()*0.95)],"gpu_p95":gpu[int(gpu.size()*0.95)]}))
	unbatched.queue_free()
	holder.queue_free()
	await process_frame
	print("GARAGE_STUDIO: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
