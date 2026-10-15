extends "res://tests/test_winter_ground_snow.gd"
const RESTRAINT_EVIDENCE: String = "res://../docs/evidence/winter-wind-restraint-2026-10-14"

func _initialize() -> void:
	OUT = RESTRAINT_EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await super.capture(game,fx)
	await restrained_comparison(game,fx)

func image_delta(a: Image, b: Image) -> float:
	var total: float = 0.0
	for y: int in range(0,a.get_height(),2):
		for x: int in range(0,a.get_width(),2):
			var p: Color = a.get_pixel(x,y); var q: Color = b.get_pixel(x,y)
			total += absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
	return total

func comparison_state(fx: WinterSnowWind, amount: float, clock: float, distance: float) -> void:
	fx.elapsed = clock; fx.travel = distance; fx.intensity = amount; fx.motion_intensity = 0.25
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.0,Vector2(34,-10),0.25,false,false)

func restrained_comparison(game: Node, fx: WinterSnowWind) -> void:
	var saved_aa: Viewport.MSAA = root.msaa_3d
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.size = Vector2i(1280,720); game.hud.visible = false
	var focus := Vector3(34,0,10)
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus); game.camera.size = 29.0
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	var before_dir: String = RESTRAINT_EVIDENCE+"/before/"
	var helper_path: String = "res://track/winter_wind_variation.gdshaderinc"
	var new_helper: String = FileAccess.get_file_as_string(helper_path).replace("\r\n","\n")
	var old_helper: String = FileAccess.get_file_as_string(before_dir+"game__track__winter_wind_variation.gdshaderinc").replace("\r\n","\n")
	var ground_path: String = "res://track/winter_ground_snow.gdshaderinc"
	var include: String = '#include "'+helper_path+'"'
	var new_ground: String = FileAccess.get_file_as_string(ground_path).replace("\r\n","\n").replace(include,new_helper)
	var old_ground: String = FileAccess.get_file_as_string(before_dir+"game__track__winter_ground_snow.gdshaderinc").replace("\r\n","\n").replace(include,old_helper)
	var materials: Array[ShaderMaterial] = fx.surface_materials.duplicate()
	var originals: Array[Shader] = []; var previous: Array[Shader] = []
	for material: ShaderMaterial in materials:
		originals.append(material.shader)
		var source: String = material.shader.code.replace("\r\n","\n")
		check(source.contains(new_ground),"paired reference replaces the actual compiled surface-powder body")
		var shader := Shader.new(); shader.code = source.replace(new_ground,old_ground)
		previous.append(shader)
	var air: ShaderMaterial = fx.airborne.material_override
	var saved_air: Shader = air.shader
	var old_air := Shader.new(); old_air.code = saved_air.code.replace(include,old_helper)
	var clears: Array[Image] = []; var pictures: Array[Image] = []; var deltas: Array[float] = []
	var motion: Array = []
	for revised: bool in [false,true]:
		for index: int in range(materials.size()): materials[index].shader = originals[index] if revised else previous[index]
		air.shader = saved_air if revised else old_air
		var amount: float = 0.2025 if revised else 0.43
		var speed: float = 13.5 if revised else 30.0
		comparison_state(fx,amount,5.0,95.0)
		fx.visible = false
		var clear: Image = await settled(game)
		fx.visible = true
		var picture: Image = await settled(game)
		clears.append(clear); pictures.append(picture); deltas.append(image_delta(clear,picture))
		picture.save_png(OUT+("/revised.png" if revised else "/previous.png"))
		clear.save_png(OUT+("/clear-revised.png" if revised else "/clear-previous.png"))
		root.size = Vector2i(960,540)
		var frames: Array[String] = []
		for frame: int in range(180):
			comparison_state(fx,amount,5.0+float(frame)/30.0,95.0+speed*float(frame)/30.0)
			await RenderingServer.frame_post_draw
			frames.append("data:image/jpeg;base64,"+Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.90)))
		motion.append(frames)
		root.size = Vector2i(1280,720)
	check(deltas[1] > 20.0 and deltas[1] < deltas[0]*0.55,"actual revised powder remains visible and contributes substantially less than the rejected version")
	for index: int in range(materials.size()): materials[index].shader = previous[index]
	air.shader = old_air
	comparison_state(fx,0.43,5.0,95.0)
	check((await settled(game)).get_data() == pictures[0].get_data(),"previous material render restores exactly for fair before/after comparison")
	for index: int in range(materials.size()): materials[index].shader = originals[index]
	air.shader = saved_air
	comparison_state(fx,0.2025,5.0,95.0)
	var start: float = fx.travel
	fx.present(1.0/30.0,Vector2(34,-10),0.25,false,false)
	var moving: Image = await settled(game)
	check(is_equal_approx(fx.travel-start,13.5/30.0) and image_delta(pictures[1],moving) > 20.0,"actual moderate wind advances0.45m per30fps frame and still moves visibly")
	check(game.sim.state.snapshot() == snapshot,"comparison and restrained wind leave canonical simulation exact")
	var report := FileAccess.open(OUT+"/comparison.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"previous_delta":deltas[0],"revised_delta":deltas[1],"contribution_ratio":deltas[1]/deltas[0],"previous_mps":30.0,"revised_mps":13.5,"previous_amount":0.43,"revised_amount":0.2025,"scope":"same scene and modest gust, paired material bodies; RGB difference is not snow mass or physical wind"},"\t"))
	print("WINTER_RESTRAINT: contribution_ratio=",deltas[1]/deltas[0]," phase_speed=30 -> 13.5")
	var preview := FileAccess.open(OUT+"/comparison-motion.html",FileAccess.WRITE)
	preview.store_string("<!doctype html><meta charset='utf-8'><title>Winter wind comparison</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;margin:24px}main{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%}button{padding:10px}</style><h1>Winter wind comparison</h1><p>Actual Godot captures, same camera and modest gust · 6 seconds at 30fps</p><main><section><h2>Previous</h2><img id='old'></section><section><h2>Revised</h2><img id='new'></section></main><button id='toggle'>Pause</button><script>const frames="+JSON.stringify(motion)+";let n=0,playing=true;const a=document.getElementById('old'),b=document.getElementById('new'),button=document.getElementById('toggle');a.src=frames[0][0];b.src=frames[1][0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){n=(n+1)%frames[0].length;a.src=frames[0][n];b.src=frames[1][n]}},1000/30)</script>")
	game.hud.visible = true; root.msaa_3d = saved_aa
