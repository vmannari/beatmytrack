extends SceneTree
## Isolated desktop stress review, not a mobile or full-game benchmark.
const OUTPUT: String = "res://../docs/evidence/track-object-refinement-2026-10-12"
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var objects: Array = []
	for i: int in range(120):
		var family: Array = CreatorCatalog.ASSETS[i%CreatorCatalog.ASSETS.size()]
		objects.append({"kind":family[3][0],"position":[-44+(i%12)*8,-36+(i/12)*8],"rotation":15+(i%4)*15})
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects}}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	var build_ms: Array[float] = []
	var visual: NativeTrackVisual
	for repeat: int in range(3):
		visual = NativeTrackVisual.new()
		var started: int = Time.get_ticks_usec()
		visual._build_placed_objects(track)
		build_ms.append((Time.get_ticks_usec()-started)/1000.0)
		if repeat < 2: visual.free()
	root.add_child(visual)
	VisualGeometry.box(visual,Vector3(130,0.1,110),Vector3(0,-0.10,0),VisualGeometry.material(Color("5c6759")))
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 87; root.add_child(camera)
	camera.look_at_from_position(Vector3(30,65,-75),Vector3.ZERO); camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-38,0); light.shadow_enabled = true; root.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_energy = 0.45; root.add_child(environment)
	var viewport: RID = root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true)
	var cpu: Array[float] = []; var gpu: Array[float] = []
	for frame: int in range(180):
		camera.position.x += 0.01
		await RenderingServer.frame_post_draw
		if frame > 59:
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)); gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	cpu.sort(); gpu.sort()
	var stats: Dictionary = geometry_stats(visual)
	var report: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"objects":objects.size(),"geometry":stats,"construction_ms":build_ms,"cpu_median_ms":cpu[cpu.size()/2],"cpu_p95_ms":cpu[int(cpu.size()*0.95)],"gpu_median_ms":gpu[gpu.size()/2],"gpu_p95_ms":gpu[int(gpu.size()*0.95)],"scope":"1280x720 isolated all-prop desktop stage, shadows enabled; excludes road, HUD, particles and gameplay; no phone or thermal claim"}
	var folder: String = ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder+"/profile.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	root.get_texture().get_image().save_png(folder+"/stress-120.png")
	print("PROP_DESKTOP_PROFILE: ",JSON.stringify(report))
	quit()

func geometry_stats(node: Node) -> Dictionary:
	var stats: Dictionary = {"triangles":0,"meshes":0}
	if node.is_in_group("contact_lighting"): return stats
	var mesh: Mesh
	var count: int = 1
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D: mesh = node.multimesh.mesh; count = node.multimesh.instance_count
	if mesh != null:
		stats.meshes += 1
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			stats.triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3*count
	for child: Node in node.get_children():
		var sub: Dictionary = geometry_stats(child)
		stats.triangles += sub.triangles; stats.meshes += sub.meshes
	return stats
