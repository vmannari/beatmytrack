extends SceneTree
## Compare support buffers with the previous constructor, including bridge mouths.
const HEIGHT = preload("res://track/road_surface_height.gd")
const CACHE = preload("res://track/road_support_cache.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func snapshot(support: RefCounted) -> PackedByteArray:
	return var_to_bytes([support.lift,support.floors,support.floor_bins])

func run() -> void:
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://tests/fixtures/loading_road_support_before.gd.txt")
	check(before.reload() == OK,"previous implementation compiles")
	if failures: quit(1); return
	for fixture: String in ["star_spline_lap","spline_circuit","underpass","knot","silmukka","ajorata","to_the_trees"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
		var track: NativeTrack = TrackCompiler.compile(document)
		check(track != null,fixture+" compiles")
		if track == null: continue
		# Exercise raised support even if the fixture originally has loose terrain.
		track.metadata.theme = "pine"
		track.metadata.creator_document.surface = "asphalt"
		CACHE.trim()
		var began: int = Time.get_ticks_usec()
		var old: RefCounted = before.new(track)
		var old_us: int = Time.get_ticks_usec()-began
		began = Time.get_ticks_usec()
		var current: RefCounted = HEIGHT.new(track)
		var new_us: int = Time.get_ticks_usec()-began
		check(not current.floors.is_empty(),fixture+" exercises support geometry")
		check(snapshot(old) == snapshot(current),fixture+" exact contours, order, spatial bins and lift")
		var sampled: int = 0
		var equal: bool = true
		for polygon: PackedVector2Array in current.floors:
			for point: Vector2 in polygon:
				for offset: Vector2 in [Vector2.ZERO,Vector2(0.001,0.001),Vector2(-0.001,-0.001)]:
					equal = equal and old.on_floor(point+offset) == current.on_floor(point+offset)
					sampled += 1
		check(equal,fixture+" boundary inclusion stays exact")
		rows.append({"fixture":fixture,"before_us":old_us,"after_us":new_us,"boundary_samples":sampled,"exact":snapshot(old)==snapshot(current)})
		check(snapshot(HEIGHT.new(track)) == snapshot(old),fixture+" cached result exact")
		current.floors[0][0] += Vector2(100,100)
		current.floors.clear()
		current.floor_bins.values()[0].clear()
		current.floor_bins.clear()
		check(snapshot(HEIGHT.new(track)) == snapshot(old),fixture+" consumer mutation cannot poison cache")
		if fixture == "star_spline_lap":
			var times: Array = []
			# Alternate order after an unmeasured construction of both paths.
			for cycle: int in range(8):
				var pair: Dictionary = {}
				for optimized: bool in ([false,true] if cycle%2 == 0 else [true,false]):
					began = Time.get_ticks_usec()
					var support: RefCounted = HEIGHT.new(track) if optimized else before.new(track)
					pair["after_us" if optimized else "before_us"] = Time.get_ticks_usec()-began
					check(snapshot(support)==snapshot(old),"timed construction retains exact support")
				times.append(pair)
			rows[-1]["interleaved"] = times
		# A changed width on the same track object must produce a new entry.
		var pieces: Array = track.metadata.creator_document.pieces
		var width: float = float(pieces[0].width)
		var count_before: int = CACHE.entries.size()
		pieces[0].width = width+0.5
		check(snapshot(HEIGHT.new(track)) == snapshot(before.new(track)),fixture+" in-place edit invalidates cached support")
		check(CACHE.entries.size() == count_before+1,fixture+" edited source has a separate cache entry")
		pieces[0].width = width
		for theme: String in ["desert","winter"]:
			track.metadata.theme = theme
			check(snapshot(before.new(track)) == snapshot(HEIGHT.new(track)),fixture+" "+theme+" unchanged")
		await process_frame
	var retired: int = CACHE.generation
	CACHE.trim()
	check(CACHE.entries.is_empty() and CACHE.bytes_used() == 0,"memory trim releases all support data")
	CACHE.write("retired",{"value":1},retired)
	check(CACHE.entries.is_empty(),"in-flight old work cannot republish after pressure")
	var track := TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/underpass.json")))
	for index: int in range(7):
		track.metadata.creator_document.pieces[0].width = 8.0+index
		HEIGHT.new(track)
	check(CACHE.entries.size() == 4,"support entries bounded to four")
	check(CACHE.bytes_used() <= CACHE.MAX_BYTES,"support respects its byte budget")
	CACHE.trim()
	var large := PackedByteArray()
	large.resize(CACHE.MAX_BYTES)
	CACHE.write("oversized",{"data":large},CACHE.generation)
	check(CACHE.entries.is_empty(),"oversized entries are not retained")
	var result := {"checks":checks,"failures":failures,"rows":rows}
	var output: String = OS.get_environment("BMT_LOADING_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		check(file != null,"write evidence")
		if file != null: file.store_string(JSON.stringify(result,"  "))
	print("LOADING_ROAD_SUPPORT ",JSON.stringify(result))
	quit(1 if failures else 0)
