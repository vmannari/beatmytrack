extends SceneTree

const OUT: String = "res://../docs/evidence/night-impact-glass-2026-11-08"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var track: NativeTrack = TrackCompiler.compile(fixture.document)
	track.metadata.theme = "night_city"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	var glass: ImpactCracks = game.impact_cracks
	check(glass.glass_tint == ImpactCracks.NIGHT_TINT, "actual Night race initializes dark glass")
	glass.restore_damage(Vector4(1.0, 0.5, 0.7, 0.3))
	var damage: Vector4 = glass.side_damage
	game._update_weather()
	check(glass.side_damage == damage and glass.visible, "weather refresh preserves damage")
	glass.clear_effect()
	check(glass.glass_tint == ImpactCracks.NIGHT_TINT and not glass.visible, "restart clearing retains Night tint")
	glass.restore_damage(damage)
	check(glass.material.get_shader_parameter("glass_tint") == ImpactCracks.NIGHT_TINT, "rewind restoration retains Night material")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		# Freeze the rendered backdrop too: Mobile temporal effects can change
		# pixels even without simulation ticks or camera movement.
		if game.paused: game.toggle_pause(false)
		game.preparation_complete = false # Suppress focus-loss pause during capture.
		game.process_mode = Node.PROCESS_MODE_DISABLED
		glass.visible = false
		var backdrop := TextureRect.new()
		backdrop.texture = ImageTexture.create_from_image(await capture())
		backdrop.z_index = 99
		root.add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glass.visible = true
		# Same Night world and damage; white is the original shader appearance.
		glass.configure("pine")
		var original: Image = await capture()
		glass.configure("night_city")
		var night: Image = await capture()
		var changed: int = 0
		var brighter: int = 0
		var before_sum: float = 0.0
		var after_sum: float = 0.0
		for y: int in range(night.get_height()):
			for x: int in range(night.get_width()):
				var a: Color = original.get_pixel(x, y)
				var b: Color = night.get_pixel(x, y)
				if a != b:
					changed += 1
					before_sum += a.get_luminance()
					after_sum += b.get_luminance()
					if b.get_luminance() > a.get_luminance() + 0.01: brighter += 1
		check(changed > 1000 and after_sum < before_sum * 0.8, "native Night glass visibly darkens")
		check(brighter == 0, "tint introduces no brighter pixels")
		var renderer: String = RenderingServer.get_current_rendering_method()
		check(original.save_png(OUT.path_join(renderer + "-before.png")) == OK, "save original comparison")
		check(night.save_png(OUT.path_join(renderer + "-after.png")) == OK, "save Night comparison")
		print("NIGHT_GLASS_PIXELS changed=%d before=%f after=%f brighter=%d" % [changed, before_sum, after_sum, brighter])
		backdrop.free()
	for theme: String in ["pine", "desert", "winter", "storm"]:
		track.metadata.theme = theme
		game._update_weather()
		check(glass.glass_tint == Color.WHITE and glass.side_damage == damage, theme + " retains original glass and damage")
	game.free()
	await process_frame
	print("NIGHT_IMPACT_GLASS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
