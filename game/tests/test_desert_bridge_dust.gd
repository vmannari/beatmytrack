extends SceneTree
## Actual relieved bridge, emitted GPU clouds and the production cloud material.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/desert-bridge-dust-2026-11-03/final"
var game: Node

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func capture() -> Image:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func changed_pixels(a: Image, b: Image, camera: Camera3D, center: Vector3) -> int:
	var pixel: Vector2 = camera.unproject_position(center)
	var changed: int = 0
	for y: int in range(roundi(pixel.y)-24,roundi(pixel.y)+25):
		for x: int in range(roundi(pixel.x)-45,roundi(pixel.x)+46):
			var ca: Color = a.get_pixel(x,y); var cb: Color = b.get_pixel(x,y)
			if maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b))) > 0.02: changed += 1
	return changed

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	root.size = Vector2i(1280,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json")))
	var canonical: PackedByteArray = var_to_bytes([track.cells,track.deck_cells,track.route,track.metadata])
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false); game.set_process(false)
	game.paused = false; game.countdown_ticks = 0; game.race_cues.reset()
	game.hud.hide()
	var effects: Node3D = game.sand_dust
	if "--before" in OS.get_cmdline_user_args():
		var legacy := GDScript.new()
		legacy.source_code = FileAccess.get_file_as_string("res://../docs/evidence/desert-bridge-dust-2026-11-03/before/sand_dust.gd").replace("class_name SandDust", "").replace("res://vehicle/dust_bridge_clip.gdshaderinc", "res://../docs/evidence/desert-bridge-dust-2026-11-03/before/dust_bridge_clip.gdshaderinc")
		check(legacy.reload() == OK,"task-start dust script loads")
		game.sand_dust.visible = false
		effects = legacy.new(); game.add_child(effects)
	var span: Dictionary = track.creator_bridges[0]
	var origin := Vector2(span.position[0],span.position[1])
	var angle: float = deg_to_rad(float(span.heading))
	var center: Vector2 = origin+Vector2(float(span.length)*0.5,0).rotated(angle)
	var state := VehicleState.new()
	state.position = center; state.track_elevated = true; state.velocity = Vector2(12,0).rotated(angle)
	state.heading = PI*0.5-angle
	var snapshot: Array = state.snapshot()
	game.camera.speed_zoom_enabled = false
	game.camera.follow(center,Vector2.ZERO,state.heading,0.0,true)
	# Exercise normal preparation followed by live sampling of the same track.
	effects.prepare_track(track)
	effects.sample(state,DriveFrame.new(),track,game.bridge_presentation)
	var birth: float = effects.deck_dust_emitters[0].position.y
	var relief: float = game.bridge_presentation.visual_offset(center)
	check(is_equal_approx(relief,-preload("res://track/desert_road_relief.gd").DEPTH),"compiled bridge has the real desert road depression")
	check(absf(birth-(CreatorBridges.HEIGHT+relief+0.025)) < 0.001,"wheel cloud is born on the visible bridge")
	check(effects.deck_dust_emitters.all(func(e: GPUParticles3D) -> bool: return e.emitting),"all four deck wheel clouds emit")
	check(effects.dust_emitters.all(func(e: GPUParticles3D) -> bool: return not e.emitting),"ground bank stays dormant above the bridge")
	await create_timer(2.0).timeout
	for emitter: GPUParticles3D in effects.get_children(): emitter.speed_scale = 0.0
	var emitted: Image = await capture()
	emitted.save_png(output.path_join("emitted-deck.png"))
	effects.visible = false
	var clean: Image = await capture()
	clean.save_png(output.path_join("clean-deck.png"))
	var road: Vector3 = VisualGeometry.world(center)+Vector3.UP*(CreatorBridges.HEIGHT+relief+0.025)
	var count: int = changed_pixels(emitted,clean,game.camera,road)
	print("EMITTED_DECK_CHANGED_PIXELS: ",count)
	check(count > 200,"actual emitted dust visibly covers the relieved bridge")
	# A newly born particle must also be visible before it lofts. Use the exact
	# production draw shader with controlled birth data, not a substitute mask.
	var source: ShaderMaterial = effects.deck_dust_emitters[0].draw_pass_1.surface_get_material(0)
	var material: ShaderMaterial = source.duplicate()
	var shader := Shader.new()
	shader.code = source.shader.code.replace("varying vec2 cloud_uv;","uniform float test_birth_height;\nvarying vec2 cloud_uv;").replace("dust_center_height = dust_birth_height_available ? INSTANCE_CUSTOM.z : MODEL_MATRIX[3].y;","dust_center_height = test_birth_height;")
	material.shader = shader
	for uniform: Dictionary in source.shader.get_shader_uniform_list():
		var value: Variant = source.get_shader_parameter(uniform.name)
		if value != null: material.set_shader_parameter(uniform.name,value)
	material.set_shader_parameter("test_birth_height",birth)
	var card := MeshInstance3D.new()
	card.mesh = effects.deck_dust_emitters[0].draw_pass_1.duplicate()
	card.material_override = material; card.position = road+Vector3.UP*0.30
	game.add_child(card)
	var newborn: Image = await capture()
	newborn.save_png(output.path_join("newborn-deck.png"))
	count = changed_pixels(newborn,clean,game.camera,road)
	print("NEWBORN_DECK_CHANGED_PIXELS: ",count)
	check(count > 200,"newly born deck dust is visible before rising past the old bridge height")
	card.hide()
	# Low ramp clouds may not project over a taller roof, even after lofting.
	material.set_shader_parameter("test_birth_height",0.7+relief)
	card.show()
	var blocked: Image = await capture()
	blocked.save_png(output.path_join("blocked-low-ramp.png"))
	check(changed_pixels(blocked,clean,game.camera,road) == 0,"low ramp birth remains blocked by the higher deck")
	check(snapshot == state.snapshot(),"sampling retains canonical vehicle state")
	check(canonical == var_to_bytes([track.cells,track.deck_cells,track.route,track.metadata]),"presentation retains canonical track data")
	game.free()
	await process_frame
	print("DESERT_BRIDGE_DUST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
