extends "res://tests/test_winter_ground_snow.gd"
const FAST_EVIDENCE: String = "res://../docs/evidence/winter-fast-spindrift-2026-10-14"

func _initialize() -> void:
	OUT = FAST_EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await super.capture(game,fx)
	await sparse_capture(game,fx)

func difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	for y: int in range(0,a.get_height(),2):
		for x: int in range(0,a.get_width(),2):
			var before: Color = a.get_pixel(x,y)
			var after: Color = b.get_pixel(x,y)
			total += absf(after.r-before.r)+absf(after.g-before.g)+absf(after.b-before.b)
	return total

func sparse_capture(game: Node, fx: WinterSnowWind) -> void:
	var aa: Viewport.MSAA = root.msaa_3d
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.size = Vector2i(1280,720)
	game.hud.visible = false
	var focus := Vector3(34,0,10)
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus); game.camera.size = 29.0
	fx.elapsed = 5.0; fx.travel = 95.0; fx.motion_intensity = 0.0; fx.intensity = 0.24
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.0,Vector2(34,-10),0.0,false,false)
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	fx.visible = false
	var clear: Image = await settled(game)
	fx.visible = true
	var light: Image = await settled(game)
	fx.intensity = 1.0
	fx.present(0.0,Vector2(34,-10),0.0,false,false)
	var dense: Image = await settled(game)
	var light_delta: float = difference(clear,light)
	var dense_delta: float = difference(clear,dense)
	check(light_delta > 50.0 and dense_delta > light_delta*1.5,"actual light powder is visible while its density stays substantially below a dense gust")
	fx.intensity = 0.24
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.0,Vector2(34,-10),0.0,false,false)
	check((await settled(game)).get_data() == light.get_data(),"density adjustment restores sparse surface pixels exactly at the same clock")
	var start: float = fx.travel
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(1.0/30.0,Vector2(34,-10),0.0,false,false)
	var moving: Image = await settled(game)
	check(is_equal_approx(fx.travel-start,28.0/30.0) and difference(light,moving) > 50.0,"sparse powder advances almost a metre per30fps frame and visibly moves on opaque ground")
	check(game.sim.state.snapshot() == snapshot,"fast sparse wind leaves canonical simulation exact")
	clear.save_png(OUT+"/sparse-clear.png"); light.save_png(OUT+"/sparse.png")
	dense.save_png(OUT+"/dense.png"); moving.save_png(OUT+"/sparse-next-frame.png")
	var report := FileAccess.open(OUT+"/sparse-motion.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"light_delta":light_delta,"dense_delta":dense_delta,"dense_to_light_ratio":dense_delta/light_delta,"calm_travel_per_30fps_frame":fx.travel-start,"light_strength":fx.intensity,"motion_strength":fx.motion_intensity},"\t"))
	print("WINTER_FAST_SPARSE: ",dense_delta/light_delta," density ratio; travel/frame=",fx.travel-start)
	# Review the subtle case for six seconds at actual display-sized road scale.
	root.size = Vector2i(960,540)
	var frames: Array[String] = []
	for frame: int in range(180):
		fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		fx.present(1.0/30.0,Vector2(34,-10),0.0,false,false)
		await RenderingServer.frame_post_draw
		frames.append("data:image/jpeg;base64,"+Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.90)))
	var preview := FileAccess.open(OUT+"/fast-light-motion.html",FileAccess.WRITE)
	preview.store_string("<!doctype html><meta charset='utf-8'><title>Fast light wind snow</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1100px;margin:32px auto}img{width:100%}button{padding:10px;margin:12px 0}</style><h1>Fast light wind snow</h1><p>Actual Godot capture · light powder · 6 seconds at 30 fps</p><img id='view'><button id='toggle'>Pause</button><script>const frames="+JSON.stringify(frames)+";let frame=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/30)</script>")
	game.hud.visible = true
	root.msaa_3d = aa
