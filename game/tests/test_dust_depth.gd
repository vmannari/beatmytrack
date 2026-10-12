extends SceneTree
## Original appearance, actual GPU particle, opaque-height occlusion; no saves.
var failures: int = 0
var checks: int = 0
var total_original_overlap: int = 0
var active_game: Node
var folder: String = "res://../docs/evidence/dust-depth-2026-10-10/desktop"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func capture() -> Image:
	for frame: int in range(5):
		active_game.paused = false
		active_game.hud.pause_menu.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func opaque_mask(mask: Image, x: int, y: int) -> bool:
	# The world colour grade tints diagnostic magenta. Erode only the test
	# classification by one pixel to exclude mixed MSAA edge/ground samples.
	for offset_y: int in range(-1,2):
		for offset_x: int in range(-1,2):
			var c: Color = mask.get_pixel(x+offset_x,y+offset_y)
			if c.r<0.95 or c.b<0.85 or c.g>0.16: return false
	return true
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): folder = argument.trim_prefix("--output=")
	root.size = Vector2i(1280,900)
	folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json")))
	for id: String in VehicleCatalog.IDS:
		var game: Node = load("res://core/game.tscn").instantiate()
		active_game = game
		game.initial_track = track
		game.vehicle_id = id
		game.production_mode = true
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process(false)
		game.countdown_ticks = 0
		game.race_cues.reset()
		game.camera.speed_zoom_enabled = false
		var heading: float = VehicleCatalog.IDS.find(id)*TAU/5.0
		game.sim.state.position = track.spawn
		game.previous_position = track.spawn
		game.previous_heading = heading
		game.sim.state.heading = heading
		game.sim.state.steering = 0.8
		game.sim.state.velocity = Vector2(0,12)
		game.paused = false
		game.call("_process",0.0)
		game.camera.follow(track.spawn,Vector2.ZERO,heading,0.0,true)
		game.sand_dust.sample(game.sim.state,DriveFrame.new(),track,game.bridge_presentation)
		game.sand_dust.visible = false
		var snapshot: Array = game.sim.state.snapshot()
		var source: ShaderMaterial = game.sand_dust.dust_emitters[0].draw_pass_1.surface_get_material(0)
		var material: ShaderMaterial = source.duplicate()
		var shader := Shader.new()
		var code: String = source.shader.code
		shader.code = code
		material.shader = shader
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			var value: Variant = source.get_shader_parameter(uniform.name)
			if value!=null: material.set_shader_parameter(uniform.name,value)
		var particle := GPUParticles3D.new()
		particle.amount = 1
		particle.lifetime = 20.0
		particle.explosiveness = 1.0
		particle.local_coords = true
		particle.draw_pass_1 = game.sand_dust.dust_emitters[0].draw_pass_1.duplicate()
		particle.draw_pass_1.surface_set_material(0,material)
		particle.position = VisualGeometry.world(track.spawn)+Vector3.UP*0.025
		particle.visibility_aabb = AABB(Vector3(-10,-10,-10),Vector3(20,20,20))
		var process := ParticleProcessMaterial.new()
		process.gravity = Vector3.ZERO
		process.scale_min = 1.4
		process.scale_max = 1.4
		process.color = Color(0.82,0.76,0.62,0.8)
		particle.process_material = process
		game.add_child(particle)
		particle.emitting = true
		await create_timer(0.3).timeout
		particle.speed_scale = 0.0
		particle.visible = false
		var clean: Image = await capture()
		clean.save_png(folder.path_join(id+"-clean.png"))
		game.car.visible = false
		var ground: Image = await capture()
		ground.save_png(folder.path_join(id+"-ground.png"))
		game.car.visible = true
		var mask_material := ShaderMaterial.new()
		mask_material.shader = Shader.new()
		mask_material.shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; void fragment() { ALBEDO = vec3(1,0,1); }"
		var saved: Dictionary = {}
		for mesh: MeshInstance3D in game.car.find_children("*","MeshInstance3D",true,false):
			saved[mesh] = mesh.material_override
			mesh.material_override = mask_material
		var body_mask: Image = await capture()
		body_mask.save_png(folder.path_join(id+"-body-mask.png"))
		for mesh: MeshInstance3D in saved: mesh.material_override = saved[mesh]
		particle.visible = true
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material.set_shader_parameter("dust_height_occlusion",false)
		var baseline: Image = await capture()
		baseline.save_png(folder.path_join(id+"-original.png"))
		material.set_shader_parameter("dust_height_occlusion",true)
		var low: Image = await capture()
		low.save_png(folder.path_join(id+"-height-depth.png"))
		particle.position.y = 2.0
		var high: Image = await capture()
		high.save_png(folder.path_join(id+"-risen.png"))
		var body: int = 0
		var overlap_original: int = 0
		var overlap_low: int = 0
		var overlap_high: int = 0
		var dust_outside: int = 0
		var altered_outside: int = 0
		for y: int in range(300,600):
			for x: int in range(440,840):
				var a: Color = clean.get_pixel(x,y)
				if opaque_mask(body_mask,x,y):
					body += 1
					if distance(a,baseline.get_pixel(x,y))>2.0/255.0: overlap_original += 1
					if distance(a,low.get_pixel(x,y))>2.0/255.0: overlap_low += 1
					if distance(a,high.get_pixel(x,y))>2.0/255.0: overlap_high += 1
				elif distance(a,ground.get_pixel(x,y))<1.0/255.0 and distance(a,baseline.get_pixel(x,y))>2.0/255.0:
					dust_outside += 1
					if distance(low.get_pixel(x,y),baseline.get_pixel(x,y))>1.0/255.0: altered_outside += 1
		print("DUST_DEPTH_PIXELS ",id," body=",body," original=",overlap_original," low=",overlap_low," high=",overlap_high," outside=",dust_outside," altered_outside=",altered_outside)
		check(body>20,id+": opaque car body sampled")
		total_original_overlap += overlap_original
		check(overlap_low==0,id+": physical particle height protects opaque body")
		check(overlap_high>20,id+": elevated dust still covers car")
		check(dust_outside>100,id+": immediate full-size cloud outside car")
		check(altered_outside==0,id+": surrounding cloud unchanged; no halo")
		check(game.sim.state.snapshot()==snapshot,id+": canonical simulation unchanged")
		game.free()
	check(total_original_overlap>100,"original low-particle billboard overlaps opaque body in the control")
	print("DUST_DEPTH_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
