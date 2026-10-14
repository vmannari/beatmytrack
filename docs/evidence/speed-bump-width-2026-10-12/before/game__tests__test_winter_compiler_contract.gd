extends SceneTree
const BEFORE: String = "res://../docs/evidence/winter-environment-2026-10-11/before/"
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
	var source: String = FileAccess.get_file_as_string(BEFORE+"game__editor__track_compiler.gd").replace("\r\n","\n").replace("class_name TrackCompiler\n","").replace("CreatorScenery.generate(","_baseline_generate(")
	var scenery: String = FileAccess.get_file_as_string(BEFORE+"game__editor__creator_scenery.gd").replace("\r\n","\n").replace("class_name CreatorScenery\n","").replace("extends RefCounted\n","").replace("static func generate(","static func _baseline_generate(").replace("static func key(","static func _baseline_scenery_key(").replace("key(object)","_baseline_scenery_key(object)")
	var baseline := GDScript.new()
	baseline.source_code = source+"\n"+scenery
	check(baseline.reload() == OK,"load exact compiler-22 and original scenery baseline")
	# Existing raster goldens retain compiler-20's metadata/hash prefix. Keep
	# their exact assertion, alongside a separate 22-to-23 geometry comparison.
	var historical := GDScript.new()
	historical.source_code = baseline.source_code.replace('"creator-compiler-22"','"creator-compiler-20"')
	check(historical.reload() == OK,"load historical golden version without changing geometry")
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE+"game__tests__fixtures__compiler_raster.json"))
	var upgraded: Dictionary = {}
	for kind: String in ["asphalt","dirt"]:
		for variant: int in range(4):
			var document: Dictionary = TrackDocument.create_default()
			document.surface = kind
			document.layout.surface = kind
			document.pieces = [RoadPieces.create("straight",Vector2(-25,0),0,12),RoadPieces.create("straight",Vector2(0,-25),90,8),RoadPieces.create("taper",Vector2(-20,-15),20,14),RoadPieces.create("curve",Vector2(10,-10),75,10)]
			document.objects = [{"kind":"water","position":[4,0],"rotation":0},{"kind":"dirt","position":[-5,-8],"rotation":0}]
			if variant == 1: document.layout = {}
			if variant >= 2: document.paint = [{"surface":1,"width":14.0,"shape":"round","points":[[-30,0],[30,0]],"protect_road":true},{"surface":2,"width":8.0,"shape":"square","points":[[0,-25],[0,25]]}]
			if variant == 3: document.theme = "desert"
			var old: NativeTrack = baseline.compile(document)
			var current: NativeTrack = TrackCompiler.compile(document)
			var key: String = kind+str(variant)
			check(fingerprint(historical.compile(document)) == prior[key],"historical compiler-20 golden remains exact: "+key)
			check(old.cells == current.cells and old.deck_cells == current.deck_cells and old.route == current.route and old.kerbs.triangles == current.kerbs.triangles,"compiler version preserves non-Winter geometry: "+key)
			var metadata: Dictionary = current.metadata.duplicate(true)
			metadata.version = old.metadata.version
			check(metadata == old.metadata,"only version changes non-Winter metadata: "+key)
			upgraded[key] = fingerprint(current)
	var winter: Dictionary = TrackDocument.create_default()
	winter.theme = "winter"
	var old_winter: NativeTrack = baseline.compile(winter)
	var new_winter: NativeTrack = TrackCompiler.compile(winter)
	check(old_winter.route == new_winter.route and old_winter.snow_banks.triangles == new_winter.snow_banks.triangles,"Winter route and prepared bank contacts remain exact")
	check(old_winter.content_hash != new_winter.content_hash and new_winter.metadata.version == "creator-compiler-24","new solid scenery has a distinct pinned contract")
	check(old_winter.metadata.scenery_objects.is_empty() and not new_winter.metadata.scenery_objects.is_empty(),"Winter compiler change adds explicit scenery objects")
	if failures == 0 and "--refresh-contract-fixtures" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://tests/fixtures/compiler_raster.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(upgraded,"\t",true)+"\n")
		var path: String = "res://../backend/tests/fixtures/verified_oval.json"
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		# Emit the two string fields and apply them to the original fixture text.
		# JSON serialization must never rewrite quantized replay integers.
		file = FileAccess.open("res://../docs/evidence/winter-environment-2026-10-11/backend-manifest-upgrade.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"compiler_version":TrackCompiler.VERSION,"track_content_hash":TrackCompiler.compile(fixture.document).content_hash}))
		var original: String = FileAccess.get_file_as_string(BEFORE+"backend__tests__fixtures__verified_oval.json")
		var previous: Dictionary = JSON.parse_string(original)
		assert(original.count(previous.expected_manifest.track_content_hash) == 1 and original.count("creator-compiler-22") == 1)
		var upgraded_text: String = original.replace(previous.expected_manifest.track_content_hash,TrackCompiler.compile(fixture.document).content_hash).replace("creator-compiler-22",TrackCompiler.VERSION)
		file = FileAccess.open(path,FileAccess.WRITE)
		file.store_string(upgraded_text)
		var variable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/variable_width_oval.json"))
		print("VARIABLE_WIDTH_COMPILER_23_HASH: ",TrackCompiler.compile(variable).content_hash)
	print("WINTER_COMPILER_CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
