extends SceneTree
## Actual cloud material, opaque bridge, and camera; no account or race writes.
var failures: int = 0
var checks: int = 0
var output: String = "res://../docs/evidence/bridge-dust-followup-2026-10-10/roof"
var projected_control: bool = false
var active_game: Node

func _initialize() -> void: call_deferred("run")

func capture() -> Image:
	for frame: int in range(4):
		active_game.paused = false
		active_game.hud.pause_menu.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument=="--projected-off": projected_control = true
	root.size = Vector2i(1280,900)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var game: Node = load("res://core/game.tscn").instantiate()
	active_game = game
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.race_cues.reset()
	game.camera.speed_zoom_enabled = false
	var span: Dictionary = track.creator_bridges[0]
	var center: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(float(span.length)*0.5,0).rotated(deg_to_rad(float(span.heading)))
	game.camera.follow(center,Vector2.ZERO,0.0,0.0,true)
	var state := VehicleState.new()
	state.position = center
	state.velocity = Vector2(0,12)
	game.sand_dust.sample(state,DriveFrame.new(),track,game.bridge_presentation)
	game.sand_dust.visible = false
	var card := MeshInstance3D.new()
	card.mesh = QuadMesh.new()
	(card.mesh as QuadMesh).size = Vector2(18,18)
	var material: ShaderMaterial = game.sand_dust.dust_emitters[0].draw_pass_1.surface_get_material(0).duplicate()
	# Repeat the roof witness with opaque-depth protection unavailable, as can
	# happen at mobile MSAA resolves; geometric projection must still seal it.
	var shader := Shader.new()
	shader.code = material.shader.code.replace("alpha *= dust_bridge_surface_visibility(opaque_world.xyz/opaque_world.w,dust_center_height);","alpha *= 1.0;")
	shader.code = shader.code.replace("varying vec2 cloud_uv;","uniform float test_birth_height = 0.7;\nvarying vec2 cloud_uv;")
	shader.code = shader.code.replace("dust_center_height = dust_birth_height_available ? INSTANCE_CUSTOM.z : MODEL_MATRIX[3].y;","dust_center_height = test_birth_height;")
	if projected_control: shader.code = shader.code.replace("alpha *= dust_bridge_projected_visibility(dust_world,camera_ray,dust_center_height);","alpha *= 1.0;")
	material.shader = shader
	for uniform: Dictionary in (game.sand_dust.dust_emitters[0].draw_pass_1.surface_get_material(0) as ShaderMaterial).shader.get_shader_uniform_list():
		var value: Variant = (game.sand_dust.dust_emitters[0].draw_pass_1.surface_get_material(0) as ShaderMaterial).get_shader_parameter(uniform.name)
		if value!=null: material.set_shader_parameter(uniform.name,value)
	card.material_override = material
	# Independently stress the bridge guard with both opaque-depth helpers off.
	material.set_shader_parameter("dust_height_occlusion",false)
	# This independent bridge guard stress test retains an oversized card.
	game.add_child(card)
	var folder: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(folder)
	card.visible = false
	var reference: Image = await capture()
	reference.save_png(folder.path_join("reference.png"))
	# Upper-bank dust can originate on a low ramp or linger after leaving it.
	# Its billboard may rise in front of a roof even while its center is below it.
	for upper: bool in [false,true]:
		material.set_shader_parameter("dust_upper_layer",upper)
		var affected: int = 0
		for side: float in [-8.0,0.0,8.0,18.0]:
			card.position = VisualGeometry.world(center+Vector2(0,side))+Vector3.UP*(4.5 if side==18.0 else 0.7)
			card.visible = true
			var image: Image = await capture()
			image.save_png(folder.path_join("%s-%s.png" % ["upper" if upper else "ground",side]))
			for along: float in [9.0,11.0,13.0,15.0,17.0,19.0]:
				for across: float in [-3.5,-2.0,0.0,2.0,3.5]:
					var p: Vector2 = Vector2(span.position[0],span.position[1])+Vector2(along,across).rotated(deg_to_rad(float(span.heading)))
					var pixel: Vector2 = game.camera.unproject_position(VisualGeometry.world(p)+Vector3.UP*(CreatorBridges.height(span,p)+0.025))
					var a: Color = image.get_pixel(roundi(pixel.x),roundi(pixel.y))
					var b: Color = reference.get_pixel(roundi(pixel.x),roundi(pixel.y))
					checks += 1
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255.0: affected += 1
		if affected>0:
			failures += 1
			push_error("%s bank below-roof card bleeds over %d opaque roof samples" % ["upper" if upper else "ground",affected])
	material.set_shader_parameter("dust_upper_layer",true)
	material.set_shader_parameter("test_birth_height",4.0)
	card.position = VisualGeometry.world(center)+Vector3.UP*4.0
	var upper_image: Image = await capture()
	upper_image.save_png(folder.path_join("above-deck.png"))
	var top_pixel: Vector2 = game.camera.unproject_position(VisualGeometry.world(center)+Vector3.UP*3.525)
	var top: Color = upper_image.get_pixel(roundi(top_pixel.x),roundi(top_pixel.y))
	var clean: Color = reference.get_pixel(roundi(top_pixel.x),roundi(top_pixel.y))
	checks += 1
	if maxf(absf(top.r-clean.r),maxf(absf(top.g-clean.g),absf(top.b-clean.b)))<0.02:
		failures += 1
		push_error("Legitimate above-deck dust must remain visible")
	print("DUST_ROOF_OCCLUSION: ",checks," roof samples, ",failures," failures")
	game.free()
	quit(1 if failures else 0)
