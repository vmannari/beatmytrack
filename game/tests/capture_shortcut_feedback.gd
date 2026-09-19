extends SceneTree
## Scripted cut trajectory through the real race session and rendered HUD.
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var document: Dictionary = TrackDocument.create_default()
	document.name = "Shortcut feedback test"
	document.width = 6.0
	document.points = [[0,0],[40,0],[40,8],[0,8],[-20,8],[-20,-20],[0,-20]]
	document.widths = [6.0,6.0,6.0,6.0,6.0,6.0,6.0]
	document.corners = ["sharp","sharp","sharp","sharp","sharp","sharp","sharp"]
	document.layout = TrackDocument.road_layout(document)
	var track: NativeTrack = TrackCompiler.compile(document)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.countdown_label.hide()
	var session := TrackSession.new()
	game.track_session = session
	var path := PackedVector2Array([Vector2.ZERO,Vector2(12,0),Vector2(12,8)])
	var position := Vector2.ZERO
	for i: int in range(path.size()-1):
		var steps: int = ceili(path[i].distance_to(path[i+1])/0.2)
		for j: int in range(steps):
			var previous: Vector2 = path[i].lerp(path[i+1],float(j)/steps)
			position = path[i].lerp(path[i+1],float(j+1)/steps)
			session.advance(track,previous,position,0)
			if session.shortcut_count > 0: break
		if session.shortcut_count > 0: break
	check(session.shortcut_count == 1,"scripted cut generates exactly one actual detector event")
	game.sim.reset(position,0.0)
	game.sim.state.route_index = track.nearest_route(position)
	game.previous_position = position
	game.previous_heading = 0.0
	game.camera.follow(position,Vector2.ZERO,0.0,0.0,true)
	for i: int in range(5):
		game.call("_process",0.016)
		await RenderingServer.frame_post_draw
	check(game.hud.shortcut_notice_label.visible and game.hud.shortcut_notice_label.text == "SHORTCUT  +5s","normal HUD updates preserve the immediate warning")
	check(game.hud.shortcut_penalty_label.text == "SHORTCUT  +5s","accumulated penalty is visible beside race time")
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/shortcut-v4")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join("immediate-warning.png")) == OK,"saved actual gameplay HUD capture")
	root.size = Vector2i(960,540)
	for i: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_visible_rect().encloses(game.hud.shortcut_notice_label.get_global_rect()),"notice fits compact landscape viewport")
	check(game.hud.shortcut_notice_label.get_global_rect().position.y > game.hud.race_timer.get_global_rect().end.y,"notice remains below race clock")
	check(root.get_texture().get_image().save_png(output.path_join("compact-warning.png")) == OK,"saved compact HUD capture")
	for tick: int in range(120): session.advance(track,position,position,0)
	game.call("_process",0.016)
	check(session.shortcut_notice_active() and game.hud.shortcut_notice_label.visible,"warning survives a full second")
	for tick: int in range(120): session.advance(track,position,position,0)
	game.call("_process",0.016)
	check(not session.shortcut_notice_active() and not game.hud.shortcut_notice_label.visible,"transient warning expires after two seconds")
	check(session.shortcut_count == 1 and session.penalty_seconds == 5.0,"stationary notice duration cannot duplicate a penalty")
	game.queue_free()
	for i: int in range(3): await process_frame
	print("SHORTCUT_HUD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
