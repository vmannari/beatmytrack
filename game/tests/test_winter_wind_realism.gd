extends "res://tests/test_winter_local_flow.gd"
const EVIDENCE: String = "res://../docs/evidence/winter-wind-density-2026-10-13"

func _initialize() -> void:
	OUT = EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	super._initialize()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await comparison(game,fx)
	game.hud.pause_menu.hide()
	await super.capture(game,fx)

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
	fx.airborne.multimesh.visible_instance_count = 24
	var before: Image = await settled_frame(game)
	fx.ground_material.shader = ground_shader; fx.powder_material.shader = bank_shader; air_material.shader = air_shader
	fx.airborne.multimesh.visible_instance_count = original_air_count
	var after: Image = await settled_frame(game)
	fx.ground_material.shader = old_wind; fx.powder_material.shader = old_wind; air_material.shader = old_air
	fx.airborne.multimesh.visible_instance_count = 24
	var restored: Image = await settled_frame(game)
	before.save_png(OUT+"/baseline-a.png"); restored.save_png(OUT+"/baseline-b.png")
	check(before.get_data() == restored.get_data(),"paired wind baseline restores pixel-exactly at fixed world clock")
	var road_pixels: int = 0
	var before_lift: float = 0.0
	var after_lift: float = 0.0
	for y: int in range(0,720,2):
		for x: int in range(0,1280,2):
			var base: Color = clear.get_pixel(x,y)
			if base.b <= base.r*1.04 or base.r < 0.15 or base.r > 0.88: continue
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			before_lift += maxf(0.0,(a.r+a.g+a.b-base.r-base.g-base.b)/3.0)
			after_lift += maxf(0.0,(b.r+b.g+b.b-base.r-base.g-base.b)/3.0)
			road_pixels += 1
	check(road_pixels > 1000 and after_lift > before_lift*1.15,"actual paired render shows stronger white powder contribution over cool surfaces")
	check(game.sim.state.snapshot() == snapshot,"wind appearance comparison leaves canonical state exact")
	clear.save_png(OUT+"/clear.png"); before.save_png(OUT+"/previous.png"); after.save_png(OUT+"/refined.png")
	var report := FileAccess.open(OUT+"/comparison.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"cool_surface_pixels":road_pixels,"previous_lift":before_lift,"refined_lift":after_lift,"ratio":after_lift/maxf(before_lift,0.000001),"scope":"fixed-clock paired shader appearance, sampled cool surfaces; not a snow mass or opacity measurement"},"\t"))
	print("WINTER_REALISM_COMPARISON: pixels=",road_pixels," white_lift_ratio=",after_lift/maxf(before_lift,0.000001))
	fx.ground_material.shader = ground_shader; fx.powder_material.shader = bank_shader; air_material.shader = air_shader
	fx.airborne.multimesh.visible_instance_count = original_air_count
	fx.elapsed = original_clock.x; fx.travel = original_clock.y; fx.intensity = original_clock.z
	game.camera.transform = original_camera; game.camera.size = original_size
	game.hud.visible = original_hud
	root.msaa_3d = original_aa
