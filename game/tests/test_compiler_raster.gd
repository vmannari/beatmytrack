extends SceneTree
## Golden complete-track output from the pre-optimization compiler.
const GOLDEN: String = "res://tests/fixtures/compiler_raster.json"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func fingerprint(track: NativeTrack) -> String:
	var bytes: PackedByteArray = var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.route_widths,track.route_radii,track.route_cut_radii,track.kerbs.triangles,track.kerbs.blocked,track.snow_banks.triangles,track.content_hash])
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func run() -> void:
	var write: bool = "--write-golden" in OS.get_cmdline_user_args()
	var corpus: bool = "--local-corpus" in OS.get_cmdline_user_args()
	var reference: GDScript
	if write or corpus:
		if not FileAccess.file_exists("res://../build/menu-selection-baseline/track_compiler.gd"):
			push_error("Place the pre-optimization compiler in build/menu-selection-baseline/track_compiler.gd before running this audit mode")
			quit(1)
			return
		reference = GDScript.new()
		reference.source_code = FileAccess.get_file_as_string("res://../build/menu-selection-baseline/track_compiler.gd").replace("\r\n","\n").replace("class_name TrackCompiler\n","")
		if reference.reload() != OK: quit(1); return
	var expected: Dictionary = {} if write else JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for kind: String in ["asphalt","dirt"]:
		for variant: int in range(4):
			var document: Dictionary = TrackDocument.create_default()
			document.surface = kind
			document.layout.surface = kind
			document.pieces = [RoadPieces.create("straight",Vector2(-25,0),0,12),RoadPieces.create("straight",Vector2(0,-25),90,8),RoadPieces.create("taper",Vector2(-20,-15),20,14),RoadPieces.create("curve",Vector2(10,-10),75,10)]
			document.objects = [{"kind":"water","position":[4,0],"rotation":0},{"kind":"dirt","position":[-5,-8],"rotation":0}]
			if variant == 1: document.layout = {}
			if variant >= 2:
				document.paint = [{"surface":1,"width":14.0,"shape":"round","points":[[-30,0],[30,0]],"protect_road":true},{"surface":2,"width":8.0,"shape":"square","points":[[0,-25],[0,25]]}]
			if variant == 3: document.theme = "desert"
			var key: String = kind+str(variant)
			var track: NativeTrack = reference.call("compile",document) if write else TrackCompiler.compile(document)
			if track == null: push_error("Invalid raster fixture "+key); quit(1); return
			if write: expected[key] = fingerprint(track)
			else:
				checks += 1
				if fingerprint(track) != expected[key]: failures += 1; print("FAIL raster golden ",key)
	if write:
		var output := FileAccess.open(GOLDEN,FileAccess.WRITE)
		output.store_string(JSON.stringify(expected,"\t",true)+"\n")
	if corpus:
		for document: Dictionary in TrackLibrary.new().list_documents():
			var before: NativeTrack = reference.call("compile",document)
			var after: NativeTrack = TrackCompiler.compile(document)
			checks += 1
			if before == null or after == null or fingerprint(before) != fingerprint(after):
				failures += 1
				print("FAIL local raster ",document.id)
	print("COMPILER_RASTER checks=",checks," failures=",failures," generated=",write)
	quit(1 if failures else 0)
