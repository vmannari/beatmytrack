extends "res://tests/test_desert_wind_sync.gd"
const PLACES_OUT: String = "res://../docs/evidence/desert-sand-places-2026-10-24/"
var original_sand: GDScript

func _initialize() -> void:
	super._initialize()
	capture_out = PLACES_OUT

func actual_app(track: NativeTrack) -> void:
	original_sand = GDScript.new()
	original_sand.source_code = FileAccess.get_file_as_string(PLACES_OUT + "before/game/track/desert_sand_wind.gd").replace("class_name DesertSandWind\r\n", "").replace("class_name DesertSandWind\n", "")
	check(original_sand.reload() == OK, "task-entry six-site source selector compiles for coverage control")
	coverage(track)
	await super.actual_app(track)

func coverage(track: NativeTrack, visual: NativeTrackVisual = null, label: String = "track") -> void:
	var before: Node3D = original_sand.new()
	var after := DesertSandWind.new()
	root.add_child(before); root.add_child(after)
	before.configure(track, visual); after.configure(track, visual)
	var old_total: int = 0
	var new_total: int = 0
	var old_sites: Dictionary = {}
	var new_sites: Dictionary = {}
	var added_positions: int = 0
	var rows: Array[Dictionary] = []
	for index: int in range(80):
		var focus: Vector2 = track.route[index * track.route.size() / 80]
		before.present(0.1, focus, 0.65, false, false, 0.75)
		after.present(0.1, focus, 0.65, false, false, 0.75)
		var old_count: int = 0
		var new_count: int = 0
		for source: Vector2 in before.sources:
			if source.distance_to(focus) < 18.0: old_count += 1; old_sites[source] = true
		for source: Vector2 in after.sources:
			if source.distance_to(focus) < 18.0: new_count += 1; new_sites[source] = true
		old_total += old_count; new_total += new_count
		if new_count > old_count: added_positions += 1
		rows.append({"position":index,"before":old_count,"after":new_count})
	check(new_total >= old_total * 1.40, "at least 40 percent more readable-range dune sites along the route: " + label)
	check(added_positions >= 48, "more nearby source locations at most route positions: " + label)
	check(after.plumes.multimesh.instance_count == 96 and after.sources.size() <= 12, "one bounded 96-quad batch covers the additional sites: " + label)
	check(after.source_samples <= 8192 and after.anchor_roots.size() <= 512, "more active sites retain existing discovery bounds: " + label)
	print("SAND_PLACES_COVERAGE: ", label, " old=", old_total, " new=", new_total, " added_positions=", added_positions, "/80 unique=", old_sites.size(), "/", new_sites.size())
	var folder: String = capture_out + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var output := FileAccess.open(folder + "coverage-" + label + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"before":old_total,"after":new_total,"added_positions":added_positions,"positions":80,"unique_before":old_sites.size(),"unique_after":new_sites.size(),"samples":rows}, "\t")); output.close()
	before.free(); after.free()

func capture(game: Node, track: NativeTrack, pass_index: int) -> void:
	if pass_index == 1: coverage(track, game.track_ground, "prepared")
	await super.capture(game, track, pass_index)
	if pass_index != 1: return
	var folder: String = capture_out + RenderingServer.get_current_rendering_method() + "/"
	var before: Node3D = original_sand.new()
	game.get_node("World").add_child(before)
	before.configure(track, game.track_ground)
	var after: DesertSandWind = game.desert_sand_wind
	after.reset()
	var focus := Vector2(0, -18)
	for tick: int in range(8 * 60):
		before.present(1.0 / 60.0, focus, 0.65, false, false, 0.75)
		after.present(1.0 / 60.0, focus, 0.65, false, false, 0.75)
	after.hide()
	for settle: int in range(5): await draw(game)
	var old_image: Image = root.get_texture().get_image()
	before.hide(); after.show()
	for settle: int in range(5): await draw(game)
	var new_image: Image = root.get_texture().get_image()
	check(old_image.save_png(folder + "places-before.png") == OK and new_image.save_png(folder + "places-after.png") == OK, "same-camera six/twelve-site native comparison saved")
	var pixels: int = changes(old_image, new_image)
	check(pixels >= 1000, "additional dune sources actually draw in the ordinary game camera")
	print("SAND_PLACES_NATIVE: added_pixels=", pixels, " before=", before.sources.size(), " after=", after.sources.size())
	before.queue_free()
