extends "res://tests/test_winter_snow_wind.gd"
const EVIDENCE: String = "res://../docs/evidence/winter-road-edge-snow-2026-10-24/"

func _initialize() -> void:
	OUT = EVIDENCE + RenderingServer.get_current_rendering_method()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func make_track() -> NativeTrack:
	var track: NativeTrack = super.make_track()
	var snapshot: PackedByteArray = var_to_bytes([track.metadata, track.cells, track.deck_cells, track.snow_banks.triangles])
	var sources: RefCounted = preload("res://track/winter_road_snow_sources.gd").new()
	sources.prepare(track)
	var pinned: bool = not sources.origins.is_empty()
	var enters_road: bool = true
	for point: Vector2 in sources.origins:
		var closest: float = INF
		for polygon: PackedVector2Array in sources.polygons:
			for i: int in range(polygon.size()): closest = minf(closest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])))
		pinned = pinned and closest < 0.0001
		var inside: bool = false; var outside: bool = true
		for polygon: PackedVector2Array in sources.polygons:
			inside = inside or Geometry2D.is_point_in_polygon(point + WinterSnowWind.WIND * 0.02, polygon)
			outside = outside and not Geometry2D.is_point_in_polygon(point - WinterSnowWind.WIND * 0.02, polygon)
		enters_road = enters_road and inside and outside and not CreatorBridges.at_any(track.creator_bridges, point)
	check(pinned, "every source is pinned to the exact rendered road outline")
	check(enters_road, "sources start on the exposed upwind road boundary, including curved edges")
	check(sources.image.get_width() <= 512 and sources.image.get_height() <= 512 and not sources.image.has_mipmaps(), "one static bounded nearest-sampled source lookup")
	check(snapshot == var_to_bytes([track.metadata, track.cells, track.deck_cells, track.snow_banks.triangles]), "edge-source preparation preserves authored content and canonical contacts exactly")
	print("WINTER_EDGE_ORIGINS: ", sources.origins.size(), " lookup=", sources.image.get_size())
	return track

func settle(game: Node) -> Image:
	game.paused = false; game.hud.pause_menu.hide(); game.hud.message_label.hide()
	game.winter_snow_wind.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	for frame: int in range(5): await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func edge_mode(fx: WinterSnowWind, enabled: bool) -> void:
	for material: ShaderMaterial in fx.surface_materials + [fx.ground_material, fx.powder_material, fx.airborne.material_override]: material.set_shader_parameter("snow_edge_sources", enabled)

