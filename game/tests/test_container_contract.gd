extends SceneTree
## Geometry stays exact; only the newly accepted cosmetic document/pin changes.
const BEFORE: String = "res://../docs/evidence/container-refinement-2026-10-12/before/"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func fingerprint(track: NativeTrack) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.route_widths,track.route_radii,track.route_cut_radii,track.kerbs.triangles,track.kerbs.blocked,track.snow_banks.triangles,track.content_hash]))
	return hash.finish().hex_encode()
func run() -> void:
	var compiler := GDScript.new()
	compiler.source_code = FileAccess.get_file_as_string(BEFORE+"game__editor__track_compiler.gd").replace("\r\n","\n").replace("class_name TrackCompiler\n","")
	check(compiler.reload() == OK,"load exact preserved compiler-26")
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
			check(fingerprint(old) == prior[key],"preserved compiler-26 golden exact: "+key)
			var metadata: Dictionary = current.metadata.duplicate(true); metadata.version = old.metadata.version
			check(metadata == old.metadata and current.cells == old.cells and current.deck_cells == old.deck_cells and current.route == old.route and current.route_widths == old.route_widths and current.kerbs.triangles == old.kerbs.triangles and current.snow_banks.triangles == old.snow_banks.triangles,"prepared geometry unchanged apart from compiler pin: "+key)
			updated[key] = fingerprint(current)
	for color: String in ContainerPaint.SWATCHES:
		var doc: Dictionary = TrackDocument.create_default(); doc["automatic_scenery"] = false
		doc.objects = [{"kind":"container","position":[-6,0],"rotation":35,"scale":1.5}]
		var old: NativeTrack = compiler.compile(doc)
		doc.objects[0]["color"] = color
		var painted: NativeTrack = TrackCompiler.compile(doc)
		check(painted.cells == old.cells and painted.deck_cells == old.deck_cells and painted.route == old.route and painted.kerbs.triangles == old.kerbs.triangles,"paint never alters rotated/scaled collision or gates")
	var starter: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	print("CONTAINER_STARTER_HASH: ",starter.content_hash)
	if failures == 0 and "--refresh-container-golden" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://tests/fixtures/compiler_raster.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(updated,"\t",true)+"\n"); file.close()
	print("CONTAINER_CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
