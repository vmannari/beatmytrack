extends SceneTree
## Uniform/variable spline loops exercise the no-hairpin reuse branch.
const CACHE = preload("res://race/checkpoint_layout_cache.gd")
const BEFORE := "res://../docs/evidence/checkpoint-preparation-2026-11-05/before/game/race/"
var checks: int = 0
var failures: int = 0
class CustomTrack extends NativeTrack:
	pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var corridor := GDScript.new()
	corridor.source_code = FileAccess.get_file_as_string(BEFORE+"spline_gate_corridor.gd").replace("class_name SplineGateCorridor","")
	check(corridor.reload() == OK,"original corridor compiles")
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string(BEFORE+"track_session.gd").replace("class_name TrackSession","").replace("SplineGateCorridor.select(self,track)","_reference_corridor.select(self,track)")+"\nvar _reference_corridor: GDScript\n"
	check(reference.reload() == OK,"original session compiles")
	for variable: bool in [false,true]:
		var piece: Dictionary = RoadPieces.create("spline",Vector2(-20,-20),0.0,8.0)
		piece.spline_points = [[0.0,0.0],[40.0,0.0],[40.0,40.0],[0.0,40.0],[0.0,0.0]]
		piece.point_widths = [6.0,8.0,12.0,8.0,6.0] if variable else [8.0,8.0,8.0,8.0,8.0]
		piece.width = piece.point_widths.max()
		var doc: Dictionary = TrackDocument.create_blank(); doc.pieces = [piece]
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,"closed spline compiles")
		if track == null: continue
		var old: RefCounted = reference.new(); old._reference_corridor = corridor
		var began: int = Time.get_ticks_usec(); old._configure(track)
		var old_us: int = Time.get_ticks_usec()-began
		var expected: PackedByteArray = var_to_bytes(track._race_gates)
		track._race_gates = {}; CACHE.trim_to()
		var current := TrackSession.new()
		began = Time.get_ticks_usec(); current._configure(track)
		var fresh_us: int = Time.get_ticks_usec()-began
		check(var_to_bytes(track._race_gates) == expected,"no-hairpin layout is byte-exact")
		var hairpins: int = 0
		for corner: Dictionary in current._road_corners(track):
			if float(corner.half_span) >= float(corner.road_half)*SplineGateCorridor.HAIRPIN_MITER_RATIO: hairpins += 1
		check(hairpins == 0 and current._spline_corridor,"fixture exercises spline with no folded hairpins")
		print("LANE_REUSE_ROW ",JSON.stringify({"variable":variable,"before_us":old_us,"fresh_us":fresh_us,"bytes":expected.size(),"gates":current.checkpoint_count()}))
		var versions: Array = [RaceRules.KEY,TrackSession.NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]
		var key: String = CACHE.key_for(track,versions)
		for field: String in ["cell_size","grid_width","grid_height","route_length","bridge_height","finish_half_width"]:
			var original: Variant = track.get(field)
			track.set(field,original+1)
			check(CACHE.key_for(track,versions) != key,"cache fences "+field)
			track.set(field,original)
		for field: String in ["cells","deck_cells","route_widths","route_cumulative","route_radii","route_cut_radii"]:
			var original: Variant = track.get(field)
			var altered: Variant = original.duplicate()
			altered.append(123)
			track.set(field,altered)
			check(CACHE.key_for(track,versions) != key,"cache fences "+field)
			track.set(field,original)
		track.kerbs.maximum_height += 1.0
		check(CACHE.key_for(track,versions) != key,"kerb inputs fence reuse")
	check(CACHE.key_for(CustomTrack.new(),[]) == "","unknown query subclasses bypass shared cache")
	CACHE.trim_to()
	print("CHECKPOINT_LANE_REUSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
