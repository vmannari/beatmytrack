extends "res://tests/test_desert_dune_edges.gd"
const BEFORE: String = "res://tests/fixtures/desert_phone_performance_before/desert_sand_wind.gd.txt"
var baseline: GDScript

func _initialize() -> void:
	super._initialize()
	capture_out = "res://../docs/evidence/desert-phone-performance-2026-10-25/focused/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): capture_out = argument.trim_prefix("--evidence=").trim_suffix("/") + "/"

func actual_app(track: NativeTrack) -> void:
	baseline = GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string(BEFORE).replace("class_name DesertSandWind\r\n", "").replace("class_name DesertSandWind\n", "")
	check(baseline.reload() == OK, "task-entry source selector compiles for exact control")
	compare(track)
	await super.actual_app(track)

func compare(track: NativeTrack, visual: NativeTrackVisual = null) -> void:
	var original: Node3D = baseline.new()
	var revised := DesertSandWind.new()
	root.add_child(original); root.add_child(revised)
	original.configure(track, visual); revised.configure(track, visual)
	var canonical: PackedByteArray = var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash])
	var exact: bool = true
	var bounded: bool = true
	var queries: int = revised.source_queries
	var logical: int = revised.source_samples
	var points := PackedVector2Array()
	for lap: int in range(2):
		for index: int in range(240): points.append(track.route[index * track.route.size() / 240])
	for at: Vector2 in [Vector2(-28.001, -28.001), Vector2(-27.999, -27.999), Vector2(28.001,28.001), Vector2(0,0), Vector2(1000,1000), Vector2(-1000,-1000), track.route[0]]: points.append(at)
	for point: Vector2 in points:
		var old_center: Vector2 = revised.center
		original.present(1.0/60.0,point,0.65,false,false,0.75)
		revised.present(1.0/60.0,point,0.65,false,false,0.75)
		exact = exact and original.sources == revised.sources and original.anchor_roots == revised.anchor_roots and original.anchor_heights == revised.anchor_heights
		exact = exact and original.elapsed == revised.elapsed and original.lift_history == revised.lift_history and original.intensity == revised.intensity
		bounded = bounded and revised.crest_tiles.size() <= 9 and revised.anchor_roots.size() <= 512 and revised.source_queries <= revised.source_samples
		if old_center != revised.center:
			queries += revised.source_queries
			logical += revised.source_samples
	check(exact, "cached discovery preserves exact sources, roots, support and wind clocks through route loops, negative edges and teleports")
	check(bounded, "tile retention stays within nine tiles and existing root/work bounds")
	check(queries < logical*0.5, "moving route performs less than half the original support queries")
	check(var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash]) == canonical, "cache never changes canonical track data")
	revised.configure(track,visual)
	check(revised.source_queries > 0 and revised.crest_tiles.size() == 9, "configure invalidates cached support before rebuilding")
	print("DESERT_WIND_CACHE: queries=", queries," logical=",logical," ratio=",float(queries)/maxi(1,logical)," prepared=",visual!=null)
	original.free(); revised.free()

func capture(game: Node, track: NativeTrack, pass_index: int) -> void:
	if pass_index == 1: compare(track,game.track_ground)
	await super.capture(game,track,pass_index)
	if pass_index != 1: return
	var original: Node3D = baseline.new()
	game.get_node("World").add_child(original)
	original.configure(track,game.track_ground)
	var revised: DesertSandWind = game.desert_sand_wind
	revised.reset()
	var folder: String = capture_out + RenderingServer.get_current_rendering_method() + "/"
	for pose: int in range(3):
		var focus: Vector2 = track.route[pose*track.route.size()/3]
		original.show(); revised.show()
		original.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		revised.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		for tick: int in range(180):
			original.present(1.0/60.0,focus,0.65,false,false,0.75)
			revised.present(1.0/60.0,focus,0.65,false,false,0.75)
		game.sim.state.position = focus; game.previous_position = focus
		game.sim.state.velocity = Vector2.ZERO
		game.camera.follow(focus,Vector2.ZERO,0.0,0.0,true)
		revised.hide(); original.show()
		for settle: int in range(4): await draw(game)
		var before: Image = root.get_texture().get_image()
		original.hide(); revised.show()
		for settle: int in range(4): await draw(game)
		var after: Image = root.get_texture().get_image()
		check(before.get_data() == after.get_data(), "cached source selection renders pixel-exactly: pose%d" % pose)
		before.save_png(folder+"cache-before-%d.png" % pose)
		after.save_png(folder+"cache-after-%d.png" % pose)
	original.queue_free()
