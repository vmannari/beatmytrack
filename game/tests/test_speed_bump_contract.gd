extends SceneTree
const BEFORE: String = "res://../docs/evidence/speed-bumps-2026-10-12/before/"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func fingerprint(track: NativeTrack) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.route_widths,track.route_radii,track.route_cut_radii,track.kerbs.triangles,track.kerbs.blocked,track.snow_banks.triangles,track.content_hash]))
	return hash.finish().hex_encode()
func run() -> void:
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string(BEFORE+"game__editor__track_compiler.gd").replace("\r\n","\n").replace("class_name TrackCompiler\n","")
	check(baseline.reload()==OK,"load exact compiler-23 baseline")
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE+"game__tests__fixtures__compiler_raster.json"))
	var updated: Dictionary = {}
	for kind: String in ["asphalt","dirt"]:
		for variant: int in range(4):
			var doc: Dictionary = TrackDocument.create_default()
			doc.surface = kind; doc.layout.surface = kind
			doc.pieces = [RoadPieces.create("straight",Vector2(-25,0),0,12),RoadPieces.create("straight",Vector2(0,-25),90,8),RoadPieces.create("taper",Vector2(-20,-15),20,14),RoadPieces.create("curve",Vector2(10,-10),75,10)]
			doc.objects = [{"kind":"water","position":[4,0],"rotation":0},{"kind":"dirt","position":[-5,-8],"rotation":0}]
			if variant == 1: doc.layout = {}
			if variant >= 2: doc.paint = [{"surface":1,"width":14.0,"shape":"round","points":[[-30,0],[30,0]],"protect_road":true},{"surface":2,"width":8.0,"shape":"square","points":[[0,-25],[0,25]]}]
			if variant == 3: doc.theme = "desert"
			var old: NativeTrack = baseline.compile(doc)
			var current: NativeTrack = TrackCompiler.compile(doc)
			var key: String = kind+str(variant)
			check(fingerprint(old) == prior[key],"original compiler-23 golden remains exact: "+key)
			var metadata: Dictionary = current.metadata.duplicate(true); metadata.version = old.metadata.version
			check(metadata == old.metadata and current.cells == old.cells and current.deck_cells == old.deck_cells and current.route == old.route and current.route_widths == old.route_widths and current.kerbs.triangles == old.kerbs.triangles and current.snow_banks.triangles == old.snow_banks.triangles,"existing geometry unchanged apart from pinned version/hash: "+key)
			updated[key] = fingerprint(current)
	# Same-engine no-bump state comparison against the exact prior physics.
	var physics := GDScript.new()
	physics.source_code = FileAccess.get_file_as_string(BEFORE+"game__vehicle__vehicle_simulation.gd").replace("\r\n","\n").replace("class_name VehicleSimulation\n","")
	check(physics.reload()==OK,"load exact physics-0.53 baseline")
	for theme: String in TrackDocument.THEMES:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var config: HandlingConfig = VehicleCatalog.config("compact")
		var old: RefCounted = physics.new(config)
		var current := VehicleSimulation.new(config)
		old.reset(track.spawn,track.spawn_heading); current.reset(track.spawn,track.spawn_heading)
		for tick: int in range(360):
			var frame := DriveFrame.new(); frame.throttle = 255 if tick%100 < 75 else 0; frame.brake = 128 if tick%100 >= 75 else 0; frame.steer = 30 if tick%180 < 90 else -30
			old.step(frame,track); current.step(frame,track)
			check(old.state.snapshot() == current.state.snapshot(),theme+" no-bump canonical state is byte-exact to prior physics")
	if failures == 0 and "--refresh-bump-golden" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://tests/fixtures/compiler_raster.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(updated,"\t",true)+"\n")
	print("SPEED_BUMP_CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
