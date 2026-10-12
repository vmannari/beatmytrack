extends SceneTree
## Frozen presentation-only bridge witness; no app/account/score writes.
class Probe extends "res://diagnostics/mobile_race_probe.gd":
	func _ready() -> void: set_process(false)
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,1100)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.race_cues.reset()
	game.camera.speed_zoom_enabled = false
	var state: VehicleState = game.sim.state
	state.position = Vector2(-3,-30)
	state.heading = 0
	state.velocity = Vector2(0,12)
	game.previous_position = state.position
	game.previous_heading = state.heading
	game.camera.follow(state.position,Vector2.ZERO,state.heading,0.0,true)
	var dust: SandDust = game.sand_dust
	for index: int in range(160):
		game.paused = false
		game.call("_process",0.0)
		dust.sample(state,DriveFrame.new(),track,game.bridge_presentation)
		await create_timer(0.025).timeout
	for emitter: GPUParticles3D in dust.dust_emitters+dust.tyre_emitters: emitter.speed_scale = 0.0
	var probe := Probe.new()
	probe.game = game
	probe.probe_track = track
	probe.original_msaa = root.msaa_3d
	root.add_child(probe)
	probe.call("_bridge_review_pose")
	if game.is_physics_processing() or game.sim.state.track_elevated: failures += 1
	var before: Array = state.snapshot()
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/tablet-shadow-dust-2026-10-09/desktop")
	var features: PackedStringArray = PackedStringArray(["msaa_2x","msaa_2x_fragment_depth","msaa_2x_vertex_depth","msaa_2x_no_fade","msaa_2x_late_depth"])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): folder = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
		if argument.begins_with("--features="): features = argument.trim_prefix("--features=").split(",")
	DirAccess.make_dir_recursive_absolute(folder)
	var captures: Dictionary = {}
	for feature: String in features:
		dust.visible = feature!="no_dust"
		probe.call("_configure_dust_depth",feature)
		for emitter: GPUParticles3D in dust.dust_emitters+dust.tyre_emitters:
			var material: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0)
			if material.get_shader_parameter("billowing")!=true or not material.get_shader_parameter("dust_texture") is Texture2D: failures += 1
		for frame: int in range(5): await process_frame
		await RenderingServer.frame_post_draw
		var captured: Image = root.get_texture().get_image()
		captures[feature] = captured
		if captured.save_png(folder.path_join(feature+".png"))!=OK: failures += 1
		if state.snapshot()!=before: failures += 1
		print("DUST_DEPTH_CAPTURE ",feature)
	if captures.has("baseline") and captures.has("no_dust"):
		var span: Dictionary = track.creator_bridges[0]
		for along: float in [12.0,16.0,20.0]:
			for across: float in [-1.5,0.0,1.5]:
				var point: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(along,across).rotated(deg_to_rad(float(span.heading)))
				var pixel: Vector2 = game.camera.unproject_position(VisualGeometry.world(point)+Vector3.UP*(CreatorBridges.height(span,point)+0.025))
				var a: Color = captures.baseline.get_pixel(roundi(pixel.x),roundi(pixel.y))
				var b: Color = captures.no_dust.get_pixel(roundi(pixel.x),roundi(pixel.y))
				if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255.0: failures += 1
		print("DUST_ROOF_REFERENCE: 9 opaque deck pixels compared to dust-hidden scene")
	dust.visible = true
	probe.call("_configure_dust_depth","baseline")
	probe.free()
	game.free()
	print("DUST_DEPTH_CAPTURE_FAILURES: ",failures)
	quit(1 if failures else 0)
