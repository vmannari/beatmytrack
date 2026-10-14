extends "res://tests/test_winter_local_flow.gd"
const EVIDENCE: String = "res://../docs/evidence/winter-wind-flow-2026-10-13"

func _initialize() -> void:
	OUT = EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	super._initialize()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await comparison(game,fx)
	game.hud.pause_menu.hide()
	await super.capture(game,fx)
	await speed_probe(game,fx)

func settled_frame(game: Node) -> Image:
	# Shader/sky uploads can complete incrementally after switching variants.
	# Reassert the fixed world clock on each material and settle before readback.
	var fx: WinterSnowWind = game.winter_snow_wind
	for material: ShaderMaterial in [fx.ground_material,fx.powder_material,fx.airborne.material_override]:
		material.set_shader_parameter("elapsed",7.5)
		material.set_shader_parameter("travel",95.0)
		material.set_shader_parameter("strength",1.0)
		material.set_shader_parameter("focus",Vector3(34,0,10))
	fx.ground_material.set_shader_parameter("bank",false)
	fx.powder_material.set_shader_parameter("bank",true)
	for index: int in range(40):
		game.hud.pause_menu.hide()
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func comparison(game: Node, fx: WinterSnowWind) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var original_camera: Transform3D = game.camera.transform
	var original_size: float = game.camera.size
	var original_hud: bool = game.hud.visible
	var original_aa: Viewport.MSAA = root.msaa_3d
	var original_clock: Vector3 = Vector3(fx.elapsed,fx.travel,fx.intensity)
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	root.size = Vector2i(1280,720)
	# Isolate shader contribution from 1/255 mixed MSAA-edge quantization.
	# Normal MSAA car protection is tested separately by the inherited suite.
	root.msaa_3d = Viewport.MSAA_DISABLED
	game.hud.visible = false
	var focus := Vector3(34,0,10)
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus)
	game.camera.size = 29.0
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.elapsed = 7.5; fx.travel = 95; fx.intensity = 1
	fx.present(0.0,Vector2(34,-10),1.0,false,false)
	var old_wind := Shader.new()
	var old_air := Shader.new()
	var include_path: String = 'res://track/winter_wind_variation.gdshaderinc'
	var helper: String = FileAccess.get_file_as_string(EVIDENCE+"/before/game__track__winter_wind_variation.gdshaderinc")
	old_wind.code = FileAccess.get_file_as_string(EVIDENCE+"/before/game__track__winter_snow_wind.gdshader").replace('#include "'+include_path+'"',helper)
	old_air.code = FileAccess.get_file_as_string(EVIDENCE+"/before/game__track__winter_air_snow.gdshader").replace('#include "'+include_path+'"',helper)
	var ground_shader: Shader = fx.ground_material.shader
	var bank_shader: Shader = fx.powder_material.shader
	var air_material: ShaderMaterial = fx.airborne.material_override
	var air_shader: Shader = air_material.shader
	var original_air_count: int = fx.airborne.multimesh.visible_instance_count
	fx.visible = false
	var clear: Image = await settled_frame(game)
	fx.visible = true
	fx.ground_material.shader = old_wind; fx.powder_material.shader = old_wind; air_material.shader = old_air
	fx.airborne.multimesh.visible_instance_count = original_air_count
	var before: Image = await settled_frame(game)
	fx.ground_material.shader = ground_shader; fx.powder_material.shader = bank_shader; air_material.shader = air_shader
	fx.airborne.multimesh.visible_instance_count = original_air_count
	var after: Image = await settled_frame(game)
	fx.ground_material.shader = old_wind; fx.powder_material.shader = old_wind; air_material.shader = old_air
	fx.airborne.multimesh.visible_instance_count = original_air_count
	var restored: Image = await settled_frame(game)
	before.save_png(OUT+"/baseline-a.png"); restored.save_png(OUT+"/baseline-b.png")
	check(before.get_data() == restored.get_data(),"paired wind baseline restores pixel-exactly at fixed world clock")
	var road_pixels: int = 0
	var before_lift: float = 0.0
	var after_lift: float = 0.0
	var changed: int = 0
	for y: int in range(0,720,2):
		for x: int in range(0,1280,2):
			var base: Color = clear.get_pixel(x,y)
			if base.b <= base.r*1.04 or base.r < 0.15 or base.r > 0.88: continue
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if a != b: changed += 1
			before_lift += maxf(0.0,(a.r+a.g+a.b-base.r-base.g-base.b)/3.0)
			after_lift += maxf(0.0,(b.r+b.g+b.b-base.r-base.g-base.b)/3.0)
			road_pixels += 1
	check(road_pixels > 1000 and changed > 500 and after_lift > 1.0,"actual paired render shows broken white powder morphology over cool surfaces")
	check(game.sim.state.snapshot() == snapshot,"wind appearance comparison leaves canonical state exact")
	clear.save_png(OUT+"/clear.png"); before.save_png(OUT+"/previous.png"); after.save_png(OUT+"/refined.png")
	var report := FileAccess.open(OUT+"/comparison.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"cool_surface_pixels":road_pixels,"changed_samples":changed,"previous_lift":before_lift,"refined_lift":after_lift,"ratio":after_lift/maxf(before_lift,0.000001),"scope":"fixed-clock paired shader appearance, sampled cool surfaces; not a snow mass or opacity measurement"},"\t"))
	print("WINTER_REALISM_COMPARISON: pixels=",road_pixels," white_lift_ratio=",after_lift/maxf(before_lift,0.000001))
	fx.ground_material.shader = ground_shader; fx.powder_material.shader = bank_shader; air_material.shader = air_shader
	fx.airborne.multimesh.visible_instance_count = original_air_count
	fx.elapsed = original_clock.x; fx.travel = original_clock.y; fx.intensity = original_clock.z
	game.camera.transform = original_camera; game.camera.size = original_size
	game.hud.visible = original_hud
	root.msaa_3d = original_aa

func speed_probe(game: Node, fx: WinterSnowWind) -> void:
	var saved_camera: Transform3D = game.camera.transform
	var saved_size: float = game.camera.size
	var saved_view: Vector2i = root.size
	var saved_aa: Viewport.MSAA = root.msaa_3d
	var saved_hud: bool = game.hud.visible
	var saved_fog: bool = game.biome_environment.fog_enabled
	var saved_powder: bool = fx.powder.visible
	var saved_air: bool = fx.airborne.visible
	var saved_shader: Shader = fx.ground_material.shader
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	root.size = Vector2i(640,360)
	root.msaa_3d = Viewport.MSAA_DISABLED
	game.hud.visible = false
	game.biome_environment.fog_enabled = false
	fx.powder.visible = false; fx.airborne.visible = false
	var focus := Vector3(34,0,10)
	game.camera.position = focus+Vector3(0,20,15)
	game.camera.look_at(focus); game.camera.size = 29.0
	var results: Array[Dictionary] = []
	for revised: bool in [false,true]:
		var helper: String = FileAccess.get_file_as_string("res://track/winter_wind_variation.gdshaderinc" if revised else EVIDENCE+"/before/game__track__winter_wind_variation.gdshaderinc")
		var source: String = saved_shader.code if revised else FileAccess.get_file_as_string(EVIDENCE+"/before/game__track__winter_snow_wind.gdshader")
		source = source.replace('#include "res://track/winter_wind_variation.gdshaderinc"',helper)
		source = source.left(source.find("void fragment()"))
		source = source.replace("void vertex()", "varying vec2 flow_rate;\nvoid vertex()")
		source = source.replace("local_gust = snow_local_gust(point,elapsed);", "flow_rate = (snow_flow_offset(point,elapsed+0.025)-snow_flow_offset(point,elapsed-0.025))/0.05;\nlocal_gust = snow_local_gust(point,elapsed);")
		# Solve the actual interpolated phase map's Eulerian velocity. This
		# measures spatial speed, not just offsets or per-instance random values.
		var field: String = "point+flow_offset"+("+snow_spatial_offset(point)" if revised else "")
		source += """
void fragment() {
	vec2 wind = vec2(0.91,-0.414608);
	vec2 point = vec2(dot(world_position.xz,wind),dot(world_position.xz,vec2(-wind.y,wind.x)));
	vec2 field = FIELD;
	vec2 dx = dFdx(point), dy = dFdy(point);
	float screen_det = dx.x*dy.y-dy.x*dx.y;
	vec2 a = (dFdx(field)*dy.y-dFdy(field)*dx.y)/screen_det;
	vec2 b = (-dFdx(field)*dy.x+dFdy(field)*dx.x)/screen_det;
	float det = a.x*b.y-a.y*b.x;
	vec2 rhs = vec2(21.6,0.0)-flow_rate;
	vec2 velocity = vec2(b.y*rhs.x-b.x*rhs.y,-a.y*rhs.x+a.x*rhs.y)/det;
	ALBEDO = vec3(velocity.x/100.0,velocity.y/40.0+0.5,0.0);
	ALPHA = 1.0;
}
""".replace("FIELD",field)
		var probe := Shader.new()
		probe.code = source.replace("diffuse_lambert","unshaded")
		if not revised:
			var calibration := Shader.new()
			calibration.code = probe.code.left(probe.code.find("void fragment()"))+"void fragment() { ALBEDO = vec3(0.216,0.5,0.0); ALPHA = 1.0; }"
			fx.ground_material.shader = calibration
			for frame: int in range(8): await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var count: int = 0; var error: float = 0.0
			for y: int in range(0,root.size.y,3):
				for x: int in range(0,root.size.x,3):
					var pixel: Color = image.get_pixel(x,y)
					if pixel.b > 0.01 or pixel.r < 0.05: continue
					var decoded: Color = pixel if RenderingServer.get_current_rendering_method() == "gl_compatibility" else pixel.srgb_to_linear()
					error = maxf(error,absf(decoded.r*100.0-21.6)); count += 1
			print("WINTER_SPEED_CALIBRATION: samples=",count," max_error_mps=",error)
			check(count > 500 and error < 0.6,"GPU velocity diagnostic resolves a known 21.6mps calibration on this renderer")
		fx.ground_material.shader = probe
		var minimum: float = INF; var maximum: float = -INF
		var means: Array[float] = []
		var samples: int = 0
		for clock: float in [1.0,2.5,5.0]:
			fx.ground_material.set_shader_parameter("elapsed",clock)
			for frame: int in range(8): await RenderingServer.frame_post_draw
			var rendered: Image = root.get_texture().get_image()
			var total: float = 0.0; var count: int = 0
			for y: int in range(3,root.size.y-3,3):
				for x: int in range(3,root.size.x-3,3):
					var pixel: Color = rendered.get_pixel(x,y)
					if pixel.b > 0.01 or pixel.r < 0.05 or pixel.r > 0.98: continue
					# Compatibility writes this unshaded numeric ALBEDO directly;
					# Mobile's output attachment performs linear-to-sRGB encoding.
					var decoded: Color = pixel if RenderingServer.get_current_rendering_method() == "gl_compatibility" else pixel.srgb_to_linear()
					var velocity: float = decoded.r*100.0
					minimum = minf(minimum,velocity); maximum = maxf(maximum,velocity)
					total += velocity; count += 1
			means.append(total/maxi(count,1)); samples += count
			if revised and clock == 5.0:
				for frame: int in range(3): await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().get_data() == rendered.get_data(),"fixed presentation clock freezes measured Eulerian flow exactly")
			if clock == 2.5: rendered.save_png(OUT+("/flow-velocity-new.png" if revised else "/flow-velocity-old.png"))
		results.append({"revised":revised,"samples":samples,"min_mps":minimum,"max_mps":maximum,"spread_mps":maximum-minimum,"means_mps":means})
	var old: Dictionary = results[0]; var current: Dictionary = results[1]
	var means: Array = current.means_mps
	var report := FileAccess.open(OUT+"/flow-speed.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"results":results,"scope":"GPU derivatives of production phase map, finite-difference temporal rate, fixed 21.6mps prevailing travel; opaque diagnostic excludes density and wind occupancy"},"\t"))
	print("WINTER_FLOW_SPEED: ",JSON.stringify(results))
	check(current.samples > 500,"GPU speed probe samples multiple actual world regions")
	check(current.max_mps/current.min_mps > 1.8 and current.spread_mps > 12.0,"actual world flow has substantial spatial transport-speed variation")
	check(current.spread_mps > old.spread_mps*1.2,"spatial transport-speed range is visibly broader than previous wind")
	check(float(means.max())-float(means.min()) > 1.5,"world flow changes speed through unequal temporal gust phases")
	check(game.sim.state.snapshot() == snapshot,"spatial flow diagnostic leaves canonical state exact")
	fx.ground_material.shader = saved_shader
	fx.powder.visible = saved_powder; fx.airborne.visible = saved_air
	game.hud.visible = saved_hud; game.biome_environment.fog_enabled = saved_fog
	game.camera.transform = saved_camera; game.camera.size = saved_size
	root.size = saved_view; root.msaa_3d = saved_aa
