extends SceneTree
## Real valid-domain data across the durable writer's byte boundary.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "byte_admission"
	var object: Dictionary = {"kind":"grass_clump","position":[12.1234567890123,-34.1234567890123],"rotation":123.123456789012,"scale":1.1234567890123}
	for index: int in range(4096): doc.objects.append(object.duplicate(true))
	var points: Array = []
	for index: int in range(512): points.append([12.1234567890123,-34.1234567890123])
	for index: int in range(32): doc.paint.append({"surface":2,"width":1.0,"shape":"round","points":points.duplicate(true)})
	# Fit in at most twelve size queries; never incrementally stringify a
	# growing maximum-sized fixture thousands of times.
	var low: int = 0; var high: int = doc.objects.size()
	while low < high:
		var middle: int = (low+high+1)/2
		var trial: Dictionary = doc.duplicate(); trial.objects = doc.objects.slice(0,middle)
		if JSON.stringify(trial,"",true).to_utf8_buffer().size() <= TrackDocument.MAX_BYTES: low = middle
		else: high = middle-1
	doc.objects = doc.objects.slice(0,low)
	check(low > 0 and low < 4096,"real domain data straddles the byte ceiling")
	check(TrackDocument.validate(doc,false).is_empty(),"byte fixture respects all domain limits")
	var canvas := EditorCanvas.new(); canvas.document = doc
	var proposed: Array = doc.objects+[object]
	check(not canvas.admit("objects",proposed),"one valid object above the byte ceiling is rejected")
	check(canvas.document == doc and canvas.document.objects.size() == low,"rejected candidate leaves exact live data")
	var library := TrackLibrary.new("user://editor_byte_admission")
	check(library.save_wip(doc) == OK,"admitted document remains durably writable")
	check(library.load_wip(doc.id) == JSON.parse_string(JSON.stringify(doc,"",true)),"recovery matches all admitted data")
	var closed: Dictionary = doc.duplicate(); closed.pieces = []
	var position := Vector2(-28,-18); var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0; piece.radius = 18.0
		closed.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); position = pose.position; heading = pose.heading
	var excess: int = JSON.stringify(closed,"",true).to_utf8_buffer().size()-TrackDocument.MAX_BYTES
	var per_object: int = JSON.stringify(object,"",true).to_utf8_buffer().size()+1
	closed.objects = closed.objects.slice(0,low-maxi(0,ceili(float(excess)/per_object)))
	var derived: Dictionary = RoadPieces.route_from_pieces(closed)
	check(derived.ok,"closed near-limit fixture has an exact derived lap")
	check(JSON.stringify(closed,"",true).to_utf8_buffer().size() <= TrackDocument.MAX_BYTES and JSON.stringify(derived.document,"",true).to_utf8_buffer().size() > TrackDocument.MAX_BYTES,"route derivation alone crosses the durable byte ceiling")
	var base: Dictionary = closed.duplicate(); base.pieces = []; canvas.document = base
	check(not canvas.admit("pieces",closed.pieces),"admission accounts for the writer's larger derived route")
	check(canvas.document.pieces.is_empty(),"rejected derived route leaves pending road outside live data")
	canvas.free()
	print("EDITOR_ADMISSION_BYTES: %d checks, %d failures; objects=%d bytes=%d" % [checks,failures,low,JSON.stringify(doc,"",true).to_utf8_buffer().size()])
	quit(1 if failures else 0)
