extends "res://tests/test_winter_ground_snow.gd"
const LOCAL_EVIDENCE: String = "res://../docs/evidence/winter-local-streams-2026-10-14"

func _initialize() -> void:
	OUT = LOCAL_EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await super.capture(game,fx)
	await local_windows()
	await local_motion(game,fx)

func local_windows() -> void:
	# Render the shipping GPU window function, without a CPU reimplementation.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,200)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rectangle := ColorRect.new()
	rectangle.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n#include \"res://track/winter_wind_variation.gdshaderinc\"\nuniform float clock;\nvoid fragment(){float gate=snow_local_gust((UV-0.5)*vec2(144.0,90.0),clock);COLOR=vec4(vec3(gate),1.0);}\n"
	material.shader = shader; rectangle.material = material
	viewport.add_child(rectangle)
	var images: Array[Image] = []
	var occupancy: Array[float] = []
	for clock: float in [0.0,3.0,6.0,9.0,0.0]:
		material.set_shader_parameter("clock",clock)
		for frame: int in range(3): await RenderingServer.frame_post_draw
		var picture: Image = viewport.get_texture().get_image()
		var active: int = 0; var white: int = 0
		for y: int in range(picture.get_height()):
			for x: int in range(picture.get_width()):
				var value: float = picture.get_pixel(x,y).r
				if value > 0.0: active += 1
				if value > 0.9: white += 1
		var fraction: float = float(active)/(picture.get_width()*picture.get_height())
		occupancy.append(fraction); images.append(picture)
		check(fraction > 0.025 and fraction < 0.30 and white > 10,"shipping GPU window leaves most world positions completely clear and retains concentrated stream cores at time "+str(clock))
	check(images[0].get_data() == images[4].get_data(),"returning to a clock restores the exact world window field")
	check(images[0].get_data() != images[1].get_data() and images[1].get_data() != images[2].get_data(),"separate local events emerge and subside over time")
	for i: int in range(4): images[i].save_png(OUT+"/window-"+str(i)+".png")
	var report := FileAccess.open(OUT+"/local-windows.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"positive_window_area":occupancy,"period_seconds":[8.0,13.0],"event_seconds":[3.2,5.2],"scope":"shipping GPU window mask over 144x90m; actual fine powder is sparser"},"\t"))
	print("WINTER_LOCAL_WINDOWS: ",occupancy)
	viewport.queue_free()

func local_motion(game: Node, fx: WinterSnowWind) -> void:
	root.size = Vector2i(1280,720); game.hud.visible = false
	var focus := Vector3(34,0,10)
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus); game.camera.size = 29.0
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	fx.elapsed = 0.0; fx.travel = 0.0; fx.intensity = 0.45; fx.motion_intensity = 1.0
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.0,Vector2(34,-10),1.0,false,false)
	fx.visible = false
	var clear: Image = await settled(game)
	fx.visible = true
	var frames: Array[String] = []
	var changed_counts: Array[int] = []
	for frame: int in range(240):
		fx.present(1.0/30.0,Vector2(34,-10),1.0,false,false)
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		frames.append("data:image/jpeg;base64,"+Marshalls.raw_to_base64(picture.save_jpg_to_buffer(0.90)))
		if frame % 60 == 0:
			var changed: int = 0
			for y: int in range(0,720,2):
				for x: int in range(0,1280,2):
					if picture.get_pixel(x,y) != clear.get_pixel(x,y): changed += 1
			changed_counts.append(changed)
			picture.save_png(OUT+"/localized-"+str(frame/60)+".png")
	check(changed_counts.max() > 500 and changed_counts.min() < changed_counts.max()*0.85,"actual world snow has visibly different coverage as local events come and go")
	check(game.sim.state.snapshot() == snapshot,"localized presentation leaves canonical state exact")
	var output := FileAccess.open(OUT+"/localized-motion.html",FileAccess.WRITE)
	output.store_string("<!doctype html><meta charset='utf-8'><title>Localized drifting snow</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:24px auto}img{width:100%}button{padding:10px}</style><h1>Localized drifting snow</h1><p>Actual Godot capture: separate snow streams come and go, with clear gaps. Eight seconds at30fps, strongest gust envelope.</p><img id='view'><button id='toggle'>Pause</button><script>const frames="+JSON.stringify(frames)+";let n=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){n=(n+1)%frames.length;view.src=frames[n]}},1000/30)</script>")
	print("WINTER_LOCAL_RENDER: changed_samples=",changed_counts)
	game.hud.visible = true
