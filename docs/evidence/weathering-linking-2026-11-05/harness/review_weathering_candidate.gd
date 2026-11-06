extends SceneTree
const CANDIDATE = preload("res://tests/weathering_candidate.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var pairs: Array = []
var output: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func capture(mode: String, name: String) -> Image:
	for pair: Dictionary in pairs: pair.material.shader = pair[mode]
	for frame: int in range(12): await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image(); result.convert(Image.FORMAT_RGBA8)
	if not name.is_empty(): result.save_png(output.path_join(name+".png"))
	return result
func difference(a: Image,b: Image) -> Dictionary:
	var left: PackedByteArray = a.get_data(); var right: PackedByteArray = b.get_data()
	if left == right: return {"changed":0,"maximum":0}
	var changed: int = 0; var maximum: int = 0
	for pixel: int in range(a.get_width()*a.get_height()):
		var delta: int = 0
		for channel: int in range(3): delta = maxi(delta,absi(left[pixel*4+channel]-right[pixel*4+channel]))
		if delta: changed += 1; maximum = maxi(maximum,delta)
	return {"changed":changed,"maximum":maximum}
func run() -> void:
	output = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.0
	var sun := DirectionalLight3D.new(); world.add_child(sun)
	sun.rotation_degrees = Vector3(-50,-30,0); sun.shadow_enabled = true
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(30,30)
	ground.mesh = plane; ground.material_override = VisualGeometry.material(Color("70757a")); world.add_child(ground)
	var car := CarVisual.new(); car.vehicle_id = "compact"; world.add_child(car)
	while not car.model_ready: await process_frame
	var effect := VehicleWeathering.new(); effect.configure(car,"pine",VehicleCatalog.config("compact"))
	var seen: Dictionary = {}
	for binding: Dictionary in effect.bindings:
		var material: ShaderMaterial = binding.finish
		if seen.has(material): continue
		seen[material] = true
		var role: String = "wheel" if binding.wheel else ("paint" if binding.graphics else ("rear" if material.get_shader_parameter("rear_only") == 1.0 else "front"))
		pairs.append({"material":material,"baseline":material.shader,"candidate":CANDIDATE.shader(material.shader,role,"toon_rear")})
	check(pairs.any(func(pair: Dictionary) -> bool: return pair.baseline != pair.candidate),"candidate changes an actual rear finish")
	for decorated: bool in [false,true]:
		if decorated:
			var livery: Dictionary = VehicleLivery.defaults("compact")
			livery.pattern = LiveryCatalog.patterns[0].id; livery.stickers.hood.id = "crest"
			car.apply_livery(livery); effect.refresh_paint()
		for state: String in ["clean","dirt","snow","wet","mixed","washed"]:
			effect.dirt_amount = 0.65 if state in ["dirt","mixed","washed"] else 0.0
			effect.snow_amount = 0.65 if state == "snow" else (0.25 if state in ["mixed","washed"] else 0.0)
			effect.slow_dirt_amount = 0.3 if state in ["mixed","washed"] else 0.0
			effect.slow_snow_amount = 0.2 if state in ["mixed","washed"] else 0.0
			effect.wetness = 0.8 if state in ["wet","mixed","washed"] else 0.0
			effect.mud_amount = 0.7; effect.smudge = 0.5
			effect._update_finish(true)
			if state == "washed": effect.wash(Vector3(0,0.45,1.9),0.7); effect._update_finish(true)
			var snapshot: Dictionary = effect.snapshot()
			for view: int in range(3):
				camera.position = [Vector3(5,3,6),Vector3(-4,2,6),Vector3(0,6,5)][view]
				camera.look_at(Vector3(0,0.5,0))
				var key: String = str(int(decorated))+"-"+state+"-"+str(view)
				var before: Image = await capture("baseline",key+"-before")
				var after: Image = await capture("candidate",key+"-after")
				var restored: Image = await capture("baseline","")
				var delta: Dictionary = difference(before,after)
				var control: Dictionary = difference(before,restored)
				check(delta.changed == 0,key+" pixel exact")
				check(control.changed == 0,key+" stable original")
				check(effect.snapshot() == snapshot,key+" cosmetics unchanged")
				rows.append({"case":key,"difference":delta,"control":control})
				print("WEATHERING_PIXELS ",JSON.stringify(rows[-1]))
				if not decorated and state == "clean":
					var saved: Array = []
					for pair: Dictionary in pairs:
						if pair.baseline == pair.candidate: continue
						saved.append({"material":pair.material,"color":pair.material.get_shader_parameter("paint_color")})
						pair.material.set_shader_parameter("paint_color",Color(5,0,5))
					var marked: Image = await capture("candidate",key+"-visibility")
					var visible: Dictionary = difference(before,marked)
					check(visible.changed > 0,key+" changed finish actually visible")
					rows[-1]["visibility"] = visible
					for item: Dictionary in saved: item.material.set_shader_parameter("paint_color",item.color)
	FileAccess.open(output.path_join("pixels.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"checks":checks,"failures":failures},"  "))
	effect.reset(); car.free(); world.free()
	print("WEATHERING_PIXELS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
