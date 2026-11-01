extends SceneTree
const SKY_SHADER=preload("res://track/winter_reflection_sky.gdshader")
func _initialize() -> void: run.call_deferred()
func make_sky() -> Sky:
	var sky:=Sky.new(); var material:=ShaderMaterial.new(); material.shader=SKY_SHADER
	sky.sky_material=material; sky.radiance_size=Sky.RADIANCE_SIZE_128; sky.process_mode=Sky.PROCESS_MODE_QUALITY
	return sky
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	root.size=Vector2i(640,360)
	var scene:=Node3D.new(); root.add_child(scene)
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); scene.add_child(env)
	var sun:=DirectionalLight3D.new(); scene.add_child(sun)
	TrackTheme.apply_lighting("winter",env.environment,sun)
	var cam:=Camera3D.new(); cam.position=Vector3(0,0,4); scene.add_child(cam); cam.current=true
	var sphere:=MeshInstance3D.new(); sphere.mesh=SphereMesh.new(); var mat:=StandardMaterial3D.new()
	mat.metallic=1.0; mat.roughness=0.1; sphere.material_override=mat; scene.add_child(sphere)
	var shared:=make_sky(); env.environment.sky=shared
	var viewport:=root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true)
	for i: int in range(50): await RenderingServer.frame_post_draw
	var reference: PackedByteArray=root.get_texture().get_image().get_data()
	var before: Array=[]; var after: Array=[]; var exact:=true
	for stage: int in range(12):
		for mode: String in (["new","reuse"] if stage%2==0 else ["reuse","new"]):
			env.environment.sky=null
			for i: int in range(4): await RenderingServer.frame_post_draw
			var start:=Time.get_ticks_usec()
			env.environment.sky=make_sky() if mode=="new" else shared
			var setup:=Time.get_ticks_usec()-start; var intervals: Array=[]; var gpu: Array=[]
			var previous:=Time.get_ticks_usec()
			for i: int in range(12):
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec(); intervals.append(float(now-previous)/1000.0); previous=now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			var pixels:=root.get_texture().get_image().get_data(); exact=exact and pixels==reference
			var result={"setup_us":setup,"interval_ms":intervals,"gpu_ms":gpu}
			if mode=="new": before.append(result)
			else: after.append(result)
	var report={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"exact":exact,"new":before,"reuse":after}
	var f:=FileAccess.open("res://../build/winter-sky-audit/report.json",FileAccess.WRITE); f.store_string(JSON.stringify(report,"  ")); f.close()
	print("WINTER_SKY_PROFILE ",JSON.stringify(report))
	env.environment.sky=null; shared=null; TrackTheme.trim_winter_sky(); env.environment=null; scene.queue_free()
	for i: int in range(20): await process_frame
	quit(0 if exact else 1)



