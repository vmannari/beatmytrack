extends SceneTree
var checks: int = 0
var failures: int = 0
var output: String = "res://../build/spatial-terrain-2026-10-13"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func run() -> void:
	root.size = Vector2i(1280,720)
	var parent := NativeTrackVisual.new()
	root.add_child(parent)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(65536):
		var center := Vector3((index%256-128)*2.0,0,(index/256-128)*2.0)
		tool.set_normal(Vector3.UP)
		for point: Vector3 in [center,center+Vector3(0,0,1),center+Vector3(1,0,0)]: tool.add_vertex(point)
	tool.index()
	var source := MeshInstance3D.new()
	source.name = "LargeStaticFixture"
	source.mesh = tool.commit()
	source.material_override = VisualGeometry.material(Color.WHITE)
	var parts: Array[MeshInstance3D] = SpatialMeshChunks.add(parent,source)
	check(source.get_script() != null and source.layers == 1,"no camera retains one direct full draw")
	check(parts.size() > 1 and parts.all(func(node: MeshInstance3D) -> bool: return not node.visible),"spatial draw resources prepared without duplicate drawing")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36
	camera.position = Vector3(0,40,0)
	camera.rotation_degrees.x = -90
	camera.current = true
	source.call("_process",0.2)
	check(source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and parts.all(func(node: MeshInstance3D) -> bool: return node.visible and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"narrow view selects spatial colour draws with original full shadow caster")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50,-25,0)
		light.shadow_enabled = true
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		root.add_child(light)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		var modes: Array[Dictionary] = []
		var original: Image
		for enabled: bool in [false,true,false,true]:
			source.call("set_spatial_draws_enabled",enabled)
			if enabled: source.call("_process",0.2)
			for frame: int in range(10): await RenderingServer.frame_post_draw
			var gpu: Array[float] = []
			var cpu: Array[float] = []
			var start: int = Time.get_ticks_usec()
			while Time.get_ticks_usec()-start < 600000:
				await process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			gpu.sort(); cpu.sort()
			var image: Image = root.get_texture().get_image()
			if original == null: original = image
			else:
				var a: PackedByteArray = original.get_data()
				var b: PackedByteArray = image.get_data()
				var maximum: int = 0
				for index: int in range(a.size()): maximum = maxi(maximum,absi(int(a[index])-int(b[index])))
				check(maximum <= 2,"large-field adaptive drawing preserves pixels")
			var report: Dictionary = {"chunks":enabled,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"gpu_ms":gpu[gpu.size()/2],"render_cpu_ms":cpu[cpu.size()/2]}
			modes.append(report)
			print("STATIC_DRAW_PROFILE ",report)
			image.save_png(output.path_join("large-field-"+RenderingServer.get_current_rendering_method()+"-"+str(enabled)+".png"))
		FileAccess.open(output.path_join("large-field-"+RenderingServer.get_current_rendering_method()+".json"),FileAccess.WRITE).store_string(JSON.stringify({"fixture":"65536 opaque triangles over a 512m field; component work, not phone FPS","stages":modes},"\t"))
	var selected_shadow: int = source.cast_shadow
	for frame: int in range(30): source.call("_process",0.01)
	check(source.cast_shadow == selected_shadow,"unchanged view keeps draw selection")
	camera.size = 900
	source.call("_process",0.2)
	check(source.layers == 1 and parts.all(func(node: MeshInstance3D) -> bool: return not node.visible),"overview returns to one direct draw")
	var cache = preload("res://track/prepared_world_cache.gd")
	cache.entries.clear()
	var track := NativeTrack.new()
	track.cells.resize(1024)
	cache.remember(["adaptive-test"],parent,track)
	var restored := NativeTrackVisual.new()
	root.add_child(restored)
	check(cache.restore(["adaptive-test"],restored),"prepared world retains adaptive resources")
	var copy: MeshInstance3D = restored.get_child(0)
	check(copy.get_script() == source.get_script() and copy.mesh == source.mesh,"immutable mesh and controller survive world reuse")
	camera.size = 36
	copy.call("_process",0.2)
	check(copy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"restored world owns a working fresh draw selector")
	check(cache.entries[0].bytes <= cache.MAX_BYTES,"original and chunk resources fit existing world budget")
	print("STATIC_MESH_DRAW_VIEW ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
