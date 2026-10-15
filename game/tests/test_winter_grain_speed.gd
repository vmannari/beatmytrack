extends "res://tests/test_winter_local_streams.gd"
const GRAIN_EVIDENCE: String = "res://../docs/evidence/winter-grain-speed-2026-10-14"

func _initialize() -> void:
	OUT = GRAIN_EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func capture(game: Node, fx: WinterSnowWind) -> void:
	await super.capture(game,fx)
	await speed_and_grain_probe()

func probe_picture(viewport: SubViewport) -> Image:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func grain_stats(picture: Image) -> Dictionary:
	var values: Array[float] = []
	var total: float = 0.0; var edges: float = 0.0
	for y: int in range(picture.get_height()):
		for x: int in range(picture.get_width()):
			var value: float = picture.get_pixel(x,y).r
			values.append(value); total += value
			if x > 0: edges += absf(value-picture.get_pixel(x-1,y).r)
			if y > 0: edges += absf(value-picture.get_pixel(x,y-1).r)
	values.sort()
	return {"core":values[int(values.size()*0.995)],"edge_to_amount":edges/maxf(total,0.001)}

func speed_and_grain_probe() -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(960,576)
	viewport.disable_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rectangle := ColorRect.new(); rectangle.size = Vector2(viewport.size)
	var material := ShaderMaterial.new(); var speed_shader := Shader.new()
	speed_shader.code = "shader_type canvas_item;\n#include \"res://track/winter_wind_variation.gdshaderinc\"\nuniform float clock;\nvoid fragment(){vec2 p=(UV-0.5)*vec2(144.0,90.0);vec3 event=snow_local_event(p,clock);float shear=(snow_flow_offset(p,clock+0.01).x-snow_flow_offset(p,clock-0.01).x)/0.02;float speed=(12.0+event.z-shear)/snow_flow_gradient(p);COLOR=vec4(speed/32.0,event.x,0.0,1.0);}\n"
	material.shader = speed_shader; rectangle.material = material; viewport.add_child(rectangle)
	var speeds: Array[Image] = []
	for clock: float in [3.0,3.5,3.0]:
		material.set_shader_parameter("clock",clock); speeds.append(await probe_picture(viewport))
	var minimum: float = INF; var maximum: float = -INF; var varying: int = 0
	for y: int in range(viewport.size.y):
		for x: int in range(viewport.size.x):
			var first: Color = speeds[0].get_pixel(x,y)
			var later: Color = speeds[1].get_pixel(x,y)
			if first.g > 0.7:
				minimum = minf(minimum,first.r*32.0); maximum = maxf(maximum,first.r*32.0)
			if first.g > 0.7 and later.g > 0.7 and absf(first.r-later.r)*32.0 > 1.0: varying += 1
	check(minimum > 0.0 and maximum < 32.0 and maximum-minimum > 8.0,"actual GPU phase speed varies substantially across active streams without reversing")
	check(varying > 50,"active local streams accelerate/decelerate over half a second")
	check(speeds[0].get_data() == speeds[2].get_data(),"local speed field restores exactly at the same presentation clock")
	var helper: String = "res://track/winter_wind_variation.gdshaderinc"
	var include: String = '#include "'+helper+'"'
	var before: String = GRAIN_EVIDENCE+"/before/"
	var old_ground: String = FileAccess.get_file_as_string(before+"game__track__winter_ground_snow.gdshaderinc").replace("\r\n","\n")
	old_ground = old_ground.replace(include,FileAccess.get_file_as_string(before+"game__track__winter_wind_variation.gdshaderinc").replace("\r\n","\n"))
	var new_ground: String = FileAccess.get_file_as_string("res://track/winter_ground_snow.gdshaderinc")
	var statistics: Array[Dictionary] = []
	for revised: bool in [false,true]:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\n"+(new_ground if revised else old_ground)+"\nvoid fragment(){float powder=winter_ground_powder((UV-0.5)*vec2(40.0,24.0),1.0);COLOR=vec4(vec3(powder),1.0);}\n"
		material.shader = shader
		material.set_shader_parameter("wind_surface_strength",0.45)
		material.set_shader_parameter("wind_surface_elapsed",3.0)
		material.set_shader_parameter("wind_surface_travel",54.0)
		material.set_shader_parameter("wind_surface_focus",Vector2.ZERO)
		material.set_shader_parameter("wind_surface_car",Vector2(1000,1000))
		material.set_shader_parameter("wind_surface_flow",preload("res://assets/textures/winter_wind_flow_v1.png"))
		var picture: Image = await probe_picture(viewport)
		statistics.append(grain_stats(picture))
		picture.save_png(OUT+("/grain-revised.png" if revised else "/grain-previous.png"))
	check(statistics[1].core > statistics[0].core*1.4,"shipping powder function has denser resolved grain cores than the previous version")
	check(statistics[1].edge_to_amount > statistics[0].edge_to_amount*1.12,"shipping powder function has more fine grain contrast relative to its total contribution")
	var result := {"renderer":RenderingServer.get_current_rendering_method(),"active_phase_speed_min":minimum,"active_phase_speed_max":maximum,"temporally_varying_samples":varying,"grain_previous":statistics[0],"grain_revised":statistics[1],"scope":"actual shared GPU functions, calm12mps phase base; coefficients are not physical snow opacity"}
	var report := FileAccess.open(OUT+"/grain-speed.json",FileAccess.WRITE); report.store_string(JSON.stringify(result,"\t"))
	print("WINTER_GRAIN_SPEED: ",result)
	viewport.queue_free()
