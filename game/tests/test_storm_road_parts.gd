extends "res://backend/runner.gd"
## Uses the canonical import validator, not just the permissive map compiler.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
const OUTPUT: String = "res://../docs/evidence/storm-driving-variety-2026-10-26"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var rows: Array[Dictionary] = []
	for id: String in IDS:
		var path: String = OUTPUT+"/before/game/resources/storm_tracks/"+id+".json" if before else "res://resources/storm_tracks/"+id+".json"
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(document.layout.is_empty() and document.base_track.is_empty(),id+" uses parts exclusively, without a painted/fallback road layout")
		check(document.pieces.size()>=20,id+" substantial editor road-part assembly")
		check(document.has("start_line"),id+" explicit start line")
		var all_standard: bool = true
		for part: Dictionary in document.pieces:
			all_standard = all_standard and part.kind in ["straight","curve","hairpin","s_bend","taper","bridge"] and RoadPieces.validate(part).is_empty()
		check(all_standard,id+" all parts are normal supported palette parts")
		var generated: Dictionary = RoadPieces.route_from_pieces(document)
		check(generated.ok,id+" actual Test drive connected-road validation: "+str(generated.errors))
		var compiled: Dictionary = compile_track(document)
		check(not compiled.has("error"),id+" canonical import/publication validation: "+str(compiled.get("error","")))
		rows.append({"id":id,"parts":document.pieces.size(),"has_start_line":document.has("start_line"),"route_ok":generated.ok,"canonical_error":compiled.get("error",""),"source_sha256":FileAccess.get_sha256(path)})
		if generated.ok:
			# Compare exactly at the actual saved-document boundary. Float32 route
			# points widen during JSON parsing; canonical validation also checks
			# the physical 2 mm bound independently, without changing its rules.
			var persisted: Dictionary = JSON.parse_string(JSON.stringify(generated.document,"\t"))
			check(document.points==persisted.points and document.corners==persisted.corners and PackedFloat32Array(document.widths)==PackedFloat32Array(persisted.widths),id+" stored route comes from the editor's exact persisted generation")
		if not compiled.has("error"):
			var owner: Dictionary = document.duplicate(true); owner.creator = "Ville"
			check(not compile_track(owner).has("error"),id+" Ville draft also passes canonical validation")
	var file := FileAccess.open(OUTPUT+("/original-validation.json" if before else "/parts-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"tracks":rows},"\t")); file.close()
	print("STORM_ROAD_PARTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