func capture(game: Node, fx: WinterSnowWind) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check(not fx.surface_materials.is_empty(), "actual Winter Game binds the opaque snow and road finishes")
	check(fx.surface_materials.all(func(material: ShaderMaterial) -> bool: return material.get_shader_parameter("snow_edge_sources") == true and material.get_shader_parameter("snow_road_sources") == fx.road_sources.texture), "all run-owned snow finishes share the same road-edge sources")
	check(fx.ground.multimesh.visible_instance_count == 0 and fx.powder.multimesh.visible_instance_count == 0 and fx.airborne.multimesh.instance_count == 48, "surface integration and existing 48-grain budget remain")
	await shape_equivalence()
	root.size = Vector2i(1280, 720)
	game.sim.state.position = Vector2(0, -18); game.previous_position = game.sim.state.position
	game.call("_process", 0.0)
	game.camera.follow(game.sim.state.position, Vector2.ZERO, 0.0, 0.0, true)
	var state: Array = game.sim.state.snapshot().duplicate(true)
	var samples: Array[Dictionary] = []
	var best: int = 0
	var snow_peak: int = 0
	var before_image: Image; var after_image: Image
	var current_image: Image
	for time: float in [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]:
		fx.elapsed = time; fx.travel = time * 13.5; fx.intensity = 0.2025
		fx.present(0.0, game.sim.state.position, 0.25, false, false)
		fx.visible = false
		var baseline: Image = await settle(game)
		fx.visible = true
		edge_mode(fx, false)
		var before: Image = await settle(game)
		edge_mode(fx, true)
		var after: Image = await settle(game)
		current_image = after
		var changed: int = 0; var snow_pixels: int = 0; var roof: int = 0; var overpainted: int = 0
		for y: int in range(720):
			for x: int in range(1280):
				if before.get_pixel(x, y) != after.get_pixel(x, y): changed += 1
				var delta: Color = after.get_pixel(x, y) - baseline.get_pixel(x, y)
				if maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) > 0.005: snow_pixels += 1
				if x >= 616 and x <= 660 and y >= 320 and y < 358 and warm_roof(before.get_pixel(x, y)):
					roof += 1
					if before.get_pixel(x, y) != after.get_pixel(x, y): overpainted += 1
		check(roof > 100 and overpainted == 0, "relocating source windows preserves every opaque roof pixel at " + str(time))
		snow_peak = maxi(snow_peak, snow_pixels)
		samples.append({"seconds":time,"changed":changed,"snow_pixels":snow_pixels,"roof":roof,"overpainted":overpainted})
		if changed > best: best = changed; before_image = before; after_image = after
	check(best > 1000, "road-edge source placement visibly changes actual Game snow locations")
	check(snow_peak > 500, "the relocated snow remains visible in the ordinary Game camera")
	check(state == game.sim.state.snapshot(), "native source relocation leaves the driving snapshot exact")
	before_image.save_png(OUT + "/before.png"); after_image.save_png(OUT + "/after.png")
	fx.visible = false
	var clean: Image = await settle(game)
	fx.visible = true
	check((await settle(game)).get_data() == current_image.get_data(), "visibility toggle restores the exact frozen snow pixels")
	clean.save_png(OUT + "/without-snow.png")
	var frames: Array[String] = []
	fx.elapsed = 0.0; fx.travel = 0.0; fx.intensity = 0.2025; fx.motion_intensity = 0.25
	for frame: int in range(120):
		fx.present(1.0 / 15.0, game.sim.state.position, 0.25, false, false)
		await settle(game)
		var filename: String = "frame-%03d.jpg" % frame
		root.get_texture().get_image().save_jpg(OUT + "/" + filename, 0.92)
		frames.append(filename)
	var output := FileAccess.open(OUT + "/capture.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"samples":samples,"peak_changed":best,"snow_peak":snow_peak,"origins":fx.road_sources.origins.size(),"lookup":[fx.road_sources.image.get_width(),fx.road_sources.image.get_height()],"frames":frames}, "\t"))
	print("WINTER_EDGE_CAPTURE: changed=", best, " snow_pixels=", snow_peak, " origins=", fx.road_sources.origins.size())

func shape_equivalence() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180); viewport.disable_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rectangle := ColorRect.new(); rectangle.size = Vector2(viewport.size)
	var original: String = FileAccess.get_file_as_string(EVIDENCE + "before/game/track/winter_wind_variation.gdshaderinc").replace("snow_", "old_snow_")
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" + original + """
#include "res://track/winter_wind_variation.gdshaderinc"
uniform float clock;
uniform bool compare = true;
void fragment() {
    vec2 cell = floor(texture(snow_road_sources,vec2(0.5)).xy/vec2(18.0,10.0));
    float seed = snow_patch_random(cell).z;
    float period = mix(8.0,13.0,seed);
    float cycle = floor((clock+seed*period)/period);
    vec3 random = snow_patch_random(cell+vec2(cycle*19.19,cycle*7.73)+17.0);
    vec2 radius = mix(vec2(6.2,2.4),vec2(7.6,3.6),random.yz);
    vec2 p = vec2(UV.x*radius.x*2.0,(UV.y*2.0-1.0)*radius.y);
    vec2 old_center = (cell+0.5)*vec2(18.0,10.0)+(random.xy-0.5)*vec2(2.0,1.4);
    vec3 actual = snow_local_event(p,clock);
    vec3 prior = old_snow_local_event(p+old_center-vec2(radius.x,0.0),clock);
    COLOR = vec4(compare ? abs(actual-prior) : vec3(actual.x),1.0);
}
"""
	var material := ShaderMaterial.new(); material.shader = shader
	var image := Image.create(1, 1, false, Image.FORMAT_RGBAF); image.set_pixel(0, 0, Color(0, 0, 0, 1))
	material.set_shader_parameter("snow_edge_sources", true); material.set_shader_parameter("snow_road_sources", ImageTexture.create_from_image(image)); material.set_shader_parameter("snow_source_bounds", Vector4(-32, -32, 64, 64))
	rectangle.material = material; viewport.add_child(rectangle)
	for clock: float in [0.5, 2.0, 4.0, 6.0, 9.0, 13.0, 17.0]:
		material.set_shader_parameter("clock", clock)
		for frame: int in range(4): await RenderingServer.frame_post_draw
		var result: Image = viewport.get_texture().get_image()
		var maximum: float = 0.0
		for y: int in range(result.get_height()):
			for x: int in range(result.get_width()):
				var value: Color = result.get_pixel(x, y)
				maximum = maxf(maximum, maxf(value.r, maxf(value.g, value.b)))
		check(maximum < 0.005, "GPU source relocation preserves the exact original window shape at " + str(clock))
		print("WINTER_WINDOW_DIFF: clock=", clock, " maximum=", maximum)
	material.set_shader_parameter("compare", false); material.set_shader_parameter("clock", 2.0)
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var active_image: Image = viewport.get_texture().get_image()
	var active: int = 0
	for y: int in range(active_image.get_height()):
		for x: int in range(active_image.get_width()):
			if active_image.get_pixel(x, y).r > 0.02: active += 1
	check(active > 1000, "shape comparison exercises a visible anchored stream rather than empty output")
	viewport.queue_free(); await process_frame
