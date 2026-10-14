extends "res://tests/test_winter_snow_wind.gd"
## Existing visibility/lifecycle suite plus an actual GPU vertex-motion probe.

func capture(game: Node, fx: WinterSnowWind) -> void:
	await super.capture(game,fx)
	var saved_size: Vector2i = root.size
	var saved_camera: Transform3D = game.camera.transform
	var saved_extent: float = game.camera.size
	var saved_hud: bool = game.hud.visible
	var saved_fog: bool = game.biome_environment.fog_enabled
	var saved_shader: Shader = fx.ground_material.shader
	var saved_powder: bool = fx.powder.visible
	var saved_air: bool = fx.airborne.visible
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	# Keep the production vertex stage (including INSTANCE_CUSTOM/world basis),
	# replacing only its fragment with data encoding for inspection. This does
	# not add a debug branch or drawing mode to the shipping shader.
	var source: String = saved_shader.code
	var at: int = source.find("void fragment()")
	assert(at >= 0)
	var probe := Shader.new()
	probe.code = source.left(at).replace("diffuse_lambert","unshaded")+"void fragment() { ALBEDO = vec3(flow_offset/12.0+vec2(0.5),0.0); ALPHA = 1.0; }"
	fx.ground_material.shader = probe
	fx.powder.visible = false
	fx.airborne.visible = false
	game.hud.visible = false
	game.biome_environment.fog_enabled = false
	root.size = Vector2i(384,216)
	var focus := Vector3(34,0,10)
	game.camera.size = 29.0
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus)
	fx.visible = true
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.0,Vector2(34,-10),1.0,false,false)
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var first: Image = root.get_texture().get_image()
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.25,Vector2(34,-10),1.0,false,false)
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var second: Image = root.get_texture().get_image()
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	var samples: int = 0
	for y: int in range(0,root.size.y,3):
		for x: int in range(0,root.size.x,3):
			var a: Color = first.get_pixel(x,y)
			var b: Color = second.get_pixel(x,y)
			# Blue=0 marks the actual drift geometry; discard opaque background
			# and mixed AA boundaries. Decode values, not the visible snow image.
			if a.b > 0.01 or b.b > 0.01 or minf(a.r,a.g) < 0.20 or minf(b.r,b.g) < 0.20: continue
			a = a.srgb_to_linear()
			b = b.srgb_to_linear()
			var velocity := Vector2(b.r-a.r,b.g-a.g)*12.0/0.25
			low = low.min(velocity)
			high = high.max(velocity)
			samples += 1
	check(samples > 100,"actual GPU motion probe samples multiple world regions")
	check(high.x-low.x > 1.0 and high.y-low.y > 1.0,"rendered local advection varies in both speed and sideways motion")
	fx.present(0.25,Vector2(34,-10),1.0,true,false)
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var frozen: Image = root.get_texture().get_image()
	check(second.get_data() == frozen.get_data(),"paused visual clock freezes actual local-flow shader output")
	check(game.sim.state.snapshot() == snapshot,"local-flow GPU probe leaves canonical simulation exact")
	first.save_png(OUT+"/local-motion-data-a.png")
	second.save_png(OUT+"/local-motion-data-b.png")
	var file := FileAccess.open(OUT+"/local-motion-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"samples":samples,"velocity_min": [low.x,low.y],"velocity_max":[high.x,high.y],"spread_m_s":[high.x-low.x,high.y-low.y],"diagnostic":"production vertex stage; false-colour fragment encodes offset derivative, not total prevailing wind velocity"},"\t"))
	print("WINTER_LOCAL_FLOW_GPU: samples=",samples," offset_velocity_spread=",high-low)
	fx.ground_material.shader = saved_shader
	fx.powder.visible = saved_powder
	fx.airborne.visible = saved_air
	game.hud.visible = saved_hud
	game.biome_environment.fog_enabled = saved_fog
	game.camera.transform = saved_camera
	game.camera.size = saved_extent
	root.size = saved_size
