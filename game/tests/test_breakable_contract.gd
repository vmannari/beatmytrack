extends SceneTree
## Verify prior geometry and untouched driving before refreshing new contract identities.
const BEFORE: String = "res://../docs/evidence/breakable-props-2026-10-12/before/"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func load_before(filename: String, class_line: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(BEFORE+filename).replace("\r\n","\n").replace(class_line+"\n","")
	check(script.reload() == OK,"load preserved baseline "+filename)
	return script
func fingerprint(track: NativeTrack) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.route_widths,track.route_radii,track.route_cut_radii,track.kerbs.triangles,track.kerbs.blocked,track.snow_banks.triangles,track.content_hash]))
	return hash.finish().hex_encode()
func run() -> void:
	var compiler: GDScript = load_before("game__editor__track_compiler.gd","class_name TrackCompiler")
	var old_light: GDScript = load_before("game__vehicle__light_props.gd","class_name LightProps")
	var old_physics: GDScript = load_before("game__vehicle__vehicle_simulation.gd","class_name VehicleSimulation")
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE+"game__tests__fixtures__compiler_raster.json"))
	var updated: Dictionary = {}
	for surface: String in ["asphalt","dirt"]:
		for variant: int in range(4):
			var doc: Dictionary = TrackDocument.create_default(); doc.surface = surface; doc.layout.surface = surface
			doc.pieces = [RoadPieces.create("straight",Vector2(-25,0),0,12),RoadPieces.create("straight",Vector2(0,-25),90,8),RoadPieces.create("taper",Vector2(-20,-15),20,14),RoadPieces.create("curve",Vector2(10,-10),75,10)]
			doc.objects = [{"kind":"water","position":[4,0],"rotation":0},{"kind":"dirt","position":[-5,-8],"rotation":0}]
			if variant == 1: doc.layout = {}
			if variant >= 2: doc.paint = [{"surface":1,"width":14.0,"shape":"round","points":[[-30,0],[30,0]],"protect_road":true},{"surface":2,"width":8.0,"shape":"square","points":[[0,-25],[0,25]]}]
			if variant == 3: doc.theme = "desert"
			var old: NativeTrack = compiler.compile(doc); var current: NativeTrack = TrackCompiler.compile(doc)
			var key: String = surface+str(variant)
			check(fingerprint(old) == prior[key],"preserved compiler-25 raster golden remains exact: "+key)
			var metadata: Dictionary = current.metadata.duplicate(true); metadata.version = old.metadata.version
			check(metadata == old.metadata and current.cells == old.cells and current.deck_cells == old.deck_cells and current.route == old.route and current.route_widths == old.route_widths and current.kerbs.triangles == old.kerbs.triangles and current.snow_banks.triangles == old.snow_banks.triangles,"all prepared geometry remains exact apart from compiler identity: "+key)
			updated[key] = fingerprint(current)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	for biome: String in TrackTheme.IDS:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = biome
		var track: NativeTrack = TrackCompiler.compile(doc)
		var old: RefCounted = old_physics.new(config); var current := VehicleSimulation.new(config)
		old.reset(track.spawn,track.spawn_heading); current.reset(track.spawn,track.spawn_heading)
		for tick: int in range(360):
			var frame := DriveFrame.new(); frame.throttle = 255 if tick%100 < 75 else 0; frame.brake = 128 if tick%100 >= 75 else 0; frame.steer = 30 if tick%180 < 90 else -30
			old.step(frame,track); current.step(frame,track)
			check(old.state.snapshot() == current.state.snapshot() and current.state.snapshot()[23] == [[],[]],biome+" unchanged no-breakable full physics state")
	for kind: String in ["cone","chevron","braking_board","barrel"]:
		var props: Array = [{"kind":kind,"position":[0,0],"rotation":0}]
		var old := VehicleState.new(); var current := VehicleState.new()
		old.position = Vector2(0,-0.8); old.velocity = Vector2(0,12)
		current.position = old.position; current.velocity = old.velocity
		for tick: int in range(100):
			old_light.step(old,props,clear,old.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			LightProps.step(current,props,clear,current.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			check(old.snapshot() == current.snapshot(),kind+" keeps exact legacy movable behavior")
	var starter: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	print("BREAKABLE_STARTER_HASH: ",starter.content_hash)
	if failures == 0 and "--refresh-breakable-golden" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://tests/fixtures/compiler_raster.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(updated,"\t",true)+"\n"); file.close()
	print("BREAKABLE_CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func clear(_p: Vector2, _radius: float, _deck: bool) -> Vector3: return Vector3.ZERO
